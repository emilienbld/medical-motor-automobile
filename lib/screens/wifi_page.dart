import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart' as loc;
import 'package:device_info_plus/device_info_plus.dart';
import '../services/wifi_connection_manager.dart';

class WifiPage extends StatefulWidget {
  const WifiPage({Key? key}) : super(key: key);

  @override
  State<WifiPage> createState() => _WifiPageState();
}

class _WifiPageState extends State<WifiPage> {
  bool isConnected = false;
  bool isConnecting = false;
  bool isScanning = false;
  String arduinoIP = '192.168.4.1';
  String connectionStatus = 'Déconnecté';
  String signalStrength = 'N/A';
  List<WiFiAccessPoint> scannedNetworks = [];
  List<Map<String, dynamic>> availableDevices = [];
  StreamSubscription<List<WiFiAccessPoint>>? _subscription;
  StreamSubscription<bool>? _connectionSubscription; // NOUVELLE LIGNE À AJOUTER
  final WiFiConnectionManager _connectionManager =
      WiFiConnectionManager(); // NOUVELLE LIGNE À AJOUTER

  // Filtres pour identifier les appareils Arduino/ESP32
  final List<String> arduinoIdentifiers = [
    'arduino',
    'r4',
    'esp32',
    'esp-32',
    'esp8266',
    'nodemcu',
    'wemos',
    'ziggycar',
    'arduinoap'
  ];

  // Préfixes MAC connus pour ESP32 (utilisé dans Arduino R4 WiFi)
  final List<String> knownMacPrefixes = [
    '94:b9',
    '34:85',
    'ac:67',
    '24:6f',
    '30:ae',
    'ec:94'
  ];

  final TextEditingController _ipController = TextEditingController();

  // REMPLACEZ votre méthode initState() par celle-ci :

  @override
  void initState() {
    super.initState();
    _ipController.text = arduinoIP;
    _requestPermissions();

    // 🔄 Récupérer l'état actuel et écouter les changements
    _syncWithConnectionManager();
    _listenToConnectionChanges();

    // ❤️ Relancer le heartbeat à chaque ouverture de la page
    if (_connectionManager.isConnected) {
      _connectionManager.startHeartbeat();
    }
  }

// AJOUTEZ ces deux nouvelles méthodes après initState() :

  void _syncWithConnectionManager() {
    final status = _connectionManager.getConnectionStatus();
    setState(() {
      isConnected = status['isConnected'];
      arduinoIP = status['arduinoIP'];
      connectionStatus = isConnected ? 'Connecté' : 'Déconnecté';
      signalStrength = isConnected ? 'Fort' : 'N/A';
    });
    print('🔄 Synchronisation avec ConnectionManager: $status');
  }

  void _listenToConnectionChanges() {
    _connectionSubscription =
        _connectionManager.connectionStream.listen((connected) {
      print('📡 Changement de connexion reçu: $connected');
      setState(() {
        isConnected = connected;
        connectionStatus = connected ? 'Connecté' : 'Déconnecté';
        signalStrength = connected ? 'Fort' : 'N/A';

        // Mettre à jour l'état des appareils dans la liste
        for (var device in availableDevices) {
          device['isConnected'] =
              connected && device['ip'] == _connectionManager.arduinoIP;
        }
      });
    });
  }

