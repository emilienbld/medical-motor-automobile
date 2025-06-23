import 'package:flutter/material.dart';

class AutomatiquePage extends StatefulWidget {
  const AutomatiquePage({Key? key}) : super(key: key);

  @override
  State<AutomatiquePage> createState() => _AutomatiquePageState();
}

class _AutomatiquePageState extends State<AutomatiquePage> {
  final TextEditingController _latDegreesController = TextEditingController();
  final TextEditingController _latMinutesController = TextEditingController();
  final TextEditingController _latSecondsController = TextEditingController();
  final TextEditingController _longDegreesController = TextEditingController();
  final TextEditingController _longMinutesController = TextEditingController();
  final TextEditingController _longSecondsController = TextEditingController();
  
  String _latDirection = 'N';
  String _longDirection = 'E';
  double statistiqueTrajet = 100;

  // Suggestions de coordonnées
  List<Map<String, String>> suggestions = [
    {'coordinates': '48°50\'18"N,2°18\'41"E', 'description': 'Paris Centre'},
    {'coordinates': '48°51\'29"N,2°17\'40"E', 'description': 'Arc de Triomphe'},
    {'coordinates': '48°52\'08"N,2°19\'56"E', 'description': 'Sacré-Cœur'},
  ];

  void _handleGoButtonPressed() {
    String latDegrees = _latDegreesController.text.trim();
    String latMinutes = _latMinutesController.text.trim();
    String latSeconds = _latSecondsController.text.trim();
    String longDegrees = _longDegreesController.text.trim();
    String longMinutes = _longMinutesController.text.trim();
    String longSeconds = _longSecondsController.text.trim();
    
    if (latDegrees.isNotEmpty && latMinutes.isNotEmpty && latSeconds.isNotEmpty &&
        longDegrees.isNotEmpty && longMinutes.isNotEmpty && longSeconds.isNotEmpty) {
      String coordinates = '${latDegrees}°${latMinutes}\'${latSeconds}"$_latDirection,${longDegrees}°${longMinutes}\'${longSeconds}"$_longDirection';
      print('Coordonnées sélectionnées: $coordinates');
      _sendCoordinatesData(coordinates);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs de coordonnées'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleSuggestionPressed(String coordinates) {
    print('Coordonnées suggérées sélectionnées: $coordinates');
    _sendCoordinatesData(coordinates);
  }

  void _sendCoordinatesData(String coordinates) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coordonnées envoyées: $coordinates'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _latDegreesController.dispose();
    _latMinutesController.dispose();
    _latSecondsController.dispose();
    _longDegreesController.dispose();
    _longMinutesController.dispose();
    _longSecondsController.dispose();
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
              
              // Coordonnées Input Section
              const Text(
                'Entrer vos coordonnées',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              // Latitude
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Latitude',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<String>(
                        value: 'N',
                        groupValue: _latDirection,
                        onChanged: (value) {
                          setState(() {
                            _latDirection = value!;
                          });
                        },
                        activeColor: Colors.blue,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Text('N', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Radio<String>(
                        value: 'S',
                        groupValue: _latDirection,
                        onChanged: (value) {
                          setState(() {
                            _latDirection = value!;
                          });
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Text('S', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _latDegreesController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '°',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(color: Colors.green),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2),
                          child: Text('°', style: TextStyle(fontSize: 12)),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _latMinutesController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '\'',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(color: Colors.green),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2),
                          child: Text('\'', style: TextStyle(fontSize: 12)),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _latSecondsController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '"',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(color: Colors.green),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2),
                          child: Text('"', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Longitude
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Longitude',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Radio<String>(
                        value: 'E',
                        groupValue: _longDirection,
                        onChanged: (value) {
                          setState(() {
                            _longDirection = value!;
                          });
                        },
                        activeColor: Colors.blue,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Text('E', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Radio<String>(
                        value: 'O',
                        groupValue: _longDirection,
                        onChanged: (value) {
                          setState(() {
                            _longDirection = value!;
                          });
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Text('O', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _longDegreesController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '°',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(color: Colors.green),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2),
                          child: Text('°', style: TextStyle(fontSize: 12)),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _longMinutesController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '\'',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(color: Colors.green),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2),
                          child: Text('\'', style: TextStyle(fontSize: 12)),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _longSecondsController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '"',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(color: Colors.green),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2),
                          child: Text('"', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Bouton GO
              Center(
                child: GestureDetector(
                  onTap: _handleGoButtonPressed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
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
              ),
              
              const SizedBox(height: 20),
              
              // Suggestions
              const Text(
                'Suggestions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              ...suggestions.map((suggestion) => _buildSuggestionItem(suggestion)),
              
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

  Widget _buildSuggestionItem(Map<String, String> suggestion) {
    return GestureDetector(
      onTap: () => _handleSuggestionPressed(suggestion['coordinates']!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
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
                suggestion['description'] ?? '',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Colors.grey[400],
            ),
            const SizedBox(width: 8),
            Text(
              suggestion['coordinates'] ?? '',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}