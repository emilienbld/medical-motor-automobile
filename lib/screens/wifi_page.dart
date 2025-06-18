import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';

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
  
  // Filtres pour identifier les appareils Arduino/ESP32
  final List<String> targetSSIDs = [
    'ZiggyCar-ESP32',
    'Arduino-Car',
    'ESP32-',
    'NodeMCU',
    'Wemos',
    'ArduinoAP',
  ];

  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ipController.text = arduinoIP;
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Demander les permissions nécessaires
    final permissions = [
      Permission.location,
      Permission.locationWhenInUse,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    bool allGranted = statuses.values.every((status) => status.isGranted);
    
    if (allGranted) {
      _scanForWifiNetworks();
    } else {
      _showPermissionDialog();
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
      // Vérifier si le WiFi est activé
      final canGetScannedResults = await WiFiScan.instance.canGetScannedResults();
      if (canGetScannedResults != CanGetScannedResults.yes) {
        throw Exception('Impossible de scanner les réseaux WiFi');
      }

      // Démarrer le scan
      await WiFiScan.instance.startScan();
      
      // Attendre un peu pour que le scan se termine
      await Future.delayed(const Duration(seconds: 3));
      
      // Récupérer les résultats
      final results = await WiFiScan.instance.getScannedResults();
      
      setState(() {
        scannedNetworks = results;
        _filterArduinoDevices();
      });

    } catch (e) {
      print('Erreur lors du scan WiFi: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur scan WiFi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isScanning = false;
      });
    }
  }

  void _filterArduinoDevices() {
    availableDevices.clear();
    
    for (var network in scannedNetworks) {
      // Filtrer les réseaux qui ressemblent à des appareils Arduino/ESP32
      bool isArduinoDevice = targetSSIDs.any((target) => 
        network.ssid.toLowerCase().contains(target.toLowerCase()));
      
      if (isArduinoDevice || network.ssid.toLowerCase().contains('esp')) {
        availableDevices.add({
          'name': network.ssid,
          'ip': _guessIPFromSSID(network.ssid),
          'type': 'Point d\'accès WiFi',
          'signal': _getSignalStrengthText(network.level),
          'signalLevel': network.level,
          'capabilities': network.capabilities,
          'frequency': network.frequency,
          'isConnected': false,
        });
      }
    }
    
    // Trier par force du signal (du plus fort au plus faible)
    availableDevices.sort((a, b) => b['signalLevel'].compareTo(a['signalLevel']));
  }

  String _guessIPFromSSID(String ssid) {
    // Logique simple pour deviner l'IP basée sur le SSID
    // En mode AP, la plupart des ESP32 utilisent 192.168.4.1
    if (ssid.toLowerCase().contains('esp32') || ssid.toLowerCase().contains('arduino')) {
      return '192.168.4.1';
    }
    return '192.168.1.1'; // IP par défaut générique
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

  Future<void> _connectToDevice(String ip) async {
    setState(() {
      isConnecting = true;
      connectionStatus = 'Connexion en cours...';
    });

    try {
      // Test de connexion avec ping
      final response = await http.get(
        Uri.parse('http://$ip/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
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
            content: Text('Connecté à $ip'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Réponse invalide du serveur');
      }
    } catch (e) {
      setState(() {
        connectionStatus = 'Erreur de connexion';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de connexion: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isConnecting = false;
      });
    }
  }

  Future<void> _disconnectFromDevice() async {
    try {
      await http.post(
        Uri.parse('http://$arduinoIP/disconnect'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
    }

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
        content: Text('Déconnecté'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _sendCommand(String command) async {
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pas de connexion active')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://$arduinoIP/command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': command}),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        print('Commande envoyée: $command');
      }
    } catch (e) {
      print('Erreur envoi commande: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            _buildDetailRow('Signal', '${device['signal']} (${device['signalLevel']} dBm)'),
            _buildDetailRow('Fréquence', '${device['frequency']} MHz'),
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
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          'Signal: $signalStrength',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                else if (isConnected)
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
            ),
          ),

          const SizedBox(height: 16),

          // Appareils détectés
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSectionHeader(
                    'Appareils détectés', 
                    'ARDUINO/ESP32', 
                    availableDevices.length
                  ),
                  
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
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.wifi_find, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Aucun appareil Arduino trouvé',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          Text(
                            'Assurez-vous que votre Arduino est allumé et en mode AP',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else
                    ...availableDevices.map((device) => _buildDeviceItem(device)),

                  const SizedBox(height: 16),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showConnectDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Connexion manuelle'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Réseaux scannés: ${scannedNetworks.length}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                  Icon(
                    Icons.wifi,
                    size: 16,
                    color: _getSignalColor(device['signal']),
                  ),
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

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  // Méthodes publiques pour envoyer des commandes depuis d'autres pages
  Future<void> sendCarCommand(String command) async {
    await _sendCommand(command);
  }

  bool get isCarConnected => isConnected;
  String get carIP => arduinoIP;
}