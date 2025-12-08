import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScanAwareApp());
}

class ScanAwareApp extends StatelessWidget {
  const ScanAwareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ScanModel(),
      child: MaterialApp(
        title: 'ScanAware',
        theme: ThemeData(primarySwatch: Colors.teal),
        home: const HomePage(),
      ),
    );
  }
}

class ScanModel extends ChangeNotifier {
  String productName = '';
  Map<String, dynamic>? productData;
  Map<String, dynamic>? toxicityData;
  bool loading = false;

  Future<void> loadLocalDatabases() async {
    final prodJson = await rootBundle.loadString('assets/data/products.json');
    final toxJson = await rootBundle.loadString('assets/data/toxicity.json');
    productData = json.decode(prodJson) as Map<String, dynamic>;
    toxicityData = json.decode(toxJson) as Map<String, dynamic>;
    notifyListeners();
  }

  Future<void> lookupBarcode(String code) async {
    loading = true;
    notifyListeners();

    // local lookup first
    if (productData != null && productData!.containsKey(code)) {
      productName = productData![code]["name"] ?? "Unknown product";
      loading = false;
      notifyListeners();
      return;
    }

    // fallback to OpenFoodFacts
    try {
      final url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$code.json');
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final product = data['product'] ?? {};
        productName = product['product_name'] ?? product['brands'] ?? 'Unknown product';
      } else {
        productName = 'Product not found';
      }
    } catch (e) {
      productName = 'Lookup failed: \$e';
    }

    loading = false;
    notifyListeners();
  }

  double computeToxicityScore(List<dynamic> ingredients) {
    if (toxicityData == null) return 0.0;
    double score = 0.0;
    for (var ing in ingredients) {
      final key = ing.toString().toLowerCase();
      if (toxicityData!.containsKey(key)) {
        score += (toxicityData![key]["risk"] ?? 0) as num;
      }
    }
    if (ingredients.isNotEmpty) score = score / ingredients.length;
    return score.clamp(0, 100).toDouble();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  CameraController? _controller;
  late BarcodeScanner _barcodeScanner;
  bool _isDetecting = false;
  List<CameraDescription>? cameras;

  @override
  void initState() {
    super.initState();
    _barcodeScanner = BarcodeScanner();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ScanModel>(context, listen: false).loadLocalDatabases();
    });
    initCamera();
  }

  Future<void> initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;
    cameras = await availableCameras();
    if (cameras == null || cameras!.isEmpty) return;
    _controller = CameraController(cameras!.first, ResolutionPreset.medium, enableAudio: false);
    await _controller?.initialize();
    await _controller?.startImageStream(_processCameraImage);
    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final InputImageData inputImageData = InputImageData(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        imageRotation: InputImageRotation.rotation0deg,
        inputImageFormat: InputImageFormatMethods.fromRawValue(image.format.raw) ?? InputImageFormat.nv21,
        planeData: image.planes.map(
          (Plane plane) {
            return InputImagePlaneMetadata(bytesPerRow: plane.bytesPerRow, height: plane.height, width: plane.width);
          },
        ).toList(),
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);

      final barcodes = await _barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        for (final b in barcodes) {
          final raw = b.rawValue ?? '';
          if (raw.isNotEmpty) {
            Provider.of<ScanModel>(context, listen: false).lookupBarcode(raw);
            // stop stream briefly
            await _controller?.stopImageStream();
            await Future.delayed(const Duration(milliseconds: 500));
            await _controller?.startImageStream(_processCameraImage);
            break;
          }
        }
      }
    } catch (e) {
      // ignore processing errors
    } finally {
      _isDetecting = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<ScanModel>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('ScanAware')),
      body: Column(
        children: [
          Expanded(
            child: _controller != null && _controller!.value.isInitialized
                ? CameraPreview(_controller!)
                : const Center(child: Text('Camera initializing...')),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                Text('Product: ${model.productName}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                model.loading ? const CircularProgressIndicator() : const SizedBox.shrink(),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    // Manual scan prompt
                    final code = await _promptBarcodeInput(context);
                    if (code != null && code.isNotEmpty) {
                      Provider.of<ScanModel>(context, listen: false).lookupBarcode(code);
                    }
                  },
                  child: const Text('Enter barcode manually'),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<String?> _promptBarcodeInput(BuildContext context) async {
    String value = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter barcode'),
        content: TextField(onChanged: (v) => value = v),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(value), child: const Text('OK')),
        ],
      ),
    );
  }
}
