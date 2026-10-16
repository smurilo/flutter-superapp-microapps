import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:micro_statement/micro_statement.dart';
import 'package:shell/bootstrap.dart';
import 'package:shell/shell_app.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await initializeDateFormatting('pt_BR');
  });

  tearDown(() async {
    await GetIt.I.reset();
    FakeLedger.reset();
  });

  testWidgets('Pix sent in one micro app updates the statement of another via the event bus', (tester) async {
    final registry = await tester.runAsync(
      () => bootstrap(
        dbFactory: databaseFactoryFfiNoIsolate,
        dbPath: inMemoryDatabasePath,
        latency: Duration.zero,
      ),
    );
    await tester.pumpWidget(ShellApp(registry: registry!));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    expect(find.text('Extrato'), findsWidgets);
    expect(find.text(r'R$ 8.432,17'), findsOneWidget);
    expect(find.text('Supermercado Bom Preço'), findsOneWidget);

    await tester.tap(find.text('Pix'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '529.982.247-25');
    await tester.enterText(find.byType(TextField).last, '100,00');
    await tester.pump();
    expect(find.text('Chave CPF'), findsOneWidget);

    await tester.tap(find.text('Transferir'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Pix enviado!'), findsOneWidget);

    await tester.tap(find.text('Extrato').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text(r'R$ 8.332,17'), findsOneWidget);
    expect(find.text('PIX enviado — Bruno Lima'), findsOneWidget);
  });
}
