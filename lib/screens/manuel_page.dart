import 'package:flutter/material.dart';
import '../widgets/joystick_widget.dart';

class ManuelPage extends StatefulWidget {
  const ManuelPage({Key? key}) : super(key: key);

  @override
  State<ManuelPage> createState() => _ManuelPageState();
}

class _ManuelPageState extends State<ManuelPage> {
  bool modeAutonome = false;
  double statistiqueTrajet = 100;
  String etatConnexion = 'CONNECTÉ';
  String signalForce = 'Fort';

  void _onJoystickMove(double x, double y) {
    // Logique pour contrôler la voiture
    print('Joystick position: x=$x, y=$y');
    
    // Ici tu peux ajouter la logique pour envoyer les commandes à l'Arduino
    // Exemple:
    // if (y > 0.5) sendCommand('FORWARD');
    // else if (y < -0.5) sendCommand('BACKWARD');
    // if (x > 0.5) sendCommand('RIGHT');
    // else if (x < -0.5) sendCommand('LEFT');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              const Text(
                'Navigation autonome',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Contrôle manuel',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const Text(
                'Utilisez le joystick pour déplacer le robot',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const Text(
                '• Robot disponible',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Joystick
              JoystickWidget(
                onJoystickMove: _onJoystickMove,
              ),
              
              const SizedBox(height: 40),
              
              // Mode autonomous toggle
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: modeAutonome ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Mode autonome',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Switch(
                    value: modeAutonome,
                    onChanged: (value) {
                      setState(() => modeAutonome = value);
                      if (value) {
                        print('Mode autonome activé');
                      } else {
                        print('Mode manuel activé');
                      }
                    },
                    activeColor: Colors.green,
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Statistics
              const Text(
                'Statistique de trajet',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  const Text('100m', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: statistiqueTrajet,
                      min: 0,
                      max: 200,
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setState(() => statistiqueTrajet = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Suivi des mouvements',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Connection Status
              const Text(
                'État de la connexion',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    etatConnexion,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    signalForce,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}