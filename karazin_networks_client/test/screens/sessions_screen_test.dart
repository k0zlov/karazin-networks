import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:karazin_networks_client/models/session_info.dart';
import 'package:karazin_networks_client/repositories/crypto_repository.dart';
import 'package:karazin_networks_client/screens/sessions_screen.dart';
import 'package:material_ui/material_ui.dart';

class FakeSessionsRepository extends Fake implements CryptoRepository {
  List<SessionInfo> sessions = [];
  Future<List<SessionInfo>> Function()? load;
  int requests = 0;

  @override
  Future<List<SessionInfo>> getSessions() async {
    requests++;
    final handler = load;
    return handler == null ? sessions : await handler();
  }
}

void main() {
  late FakeSessionsRepository repository;
  setUp(() => repository = FakeSessionsRepository());

  Future<void> open(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(home: SessionsScreen(repository: repository)),
  );

  testWidgets(
    'Shows loading, blocks duplicate refreshes and displays an empty list',
    (tester) async {
      final gate = Completer<List<SessionInfo>>();
      repository.load = () => gate.future;
      await open(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final refresh = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == 'Refresh sessions',
        ),
      );
      expect(refresh.onPressed, isNull);
      expect(repository.requests, 1);
      gate.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('No sessions yet.'), findsOneWidget);
    },
  );

  testWidgets('Displays IDs, statuses and expiration in local time', (
    tester,
  ) async {
    final expiresAt = DateTime.utc(2026, 11, 18, 12, 1, 5);
    repository.sessions = [
      SessionInfo(
        sessionId: 'valid-session',
        isValid: true,
        expiresAt: expiresAt,
      ),
      SessionInfo(
        sessionId: 'expired-session',
        isValid: false,
        expiresAt: expiresAt,
      ),
    ];
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.text('valid-session'), findsOneWidget);
    expect(find.text('expired-session'), findsOneWidget);
    expect(find.text('Valid'), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
    final local = expiresAt.toLocal();
    final date = MaterialLocalizations.of(
      tester.element(find.byType(SessionsScreen)),
    ).formatMediumDate(local);
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
    expect(find.text('Expires: $date, $time'), findsNWidgets(2));
  });

  testWidgets('Refreshes the list and replaces stale validity statuses', (
    tester,
  ) async {
    final expiresAt = DateTime.utc(2026, 11, 18, 12, 1);
    repository.sessions = [
      SessionInfo(sessionId: 'session', isValid: true, expiresAt: expiresAt),
    ];
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.text('Valid'), findsOneWidget);
    repository.sessions = [
      SessionInfo(sessionId: 'session', isValid: false, expiresAt: expiresAt),
    ];
    await tester.tap(find.byTooltip('Refresh sessions'));
    await tester.pumpAndSettle();
    expect(repository.requests, 2);
    expect(find.text('Valid'), findsNothing);
    expect(find.text('Expired'), findsOneWidget);
  });

  testWidgets('Reports a load error and allows retrying', (tester) async {
    repository.load = () async => throw StateError('Unavailable');
    await open(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Could not load sessions. Please try again.'),
      findsOneWidget,
    );
    repository.load = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.requests, 2);
    expect(find.text('No sessions yet.'), findsOneWidget);
    expect(
      find.text('Could not load sessions. Please try again.'),
      findsNothing,
    );
  });

  testWidgets('Does not update a removed screen when loading completes', (
    tester,
  ) async {
    final gate = Completer<List<SessionInfo>>();
    repository.load = () => gate.future;
    await open(tester);
    await tester.pumpWidget(const SizedBox());
    gate.complete([]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fits long session IDs on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final id = 'a' * 128;
    repository.sessions = [
      SessionInfo(
        sessionId: id,
        isValid: false,
        expiresAt: DateTime.utc(2026, 11, 18),
      ),
    ];
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.text(id), findsOneWidget);
    expect(find.text('Expired'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
