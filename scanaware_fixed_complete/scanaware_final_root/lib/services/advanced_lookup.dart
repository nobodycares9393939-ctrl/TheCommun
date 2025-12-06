class AdvancedLookup {
  static Future<Map<String,dynamic>> lookup(String barcode) async {
    return {'barcode': barcode, 'product_name': 'Demo product'};
  }
}