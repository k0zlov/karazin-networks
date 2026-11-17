import 'package:go_router/go_router.dart';
import 'package:lab6_client/navigation/routes.dart';

final GoRouter router = GoRouter(
  routes: $appRoutes,
  initialLocation: const MainRoute().location,
);
