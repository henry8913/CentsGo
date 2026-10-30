import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Italian date formats (dd/MM/yyyy, month names) used by the Garage.
  await initializeDateFormatting('it_IT');
  final state = AppState();
  runApp(CentsGoApp(state: state));
  state.init();
}
