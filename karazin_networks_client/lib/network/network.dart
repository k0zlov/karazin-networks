abstract interface class Network {
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  });

  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, String>? headers,
  });

  Future<T> put<T>(
    String path, {
    Object? data,
    Map<String, String>? headers,
  });

  Future<T> patch<T>(
    String path, {
    Object? data,
    Map<String, String>? headers,
  });

  Future<void> delete(
    String path, {
    Map<String, String>? headers,
  });
}
