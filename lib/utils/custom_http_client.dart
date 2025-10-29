import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:lagfrontend/config/app_config.dart';
import 'package:lagfrontend/utils/network_exception.dart';

class CustomHttpClient extends http.BaseClient {
  final http.Client _inner;
  
  CustomHttpClient() : _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Agregar timeout a todas las peticiones
    request.headers['Accept'] = 'application/json';
    
    try {
      final response = await _inner.send(request).timeout(
        Duration(milliseconds: AppConfig.connectionTimeout),
        onTimeout: () {
          throw NetworkException.connectionTimeout();
        },
      );

      // Manejar errores comunes
      if (response.statusCode >= 500) {
        throw NetworkException.serverError();
      }

      return response;
    } on SocketException catch (_) {
      throw NetworkException.noInternet();
    } on TimeoutException catch (_) {
      throw NetworkException.connectionTimeout();
    } catch (e) {
      if (e is NetworkException) rethrow;
      throw NetworkException(message: e.toString());
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}