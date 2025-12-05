import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/scan_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('cache');
  await Hive.openBox('history');
  await Hive.openBox('prefs');
  runApp(const BarcodeApp());
}

class BarcodeApp extends StatelessWidget {
  const BarcodeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const ScanScreen(), title: 'ScanAware');
  }
}
