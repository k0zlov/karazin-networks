import 'package:dio/dio.dart';
import 'package:lab6_client/network/network.dart';

class DioNetwork(final Dio _dio) implements Network {
  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final response = await _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: Options(headers: headers),
    );

    return response.data as T;
  }

  @override
  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, String>? headers,
  }) async {
    final response = await _dio.post<T>(
      path,
      data: data,
      options: Options(headers: headers),
    );

    return response.data as T;
  }

  @override
  Future<T> put<T>(
    String path, {
    Object? data,
    Map<String, String>? headers,
  }) async {
    final response = await _dio.put<T>(
      path,
      data: data,
      options: Options(headers: headers),
    );

    return response.data as T;
  }

  @override
  Future<T> patch<T>(
    String path, {
    Object? data,
    Map<String, String>? headers,
  }) async {
    final response = await _dio.patch<T>(
      path,
      data: data,
      options: Options(headers: headers),
    );

    return response.data as T;
  }

  @override
  Future<void> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    await _dio.delete<void>(
      path,
      options: Options(headers: headers),
    );
  }
}
