// services/gps_navigation_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'wifi_connection_manager.dart';

enum NavigationState {
  idle,           // Au repos
  setting,        // Configuration de la destination
  navigating,     // Navigation en cours
  arrived,        // Arrivé à destination
  error           // Erreur
}

class GPSNavigationService {
  final WiFiConnectionManager _connectionManager;
  
  // État de la navigation
  NavigationState _currentState = NavigationState.idle;
  String? _currentDestination;
  DateTime? _navigationStartTime;
  String? _lastStatusMessage;
  bool _isCommandInProgress = false;
  
  // Streams pour notifier l'UI
  final StreamController<NavigationState> _stateController = StreamController<NavigationState>.broadcast();
  final StreamController<String?> _destinationController = StreamController<String?>.broadcast();
  final StreamController<String?> _statusController = StreamController<String?>.broadcast();
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  
  // Timer pour mettre à jour la durée
  Timer? _durationTimer;
  
  GPSNavigationService(this._connectionManager);
  
  // Getters
  NavigationState get currentState => _currentState;
  String? get currentDestination => _currentDestination;
  DateTime? get navigationStartTime => _navigationStartTime;
  String? get lastStatusMessage => _lastStatusMessage;
  bool get isNavigating => _currentState == NavigationState.navigating;
  bool get isConnected => _connectionManager.isConnected;
  
  // Streams pour l'UI
  Stream<NavigationState> get stateStream => _stateController.stream;
  Stream<String?> get destinationStream => _destinationController.stream;
  Stream<String?> get statusStream => _statusController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  
  // Calculer la durée de navigation
  Duration get navigationDuration {
    if (_navigationStartTime == null) return Duration.zero;
    return DateTime.now().difference(_navigationStartTime!);
  }
  
  /// Définir la destination GPS
  Future<bool> setDestination(String coordinates) async {
    if (!isConnected) {
      _updateStatus('❌ Robot non connecté');
      return false;
    }
    
    if (_isCommandInProgress) {
      _updateStatus('⚠️ Commande en cours...');
      return false;
    }
    
    try {
      _isCommandInProgress = true;
      _updateState(NavigationState.setting);
      _updateStatus('📍 Configuration de la destination...');
      
      print('🎯 Définition destination: $coordinates');
      
      // Envoyer la commande SET au robot
      final setCommand = 'set $coordinates';
      final success = await _sendCommand(setCommand);
      
      if (success) {
        _currentDestination = coordinates;
        _destinationController.add(coordinates);
        _updateStatus('✅ Destination configurée');
        _updateState(NavigationState.idle);
        print('✅ Destination définie: $coordinates');
        return true;
      } else {
        _updateStatus('❌ Échec configuration destination');
        _updateState(NavigationState.error);
        return false;
      }
    } catch (e) {
      print('❌ Erreur setDestination: $e');
      _updateStatus('❌ Erreur: $e');
      _updateState(NavigationState.error);
      return false;
    } finally {
      _isCommandInProgress = false;
    }
  }
  
  /// Démarrer la navigation
  Future<bool> startNavigation() async {
    if (!isConnected) {
      _updateStatus('❌ Robot non connecté');
      return false;
    }
    
    if (_currentDestination == null) {
      _updateStatus('❌ Aucune destination définie');
      return false;
    }
    
    if (_isCommandInProgress) {
      _updateStatus('⚠️ Commande en cours...');
      return false;
    }
    
    try {
      _isCommandInProgress = true;
      _updateStatus('🚀 Démarrage navigation...');
      
      print('🚀 Démarrage navigation vers: $_currentDestination');
      
      // Envoyer la commande GO au robot
      final success = await _sendCommand('go');
      
      if (success) {
        _navigationStartTime = DateTime.now();
        _updateState(NavigationState.navigating);
        _updateStatus('🧭 Navigation en cours...');
        _startDurationTimer();
        print('✅ Navigation démarrée');
        return true;
      } else {
        _updateStatus('❌ Échec démarrage navigation');
        _updateState(NavigationState.error);
        return false;
      }
    } catch (e) {
      print('❌ Erreur startNavigation: $e');
      _updateStatus('❌ Erreur: $e');
      _updateState(NavigationState.error);
      return false;
    } finally {
      _isCommandInProgress = false;
    }
  }
  
  /// Arrêter la navigation
  Future<bool> stopNavigation() async {
    if (!isConnected) {
      _updateStatus('❌ Robot non connecté');
      return false;
    }
    
    try {
      _updateStatus('🛑 Arrêt navigation...');
      
      print('🛑 Arrêt de la navigation');
      
      // Envoyer la commande STOP au robot
      final success = await _sendCommand('stop');
      
      if (success) {
        _stopDurationTimer();
        _updateState(NavigationState.idle);
        _updateStatus('⏹️ Navigation arrêtée');
        print('✅ Navigation arrêtée');
        return true;
      } else {
        _updateStatus('❌ Échec arrêt navigation');
        return false;
      }
    } catch (e) {
      print('❌ Erreur stopNavigation: $e');
      _updateStatus('❌ Erreur: $e');
      return false;
    }
  }
  
  /// Obtenir le statut du robot
  Future<Map<String, dynamic>?> getRobotStatus() async {
    if (!isConnected) return null;
    
    try {
      final response = await http.get(
        Uri.parse('http://${_connectionManager.arduinoIP}/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('❌ Erreur getRobotStatus: $e');
    }
    
    return null;
  }
  
  /// Envoyer une commande au robot
  Future<bool> _sendCommand(String command) async {
    try {
      print('📤 Envoi commande GPS: $command');
      
      final response = await http.post(
        Uri.parse('http://${_connectionManager.arduinoIP}/command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': command}),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        print('✅ Commande GPS envoyée: $command');
        return true;
      } else {
        print('⚠️ Réponse inattendue: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Erreur envoi commande GPS: $e');
      return false;
    }
  }
  
  /// Mettre à jour l'état
  void _updateState(NavigationState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
      print('📍 État navigation: $newState');
    }
  }
  
  /// Mettre à jour le message de statut
  void _updateStatus(String message) {
    _lastStatusMessage = message;
    _statusController.add(message);
    print('💬 Status: $message');
  }
  
  /// Démarrer le timer de durée
  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_navigationStartTime != null) {
        _durationController.add(navigationDuration);
      }
    });
  }
  
  /// Arrêter le timer de durée
  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }
  
  /// Réinitialiser complètement le service
  void reset() {
    _stopDurationTimer();
    _currentDestination = null;
    _navigationStartTime = null;
    _updateState(NavigationState.idle);
    _updateStatus('🏠 Prêt');
    _destinationController.add(null);
  }
  
  /// Obtenir un résumé de l'état actuel
  Map<String, dynamic> getNavigationSummary() {
    return {
      'state': _currentState.toString(),
      'destination': _currentDestination,
      'isNavigating': isNavigating,
      'duration': _navigationStartTime != null 
          ? navigationDuration.inSeconds 
          : 0,
      'startTime': _navigationStartTime?.toIso8601String(),
      'lastStatus': _lastStatusMessage,
      'isConnected': isConnected,
    };
  }
  
  /// Nettoyer les ressources
  void dispose() {
    print('🗑️ Disposal du GPSNavigationService');
    _stopDurationTimer();
    _stateController.close();
    _destinationController.close();
    _statusController.close();
    _durationController.close();
  }
}