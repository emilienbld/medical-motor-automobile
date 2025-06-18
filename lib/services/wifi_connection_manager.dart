// wifi_connection_manager.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class WiFiConnectionManager {
  static final WiFiConnectionManager _instance = WiFiConnectionManager._internal();
  factory WiFiConnectionManager() => _instance;
  WiFiConnectionManager._internal();

  bool _isConnected = false;
  String _arduinoIP = '192.168.4.1';
  Timer? _heartbeatTimer;
  
  // Stream pour notifier les changements de connexion
  final StreamController<bool> _connectionStream = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionStream.stream;

  bool get isConnected => _isConnected;
  String get arduinoIP => _arduinoIP;

  // Maintenir la connexion avec un heartbeat
  void startHeartbeat() {
    if (_heartbeatTimer?.isActive == true) return; // Éviter les doublons
    
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkConnection();
    });
    print('🔄 Heartbeat démarré pour $_arduinoIP');
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    print('⏹️ Heartbeat arrêté');
  }

  Future<void> _checkConnection() async {
    if (_arduinoIP.isEmpty) return;
    
    try {
      print('🏓 Ping vers $_arduinoIP...');
      
      // Essayer plusieurs endpoints pour la vérification
      final endpoints = ['/ping', '/status', '/'];
      bool connectionFound = false;
      
      for (String endpoint in endpoints) {
        try {
          final response = await http.get(
            Uri.parse('http://$_arduinoIP$endpoint'),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 3));

          if (response.statusCode == 200) {
            connectionFound = true;
            break;
          }
        } catch (e) {
          // Continuer avec le prochain endpoint
          continue;
        }
      }

      if (connectionFound != _isConnected) {
        _isConnected = connectionFound;
        _connectionStream.add(_isConnected);
        print('📡 Status connexion changé: $_isConnected');
      }
    } catch (e) {
      print('❌ Erreur ping: $e');
      if (_isConnected) {
        _isConnected = false;
        _connectionStream.add(_isConnected);
        print('📡 Connexion perdue');
      }
    }
  }

  Future<bool> connectToDevice(String ip) async {
    print('🔌 Tentative de connexion à $ip');
    
    try {
      // Essayer plusieurs endpoints communs pour les Arduino/ESP32
      final endpoints = [
        'http://$ip/status',
        'http://$ip/info',
        'http://$ip/',
        'http://$ip/api'
      ];

      bool connected = false;
      String workingEndpoint = '';

      for (var endpoint in endpoints) {
        try {
          print('🔍 Test endpoint: $endpoint');
          final response = await http.get(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 3));

          if (response.statusCode == 200) {
            connected = true;
            workingEndpoint = endpoint;
            print('✅ Endpoint fonctionnel trouvé: $endpoint');
            break;
          }
        } catch (e) {
          print('❌ Endpoint $endpoint non disponible: $e');
          continue;
        }
      }

      if (connected) {
        _isConnected = true;
        _arduinoIP = ip;
        _connectionStream.add(_isConnected);
        startHeartbeat();
        print('🎉 Connexion établie avec $ip via $workingEndpoint');
        return true;
      } else {
        print('❌ Aucun endpoint disponible pour $ip');
      }
    } catch (e) {
      print('❌ Erreur de connexion: $e');
    }
    
    _isConnected = false;
    _connectionStream.add(_isConnected);
    return false;
  }

  Future<void> disconnect() async {
    print('🔌 Déconnexion de $_arduinoIP');
    
    try {
      await http.post(
        Uri.parse('http://$_arduinoIP/disconnect'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      print('⚠️ Erreur lors de la déconnexion: $e');
    }

    _isConnected = false;
    _connectionStream.add(_isConnected);
    stopHeartbeat();
    print('📡 Déconnecté');
  }

  Future<bool> sendCommand(String command) async {
    if (!_isConnected) {
      print('❌ Pas de connexion pour envoyer: $command');
      return false;
    }

    try {
      print('📤 Envoi commande: $command vers $_arduinoIP');
      
      final response = await http.post(
        Uri.parse('http://$_arduinoIP/command'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'command': command}),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        print('✅ Commande envoyée avec succès');
        return true;
      } else {
        print('⚠️ Réponse inattendue: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Erreur envoi commande: $e');
      // Vérifier si la connexion est toujours active
      await _checkConnection();
      return false;
    }
  }

  // Méthode pour forcer une vérification immédiate
  Future<void> checkConnectionNow() async {
    await _checkConnection();
  }

  // Méthode pour récupérer le status détaillé
  Map<String, dynamic> getConnectionStatus() {
    return {
      'isConnected': _isConnected,
      'arduinoIP': _arduinoIP,
      'heartbeatActive': _heartbeatTimer?.isActive ?? false,
    };
  }

  void dispose() {
    print('🗑️ Disposal du WiFiConnectionManager');
    stopHeartbeat();
    _connectionStream.close();
  }
}