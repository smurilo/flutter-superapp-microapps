import 'dart:async';

import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

class ShellApp extends StatefulWidget {
  const ShellApp({required this.registry, super.key});

  final MicroAppRegistry registry;

  @override
  State<ShellApp> createState() => _ShellAppState();
}

class _ShellAppState extends State<ShellApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final GoRouter _router;
  StreamSubscription<SessionExpiredEvent>? _session;

  @override
  void initState() {
    super.initState();
    final entries = widget.registry.entries;
    _router = GoRouter(
      initialLocation: entries.first.initialRoute,
      routes: [
        // Bottom navigation is owned by the shell; each tab's content belongs to a micro app.
        ShellRoute(
          builder: (context, state, child) =>
              _NavigationScaffold(entries: entries, location: state.uri.path, child: child),
          routes: widget.registry.routes,
        ),
      ],
    );
    _session = GetIt.I<EventBus>().on<SessionExpiredEvent>().listen((_) {
      _messengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Sessão expirada. Faça login novamente.')));
    });
  }

  @override
  void dispose() {
    _session?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Super App',
        theme: DsTheme.light(),
        darkTheme: DsTheme.dark(),
        routerConfig: _router,
        scaffoldMessengerKey: _messengerKey,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      );
}

class _NavigationScaffold extends StatelessWidget {
  const _NavigationScaffold({required this.entries, required this.location, required this.child});

  final List<MicroAppEntry> entries;
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final index = entries.indexWhere((e) => location.startsWith(e.initialRoute));
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(entries[i].initialRoute),
        destinations: [
          for (final e in entries) NavigationDestination(icon: Icon(e.icon), label: e.label),
        ],
      ),
    );
  }
}
