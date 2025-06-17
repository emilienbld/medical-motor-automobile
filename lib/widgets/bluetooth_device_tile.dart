import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothDeviceTile extends StatelessWidget {
  final BluetoothDevice device;
  final int rssi;

  const BluetoothDeviceTile({super.key, required this.device, required this.rssi});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(device.name.isNotEmpty ? device.name : "Appareil sans nom"),
      subtitle: Text("ID: ${device.remoteId.str}"),
      trailing: Text("RSSI: $rssi dBm"),
    );
  }
}
