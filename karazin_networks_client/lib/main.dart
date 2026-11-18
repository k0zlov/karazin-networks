import 'package:karazin_networks_client/di_container.dart';
import 'package:karazin_networks_client/navigation/screen_factory.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  await registerDependencies();
  WidgetsFlutterBinding.ensureInitialized();

  runApp(ScreenFactory.createApplication());
}
