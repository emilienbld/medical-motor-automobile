import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ActivationBluetoothPage extends StatefulWidget {
  const ActivationBluetoothPage({Key? key}) : super(key: key);

  @override
  State<ActivationBluetoothPage> createState() => _ActivationBluetoothPageState();
}

class _ActivationBluetoothPageState extends State<ActivationBluetoothPage> {
  bool isBluetoothEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBluetoothState();
  }

  void _checkBluetoothState() async {
    final state = await FlutterBluePlus.adapterState.first;
    setState(() {
      isBluetoothEnabled = state == BluetoothAdapterState.on;
    });
  }

  void _toggleBluetooth() async {
    try {
      if (isBluetoothEnabled) {
        // Note: Flutter Blue Plus ne peut pas désactiver le Bluetooth directement
        // Il faut rediriger vers les paramètres système
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez désactiver le Bluetooth dans les paramètres')),
        );
      } else {
        // Tenter d'activer le Bluetooth (sur Android uniquement)
        await FlutterBluePlus.turnOn();
        setState(() {
          isBluetoothEnabled = true;
        });
      }
    } catch (e) {
      print('Erreur Bluetooth: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.arrow_back, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Hopital Car Automate',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.close, size: 20),
              ],
            ),
            const SizedBox(height: 60),
            
            // Bluetooth Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isBluetoothEnabled ? Colors.blue : Colors.red,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isBluetoothEnabled ? Icons.bluetooth : Icons.bluetooth_disabled,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            
            // Status Text
            Text(
              isBluetoothEnabled ? 'Bluetooth activé' : 'Bluetooth désactivé',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            
            // Description
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Le bluetooth est actuellement désactivé sur votre système. Activez-le pour découvrir et connecter d\'autres appareils.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 40),
            
            // Activate Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _toggleBluetooth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bluetooth, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      isBluetoothEnabled ? 'Désactiver le Bluetooth' : 'Activer le Bluetooth',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            // Settings hint
            const Row(
              children: [
                Icon(Icons.settings_outlined, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Conseils d\'utilisation',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              'Assurez-vous que les appareils sont proches et que bluetooth est activé pour une meilleure détection.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}