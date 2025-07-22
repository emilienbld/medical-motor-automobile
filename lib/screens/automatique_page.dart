// automatique_page.dart - VERSION AVEC 3 SECTIONS DISTINCTES
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import '../services/wifi_connection_manager.dart';
import '../services/gps_navigation_service.dart';
import '../widgets/navigation_status_widget.dart';
import '../widgets/coordinate_input_widget.dart';

class AutomatiquePage extends StatefulWidget {
  const AutomatiquePage({Key? key}) : super(key: key);

  @override
  State<AutomatiquePage> createState() => _AutomatiquePageState();
}

class _AutomatiquePageState extends State<AutomatiquePage> {
  // Services
  final WiFiConnectionManager _connectionManager = WiFiConnectionManager();
  late final GPSNavigationService _gpsNavigationService;
  
  // État de l'interface
  bool isConnected = false;
  NavigationState _navigationState = NavigationState.idle;
  String? _currentDestination;
  Duration _navigationDuration = Duration.zero;
  DateTime? _navigationStartTime;
  String? _selectedSuggestion;

  // Instance Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ✅ NOUVEAU : 2 streams distincts
  late Stream<QuerySnapshot> _predefinedDestinationsStream;  // Global
  late Stream<QuerySnapshot> _personalDestinationsStream;     // Personnel
  
  // Subscriptions
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<NavigationState>? _navigationStateSubscription;
  StreamSubscription<String?>? _destinationSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    
    // Initialiser les services
    _gpsNavigationService = GPSNavigationService(_connectionManager);
    
    // État initial
    isConnected = _connectionManager.isConnected;
    
    // ✅ NOUVEAU : Initialiser les 2 streams
    String userId = FirebaseAuth.instance.currentUser!.uid;
    
    // Stream pour destinations prédéfinies (global)
    _predefinedDestinationsStream = _firestore
        .collection('destinations')
        .where('type', isEqualTo: 'predefini')
        // .orderBy('lieu')
        .snapshots();
    
