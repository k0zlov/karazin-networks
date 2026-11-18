import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karazin_networks_client/cubit/main_cubit.dart';
import 'package:karazin_networks_client/cubit/main_state.dart';
import 'package:karazin_networks_client/repositories/crypto_repository.dart';
import 'package:karazin_networks_client/screens/main_screen.dart';
import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';
import 'package:material_ui/material_ui.dart';

class FakeCryptoRepository extends Fake implements CryptoRepository {}

class RecordingMainCubit extends MainCubit {
  RecordingMainCubit({bool isSending = false})
    : super(
        repository: FakeCryptoRepository(),
        rsaService: RsaService(),
        aesService: AesService(),
        hashService: HashService(),
      ) {
    emit(
      MainState(
        session: (id: 'test', key: AesKey(key: 'unused', iv: 'unused')),
        isSending: isSending,
        message: isSending ? 'Hello' : '',
      ),
    );
  }

  final sentModes = <bool>[];

  @override
  Future<void> sendMessage({bool corruptHash = false}) async {
    sentModes.add(corruptHash);
  }
}

void main() {
  Future<void> open(WidgetTester tester, RecordingMainCubit cubit) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<MainCubit>.value(
          value: cubit,
          child: const MainScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Enables both buttons for text and sends with the selected hash mode',
    (tester) async {
      final cubit = RecordingMainCubit();
      addTearDown(cubit.close);
      await open(tester, cubit);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      await tester.tap(find.text('Send'));
      await tester.tap(find.text('Send invalid hash'));
      expect(cubit.sentModes, [false, true]);
    },
  );

  testWidgets(
    'Disables both send buttons and editing while a message is pending',
    (tester) async {
      final cubit = RecordingMainCubit(isSending: true);
      addTearDown(cubit.close);
      await open(tester, cubit);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    },
  );

  testWidgets('Fits both send controls on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = RecordingMainCubit();
    addTearDown(cubit.close);
    await open(tester, cubit);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Send invalid hash'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
