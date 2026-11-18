import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:karazin_networks_client/application.dart';
import 'package:karazin_networks_client/cubit/main_cubit.dart';
import 'package:karazin_networks_client/di_container.dart';
import 'package:karazin_networks_client/screens/main_screen.dart';
import 'package:material_ui/material_ui.dart';

abstract final class ScreenFactory {
  static Widget createApplication() => const Application();

  static Widget createMainScreen() {
    return BlocProvider(
      create: (_) => getIt<MainCubit>()..connect(),
      child: const MainScreen(),
    );
  }
}
