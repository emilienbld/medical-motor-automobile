// services/wifi_scanner_service.dart
import 'dart:io';
import 'dart:async';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart' as loc;
import 'package:device_info_plus/device_info_plus.dart';

class WiFiScannerService {
  // État du scan
  bool _isScanning = false;
  List<WiFiAccessPoint> _scannedNetworks = [];
  StreamSubscription<List<WiFiAccessPoint>>? _subscription;
  
  // Streams pour notifier l'UI
  final StreamController<bool> _scanningController = StreamController<bool>.broadcast();
  final StreamController<List<WiFiAccessPoint>> _networksController = StreamController<List<WiFiAccessPoint>>.broadcast();
  final StreamController<String> _errorController = StreamController<String>.broadcast();
  
  // Getters
  bool get isScanning => _isScanning;
  List<WiFiAccessPoint> get scannedNetworks => _scannedNetworks;
  
  // Streams pour l'UI
  Stream<bool> get scanningStream => _scanningController.stream;
  Stream<List<WiFiAccessPoint>> get networksStream => _networksController.stream;
  Stream<String> get errorStream => _errorController.stream;
  
  // Vérifier le service de localisation
  Future<bool> _checkLocationService() async {
    loc.Location location = loc.Location();
    
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        _errorController.add('Le GPS doit être activé pour scanner les réseaux WiFi');
        return false;
      }
    }
    return true;
  }
  
  // Demander les permissions nécessaires
  Future<bool> requestPermissions() async {
    final permissions = [
      Permission.location,
      Permission.locationWhenInUse,
      if (Platform.isAndroid) Permission.nearbyWifiDevices,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();
    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      if (statuses.values.any((status) => status.isPermanentlyDenied)) {
        _errorController.add('Permissions refusées définitivement. Allez dans les paramètres.');
        return false;
      } else {
        _errorController.add('Permissions requises pour scanner les réseaux WiFi');
        return false;
      }
    }
    
    return true;
  }
  
  // Ouvrir les paramètres WiFi
  void openWifiSettings() {
    if (Platform.isAndroid) {
      final intent = AndroidIntent(
        action: 'android.settings.WIFI_SETTINGS',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      intent.launch();
    }
  }
  
  // Scanner les réseaux WiFi
  Future<void> scanNetworks() async {
    if (_isScanning) return;
    
    _updateScanningState(true);
    _scannedNetworks.clear();
    _networksController.add([]);

    try {
      // Vérifier localisation et permissions
      bool locationEnabled = await _checkLocationService();
      if (!locationEnabled) {
        _updateScanningState(false);
        return;
      }

      bool permissionsGranted = await requestPermissions();
      if (!permissionsGranted) {
        _updateScanningState(false);
        return;
      }

      // Vérifier les capacités de scan
      final canGetScannedResults = await WiFiScan.instance.canGetScannedResults(askPermissions: true);
      
      if (canGetScannedResults != CanGetScannedResults.yes) {
        String errorMsg = _getCanGetScannedResultsError(canGetScannedResults);
        throw Exception(errorMsg);
      }

      // Démarrer le scan
      final canStartScan = await WiFiScan.instance.canStartScan();
      
      if (canStartScan == CanStartScan.yes) {
        final started = await WiFiScan.instance.startScan();
        if (started) {
          await Future.delayed(const Duration(seconds: 5));
        }
      }

      // Récupérer les résultats
      final results = await WiFiScan.instance.getScannedResults();
      
      _scannedNetworks = results;
      _networksController.add(results);
      
      if (results.isEmpty) {
        _errorController.add('Aucun réseau trouvé. Vérifiez que le WiFi et le GPS sont activés.');
      }
      
    } catch (e) {
      _errorController.add('Erreur scan WiFi: ${e.toString()}');
    } finally {
      _updateScanningState(false);
    }
  }
  
  // Commencer à écouter les résultats de scan
  Future<void> startListeningToScannedResults() async {
    _subscription?.cancel();

    final can = await WiFiScan.instance.canGetScannedResults(askPermissions: true);
    if (can != CanGetScannedResults.yes) return;

    _subscription = WiFiScan.instance.onScannedResultsAvailable.listen((results) {
      _scannedNetworks = results;
      _networksController.add(results);
    });
  }
  
  // Mettre à jour l'état de scan
  void _updateScanningState(bool scanning) {
    _isScanning = scanning;
    _scanningController.add(scanning);
  }
  
  // Traduire les erreurs de scan
  String _getCanGetScannedResultsError(CanGetScannedResults result) {
    switch (result) {
      case CanGetScannedResults.noLocationPermissionRequired:
        return 'Permission de localisation requise';
      case CanGetScannedResults.noLocationPermissionDenied:
        return 'Permission de localisation refusée';
      case CanGetScannedResults.noLocationPermissionUpgradeAccuracy:
        return 'Localisation précise requise';
      case CanGetScannedResults.noLocationServiceDisabled:
        return 'Service de localisation désactivé';
      case CanGetScannedResults.notSupported:
        return 'Scan WiFi non supporté sur cet appareil';
      default:
        return 'Impossible de scanner les réseaux WiFi';
    }
  }
  
  // Debug des permissions
  Future<Map<String, dynamic>> getDebugInfo() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.locationAlways,
      Permission.nearbyWifiDevices,
    ].request();

    loc.Location location = loc.Location();
    bool serviceEnabled = await location.serviceEnabled();

    final canGetResults = await WiFiScan.instance.canGetScannedResults();
    final canStartScan = await WiFiScan.instance.canStartScan();

    Map<String, dynamic> debugInfo = {
      'permissions': statuses.map((k, v) => MapEntry(k.toString(), v.toString())),
      'locationServiceEnabled': serviceEnabled,
      'canGetScannedResults': canGetResults.toString(),
      'canStartScan': canStartScan.toString(),
    };

    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      debugInfo['androidSDK'] = info.version.sdkInt;
      debugInfo['androidVersion'] = info.version.release;
    }

    return debugInfo;
  }
  
  // Nettoyer les ressources
  void dispose() {
    _subscription?.cancel();
    _scanningController.close();
    _networksController.close();
    _errorController.close();
  }
}