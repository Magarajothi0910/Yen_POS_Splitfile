import 'dart:convert';
import 'package:http/http.dart' as http;

class OrderApiService {
  final String baseUrl = 'https://yenerp.com/fastapi/orders';

  Future<Map<String, int>> fetchOrderCounts() async {
    final response = await http.get(Uri.parse(baseUrl));

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body) as List<dynamic>;
        int holdOrders =
            data.where((order) => order['status'] == 'active').length;
        int pendingOrders =
            data.where((order) => order['status'] == 'confirm').length;
        int completedOrders =
            data.where((order) => order['status'] == 'invoiced').length;

        return {
          'Hold': holdOrders,
          'Pending': pendingOrders,
          'Completed': completedOrders,
        };
      } catch (e) {
        throw Exception('Failed to parse response: $e');
      }
    } else {
      throw Exception('No Data available');
    }
  }
}
