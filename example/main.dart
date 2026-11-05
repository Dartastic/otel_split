// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_split/otel_split.dart';

/// Traces Split.io calls with OpenTelemetry.
///
/// `otel_split` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Split.io call in
/// [tracedSplit]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'split-example');

  // Wraps a Split.io API call in a CLIENT span.
  final splitId = await tracedSplit<String>(
    operation: 'treatment.get',
    invoke: () async {
      // Make the Split.io call here, then report what it returned.
      const id = 'split_8f3a2c';
      return const SplitCallResult(
          value: id,
          result: SplitResult(
              splitName: 'split_name',
              treatment: 'on',
              environment: 'prod',
              trafficType: 'user',
              evaluatedRule: 'whitelist',
              impressionLabel: ',',
              timedOut: true,
              fromCache: true,
              requestId: 'request_8f3a2c',
              statusCode: 200));
    },
  );
  OTelLog.info('tracedSplit treatment.get returned $splitId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutSplitInstrumentationAsync.
  await runWithoutSplitInstrumentationAsync(
    () => tracedSplit<String>(
      operation: 'treatment.get',
      invoke: () async {
        const id = 'split_8f3a2c';
        return const SplitCallResult(
            value: id,
            result: SplitResult(
                splitName: 'split_name',
                treatment: 'on',
                environment: 'prod',
                trafficType: 'user',
                evaluatedRule: 'whitelist',
                impressionLabel: ',',
                timedOut: true,
                fromCache: true,
                requestId: 'request_8f3a2c',
                statusCode: 200));
      },
    ),
  );

  await OTel.shutdown();
}
