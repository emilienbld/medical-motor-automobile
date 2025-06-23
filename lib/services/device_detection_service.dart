// services/device_detection_service.dart
import 'package:wifi_scan/wifi_scan.dart';
import 'dart:async';

class DetectedDevice {
  final String name;
  final String ip;
  final String type;
  final String signal;
  final int signalLevel;
  final String capabilities;
  final int frequency;
  final String bssid;
  bool isConnected;

  DetectedDevice({
    required this.name,
    required this.ip,
    required this.type,
    required this.signal,
    required this.signalLevel,
    required this.capabilities,
    required this.frequency,
    required this.bssid,
    this.isConnected = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ip': ip,
      'type': type,
      'signal': signal,
      'signalLevel': signalLevel,
      'capabilities': capabilities,
      'frequency': frequency,
      'bssid': bssid,
      'isConnected': isConnected,
    };
  }
}

class DeviceDetectionService {
  // Identifiants pour détecter les Arduino/ESP32
  static const List<String> _arduinoIdentifiers = [
    'arduino',
    'r4',
    'esp32',
    'esp-32',
    'esp8266',
    'nodemcu',
    'wemos',
    'ziggycar',
    'arduinoap'
  ];

  // Préfixes MAC connus pour ESP32
  static const List<String> _knownMacPrefixes = [
    '94:b9',
    '34:85',
    'ac:67',
    '24:6f',
    '30:ae',
    'ec:94'
  ];

  List<DetectedDevice> _detectedDevices = [];
  
  // Stream pour notifier l'UI
  final StreamController<List<DetectedDevice>> _devicesController = 
      StreamController<List<DetectedDevice>>.broadcast();
  
  // Getters
  List<DetectedDevice> get detectedDevices => _detectedDevices;
  Stream<List<DetectedDevice>> get devicesStream => _devicesController.stream;
  
  // Filtrer et détecter les appareils Arduino à partir des réseaux scannés
  void filterArduinoDevices(List<WiFiAccessPoint> networks) {
    _detectedDevices.clear();

    for (var network in networks) {
      if (_isArduinoDevice(network)) {
        _detectedDevices.add(_createDetectedDevice(network));
      }
    }

    // Trier par force du signal (du plus fort au plus faible)
    _detectedDevices.sort((a, b) => b.signalLevel.compareTo(a.signalLevel));
    
    _devicesController.add(_detectedDevices);
  }
  
  // Ajouter un appareil manuellement
  void addManualDevice(String name, String ip) {
    final manualDevice = DetectedDevice(
      name: name,
      ip: ip,
      type: 'Arduino (Manuel)',
      signal: 'Manuel',
      signalLevel: -50,
      capabilities: 'N/A',
      frequency: 2400,
      bssid: 'Manual',
    );
    
    _detectedDevices.add(manualDevice);
    _devicesController.add(_detectedDevices);
  }
  
  // Mettre à jour l'état de connexion d'un appareil
  void updateDeviceConnectionStatus(String ip, bool isConnected) {
    for (var device in _detectedDevices) {
      device.isConnected = (device.ip == ip) && isConnected;
    }
    _devicesController.add(_detectedDevices);
  }
  
  // Vérifier si un réseau est un appareil Arduino
  bool _isArduinoDevice(WiFiAccessPoint network) {
    String ssid = network.ssid.toLowerCase();
    String bssid = network.bssid.toLowerCase();

    // Vérifier si le SSID contient un identifiant Arduino
    bool isArduinoBySSID = _arduinoIdentifiers.any((id) => ssid.contains(id));

    // Vérifier si le BSSID (MAC) correspond à un préfixe connu
    bool isArduinoByMAC = _knownMacPrefixes.any((prefix) => bssid.startsWith(prefix));

    // Vérifier la force du signal - les appareils proches ont généralement un signal plus fort
    bool hasStrongSignal = network.level > -70;

    return isArduinoBySSID || 
           isArduinoByMAC || 
           (hasStrongSignal && ssid.length < 10);
  }
  
  // Créer un DetectedDevice à partir d'un WiFiAccessPoint
  DetectedDevice _createDetectedDevice(WiFiAccessPoint network) {
    return DetectedDevice(
      name: network.ssid,
      ip: _guessIPFromSSID(network.ssid),
      type: _determineDeviceType(network.ssid, network.bssid),
      signal: _getSignalStrengthText(network.level),
      signalLevel: network.level,
      capabilities: network.capabilities,
      frequency: network.frequency,
      bssid: network.bssid,
    );
  }
  
  // Deviner l'IP basée sur le SSID
  String _guessIPFromSSID(String ssid) {
    if (ssid.toLowerCase().contains('esp32') ||
        ssid.toLowerCase().contains('arduino')) {
      return '192.168.4.1';
    }
    return '192.168.1.1';
  }
  
  // Déterminer le type d'appareil
  String _determineDeviceType(String ssid, String bssid) {
    ssid = ssid.toLowerCase();

    if (ssid.contains('arduino') && ssid.contains('r4')) {
      return 'Arduino R4 WiFi';
    } else if (ssid.contains('arduino')) {
      return 'Arduino (Autre)';
    } else if (ssid.contains('esp32') || ssid.contains('esp-32')) {
      return 'ESP32';
    } else if (ssid.contains('esp8266')) {
      return 'ESP8266';
    } else {
      return 'Appareil IoT';
    }
  }
  
  // Convertir le niveau de signal en texte
  String _getSignalStrengthText(int level) {
    if (level > -50) return 'Excellent';
    if (level > -60) return 'Très bon';
    if (level > -70) return 'Bon';
    if (level > -80) return 'Faible';
    return 'Très faible';
  }
  
  // Obtenir la couleur du signal
  static String getSignalColorName(String? signal) {
    switch (signal?.toLowerCase()) {
      case 'excellent':
      case 'très bon':
        return 'green';
      case 'bon':
        return 'lightGreen';
      case 'faible':
        return 'orange';
      case 'très faible':
        return 'red';
      default:
        return 'grey';
    }
  }
  
  // Nettoyer les ressources
  void dispose() {
    _devicesController.close();
  }
}