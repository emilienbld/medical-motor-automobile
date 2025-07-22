// services/camera_service.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';
import 'wifi_connection_manager.dart';

class CameraService {
  final WiFiConnectionManager _connectionManager;
  
  late final WebViewController _controller;
  bool _isLoaded = false;
  bool _isVisible = true;
  
  // Streams pour notifier l'UI
  final StreamController<bool> _loadedController = StreamController<bool>.broadcast();
  final StreamController<bool> _visibilityController = StreamController<bool>.broadcast();
  
  CameraService(this._connectionManager) {
    _initializeController();
  }
  
  // Getters
  WebViewController get controller => _controller;
  bool get isLoaded => _isLoaded;
  bool get isVisible => _isVisible;
  bool get isConnected => _connectionManager.isConnected;
  
  // Streams pour l'UI
  Stream<bool> get loadedStream => _loadedController.stream;
  Stream<bool> get visibilityStream => _visibilityController.stream;
  
  // Initialiser le contrôleur
  void _initializeController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('Caméra en cours de chargement: $progress%');
          },
          onPageStarted: (String url) {
            debugPrint('Caméra: chargement démarré');
            _updateLoadedState(false);
          },
          onPageFinished: (String url) {
            debugPrint('Caméra: chargement terminé');
            _updateLoadedState(true);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Erreur caméra: ${error.description}');
            _updateLoadedState(false);
          },
        ),
      );
  }
  
  // Mettre à jour l'état de chargement
  void _updateLoadedState(bool loaded) {
    _isLoaded = loaded;
    _loadedController.add(loaded);
  }
  
  // Charger le stream de la caméra
  void loadCameraStream() {
    if (!isConnected) return;
    
    String cameraUrl = "http://192.168.4.2";
    _controller.loadRequest(Uri.parse(cameraUrl));
  }
  
  // Basculer la visibilité
  void toggleVisibility() {
    _isVisible = !_isVisible;
    _visibilityController.add(_isVisible);
  }
  
  // Actualiser la caméra en cas de reconnexion
  void onConnectionChanged(bool connected) {
    if (connected) {
      loadCameraStream();
    } else {
      _updateLoadedState(false);
    }
  }
  
  // Nettoyer les ressources
  void dispose() {
    _loadedController.close();
    _visibilityController.close();
  }
}