  Future<bool> _checkLocationService() async {
    loc.Location location = loc.Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Le GPS doit être activé pour scanner les réseaux WiFi'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _requestPermissions() async {
    // Demander les permissions nécessaires
    final permissions = [
      Permission.location,
      Permission.locationWhenInUse,
      // Ajouter Permission.nearbyWifiDevices pour Android 13+
      if (Platform.isAndroid) Permission.nearbyWifiDevices,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (allGranted) {
      _scanForWifiNetworks();
      _startListeningToScannedResults();
    } else {
      // Vérifier si l'utilisateur a refusé définitivement
      if (statuses.values.any((status) => status.isPermanentlyDenied)) {
        // Suggérer d'ouvrir les paramètres
        await openAppSettings();
      } else {
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions requises'),
        content: const Text(
          'L\'application a besoin de la permission de localisation pour scanner les réseaux WiFi. '
          'Veuillez activer les permissions dans les paramètres.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Paramètres'),
          ),
        ],
      ),
    );
  }

  void _openWifiSettings() {
    if (Platform.isAndroid) {
      final intent = AndroidIntent(
        action: 'android.settings.WIFI_SETTINGS',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      intent.launch();
    }
  }

  Future<void> _scanForWifiNetworks() async {
    setState(() {
      isScanning = true;
      availableDevices.clear();
    });

    try {
      // Vérifier d'abord que le GPS est activé
      bool locationEnabled = await _checkLocationService();
      if (!locationEnabled) {
        setState(() {
          isScanning = false;
        });
        return;
      }

      // Vérifier les permissions
      final status = await Permission.location.status;
      if (!status.isGranted) {
        final result = await Permission.location.request();
        if (!result.isGranted) {
          throw Exception('Permission de localisation refusée');
        }
      }

      // Pour Android 13+, vérifier aussi NEARBY_WIFI_DEVICES
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        if (info.version.sdkInt >= 33) {
          final nearbyStatus = await Permission.nearbyWifiDevices.status;
          if (!nearbyStatus.isGranted) {
            await Permission.nearbyWifiDevices.request();
          }
        }
      }

      // Vérifier si le WiFi est activé
      final canGetScannedResults =
          await WiFiScan.instance.canGetScannedResults(askPermissions: true);

      print('Can get scanned results: $canGetScannedResults');

      if (canGetScannedResults != CanGetScannedResults.yes) {
        String errorMsg = 'Impossible de scanner les réseaux WiFi';

        switch (canGetScannedResults) {
          case CanGetScannedResults.noLocationPermissionRequired:
            errorMsg = 'Permission de localisation requise';
            break;
          case CanGetScannedResults.noLocationPermissionDenied:
            errorMsg = 'Permission de localisation refusée';
            break;
          case CanGetScannedResults.noLocationPermissionUpgradeAccuracy:
            errorMsg = 'Localisation précise requise';
            break;
          case CanGetScannedResults.noLocationServiceDisabled:
            errorMsg = 'Service de localisation désactivé';
            break;
          case CanGetScannedResults.notSupported:
            errorMsg = 'Scan WiFi non supporté sur cet appareil';
            break;
          default:
            break;
        }

        throw Exception(errorMsg);
      }

      // Démarrer le scan
      final canStartScan = await WiFiScan.instance.canStartScan();
      print('Can start scan: $canStartScan');

      if (canStartScan == CanStartScan.yes) {
        final started = await WiFiScan.instance.startScan();
        print('Scan started: $started');

        // Attendre plus longtemps pour le scan
        await Future.delayed(const Duration(seconds: 5));
      } else {
        print('Cannot start scan: $canStartScan');

        // Essayer quand même de récupérer les derniers résultats
        String cannotStartMsg = 'Impossible de démarrer le scan';

        switch (canStartScan) {
          case CanStartScan.notSupported:
            cannotStartMsg = 'Scan non supporté';
            break;
          case CanStartScan.noLocationPermissionRequired:
            cannotStartMsg = 'Permission de localisation requise';
            break;
          case CanStartScan.noLocationPermissionDenied:
            cannotStartMsg = 'Permission de localisation refusée';
            break;
          case CanStartScan.noLocationPermissionUpgradeAccuracy:
            cannotStartMsg = 'Localisation précise requise';
            break;
          case CanStartScan.noLocationServiceDisabled:
            cannotStartMsg = 'GPS désactivé';
            break;
          case CanStartScan.failed:
            cannotStartMsg = 'Échec du scan';
            break;
          default:
            break;
        }

        print(cannotStartMsg);
      }

      // Récupérer les résultats
      final results = await WiFiScan.instance.getScannedResults();
      print('Scan results count: ${results.length}');

      // Logger les résultats pour debug
      for (var network in results) {
        print(
            'Network found: ${network.ssid} - Signal: ${network.level} dBm - BSSID: ${network.bssid}');
      }

      setState(() {
        scannedNetworks = results;
        _filterArduinoDevices();
      });

      // Si aucun réseau trouvé, suggérer des solutions
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucun réseau trouvé. Vérifiez que:\n'
              '• Le WiFi est activé\n'
              '• Le GPS est activé\n'
              '• Les permissions sont accordées',
            ),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Erreur lors du scan WiFi: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur scan WiFi: ${e.toString()}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Paramètres',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    } finally {
      setState(() {
        isScanning = false;
      });
    }
  }

  Future<void> _debugWifiPermissions() async {
    print('=== DEBUG WIFI PERMISSIONS ===');

    // Vérifier toutes les permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.locationAlways,
      Permission.nearbyWifiDevices,
    ].request();

    statuses.forEach((permission, status) {
      print('$permission: $status');
    });

    // Vérifier le service de localisation
    loc.Location location = loc.Location();
    bool serviceEnabled = await location.serviceEnabled();
    print('Location service enabled: $serviceEnabled');

    // Vérifier les capacités WiFi
    final canGetResults = await WiFiScan.instance.canGetScannedResults();
    print('Can get scanned results: $canGetResults');

    final canStartScan = await WiFiScan.instance.canStartScan();
    print('Can start scan: $canStartScan');

    // Info sur l'appareil
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      print('Android SDK: ${info.version.sdkInt}');
      print('Android version: ${info.version.release}');
    }

    print('=== END DEBUG ===');
  }

  void _showManualAddDialog() {
    final ssidController = TextEditingController();
    final ipController = TextEditingController(text: '192.168.4.1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter manuellement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Si le scan ne fonctionne pas, vous pouvez ajouter '
              'manuellement votre Arduino.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ssidController,
              decoration: const InputDecoration(
                labelText: 'Nom du réseau (SSID)',
                hintText: 'Ex: ArduinoAP',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'Adresse IP',
                hintText: '192.168.4.1',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            const Text(
              'Assurez-vous d\'être connecté au réseau WiFi de votre Arduino '
              'dans les paramètres WiFi de votre téléphone.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ssidController.text.isNotEmpty) {
                // Ajouter manuellement à la liste
                setState(() {
                  availableDevices.add({
                    'name': ssidController.text,
                    'ip': ipController.text,
                    'type': 'Arduino (Manuel)',
                    'signal': 'Manuel',
                    'signalLevel': -50,
                    'capabilities': 'N/A',
                    'frequency': 2400,
                    'bssid': 'Manual',
                    'isConnected': false,
                  });
                });
                Navigator.pop(context);

                // Suggérer de se connecter
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Réseau ajouté. Connectez-vous au WiFi Arduino puis appuyez sur Connecter.'),
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _startListeningToScannedResults() async {
    // Annuler l'abonnement précédent s'il existe
    _subscription?.cancel();

    final can =
        await WiFiScan.instance.canGetScannedResults(askPermissions: true);
    if (can != CanGetScannedResults.yes) return;

    _subscription =
        WiFiScan.instance.onScannedResultsAvailable.listen((results) {
      setState(() {
        scannedNetworks = results;
        _filterArduinoDevices();
      });
    });
  }

  void _filterArduinoDevices() {
    availableDevices.clear();

    for (var network in scannedNetworks) {
      String ssid = network.ssid.toLowerCase();
      String bssid = network.bssid.toLowerCase();

      // Vérifier si le SSID contient un identifiant Arduino
      bool isArduinoBySSID = arduinoIdentifiers.any((id) => ssid.contains(id));

      // Vérifier si le BSSID (MAC) correspond à un préfixe connu
      bool isArduinoByMAC =
          knownMacPrefixes.any((prefix) => bssid.startsWith(prefix));

      // Vérifier la force du signal - les appareils proches ont généralement un signal plus fort
      bool hasStrongSignal = network.level > -70;

      if (isArduinoBySSID ||
          isArduinoByMAC ||
          (hasStrongSignal && ssid.length < 10)) {
        availableDevices.add({
          'name': network.ssid,
          'ip': _guessIPFromSSID(network.ssid),
          'type': _determineDeviceType(network.ssid, bssid),
          'signal': _getSignalStrengthText(network.level),
          'signalLevel': network.level,
          'capabilities': network.capabilities,
          'frequency': network.frequency,
          'bssid': network.bssid,
          'isConnected': false,
        });
      }
    }

    // Trier par force du signal (du plus fort au plus faible)
    availableDevices
        .sort((a, b) => b['signalLevel'].compareTo(a['signalLevel']));
  }

  String _guessIPFromSSID(String ssid) {
    // Logique simple pour deviner l'IP basée sur le SSID
    // En mode AP, la plupart des ESP32 utilisent 192.168.4.1
    if (ssid.toLowerCase().contains('esp32') ||
        ssid.toLowerCase().contains('arduino')) {
      return '192.168.4.1';
    }
    return '192.168.1.1'; // IP par défaut générique
  }

  String _determineDeviceType(String ssid, String bssid) {
    ssid = ssid.toLowerCase();

    if (ssid.contains('arduino') && ssid.contains('r4')) {
      return 'Arduino R4 WiFi';
    } else if (ssid.contains('arduino')) {
      return 'Arduino (Autre)';
    } else if (ssid.contains('esp32') || ssid.contains('esp-32')) {
      return 'ESP32';
    } else if (ssid.contains('esp8266')) {
      return 'ESP8266';
    } else {
      return 'Appareil IoT';
    }
  }

  String _getSignalStrengthText(int level) {
    if (level > -50) return 'Excellent';
    if (level > -60) return 'Très bon';
    if (level > -70) return 'Bon';
    if (level > -80) return 'Faible';
    return 'Très faible';
  }

  Color _getSignalColor(String? signal) {
    switch (signal?.toLowerCase()) {
      case 'excellent':
      case 'très bon':
        return Colors.green;
      case 'bon':
        return Colors.lightGreen;
      case 'faible':
        return Colors.orange;
      case 'très faible':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSignalIndicator(int level) {
    int bars = 0;
    Color color = Colors.grey;

    if (level > -55) {
      bars = 4;
      color = Colors.green;
    } else if (level > -65) {
      bars = 3;
      color = Colors.green;
    } else if (level > -75) {
      bars = 2;
      color = Colors.orange;
    } else if (level > -85) {
      bars = 1;
      color = Colors.red;
    }

    return Row(
      children: List.generate(4, (index) {
        return Container(
          width: 3,
          height: 6 + (index * 3),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: index < bars ? color : Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  // Future<void> _connectToDevice(String ip) async {
  //   setState(() {
  //     isConnecting = true;
  //     connectionStatus = 'Connexion en cours...';
  //   });

  //   try {
  //     // Essayer plusieurs endpoints communs pour les Arduino/ESP32
  //     final endpoints = [
  //       'http://$ip/status',
  //       'http://$ip/info',
  //       'http://$ip/',
  //       'http://$ip/api'
  //     ];

  //     bool connected = false;
  //     String workingEndpoint = '';

  //     for (var endpoint in endpoints) {
  //       try {
  //         final response = await http.get(
  //           Uri.parse(endpoint),
  //           headers: {'Content-Type': 'application/json'},
  //         ).timeout(const Duration(seconds: 2));

  //         if (response.statusCode == 200) {
  //           connected = true;
  //           workingEndpoint = endpoint;
  //           break;
  //         }
  //       } catch (e) {
  //         // Continuer avec le prochain endpoint
  //         print('Endpoint $endpoint non disponible: $e');
  //       }
  //     }

  //     if (connected) {
  //       setState(() {
  //         isConnected = true;
  //         connectionStatus = 'Connecté';
  //         arduinoIP = ip;
  //         signalStrength = 'Fort';
  //       });

  //       // Mettre à jour l'état de l'appareil dans la liste
  //       for (var device in availableDevices) {
  //         device['isConnected'] = device['ip'] == ip;
  //       }

  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('Connecté à $ip via $workingEndpoint'),
  //           backgroundColor: Colors.green,
  //         ),
  //       );
  //     } else {
  //       throw Exception('Aucun endpoint disponible');
  //     }
  //   } catch (e) {
  //     setState(() {
  //       connectionStatus = 'Erreur de connexion';
  //     });

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Erreur de connexion: ${e.toString()}'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   } finally {
  //     setState(() {
  //       isConnecting = false;
  //     });
  //   }
  // }
// REMPLACEZ votre méthode _connectToDevice par celle-ci :

  Future<void> _connectToDevice(String ip) async {
    setState(() {
      isConnecting = true;
      connectionStatus = 'Connexion en cours...';
    });

    try {
      bool success = await _connectionManager.connectToDevice(ip);

      if (success) {
        setState(() {
          isConnected = true;
          connectionStatus = 'Connecté';
          arduinoIP = ip;
          signalStrength = 'Fort';
        });

        // Mettre à jour l'état de l'appareil dans la liste
        for (var device in availableDevices) {
          device['isConnected'] = device['ip'] == ip;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Connecté à $ip'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          connectionStatus = 'Erreur de connexion';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Impossible de se connecter'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        connectionStatus = 'Erreur de connexion';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isConnecting = false;
      });
    }
  }

  // Future<void> _disconnectFromDevice() async {
  //   try {
  //     await http.post(
  //       Uri.parse('http://$arduinoIP/disconnect'),
  //       headers: {'Content-Type': 'application/json'},
  //     ).timeout(const Duration(seconds: 3));
  //   } catch (e) {
  //     print('Erreur lors de la déconnexion: $e');
  //   }

  //   setState(() {
  //     isConnected = false;
  //     connectionStatus = 'Déconnecté';
  //     signalStrength = 'N/A';

  //     for (var device in availableDevices) {
  //       device['isConnected'] = false;
  //     }
  //   });

  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(
  //       content: Text('Déconnecté'),
  //       backgroundColor: Colors.orange,
  //     ),
  //   );
  // }
  Future<void> _disconnectFromDevice() async {
    await _connectionManager.disconnect();

    setState(() {
      isConnected = false;
      connectionStatus = 'Déconnecté';
      signalStrength = 'N/A';

      for (var device in availableDevices) {
        device['isConnected'] = false;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔌 Déconnecté'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // Future<void> _sendCommand(String command) async {
  //   if (!isConnected) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Pas de connexion active')),
  //     );
  //     return;
  //   }

  //   try {
  //     final response = await http
  //         .post(
  //           Uri.parse('http://$arduinoIP/command'),
  //           headers: {'Content-Type': 'application/json'},
  //           body: jsonEncode({'command': command}),
  //         )
  //         .timeout(const Duration(seconds: 3));

  //     if (response.statusCode == 200) {
  //       print('Commande envoyée: $command');
  //     }
  //   } catch (e) {
  //     print('Erreur envoi commande: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Erreur: ${e.toString()}')),
  //     );
  //   }
  // }
  Future<void> _sendCommand(String command) async {
    bool success = await _connectionManager.sendCommand(command);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Erreur lors de l\'envoi de la commande'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showConnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connexion manuelle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Entrez l\'adresse IP de votre Arduino :'),
            const SizedBox(height: 16),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Adresse IP',
                hintText: '192.168.4.1',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _connectToDevice(_ipController.text);
            },
            child: const Text('Connecter'),
          ),
        ],
      ),
    );
  }

  void _showNetworkDetails(Map<String, dynamic> device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(device['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('IP suggérée', device['ip']),
            _buildDetailRow('Type', device['type']),
            _buildDetailRow(
                'Signal', '${device['signal']} (${device['signalLevel']} dBm)'),
            _buildDetailRow('Fréquence', '${device['frequency']} MHz'),
            _buildDetailRow('MAC', device['bssid']),
            if (device['capabilities'] != null)
              _buildDetailRow('Sécurité', device['capabilities']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _connectToDevice(device['ip']);
            },
            child: const Text('Connecter'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.arrow_back, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Scanner WiFi Arduino',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.bug_report, size: 20),
                  onPressed: _debugWifiPermissions,
                  tooltip: 'Debug permissions',
                ),
                IconButton(
                  icon: isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  onPressed: isScanning ? null : _scanForWifiNetworks,
                  tooltip: 'Scanner les réseaux',
                ),
                IconButton(
                  icon: Icon(
                    Icons.wifi,
                    size: 20,
                    color: isConnected ? Colors.green : Colors.grey,
                  ),
                  onPressed: _openWifiSettings,
                  tooltip: 'Paramètres WiFi',
                ),
                const Icon(Icons.close, size: 20),
              ],
            ),
          ),

          // Status de connexion
          // Container(
          //   margin: const EdgeInsets.symmetric(horizontal: 16),
          //   padding: const EdgeInsets.all(16),
          //   decoration: BoxDecoration(
          //     color: isConnected ? Colors.green[50] : Colors.grey[50],
          //     borderRadius: BorderRadius.circular(8),
          //     border: Border.all(
          //       color: isConnected ? Colors.green : Colors.grey[300]!,
          //     ),
          //   ),
          //   child: Row(
          //     children: [
          //       Icon(
          //         isConnected ? Icons.wifi : Icons.wifi_off,
          //         color: isConnected ? Colors.green : Colors.grey,
          //         size: 24,
          //       ),
          //       const SizedBox(width: 12),
          //       Expanded(
          //         child: Column(
          //           crossAxisAlignment: CrossAxisAlignment.start,
          //           children: [
          //             Text(
          //               connectionStatus,
          //               style: TextStyle(
          //                 fontSize: 14,
          //                 fontWeight: FontWeight.w600,
          //                 color: isConnected ? Colors.green : Colors.grey[600],
          //               ),
          //             ),
          //             if (isConnected) ...[
          //               Text(
          //                 'IP: $arduinoIP',
          //                 style: const TextStyle(fontSize: 12, color: Colors.grey),
          //               ),
          //               Text(
          //                 'Signal: $signalStrength',
          //                 style: const TextStyle(fontSize: 12, color: Colors.grey),
          //               ),
          //             ],
          //           ],
          //         ),
          //       ),
          //       if (isConnecting)
          //         const SizedBox(
          //           width: 20,
          //           height: 20,
          //           child: CircularProgressIndicator(strokeWidth: 2),
          //         )
          //       else if (isConnected)
          //         ElevatedButton(
          //           onPressed: _disconnectFromDevice,
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: Colors.red,
          //             minimumSize: const Size(80, 32),
          //           ),
          //           child: const Text(
          //             'Déconnecter',
          //             style: TextStyle(fontSize: 12, color: Colors.white),
          //           ),
          //         ),
          //     ],
          //   ),
          // ),

// Status de connexion
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isConnected ? Colors.green[50] : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isConnected ? Colors.green : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isConnected ? Icons.wifi : Icons.wifi_off,
                  color: isConnected ? Colors.green : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connectionStatus,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isConnected ? Colors.green : Colors.grey[600],
                        ),
                      ),
                      if (isConnected) ...[
                        Text(
                          'IP: $arduinoIP',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          'Signal: $signalStrength',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isConnecting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (isConnected) ...[
                  // AJOUTEZ LE BOUTON TEST ICI
                  ElevatedButton.icon(
                    onPressed: _testConnection,
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Test', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(70, 32),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _disconnectFromDevice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size(80, 32),
                    ),
                    child: const Text(
                      'Déconnecter',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Appareils détectés
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSectionHeader('Appareils détectés', 'ARDUINO/ESP32',
                      availableDevices.length),

                  if (isScanning)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Scan des réseaux WiFi en cours...',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else if (availableDevices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(Icons.wifi_find,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucun appareil Arduino trouvé',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const Text(
                            'Assurez-vous que votre Arduino est allumé et en mode AP',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showManualAddDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter manuellement'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...availableDevices
                        .map((device) => _buildDeviceItem(device)),

                  const SizedBox(height: 16),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _showConnectDialog,
                                icon: const Icon(Icons.wifi_tethering),
                                label: const Text('Connexion par IP'),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _showManualAddDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Ajout manuel'),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Réseaux scannés: ${scannedNetworks.length}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        if (scannedNetworks.isEmpty)
                          const Text(
                            'Assurez-vous que le GPS et le WiFi sont activés',
                            style:
                                TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String badge, int count) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$badge ($count)',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(Map<String, dynamic> device) {
    final bool deviceIsConnected = device['isConnected'] ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: deviceIsConnected ? Colors.green : Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),

          // Device info
          Expanded(
            child: GestureDetector(
              onTap: () => _showNetworkDetails(device),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device['name'] ?? 'Appareil inconnu',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${device['type']} • IP suggérée: ${device['ip']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Signal strength
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSignalIndicator(device['signalLevel']),
                  const SizedBox(width: 4),
                  Text(
                    device['signal'] ?? 'N/A',
                    style: TextStyle(
                      fontSize: 12,
                      color: _getSignalColor(device['signal']),
                    ),
                  ),
                ],
              ),
              Text(
                '${device['signalLevel']} dBm',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Connect button
          GestureDetector(
            onTap: () {
              if (deviceIsConnected) {
                _disconnectFromDevice();
              } else {
                _connectToDevice(device['ip']);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: deviceIsConnected ? Colors.red[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                deviceIsConnected ? 'Déconnecter' : 'Connecter',
                style: TextStyle(
                  fontSize: 11,
                  color: deviceIsConnected ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// Méthode de test simple
  Future<void> _testConnection() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('Test en cours...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Envoi de commande test...'),
            ],
          ),
        ),
      );

      // Test 1: Vérifier que le serveur répond
      final response = await http
          .get(
            Uri.parse('http://$arduinoIP/'),
          )
          .timeout(const Duration(seconds: 3));

      Navigator.pop(context);

      if (response.statusCode == 200) {
        // Afficher la réponse
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ Connexion OK!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${response.statusCode}'),
                const SizedBox(height: 8),
                const Text('Réponse du serveur:'),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    response.body.length > 200
                        ? '${response.body.substring(0, 200)}...'
                        : response.body,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur test: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Méthode pour envoyer des commandes de test
  Future<void> _sendTestCommand(String command) async {
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non connecté!')),
      );
      return;
    }

    try {
      print('Envoi commande: $command vers http://$arduinoIP/command');

      final response = await http
          .post(
            Uri.parse('http://$arduinoIP/command'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'command': command}),
          )
          .timeout(const Duration(seconds: 3));

      print('Réponse: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Commande "$command" envoyée!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${response.statusCode}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Erreur envoi commande: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Widget pour les boutons de test
  Widget _buildTestControls() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🧪 Zone de test',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: _testConnection,
                child: const Text('Test connexion'),
              ),
              ElevatedButton(
                onPressed: () => _sendTestCommand('LED_ON'),
                child: const Text('LED ON'),
              ),
              ElevatedButton(
                onPressed: () => _sendTestCommand('LED_OFF'),
                child: const Text('LED OFF'),
              ),
              ElevatedButton(
                onPressed: () => _sendTestCommand('FORWARD'),
                child: const Text('Avancer'),
              ),
              ElevatedButton(
                onPressed: () => _sendTestCommand('STOP'),
                child: const Text('Stop'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Vérifiez le moniteur série Arduino pour voir les commandes reçues',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // @override
  // void dispose() {
  //   _ipController.dispose();
  //   _subscription?.cancel();
  //   super.dispose();
  // }
  @override
  void dispose() {
    _ipController.dispose();
    _subscription?.cancel();
    _connectionSubscription?.cancel(); // LIGNE AJOUTÉE

    // NE PAS dispose le manager ici car il doit persister !
    print('🗑️ Disposal de WifiPage');

    super.dispose();
  }

  // Méthodes publiques pour envoyer des commandes depuis d'autres pages
  Future<void> sendCarCommand(String command) async {
    await _sendCommand(command);
  }

  bool get isCarConnected => isConnected;
  String get carIP => arduinoIP;
}
