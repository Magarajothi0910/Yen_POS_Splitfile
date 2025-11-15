import 'package:dio/dio.dart';

class OrderApiService {
  final String baseUrl = 'https://yenerp.com/fastapi/orders';

  Future<Map<String, int>> fetchOrderCounts() async {
    final dio = Dio();

    final response = await dio.get(baseUrl);

    if (response.statusCode == 200) {
      try {
        final data = response.data as List<dynamic>;
        int holdOrders = data
            .where((order) => order['status'] == 'active')
            .length;
        int pendingOrders = data
            .where((order) => order['status'] == 'confirm')
            .length;
        int completedOrders = data
            .where((order) => order['status'] == 'invoiced')
            .length;

        return {
          'Hold': holdOrders,
          'Pending': pendingOrders,
          'Completed': completedOrders,
        };
      } catch (e) {
        throw Exception('Failed to parse response: $e');
      } finally {
        dio.close();
      }
    } else {
      throw Exception('No Data available');
    }
  }
}
