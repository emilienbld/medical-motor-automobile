import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/bluetooth_device_tile.dart';

class BluetoothPage extends StatefulWidget {
  const BluetoothPage({Key? key}) : super(key: key);

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  BluetoothAdapterState _bluetoothState = BluetoothAdapterState.unknown;
  List<BluetoothDevice> _connectedDevices = [];
  List<ScanResult> _availableDevices = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    await _askPermissions();

    // Écouter les changements d'état Bluetooth
    FlutterBluePlus.adapterState.listen((state) {
      setState(() {
        _bluetoothState = state;
      });

      if (state == BluetoothAdapterState.on) {
        _scanDevices();
      } else {
        _connectedDevices.clear();
        _availableDevices.clear();
      }
    });

    // Obtenir l'état initial
    final state = await FlutterBluePlus.adapterState.first;
    setState(() {
      _bluetoothState = state;
    });

    if (state == BluetoothAdapterState.on) {
      _scanDevices();
    }
  }

  Future<void> _askPermissions() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }

  Future<void> _scanDevices() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _availableDevices.clear();
    });

    try {
      // Obtenir les appareils connectés
      List<BluetoothDevice> connected = await FlutterBluePlus.connectedDevices;
      setState(() {
        _connectedDevices = connected;
      });

      // Scanner les appareils disponibles
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      
      FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          _availableDevices = results;
        });
      });

      // Arrêter le scan après 10 secondes
      await Future.delayed(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('Erreur lors du scan: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      print('Connecté à ${device.name}');
      // Rafraîchir la liste après connexion
      _scanDevices();
    } catch (e) {
      print('Erreur de connexion: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de connexion: $e')),
      );
    }
  }

  Future<void> _disconnectFromDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      print('Déconnecté de ${device.name}');
      // Rafraîchir la liste après déconnexion
      _scanDevices();
    } catch (e) {
      print('Erreur de déconnexion: $e');
    }
  }

  List<ScanResult> _sortByRSSI(List<ScanResult> devices) {
    devices.sort((a, b) => b.rssi.compareTo(a.rssi));
    return devices;
  }

  @override
  Widget build(BuildContext context) {
    final isBluetoothOn = _bluetoothState == BluetoothAdapterState.on;

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
                  'Appareils Bluetooth',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (_isScanning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: isBluetoothOn ? _scanDevices : null,
                  ),
                const Icon(Icons.close, size: 20),
              ],
            ),
          ),

          if (!isBluetoothOn)
            // Message si Bluetooth désactivé
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Bluetooth désactivé',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    Text(
                      'Activez le Bluetooth pour scanner les appareils',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            // Liste des appareils
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Appareils connectés
                    if (_connectedDevices.isNotEmpty) ...[
                      _buildSectionHeader('Appareils connectés', 'ACTIFS', _connectedDevices.length),
                      ..._connectedDevices.map((device) => _buildConnectedDeviceItem(device)),
                      const SizedBox(height: 16),
                    ],

                    // Appareils disponibles
                    _buildSectionHeader('Appareils disponibles', 'DÉTECTÉS', _availableDevices.length),
                    
                    if (_availableDevices.isEmpty && !_isScanning)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Aucun appareil trouvé\nAppuyez sur actualiser pour scanner',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ..._sortByRSSI(_availableDevices).map((scanResult) => 
                        _buildAvailableDeviceItem(scanResult)),
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

  Widget _buildConnectedDeviceItem(BluetoothDevice device) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Status indicator (vert pour connecté)
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          
          // Device info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name.isNotEmpty ? device.name : "Appareil sans nom",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  "ID: ${device.remoteId.str}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          
          // Status
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Connecté',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          
          // Disconnect button
          GestureDetector(
            onTap: () => _disconnectFromDevice(device),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Déconnecter',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableDeviceItem(ScanResult scanResult) {
    final device = scanResult.device;
    final rssi = scanResult.rssi;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Status indicator (orange pour disponible)
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          
          // Device info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name.isNotEmpty ? device.name : "Appareil sans nom",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  "ID: ${device.remoteId.str}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          
          // RSSI
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'RSSI: ${rssi}dBm',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Text(
                _getSignalStrength(rssi),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          
          // Connect button
          GestureDetector(
            onTap: () => _connectToDevice(device),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Connecter',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSignalStrength(int rssi) {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Bon';
    if (rssi >= -70) return 'Moyen';
    return 'Faible';
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }
}