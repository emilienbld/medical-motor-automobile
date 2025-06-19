import 'package:flutter/material.dart';

class AutomatiquePage extends StatefulWidget {
  const AutomatiquePage({Key? key}) : super(key: key);

  @override
  State<AutomatiquePage> createState() => _AutomatiquePageState();
}

class _AutomatiquePageState extends State<AutomatiquePage> {
  final TextEditingController _destinationController = TextEditingController();
  double statistiqueTrajet = 100;

  List<Map<String, String>> locations = [
    {'name': 'Salle 101', 'status': 'OK'},
    {'name': 'Salle 102', 'status': 'OK'},
    {'name': 'Salle 103', 'status': 'OK'},
  ];

  void _handleGoButtonPressed() {
    String destination = _destinationController.text.trim();
    if (destination.isNotEmpty) {
      // Ici vous pouvez envoyer les données
      print('Destination sélectionnée: $destination');
      // Exemple d'envoi de données - remplacez par votre logique
      _sendDestinationData(destination);
    } else {
      // Afficher un message d'erreur si le champ est vide
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer une destination'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _sendDestinationData(String destination) {
    // Implémentez ici votre logique d'envoi de données
    // Par exemple: appel API, navigation, etc.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Destination envoyée: $destination'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
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
              
              // Destination Input Section
              const Text(
                'Entrer votre destination',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _destinationController,
                      decoration: InputDecoration(
                        hintText: 'Saisir la destination...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Colors.green),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _handleGoButtonPressed,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Text(
                        'GO',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Location list
              ...locations.map((location) => _buildLocationItem(location)),
              
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
}