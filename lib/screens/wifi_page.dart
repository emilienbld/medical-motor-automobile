import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

import '../services/wifi_connection_manager.dart';
import '../services/wifi_scanner_service.dart';
import '../services/device_detection_service.dart';

class WifiPage extends StatefulWidget {
  const WifiPage({Key? key}) : super(key: key);

  @override
  State<WifiPage> createState() => _WifiPageState();
}

class _WifiPageState extends State<WifiPage> {
  // Services
  final WiFiConnectionManager _connectionManager = WiFiConnectionManager();
  late final WiFiScannerService _scannerService;
  late final DeviceDetectionService _detectionService;
  
  // État de l'interface
  bool isConnected = false;
  bool isConnecting = false;
  String arduinoIP = '192.168.4.1';
  String connectionStatus = 'Déconnecté';
  String signalStrength = 'N/A';
  bool isScanning = false;
  List<DetectedDevice> availableDevices = [];
  
  // Subscriptions
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<bool>? _scanningSubscription;
  StreamSubscription<List<DetectedDevice>>? _devicesSubscription;
  StreamSubscription<String>? _errorSubscription;
  
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    // Initialiser les services
    _scannerService = WiFiScannerService();
    _detectionService = DeviceDetectionService();
    
    _ipController.text = arduinoIP;
    
    _setupSubscriptions();
    _syncWithConnectionManager();
    
    // Démarrer le scan initial et le heartbeat si connecté
    _scannerService.requestPermissions().then((granted) {
      if (granted) {
        _scannerService.scanNetworks();
        _scannerService.startListeningToScannedResults();
      }
    });
    
