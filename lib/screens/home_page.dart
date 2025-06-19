// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:android_intent_plus/android_intent.dart';
// import 'package:android_intent_plus/flag.dart';
// import '../screens/joystick_page.dart';
// import '../widgets/app_scaffold.dart';

// class HomePage extends StatefulWidget {
//   const HomePage({super.key});

//   @override
//   State<HomePage> createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   BluetoothAdapterState _bluetoothState = BluetoothAdapterState.unknown;
//   List<BluetoothDevice> _connectedDevices = [];
//   List<ScanResult> _availableDevices = [];

//   @override
//   void initState() {
//     super.initState();
//     _initBluetooth();
//   }

//   Future<void> _initBluetooth() async {
//     await _askPermissions();

//     FlutterBluePlus.adapterState.listen((state) {
//       setState(() {
//         _bluetoothState = state;
//       });

//       if (state == BluetoothAdapterState.on) {
//         _scanDevices();
//       } else {
//         _connectedDevices.clear();
//         _availableDevices.clear();
//       }
//     });

//     final state = await FlutterBluePlus.adapterState.first;
//     setState(() {
//       _bluetoothState = state;
//     });

//     if (state == BluetoothAdapterState.on) {
//       _scanDevices();
//     }
//   }

//   Future<void> _askPermissions() async {
//     await Permission.location.request();
//     await Permission.bluetooth.request();
//     await Permission.bluetoothScan.request();
//     await Permission.bluetoothConnect.request();
//   }

//   void _openBluetoothSettings() {
//     if (Platform.isAndroid) {
//       final intent = AndroidIntent(
//         action: 'android.settings.BLUETOOTH_SETTINGS',
//         flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
//       );
//       intent.launch();
//     }
//   }

//   Future<void> _scanDevices() async {
//     setState(() {
//       _availableDevices.clear();
//     });

//     List<BluetoothDevice> connected = await FlutterBluePlus.connectedDevices;
//     setState(() {
//       _connectedDevices = connected;
//     });

//     await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
//     FlutterBluePlus.scanResults.listen((results) {
//       setState(() {
//         _availableDevices = results;
//       });
//     });
//   }

//   List<ScanResult> _sortByRSSI(List<ScanResult> devices) {
//     devices.sort((a, b) => b.rssi.compareTo(a.rssi));
//     return devices;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isBluetoothOn = _bluetoothState == BluetoothAdapterState.on;

//     return AppScaffold(
//         bluetoothState: _bluetoothState,
//         onBluetoothToggle: _openBluetoothSettings,
//         title: "Home",
//         body: SingleChildScrollView(
//             child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//                 Text(
//                 isBluetoothOn ? "Bluetooth actif" : "Bluetooth désactivé",
//                 style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: isBluetoothOn ? Colors.green : Colors.red,
//                 ),
//                 ),
//                 const SizedBox(height: 16),
//                 if (isBluetoothOn) ...[
//                 ElevatedButton(
//                     onPressed: _scanDevices,
//                     child: const Text("Scanner les appareils"),
//                 ),
//                 const SizedBox(height: 16),
//                 Text(
//                     "${_connectedDevices.length} Appareil${_connectedDevices.length > 1 ? 's' : ''} connecté${_connectedDevices.length > 1 ? 's' : ''}",
//                     style: const TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 ..._connectedDevices.map(
//                     (d) => BluetoothDeviceTile(device: d, rssi: 0),
//                 ),
//                 const SizedBox(height: 16),
//                 Text(
//                     "${_availableDevices.length} Appareil${_availableDevices.length > 1 ? 's' : ''} disponible${_availableDevices.length > 1 ? 's' : ''}",
//                     style: const TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 ..._sortByRSSI(_availableDevices).map(
//                     (r) => BluetoothDeviceTile(device: r.device, rssi: r.rssi),
//                 ),
//                 ],
//                 const SizedBox(height: 24),
//                 Center(
//                 child: ElevatedButton(
//                     onPressed: () {
//                     Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (_) => const JoystickPage()),
//                     );
//                     },
//                     child: const Text("Joystick"),
//                 ),
//                 ),
//                 const SizedBox(height: 24),
//             ],
//             ),
//         ),
//     );


//   }
// }
