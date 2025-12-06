import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}
class _ScanScreenState extends State<ScanScreen> {
  bool scanning = false;
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ScanAware')),
      body: MobileScanner(
        allowDuplicates: false,
        onDetect: (capture) async {
          final code = capture.barcodes.first.rawValue ?? '';
          if (!scanning) {
            setState(() => scanning = true);
            showDialog(context: context, builder: (_) => AlertDialog(content: Text('Scanned: \$code')))
              .then((_) => setState(() => scanning = false));
          }
        },
      ),
    );
  }
}