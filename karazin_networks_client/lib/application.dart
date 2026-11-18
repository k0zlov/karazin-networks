import 'package:karazin_networks_client/navigation/router.dart';
import 'package:material_ui/material_ui.dart';

class Application extends StatelessWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(title: 'Karazin Networks', debugShowCheckedModeBanner: false, routerConfig: router);
  }
}
