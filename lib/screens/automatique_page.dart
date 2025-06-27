import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Instance Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Stream pour les destinations (créé une seule fois pour éviter les freeze)
  late Stream<QuerySnapshot> _destinationsStream;

  @override
  void initState() {
    super.initState();
    
    // Initialiser le stream une seule fois pour éviter les reconstructions
    _destinationsStream = _firestore
        .collection('destinations')
        .orderBy('lieu')
        .snapshots();
    
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

  // Fonction pour sauvegarder les coordonnées personnalisées dans Firebase
  Future<void> _saveCustomCoordinates(String coordinates) async {
    try {
      // Demander à l'utilisateur une description
      String? description = await _showDescriptionDialog();
      
      if (description != null && description.isNotEmpty) {
        await _firestore.collection('destinations').add({
          'coordonnees': coordinates,
          'lieu': description,
          'historique': true, // Marquer comme historique car c'est personnalisé
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Destination sauvegardée: $description'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sauvegarde: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _showDescriptionDialog() async {
    final TextEditingController descController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sauvegarder cette destination'),
        content: TextField(
          controller: descController,
          decoration: const InputDecoration(
            labelText: 'Nom de la destination',
            hintText: 'Ex: Mon lieu favori',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, descController.text.trim()),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showSaveDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sauvegarder ces coordonnées ?'),
        content: const Text('Voulez-vous sauvegarder ces coordonnées pour un usage ultérieur ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui'),
          ),
        ],
      ),
    );
  }

  void _handleGoButtonPressed() async {
    if (!_areAllFieldsFilled) return;
    
    String latDegrees = _latDegreesController.text.trim();
    String latMinutes = _latMinutesController.text.trim();
    String latSeconds = _latSecondsController.text.trim();
    String longDegrees = _longDegreesController.text.trim();
    String longMinutes = _longMinutesController.text.trim();
    String longSeconds = _longSecondsController.text.trim();
    
    String coordinates = '${latDegrees}°${latMinutes}\'${latSeconds}"$_latDirection,${longDegrees}°${longMinutes}\'${longSeconds}"$_longDirection';
    print('Coordonnées sélectionnées: $coordinates');
    
    // Proposer de sauvegarder les coordonnées
    bool? shouldSave = await _showSaveDialog();
    if (shouldSave == true) {
      await _saveCustomCoordinates(coordinates);
    }
    
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
            
            // StreamBuilder optimisé pour éviter les freeze
            StreamBuilder<QuerySnapshot>(
              stream: _destinationsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red, width: 1),
                    ),
                    child: Text(
                      'Erreur: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aucune destination disponible'),
                    ),
                  );
                }
                
                // Séparer les destinations
                final separatedDestinations = _separateDestinations(docs);
                final destinationsRapides = separatedDestinations['rapides']!;
                final historiqueDestinations = separatedDestinations['historique']!;
                
                return Column(
                  children: [
                    // Section Destinations rapides (historique: false)
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
                            Row(
                              children: [
                                Icon(Icons.flash_on, color: Colors.green[600], size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Destinations rapides',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            if (destinationsRapides.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Aucune destination rapide disponible',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            else
                              ...destinationsRapides.map((destination) => 
                                _buildSuggestionItem(destination, isHistoriqueSection: false)),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Section Historique (historique: true)
                    if (historiqueDestinations.isNotEmpty)
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
                              Row(
                                children: [
                                  Icon(Icons.history, color: Colors.blue[600], size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Historique',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              ...historiqueDestinations.map((destination) => 
                                _buildSuggestionItem(destination, isHistoriqueSection: true)),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            
            // Bouton "Y ALLER" pour la suggestion sélectionnée
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
    );
  }

  Widget _buildSuggestionItem(Map<String, dynamic> suggestion, {required bool isHistoriqueSection}) {
    final isSelected = _selectedSuggestion == suggestion['coordinates'];
    final isHistorique = suggestion['historique'] ?? false;
    
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
            
            // Actions à droite
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouton pour basculer vers/depuis l'historique
                IconButton(
                  icon: Icon(
                    isHistoriqueSection ? Icons.flash_on : Icons.history,
                    size: 18,
                    color: isHistoriqueSection ? Colors.green[600] : Colors.blue[600],
                  ),
                  onPressed: () => _toggleHistorique(suggestion['id'], isHistorique),
                  tooltip: isHistoriqueSection 
                      ? 'Déplacer vers les destinations rapides' 
                      : 'Ajouter à l\'historique',
                ),
                
                // Bouton de suppression (seulement pour l'historique)
                if (isHistoriqueSection)
                  IconButton(
                    icon: Icon(Icons.delete, size: 18, color: Colors.red[400]),
                    onPressed: () => _deleteDestination(suggestion['id']),
                    tooltip: 'Supprimer cette destination',
                  ),
              ],
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

  // Fonction pour supprimer une destination
  Future<void> _deleteDestination(String documentId) async {
    // Demander confirmation
    bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la destination'),
        content: const Text('Êtes-vous sûr de vouloir supprimer définitivement cette destination ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    
    if (shouldDelete != true) return;
    
    try {
      await _firestore.collection('destinations').doc(documentId).delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Destination supprimée'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fonction pour basculer une destination vers/depuis l'historique
  Future<void> _toggleHistorique(String documentId, bool currentHistorique) async {
    try {
      await _firestore.collection('destinations').doc(documentId).update({
        'historique': !currentHistorique,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentHistorique 
              ? 'Destination déplacée vers les destinations rapides' 
              : 'Destination ajoutée à l\'historique'),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fonction pour séparer les destinations
  Map<String, List<Map<String, dynamic>>> _separateDestinations(List<QueryDocumentSnapshot> docs) {
    final destinationsRapides = <Map<String, dynamic>>[];
    final historiqueDestinations = <Map<String, dynamic>>[];
    
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final destination = {
        'coordinates': data['coordonnees'] ?? '',
        'description': data['lieu'] ?? '',
        'id': doc.id,
        'historique': data['historique'] ?? false,
      };
      
      if (destination['historique'] as bool) {
        historiqueDestinations.add(destination);
      } else {
        destinationsRapides.add(destination);
      }
    }
    
    return {
      'rapides': destinationsRapides,
      'historique': historiqueDestinations,
    };
  }
}