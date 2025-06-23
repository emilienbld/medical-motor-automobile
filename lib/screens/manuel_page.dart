import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

import '../widgets/joystick_widget.dart';
import '../services/wifi_connection_manager.dart';
import '../services/camera_service.dart';
import '../services/robot_control_service.dart';

class ManuelPage extends StatefulWidget {
  const ManuelPage({Key? key}) : super(key: key);

  @override
  State<ManuelPage> createState() => _ManuelPageState();
}

class _ManuelPageState extends State<ManuelPage> {
  // Services
  final WiFiConnectionManager _connectionManager = WiFiConnectionManager();
  late final CameraService _cameraService;
  late final RobotControlService _robotControlService;
  
  // État de l'interface
  bool isConnected = false;
  bool _cameraLoaded = false;
  bool _showCamera = true;
  String? _currentCommand;
  String? _lastSentCommand;
  
  // Subscriptions
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<bool>? _cameraLoadedSubscription;
  StreamSubscription<bool>? _cameraVisibilitySubscription;
  StreamSubscription<String?>? _commandSubscription;
  StreamSubscription<String?>? _lastCommandSubscription;

  @override
  void initState() {
    super.initState();
    
    // Initialiser les services
    _cameraService = CameraService(_connectionManager);
    _robotControlService = RobotControlService(_connectionManager);
    
    // État initial
    isConnected = _connectionManager.isConnected;
    _cameraLoaded = _cameraService.isLoaded;
    _showCamera = _cameraService.isVisible;
    
    _setupSubscriptions();
    
    // Charger la caméra si connecté
    if (isConnected) {
      _cameraService.loadCameraStream();
      _connectionManager.startHeartbeat();
    }
  }

  void _setupSubscriptions() {
    // Écouter les changements de connexion
    _connectionSubscription = _connectionManager.connectionStream.listen((connected) {
      setState(() {
        isConnected = connected;
      });
      
      _cameraService.onConnectionChanged(connected);
      
      if (!connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Connexion Arduino perdue'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
    
    // Écouter l'état de la caméra
    _cameraLoadedSubscription = _cameraService.loadedStream.listen((loaded) {
      setState(() {
        _cameraLoaded = loaded;
      });
    });
    
    _cameraVisibilitySubscription = _cameraService.visibilityStream.listen((visible) {
      setState(() {
        _showCamera = visible;
      });
    });
    
    // Écouter les commandes du robot
    _commandSubscription = _robotControlService.commandStream.listen((command) {
      setState(() {
        _currentCommand = command;
      });
    });
    
    _lastCommandSubscription = _robotControlService.lastCommandStream.listen((command) {
      setState(() {
        _lastSentCommand = command;
      });
    });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _cameraLoadedSubscription?.cancel();
    _cameraVisibilitySubscription?.cancel();
    _commandSubscription?.cancel();
    _lastCommandSubscription?.cancel();
    
    _cameraService.dispose();
    _robotControlService.dispose();
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
            children: [
              const SizedBox(height: 8),
              const Text(
                'Contrôle manuel avec vision',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const Text(
                'Utilisez le joystick pour déplacer le robot (mode réactif)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 20),

              // Section Caméra
              _buildCameraSection(),

              const SizedBox(height: 20),

              // Indicateur de connexion si pas connecté
              if (!isConnected) _buildConnectionWarning(),

              // Joystick
              Opacity(
                opacity: isConnected ? 1.0 : 0.5,
                child: JoystickWidget(
                  onJoystickMove: _robotControlService.handleJoystickMove,
                ),
              ),

              const SizedBox(height: 20),

              // Debug info
              if (isConnected) _buildDebugInfo(),

              // Affichage de la commande actuelle
              if (isConnected && _currentCommand != null) _buildCurrentCommand(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraSection() {
    return Card(
      elevation: 4,
      child: Column(
        children: [
          // En-tête de la caméra
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.videocam,
                  size: 18,
                  color: _cameraLoaded ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Vision Robot',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _cameraLoaded ? Colors.black : Colors.grey,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _cameraLoaded ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _showCamera ? Icons.visibility : Icons.visibility_off,
                    size: 18,
                  ),
                  onPressed: _cameraService.toggleVisibility,
                ),
              ],
            ),
          ),

          // Vue de la caméra
          if (_showCamera) _buildCameraView(),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: isConnected ? _buildConnectedCameraView() : _buildDisconnectedCameraView(),
    );
  }

  Widget _buildConnectedCameraView() {
    return Stack(
      children: [
        WebViewWidget(controller: _cameraService.controller),
        if (!_cameraLoaded)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    'Connexion caméra...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDisconnectedCameraView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, color: Colors.grey, size: 40),
          SizedBox(height: 8),
          Text('Caméra non disponible', style: TextStyle(color: Colors.grey)),
          Text(
            'Connectez-vous au robot',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
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

  Widget _buildDebugInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey, width: 1),
      ),
      child: Column(
        children: [
          if (_lastSentCommand != null) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gamepad, size: 12, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  'Direction: $_lastSentCommand',
                  style: const TextStyle(fontSize: 10, color: Colors.green),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          const Text(
            'TEST: Bougez le joystick à fond à droite puis à gauche',
            style: TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentCommand() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.send, size: 12, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            'Envoyé: $_currentCommand',
            style: const TextStyle(fontSize: 10, color: Colors.blue),
          ),
        ],
      ),
    );
  }
}