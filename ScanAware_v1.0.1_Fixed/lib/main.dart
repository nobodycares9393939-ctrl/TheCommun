import 'package:flutter/material.dart';
import 'screens/scan_screen.dart';

void main() {
  runApp(const BarcodeApp());
}

class BarcodeApp extends StatelessWidget {
  const BarcodeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScanAware',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const ScanScreen(),
    );
  }
}
