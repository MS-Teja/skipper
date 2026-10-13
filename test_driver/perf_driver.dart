import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Writes the frame-time summaries to `build/perf.json`.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    await File(
      'build/perf.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  },
);
