import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'bootstrap.dart';
import 'shell_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final registry = await bootstrap();
  runApp(ShellApp(registry: registry));
}
