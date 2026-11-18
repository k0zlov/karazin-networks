import 'package:go_router/go_router.dart';
import 'package:karazin_networks_client/di_container.dart';
import 'package:karazin_networks_client/models/session_info.dart';
import 'package:karazin_networks_client/navigation/routes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karazin_networks_client/cubit/main_cubit.dart';
import 'package:karazin_networks_client/cubit/main_state.dart';
import 'package:karazin_networks_client/repositories/crypto_repository.dart';
import 'package:karazin_networks_client/screens/main_screen.dart';
import 'package:karazin_networks_crypto/karazin_networks_crypto.dart';
import 'package:material_ui/material_ui.dart';

class FakeCryptoRepository extends Fake implements CryptoRepository {
  @override
  Future<List<SessionInfo>> getSessions() async => [
    SessionInfo(
      sessionId: 'listed-session',
      isValid: true,
      expiresAt: DateTime.utc(2026, 11, 18, 12, 1),
    ),
  ];
}

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

  Future<void> openRouter(
    WidgetTester tester, {
    String initialLocation = '/',
  }) async {
    await getIt.reset();
    final cubit = RecordingMainCubit();
    getIt.registerSingleton<CryptoRepository>(FakeCryptoRepository());
    getIt.registerFactory<MainCubit>(() => cubit);
    final router = GoRouter(
      routes: $appRoutes,
      initialLocation: initialLocation,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      await getIt.reset();
      if (!cubit.isClosed) await cubit.close();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('Opens sessions and returns to the same draft and session', (
    tester,
  ) async {
    await openRouter(tester);
    await tester.enterText(find.byType(TextField), 'Saved draft');
    await tester.pump();
    final cubit = getIt<MainCubit>();
    final sessionId = cubit.state.session!.id;
    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();
    expect(find.text('listed-session'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Karazin Networks'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Saved draft',
    );
    expect(cubit.state.session!.id, sessionId);
    expect(cubit.isClosed, isFalse);
  });

  testWidgets('Returns to the main screen when sessions is opened directly', (
    tester,
  ) async {
    await openRouter(tester, initialLocation: '/sessions');
    expect(find.text('listed-session'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Karazin Networks'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