    if (_connectionManager.isConnected) {
      _connectionManager.startHeartbeat();
    }
  }

  void _setupSubscriptions() {
    // Écouter les changements de connexion
    _connectionSubscription = _connectionManager.connectionStream.listen((connected) {
      setState(() {
        isConnected = connected;
        connectionStatus = connected ? 'Connecté' : 'Déconnecté';
        signalStrength = connected ? 'Fort' : 'N/A';
      });
      
      // Mettre à jour l'état des appareils
      _detectionService.updateDeviceConnectionStatus(
        _connectionManager.arduinoIP, 
        connected
      );
      
      if (!connected) {
        _showSnackBar('⚠️ Connexion Arduino perdue', Colors.orange);
      }
    });
    
    // Écouter l'état du scan
    _scanningSubscription = _scannerService.scanningStream.listen((scanning) {
      setState(() {
        isScanning = scanning;
      });
    });
    
    // Écouter les appareils détectés
    _devicesSubscription = _detectionService.devicesStream.listen((devices) {
      setState(() {
        availableDevices = devices;
      });
    });
    
    // Écouter les erreurs
    _errorSubscription = _scannerService.errorStream.listen((error) {
      _showSnackBar(error, Colors.red);
    });
    
    // Écouter les nouveaux réseaux scannés pour détecter les appareils
    _scannerService.networksStream.listen((networks) {
      _detectionService.filterArduinoDevices(networks);
    });
  }

  void _syncWithConnectionManager() {
    final status = _connectionManager.getConnectionStatus();
    setState(() {
      isConnected = status['isConnected'];
      arduinoIP = status['arduinoIP'];
      connectionStatus = isConnected ? 'Connecté' : 'Déconnecté';
      signalStrength = isConnected ? 'Fort' : 'N/A';
    });
  }

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

        _detectionService.updateDeviceConnectionStatus(ip, true);
        _showSnackBar('✅ Connecté à $ip', Colors.green);
      } else {
        setState(() {
          connectionStatus = 'Erreur de connexion';
        });
        _showSnackBar('❌ Impossible de se connecter', Colors.red);
      }
    } catch (e) {
      setState(() {
        connectionStatus = 'Erreur de connexion';
      });
      _showSnackBar('Erreur: ${e.toString()}', Colors.red);
    } finally {
      setState(() {
        isConnecting = false;
      });
    }
  }

  Future<void> _disconnectFromDevice() async {
    await _connectionManager.disconnect();

    setState(() {
      isConnected = false;
      connectionStatus = 'Déconnecté';
      signalStrength = 'N/A';
    });

    _detectionService.updateDeviceConnectionStatus('', false);
    _showSnackBar('🔌 Déconnecté', Colors.orange);
  }

  Future<void> _testConnection() async {
    if (!isConnected) {
      _showSnackBar('Non connecté!', Colors.red);
      return;
    }

    try {
      _showLoadingDialog('Test en cours...', 'Envoi de commande test...');

      final response = await http
          .get(Uri.parse('http://$arduinoIP/'))
          .timeout(const Duration(seconds: 3));

      Navigator.pop(context);

      if (response.statusCode == 200) {
        _showTestResultDialog(response);
      }
    } catch (e) {
      Navigator.pop(context);
      _showSnackBar('Erreur test: ${e.toString()}', Colors.red);
    }
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                _detectionService.addManualDevice(
                  ssidController.text, 
                  ipController.text
                );
                Navigator.pop(context);
                _showSnackBar(
                  'Réseau ajouté. Connectez-vous au WiFi Arduino puis appuyez sur Connecter.',
                  Colors.blue,
                );
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
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

  void _showNetworkDetails(DetectedDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(device.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('IP suggérée', device.ip),
            _buildDetailRow('Type', device.type),
            _buildDetailRow('Signal', '${device.signal} (${device.signalLevel} dBm)'),
            _buildDetailRow('Fréquence', '${device.frequency} MHz'),
            _buildDetailRow('MAC', device.bssid),
            if (device.capabilities.isNotEmpty)
              _buildDetailRow('Sécurité', device.capabilities),
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
              _connectToDevice(device.ip);
            },
            child: const Text('Connecter'),
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
          _buildHeader(),
          _buildConnectionStatus(),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildDevicesSection(),
                  _buildActionsSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.arrow_back, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Scanner WiFi Arduino',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.bug_report, size: 20),
            onPressed: _showDebugInfo,
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
            onPressed: isScanning ? null : _scannerService.scanNetworks,
            tooltip: 'Scanner les réseaux',
          ),
          IconButton(
            icon: Icon(
              Icons.wifi,
              size: 20,
              color: isConnected ? Colors.green : Colors.grey,
            ),
            onPressed: _scannerService.openWifiSettings,
            tooltip: 'Paramètres WiFi',
          ),
          const Icon(Icons.close, size: 20),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
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
                  Text('IP: $arduinoIP', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('Signal: $signalStrength', style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
            ElevatedButton.icon(
              onPressed: _testConnection,
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Test', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(70, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _disconnectFromDevice,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(80, 32),
              ),
              child: const Text('Déconnecter', style: TextStyle(fontSize: 12, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDevicesSection() {
    return Column(
      children: [
        _buildSectionHeader('Appareils détectés', 'ARDUINO/ESP32', availableDevices.length),
        
        if (isScanning)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Scan des réseaux WiFi en cours...', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          )
        else if (availableDevices.isEmpty)
          _buildEmptyDevicesState()
        else
          ...availableDevices.map((device) => _buildDeviceItem(device)),
      ],
    );
  }

  Widget _buildEmptyDevicesState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.wifi_find, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Aucun appareil Arduino trouvé', style: TextStyle(fontSize: 16, color: Colors.grey)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(DetectedDevice device) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: device.isConnected ? Colors.green : Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _showNetworkDetails(device),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(
                    '${device.type} • IP suggérée: ${device.ip}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSignalIndicator(device.signalLevel),
                  const SizedBox(width: 4),
                  Text(device.signal, style: TextStyle(fontSize: 12, color: _getSignalColor(device.signal))),
                ],
              ),
              Text('${device.signalLevel} dBm', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              if (device.isConnected) {
                _disconnectFromDevice();
              } else {
                _connectToDevice(device.ip);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: device.isConnected ? Colors.red[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                device.isConnected ? 'Déconnecter' : 'Connecter',
                style: TextStyle(
                  fontSize: 11,
                  color: device.isConnected ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return Padding(
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
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showManualAddDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajout manuel'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Réseaux scannés: ${_scannerService.scannedNetworks.length}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (_scannerService.scannedNetworks.isEmpty)
            const Text(
              'Assurez-vous que le GPS et le WiFi sont activés',
              style: TextStyle(fontSize: 12, color: Colors.orange),
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
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$badge ($count)',
              style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
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
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _showLoadingDialog(String title, String content) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(content),
          ],
        ),
      ),
    );
  }

  void _showTestResultDialog(http.Response response) {
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

  void _showDebugInfo() async {
    final debugInfo = await _scannerService.getDebugInfo();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: debugInfo.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
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

  @override
  void dispose() {
    _ipController.dispose();
    _connectionSubscription?.cancel();
    _scanningSubscription?.cancel();
    _devicesSubscription?.cancel();
    _errorSubscription?.cancel();
    
    _scannerService.dispose();
    _detectionService.dispose();
    
    super.dispose();
  }
}