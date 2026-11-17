import 'package:lab6_client/navigation/router.dart';
import 'package:material_ui/material_ui.dart';

class Application extends StatelessWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(title: 'Lab 6', debugShowCheckedModeBanner: false, routerConfig: router);
  }
}
