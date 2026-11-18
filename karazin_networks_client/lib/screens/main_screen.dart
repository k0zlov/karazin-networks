import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:karazin_networks_client/cubit/main_cubit.dart';
import 'package:karazin_networks_client/cubit/main_state.dart';
import 'package:karazin_networks_client/navigation/routes.dart';
import 'package:karazin_networks_client/widgets/message_panel.dart';
import 'package:karazin_networks_client/widgets/session_status.dart';
import 'package:material_ui/material_ui.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MainCubit>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Karazin Networks'),
        actions: [
          TextButton(
            onPressed: () => const SessionsRoute().push<void>(context),
            child: const Text('Sessions'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: BlocBuilder<MainCubit, MainState>(
              builder: (context, state) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    SessionStatus(
                      isConnecting: state.isConnecting,
                      isConnected: state.isConnected,
                      error: state.sessionError,
                      onRetry: cubit.connect,
                    ),
                    const SizedBox(height: 24),
                    MessagePanel(
                      inputEnabled: state.isConnected && !state.isSending,
                      isSending: state.isSending,
                      reply: state.reply,
                      error: state.messageError,
                      onChanged: cubit.changeMessage,
                      onSend: state.canSend ? cubit.sendMessage : null,
                      onSendInvalidHash: state.canSend
                          ? () => cubit.sendMessage(corruptHash: true)
                          : null,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
