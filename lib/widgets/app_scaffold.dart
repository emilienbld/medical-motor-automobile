import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final BluetoothAdapterState bluetoothState;
  final VoidCallback onBluetoothToggle;

  const AppScaffold({
    super.key,
    required this.body,
    required this.title,
    required this.bluetoothState,
    required this.onBluetoothToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isOn = bluetoothState == BluetoothAdapterState.on;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[900],
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Projet M1 IOT", style: TextStyle(color: Colors.white)),
            IconButton(
              onPressed: onBluetoothToggle,
              icon: Icon(
                isOn ? Icons.bluetooth : Icons.bluetooth_disabled,
                color: isOn ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.grey[200],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Center(
              child: Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
