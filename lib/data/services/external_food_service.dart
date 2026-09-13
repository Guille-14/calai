import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';

class ExternalFoodService {
  static const String _baseUrl =
      'https://world.openfoodfacts.org/api/v2/product';

  Future<ProductModel?> getProductByBarcode(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$barcode.json'),
        headers: {'User-Agent': 'CalorieLens/1.0.0 (Flutter App)'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1) {
          return _parseOpenFoodFactsProduct(data['product']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<ProductModel>> searchProducts(String query) async {
    try {
      final uri = Uri.parse('https://world.openfoodfacts.org/cgi/search.pl')
          .replace(queryParameters: {
        'search_terms': query,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '20',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'CalorieLens/1.0.0 (Flutter App)'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final products = data['products'] as List? ?? [];
        return products
            .where((p) => p != null)
            .map((p) => _parseOpenFoodFactsProduct(p))
            .where((p) => p != null)
            .cast<ProductModel>()
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  ProductModel? _parseOpenFoodFactsProduct(Map<String, dynamic>? product) {
    if (product == null) return null;

    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};

    return ProductModel.create(
      name: product['product_name'] as String? ?? 'Unknown Product',
      calories: _parseDouble(nutriments['energy-kcal_100g']),
      proteins: _parseDouble(nutriments['proteins_100g']),
      carbs: _parseDouble(nutriments['carbohydrates_100g']),
      fats: _parseDouble(nutriments['fat_100g']),
      sugar: _parseDouble(nutriments['sugars_100g']),
      fiber: _parseDouble(nutriments['fiber_100g']),
      countryOrigin: product['countries_tags'] as String?,
      category: product['categories_tags'] as String?,
      barcode: product['code'] as String?,
      imageUrl: product['image_url'] as String?,
    );
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
