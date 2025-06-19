import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CameraStreamPage extends StatefulWidget {
  @override
  _CameraStreamPageState createState() => _CameraStreamPageState();
}

class _CameraStreamPageState extends State<CameraStreamPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    
    // Initialisation du contrôleur WebView
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Optionnel : afficher le progrès de chargement
            debugPrint('WebView is loading (progress : $progress%)');
          },
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Page resource error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse('http://172.20.10.3:81/stream'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Flux ESP32-CAM"),
        backgroundColor: Colors.blueAccent,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}