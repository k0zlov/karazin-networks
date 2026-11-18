import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:karazin_networks_client/cubit/main_cubit.dart';
import 'package:karazin_networks_client/network/dio_network.dart';
import 'package:karazin_networks_client/network/network.dart';
import 'package:karazin_networks_client/repositories/crypto_repository.dart';
import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';

final GetIt getIt = GetIt.instance;

Future<void> registerDependencies() async {
  getIt.registerLazySingleton<Dio>(
    () => Dio(
      BaseOptions(
        baseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://localhost:8080',
        ),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    ),
    dispose: (dio) => dio.close(force: true),
  );
  getIt.registerLazySingleton<Network>(() => DioNetwork(getIt<Dio>()));
  getIt.registerLazySingleton<CryptoRepository>(
    () => CryptoRepository(getIt<Network>()),
  );
  getIt.registerLazySingleton<RsaService>(RsaService.new);
  getIt.registerLazySingleton<AesService>(AesService.new);
  getIt.registerFactory<MainCubit>(
    () => MainCubit(
      repository: getIt(),
      rsaService: getIt(),
      aesService: getIt(),
    ),
  );

  await getIt.allReady();
}
