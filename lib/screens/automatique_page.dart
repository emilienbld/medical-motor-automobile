import 'package:flutter/material.dart';
import '../widgets/parameter_item.dart';

class AutomatiquePage extends StatefulWidget {
  const AutomatiquePage({Key? key}) : super(key: key);

  @override
  State<AutomatiquePage> createState() => _AutomatiquePageState();
}

class _AutomatiquePageState extends State<AutomatiquePage> {
  bool modeAutonome = true;
  bool navigationPrecise = true;
  bool obstacleDetection = true;
  double statistiqueTrajet = 100;
  String etatConnexion = 'Fort';

  List<Map<String, String>> locations = [
    {'name': 'Salle 101', 'status': 'OK'},
    {'name': 'Salle 102', 'status': 'OK'},
    {'name': 'Salle 103', 'status': 'OK'},
  ];

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Hopital Car Automate',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Text(
                    'Lieux disponibles',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'Connecté',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Location list
              ...locations.map((location) => _buildLocationItem(location)),
              
              const SizedBox(height: 20),
              
              // Parameters
              const Text(
                'Paramètres',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              ParameterItem(
                title: 'Mode autonome',
                value: modeAutonome,
                onChanged: (value) => setState(() => modeAutonome = value),
              ),
              ParameterItem(
                title: 'Navigation précise',
                value: navigationPrecise,
                onChanged: (value) => setState(() => navigationPrecise = value),
              ),
              ParameterItem(
                title: 'Obstacledetection',
                value: obstacleDetection,
                onChanged: (value) => setState(() => obstacleDetection = value),
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
                  const Text('Distribution',
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
                  _buildConnectionStatus('Faible', etatConnexion == 'Faible'),
                  _buildConnectionStatus('Fort', etatConnexion == 'Fort'),
                  _buildConnectionStatus('Moyenne', etatConnexion == 'Moyenne'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationItem(Map<String, String> location) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              location['name'] ?? '',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            location['status'] ?? '',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => etatConnexion = label),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? Colors.green : Colors.grey[300]!,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.green : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}