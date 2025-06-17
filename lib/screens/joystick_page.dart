import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../widgets/app_scaffold.dart';

class JoystickPage extends StatelessWidget {
  const JoystickPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      bluetoothState: BluetoothAdapterState.on, // Juste pour l’icône
      onBluetoothToggle: () {}, // Option vide ici
      title: "Contrôle manuel",
      body: Center(
        child: Joystick(
          mode: JoystickMode.all,
          stick: Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          base: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          listener: (details) {
            print("x: ${details.x}, y: ${details.y}");
          },
        ),
      ),
    );
  }
}
