import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';
import 'package:timer_counter/data/models/client_model.dart';
import 'package:timer_counter/data/models/project_client_model.dart';
import 'package:timer_counter/data/models/project_model.dart';
import 'package:timer_counter/data/models/standalone_invoice_model.dart';
import 'package:timer_counter/data/repositories/client_repository.dart';
import 'package:timer_counter/data/repositories/project_client_repository.dart';
import 'package:timer_counter/data/repositories/project_repository.dart';
import 'package:timer_counter/data/repositories/standalone_invoice_repository.dart';
import 'package:timer_counter/presentation/blocs/client/client_bloc.dart';
import 'package:timer_counter/presentation/blocs/client/client_event.dart';
import 'package:timer_counter/presentation/screens/clients_screen.dart';

void main() {
  late Directory tempDir;
  late ClientRepository clients;
  late ProjectClientRepository links;
  late ProjectRepository projects;
  late StandaloneInvoiceRepository invoices;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // EasyLocalization keeps the chosen locale in shared preferences; an empty store is enough here.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : true,
    );
    await EasyLocalization.ensureInitialized();
    Hive.registerAdapter(ClientModelAdapter());
    Hive.registerAdapter(ProjectClientModelAdapter());
    Hive.registerAdapter(ProjectModelAdapter());
    Hive.registerAdapter(InvoiceLineItemAdapter());
    Hive.registerAdapter(StandaloneInvoiceModelAdapter());
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('clients_screen_test');
    Hive.init(tempDir.path);
    clients = ClientRepository();
    links = ProjectClientRepository();
    projects = ProjectRepository();
    invoices = StandaloneInvoiceRepository();
    for (final init in [clients.init, links.init, projects.init, invoices.init]) {
      await init();
    }
    await projects.add(ProjectModel(id: 'p1', name: '2. Artemis', colorValue: 0xFFFFA726, createdAt: DateTime(2026, 1, 1)));
    await clients.add(ClientModel(id: 'c1', name: 'Medutech s.r.o.', ico: '08975922', addressLine2: '19900 PRAHA 18', createdAt: DateTime(2026, 1, 1)));
    await clients.add(ClientModel(id: 'c2', name: 'Mateřská škola Stará Břeclav s velmi dlouhým názvem', ico: '49137182', createdAt: DateTime(2026, 1, 1)));
    await links.add(ProjectClientModel(id: 'l1', projectId: 'p1', clientId: 'c1', createdAt: DateTime(2026, 1, 1)));
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('cs')],
        path: 'assets/translations',
        fallbackLocale: const Locale('cs'),
        startLocale: const Locale('cs'),
        useOnlyLangCode: true,
        child: Builder(
          builder: (context) => MultiProvider(
            providers: [Provider<ProjectRepository>.value(value: projects)],
            child: BlocProvider(
              create: (_) => ClientBloc(clientRepository: clients, projectClientRepository: links, invoiceRepository: invoices)..add(const LoadClients()),
              child: MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: const ClientsScreen(),
              ),
            ),
          ),
        ),
      ),
    );
    // Translations are read from assets with real I/O, outside the fake test clock.
    for (var i = 0; i < 50 && find.byType(ClientsScreen).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('phone: mobile header and no overflow; desktop window: pane toolbar', (tester) async {
    await pumpAt(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('Firmy'), findsOneWidget);
    expect(find.text('Medutech s.r.o.'), findsOneWidget);
    expect(find.text('2. Artemis'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Firmy, kterým fakturuješ'), findsNothing);

    tester.view.physicalSize = const Size(1100, 800);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Firmy, kterým fakturuješ'), findsOneWidget);
    expect(find.text('Přidat firmu'), findsOneWidget);
  });
}