  Widget _buildPredefinedDestinationsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _predefinedDestinationsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorContainer('Erreur: ${snapshot.error}');
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingContainer();
        }
        
        final docs = snapshot.data?.docs ?? [];
        final predefinedDestinations = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'coordinates': data['coordonnees'] ?? '',
            'description': data['lieu'] ?? '',
            'id': doc.id,
            'type': 'predefini',
          };
        }).toList();
        predefinedDestinations.sort((a, b) => 
          (a['description'] as String).compareTo(b['description'] as String));
        
        return _buildDestinationCategory(
          title: 'Destinations prédéfinies',
          subtitle: 'Lieux médicaux disponibles pour tous',
          icon: Icons.local_hospital,
          color: Colors.purple,
          destinations: predefinedDestinations,
          isPredefined: true,
        );
      },
    );
  }

    // Stream pour destinations personnelles
    _personalDestinationsStream = _firestore
        .collection('users')
        .doc(userId)
        .collection('destinations')
        .orderBy('lieu')
        .snapshots();
    
    _setupSubscriptions();
    
    // Démarrer heartbeat si connecté
    if (isConnected) {
      _connectionManager.startHeartbeat();
    }
  }

  void _setupSubscriptions() {
    // Écouter les changements de connexion
    _connectionSubscription = _connectionManager.connectionStream.listen((connected) {
      setState(() {
        isConnected = connected;
      });
      
      if (!connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Connexion robot perdue'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
    
    // Écouter l'état de navigation
    _navigationStateSubscription = _gpsNavigationService.stateStream.listen((state) {
      setState(() {
        _navigationState = state;
      });
    });
    
    // Écouter la destination
    _destinationSubscription = _gpsNavigationService.destinationStream.listen((destination) {
      setState(() {
        _currentDestination = destination;
      });
    });
    
    // Écouter la durée
    _durationSubscription = _gpsNavigationService.durationStream.listen((duration) {
      setState(() {
        _navigationDuration = duration;
        _navigationStartTime = _gpsNavigationService.navigationStartTime;
      });
    });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _navigationStateSubscription?.cancel();
    _destinationSubscription?.cancel();
    _durationSubscription?.cancel();
    
    _gpsNavigationService.dispose();
    super.dispose();
  }

  // === GESTION DES COORDONNÉES ===

  void _handleCoordinatesEntered(String coordinates) async {
    print('Coordonnées saisies: $coordinates');
    
    if (!isConnected) {
      _showErrorSnackBar('Robot non connecté');
      return;
    }
    
    // Proposer de sauvegarder les coordonnées
    bool? shouldSave = await _showSaveDialog();
    if (shouldSave == true) {
      await _saveCustomCoordinates(coordinates);
    }
    
    // Démarrer la navigation
    await _startNavigationWithCoordinates(coordinates);
  }

  void _handleSuggestionPressed(String coordinates) {
    setState(() {
      _selectedSuggestion = coordinates;
    });
  }

  void _handleSuggestionGoPressed() async {
    if (_selectedSuggestion != null) {
      print('Coordonnées suggérées: $_selectedSuggestion');
      await _startNavigationWithCoordinates(_selectedSuggestion!);
    }
  }

  Future<void> _startNavigationWithCoordinates(String coordinates) async {
    if (!isConnected) {
      _showErrorSnackBar('Robot non connecté');
      return;
    }
    
    try {
      // 1. Définir la destination
      final setSuccess = await _gpsNavigationService.setDestination(coordinates);
      if (!setSuccess) {
        _showErrorSnackBar('Erreur lors de la configuration de la destination');
        return;
      }
      
      // 2. Démarrer la navigation
      final startSuccess = await _gpsNavigationService.startNavigation();
      if (startSuccess) {
        _showSuccessSnackBar('Navigation démarrée vers: $coordinates');
      } else {
        _showErrorSnackBar('Erreur lors du démarrage de la navigation');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur: $e');
    }
  }

  Future<void> _stopNavigation() async {
    final success = await _gpsNavigationService.stopNavigation();
    if (success) {
      _showWarningSnackBar('Navigation arrêtée');
    } else {
      _showErrorSnackBar('Erreur lors de l\'arrêt');
    }
  }

  // === GESTION FIREBASE ===

  Future<void> _saveCustomCoordinates(String coordinates) async {
    try {
      String? description = await _showDescriptionDialog();
      
      if (description != null && description.isNotEmpty) {
        // Sauvegarder dans la collection personnelle de l'utilisateur
        String userId = FirebaseAuth.instance.currentUser!.uid;
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('destinations')
            .add({
          'coordonnees': coordinates,
          'lieu': description,
          'historique': true, // Par défaut dans l'historique
        });
        
        _showSuccessSnackBar('Destination sauvegardée: $description');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la sauvegarde: $e');
    }
  }

  Future<void> _deleteDestination(String documentId) async {
    bool? shouldDelete = await _showDeleteConfirmationDialog();
    
    if (shouldDelete != true) return;
    
    try {
      // Supprimer de la collection personnelle de l'utilisateur
      String userId = FirebaseAuth.instance.currentUser!.uid;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('destinations')
          .doc(documentId)
          .delete();
      _showWarningSnackBar('Destination supprimée');
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la suppression: $e');
    }
  }

  Future<void> _toggleHistorique(String documentId, bool currentHistorique) async {
    try {
      // Modifier dans la collection personnelle de l'utilisateur
      String userId = FirebaseAuth.instance.currentUser!.uid;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('destinations')
          .doc(documentId)
          .update({
        'historique': !currentHistorique,
      });
      
      _showInfoSnackBar(currentHistorique 
          ? 'Déplacée vers les destinations rapides' 
          : 'Ajoutée à l\'historique');
    } catch (e) {
      _showErrorSnackBar('Erreur: $e');
    }
  }

  // === DIALOGS ===

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

  Future<bool?> _showDeleteConfirmationDialog() async {
    return showDialog<bool>(
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
  }

  // === SNACKBARS ===

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicateur de connexion si pas connecté
            if (!isConnected) _buildConnectionWarning(),
            
            // Section Navigation en cours
            NavigationStatusWidget(
              state: _navigationState,
              destination: _currentDestination,
              duration: _navigationDuration,
              startTime: _navigationStartTime,
              onStop: _stopNavigation,
            ),
            
            // Section Coordonnées manuelles
            CoordinateInputWidget(
              onCoordinatesEntered: _handleCoordinatesEntered,
              isNavigating: _navigationState == NavigationState.navigating,
            ),
            
            const SizedBox(height: 20),
            
            // ✅ NOUVEAU : Section Destinations prédéfinies
            _buildPredefinedDestinationsSection(),
            
            const SizedBox(height: 16),
            
            // ✅ NOUVEAU : Sections Destinations personnelles (rapides + historique)
            _buildPersonalDestinationsSection(),
            
            // Bouton "Y ALLER" pour la suggestion sélectionnée
            if (_selectedSuggestion != null && _navigationState != NavigationState.navigating) ...[
              const SizedBox(height: 16),
              _buildGoToSelectedButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Robot non connecté. Allez dans l\'onglet WiFi pour vous connecter.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoToSelectedButton() {
    return Center(
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.navigation, size: 16, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'Y ALLER',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ NOUVEAU : Section destinations prédéfinies (global)
  Widget _buildPredefinedDestinationsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _predefinedDestinationsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorContainer('Erreur: ${snapshot.error}');
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingContainer();
        }
        
        final docs = snapshot.data?.docs ?? [];
        final predefinedDestinations = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'coordinates': data['coordonnees'] ?? '',
            'description': data['lieu'] ?? '',
            'id': doc.id,
            'type': 'predefini',
          };
        }).toList();
        
        return _buildDestinationCategory(
          title: 'Destinations prédéfinies',
          subtitle: 'Lieux médicaux disponibles pour tous',
          icon: Icons.local_hospital,
          color: Colors.purple,
          destinations: predefinedDestinations,
          isPredefined: true,
        );
      },
    );
  }

  // ✅ NOUVEAU : Section destinations personnelles (rapides + historique)
  Widget _buildPersonalDestinationsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _personalDestinationsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorContainer('Erreur: ${snapshot.error}');
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingContainer();
        }
        
        final docs = snapshot.data?.docs ?? [];
        final separatedDestinations = _separatePersonalDestinations(docs);
        final destinationsRapides = separatedDestinations['rapides']!;
        final historiqueDestinations = separatedDestinations['historique']!;
        
        return Column(
          children: [
            // Destinations rapides personnelles
            _buildDestinationCategory(
              title: 'Mes destinations rapides',
              subtitle: 'Vos lieux favoris pour un accès rapide',
              icon: Icons.flash_on,
              color: Colors.green,
              destinations: destinationsRapides,
              isPredefined: false,
              isHistoriqueSection: false,
            ),
            
            if (historiqueDestinations.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDestinationCategory(
                title: 'Mon historique',
                subtitle: 'Vos destinations sauvegardées',
                icon: Icons.history,
                color: Colors.blue,
                destinations: historiqueDestinations,
                isPredefined: false,
                isHistoriqueSection: true,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDestinationCategory({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color? color,
    required List<Map<String, dynamic>> destinations,
    required bool isPredefined,
    bool isHistoriqueSection = false,
  }) {
    return Container(
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
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (destinations.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  isPredefined 
                      ? 'Aucune destination prédéfinie disponible'
                      : 'Aucune destination ${isHistoriqueSection ? 'dans l\'historique' : 'rapide'} disponible',
                  style: const TextStyle(color: Colors.grey),
                ),
              )
            else
              ...destinations.map((destination) => 
                _buildSuggestionItem(
                  destination, 
                  isPredefined: isPredefined,
                  isHistoriqueSection: isHistoriqueSection,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(
    Map<String, dynamic> suggestion, {
    required bool isPredefined,
    bool isHistoriqueSection = false,
  }) {
    final isSelected = _selectedSuggestion == suggestion['coordinates'];
    final isHistorique = suggestion['historique'] ?? false;
    final isNavigationInProgress = _navigationState == NavigationState.navigating;
    
    return GestureDetector(
      onTap: isNavigationInProgress ? null : () => _handleSuggestionPressed(suggestion['coordinates']!),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          suggestion['description'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.green[700] : Colors.black87,
                          ),
                        ),
                      ),
                      // Badge pour les destinations prédéfinies
                      if (isPredefined)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Global',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.purple[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
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
            
            // ✅ Actions selon le type
            if (!isNavigationInProgress && !isPredefined) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  
                  if (isHistoriqueSection)
                    IconButton(
                      icon: Icon(Icons.delete, size: 18, color: Colors.red[400]),
                      onPressed: () => _deleteDestination(suggestion['id']),
                      tooltip: 'Supprimer cette destination',
                    ),
                ],
              ),
            ],
            
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

  Widget _buildErrorContainer(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red, width: 1),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }

  Widget _buildLoadingContainer() {
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

  // ✅ NOUVEAU : Séparer les destinations personnelles
  Map<String, List<Map<String, dynamic>>> _separatePersonalDestinations(List<QueryDocumentSnapshot> docs) {
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