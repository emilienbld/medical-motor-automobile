import 'package:flutter/material.dart';
import 'dart:async';

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
  String? _selectedSuggestion;
  DateTime? _departureTime;
  Timer? _chronoTimer;
  Duration _elapsedTime = Duration.zero;
  bool _isNavigating = false;

  // Suggestions de coordonnées
  List<Map<String, String>> suggestions = [
    {'coordinates': '48°50\'18"N,2°18\'41"E', 'description': 'Paris Centre'},
    {'coordinates': '48°51\'29"N,2°17\'40"E', 'description': 'Arc de Triomphe'},
    {'coordinates': '48°52\'08"N,2°19\'56"E', 'description': 'Sacré-Cœur'},
  ];

  @override
  void initState() {
    super.initState();
    
    // Ajouter des listeners pour vérifier si tous les champs sont remplis
    _latDegreesController.addListener(_checkFieldsCompletion);
    _latMinutesController.addListener(_checkFieldsCompletion);
    _latSecondsController.addListener(_checkFieldsCompletion);
    _longDegreesController.addListener(_checkFieldsCompletion);
    _longMinutesController.addListener(_checkFieldsCompletion);
    _longSecondsController.addListener(_checkFieldsCompletion);
  }

  void _checkFieldsCompletion() {
    setState(() {});
  }

  bool get _areAllFieldsFilled {
    return _latDegreesController.text.isNotEmpty &&
           _latMinutesController.text.isNotEmpty &&
           _latSecondsController.text.isNotEmpty &&
           _longDegreesController.text.isNotEmpty &&
           _longMinutesController.text.isNotEmpty &&
           _longSecondsController.text.isNotEmpty;
  }

  void _handleGoButtonPressed() {
    if (!_areAllFieldsFilled) return;
    
    String latDegrees = _latDegreesController.text.trim();
    String latMinutes = _latMinutesController.text.trim();
    String latSeconds = _latSecondsController.text.trim();
    String longDegrees = _longDegreesController.text.trim();
    String longMinutes = _longMinutesController.text.trim();
    String longSeconds = _longSecondsController.text.trim();
    
    String coordinates = '${latDegrees}°${latMinutes}\'${latSeconds}"$_latDirection,${longDegrees}°${longMinutes}\'${longSeconds}"$_longDirection';
    print('Coordonnées sélectionnées: $coordinates');
    _sendCoordinatesData(coordinates);
  }

  void _handleSuggestionPressed(String coordinates) {
    setState(() {
      _selectedSuggestion = coordinates;
    });
  }

  void _handleSuggestionGoPressed() {
    if (_selectedSuggestion != null) {
      print('Coordonnées suggérées sélectionnées: $_selectedSuggestion');
      _sendCoordinatesData(_selectedSuggestion!);
    }
  }

  void _sendCoordinatesData(String coordinates) {
    setState(() {
      _departureTime = DateTime.now();
      _isNavigating = true;
      _elapsedTime = Duration.zero;
    });
    
    // Démarrer le chronomètre
    _chronoTimer?.cancel();
    _chronoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime = DateTime.now().difference(_departureTime!);
      });
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation vers: $coordinates'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _chronoTimer?.cancel();
      _departureTime = null;
      _elapsedTime = Duration.zero;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Navigation arrêtée'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  String _formatTime(DateTime time) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(time.hour)}:${twoDigits(time.minute)}";
  }

  @override
  void dispose() {
    _chronoTimer?.cancel();
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
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Navigation en cours (si active)
            if (_isNavigating) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.navigation,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Navigation en cours',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: _stopNavigation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.stop, size: 16, color: Colors.red),
                                const SizedBox(width: 4),
                                const Text(
                                  'Arrêter',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          'Départ: ${_formatTime(_departureTime!)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          'Durée: ${_formatDuration(_elapsedTime)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Section Coordonnées manuelles
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Entrer vos coordonnées',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Latitude
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 70,
                          child: const Text(
                            'Latitude',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
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
                              activeColor: Colors.green,
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
                              activeColor: Colors.green,
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
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
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
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text('°', style: TextStyle(fontSize: 14)),
                              ),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _latMinutesController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
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
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text('\'', style: TextStyle(fontSize: 14)),
                              ),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _latSecondsController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
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
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text('"', style: TextStyle(fontSize: 14)),
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
                        SizedBox(
                          width: 70,
                          child: const Text(
                            'Longitude',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
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
                              activeColor: Colors.green,
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
                              activeColor: Colors.green,
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
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
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
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text('°', style: TextStyle(fontSize: 14)),
                              ),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _longMinutesController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
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
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text('\'', style: TextStyle(fontSize: 14)),
                              ),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _longSecondsController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
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
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text('"', style: TextStyle(fontSize: 14)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Bouton Y ALLER pour coordonnées manuelles
                    Center(
                      child: GestureDetector(
                        onTap: _areAllFieldsFilled ? _handleGoButtonPressed : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _areAllFieldsFilled 
                                ? Colors.green[50] 
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _areAllFieldsFilled 
                                  ? Colors.green 
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Text(
                            'Y ALLER',
                            style: TextStyle(
                              fontSize: 14,
                              color: _areAllFieldsFilled 
                                  ? Colors.green 
                                  : Colors.grey[400],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Section Suggestions
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Destinations rapides',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    ...suggestions.map((suggestion) => _buildSuggestionItem(suggestion)),
                    
                    if (_selectedSuggestion != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: GestureDetector(
                          onTap: _handleSuggestionGoPressed,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: const Text(
                              'Y ALLER',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(Map<String, String> suggestion) {
    final isSelected = _selectedSuggestion == suggestion['coordinates'];
    
    return GestureDetector(
      onTap: () => _handleSuggestionPressed(suggestion['coordinates']!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[50] : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? Colors.green : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion['description'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.green[700] : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion['coordinates'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.location_on,
              size: 20,
              color: isSelected ? Colors.green : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}