import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyService {
  // Base URL ends with /latest/ and we append the `from` currency.
  static const String _baseUrl =
      'https://v6.exchangerate-api.com/v6/41c690c37dbf6dee537bdb58/latest/';

  /// Contoh: convertCurrency('USD', 'IDR', 10)
  static Future<double?> convertCurrency(
    String from,
    String to,
    double amount,
  ) async {
    try {
      final url = Uri.parse('$_baseUrl$from');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // rates is a map of currency -> rate (1 FROM = rate TO)
        final rates =
            data['conversion_rates'] ?? data['rates'] ?? data['rates'];
        if (rates == null) return null;
        final dynamic rateDyn = rates[to];
        if (rateDyn == null) return null;
        final double rate = (rateDyn as num).toDouble();
        return amount * rate;
      } else {
        // print('Failed to fetch rate: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      // print('Error in convertCurrency: $e');
      return null;
    }
  }
}
