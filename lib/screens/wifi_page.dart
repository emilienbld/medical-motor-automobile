import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'Ajouter manuellement',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Si le scan ne fonctionne pas, vous pouvez ajouter '
              'manuellement votre Arduino.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ssidController,
              decoration: InputDecoration(
                labelText: 'Nom du réseau (SSID)',
                labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
                hintText: 'Ex: ArduinoAP',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.green),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ipController,
              decoration: InputDecoration(
                labelText: 'Adresse IP',
                labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
                hintText: '192.168.4.1',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.green),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Assurez-vous d\'être connecté au réseau WiFi de votre Arduino '
                      'dans les paramètres WiFi de votre téléphone.',
                      style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: Colors.grey[600])),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'Connexion manuelle',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Entrez l\'adresse IP de votre Arduino :',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: 'Adresse IP',
                labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
                hintText: '192.168.4.1',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.green),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _connectToDevice(_ipController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          device.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
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
            child: Text('Fermer', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _connectToDevice(device.ip);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
      child: Column(
        children: [
          // Header avec Scanner WiFi Arduino
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text(
                  'Scanner WiFi Arduino',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.bug_report, size: 20),
                  onPressed: _showDebugInfo,
                  tooltip: 'Debug permissions',
                  color: Colors.grey[600],
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
                  color: Colors.grey[600],
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Statut de connexion
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isConnected ? Colors.green[50] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
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
                        const SizedBox(height: 4),
                        Text(
                          'IP: $arduinoIP • Signal: $signalStrength',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
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
                  GestureDetector(
                    onTap: _testConnection,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            'Test',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _disconnectFromDevice,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        'Déconnecter',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Section des appareils détectés
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Header de la section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text(
                          'Appareils détectés',
                          style: TextStyle(
                            fontSize: 16,
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
                            'ARDUINO/ESP32 (${availableDevices.length})',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Contenu de la liste
                  Expanded(
                    child: isScanning
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Scan des réseaux WiFi en cours...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : availableDevices.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.wifi_find,
                                      size: 64,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Aucun appareil Arduino trouvé',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Assurez-vous que votre Arduino est allumé\net en mode AP',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    GestureDetector(
                                      onTap: _showManualAddDialog,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.blue),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.add,
                                              size: 18,
                                              color: Colors.blue,
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'Ajouter manuellement',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.blue,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: availableDevices.length,
                                itemBuilder: (context, index) {
                                  final device = availableDevices[index];
                                  return _buildDeviceItem(device);
                                },
                              ),
                  ),
                  
                  // Boutons d'action en bas
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _showConnectDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.wifi_tethering,
                                        size: 18,
                                        color: Colors.grey[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Connexion par IP',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: _showManualAddDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add,
                                        size: 18,
                                        color: Colors.grey[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Ajout manuel',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Réseaux scannés: ${_scannerService.scannedNetworks.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_scannerService.scannedNetworks.isEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Assurez-vous que le GPS et le WiFi sont activés',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(DetectedDevice device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: device.isConnected ? Colors.green[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: device.isConnected ? Colors.green[300]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: device.isConnected ? Colors.green[100] : Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.router,
              color: device.isConnected ? Colors.green : Colors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _showNetworkDetails(device),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          device.type,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'IP: ${device.ip}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
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
                  Text(
                    device.signal,
                    style: TextStyle(
                      fontSize: 12,
                      color: _getSignalColor(device.signal),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${device.signalLevel} dBm',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: device.isConnected ? Colors.red[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: device.isConnected ? Colors.red : Colors.green,
                ),
              ),
              child: Text(
                device.isConnected ? 'Déconnecter' : 'Connecter',
                style: TextStyle(
                  fontSize: 12,
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
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
          height: 8 + (index * 3.0),
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: index < bars ? color : Colors.grey[300],
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
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showLoadingDialog(String title, String content) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 16),
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTestResultDialog(http.Response response) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Connexion OK!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Status', response.statusCode.toString()),
            const SizedBox(height: 8),
            Text(
              'Réponse du serveur:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                response.body.length > 200
                    ? '${response.body.substring(0, 200)}...'
                    : response.body,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'Debug Info',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: debugInfo.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        '${entry.key}:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Fermer',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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