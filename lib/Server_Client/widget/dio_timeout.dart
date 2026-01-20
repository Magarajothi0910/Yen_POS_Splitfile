import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late Dio dio;

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://yenerp.com',
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final connectivity = await Connectivity().checkConnectivity();
          if (connectivity == ConnectivityResult.none) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: 'No Internet Connection',
              ),
            );
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Log error details
          handler.next(e);
        },
      ),
    );
  }

  // Helper method to make POST requests
  Future<Response?> postRequest({
    required String path,
    required Map<String, dynamic> data,
    bool throwOnError = false,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await dio.post(
        path,
        data: data,
        options: Options(headers: headers),
      );
      return response;
    } on DioException catch (e) {
      if (throwOnError) {
        rethrow;
      }
      return null;
    }
  }

  // Helper method to make PATCH requests
  Future<Response?> patchRequest({
    required String path,
    required Map<String, dynamic> data,
    bool throwOnError = false,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await dio.patch(
        path,
        data: data,
        options: Options(headers: headers),
      );
      return response;
    } on DioException catch (e) {
      if (throwOnError) {
        rethrow;
      }
      return null;
    }
  }
}
