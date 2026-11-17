import 'package:go_router/go_router.dart';
import 'package:lab6_client/navigation/screen_factory.dart';
import 'package:material_ui/material_ui.dart';

part 'routes.g.dart';

@TypedGoRoute<MainRoute>(path: '/')
class MainRoute extends GoRouteData with $MainRoute {
  const MainRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return ScreenFactory.createMainScreen();
  }
}
