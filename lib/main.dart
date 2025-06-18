// import 'package:flutter/material.dart';
// import 'screens/home_page.dart';

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
//         useMaterial3: true,
//       ),
//       home: const HomePage(),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'navigation/main_navigation.dart';

void main() {
  runApp(const ZiggyCarApp());
}

class ZiggyCarApp extends StatelessWidget {
  const ZiggyCarApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZIGGY CAR',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'SF Pro',
      ),
      home: const MainNavigationPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}