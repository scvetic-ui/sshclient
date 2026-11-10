import 'package:flutter/material.dart';

import 'app_state.dart';
import 'prompter.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const KonzolaApp());
}

class KonzolaApp extends StatelessWidget {
  const KonzolaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kBrand,
        brightness: Brightness.light,
      ),
      home: const HomeScreen(),
    );
  }
}
