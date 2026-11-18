import 'package:go_router/go_router.dart';
import 'package:karazin_networks_client/navigation/routes.dart';

final GoRouter router = GoRouter(
  routes: $appRoutes,
  initialLocation: const MainRoute().location,
);
