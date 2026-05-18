// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_split/otel_split.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_split-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('treatment.get records split + treatment + rule', () async {
    await tracedSplit<String>(
      operation: 'treatment.get',
      invoke: () async => const SplitCallResult(
        value: 'ok',
        result: SplitResult(
          splitName: 'checkout_v2',
          treatment: 'on',
          environment: 'prod',
          trafficType: 'user',
          evaluatedRule: 'targeting rule 1',
          impressionLabel: 'targeting rule',
          timedOut: false,
          fromCache: true,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('split treatment.get')!);
    expect(a['split.name'], 'checkout_v2');
    expect(a['split.treatment'], 'on');
    expect(a['split.rule'], 'targeting rule 1');
    expect(a['split.from_cache'], true);
  });

  test('timed-out evaluation flagged', () async {
    await tracedSplit<String>(
      operation: 'treatment.get',
      invoke: () async => const SplitCallResult(
        value: 'ok',
        result: SplitResult(
          treatment: 'control',
          impressionLabel: 'time out',
          timedOut: true,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('split treatment.get')!);
    expect(a['split.timed_out'], true);
    expect(a['split.impression.label'], 'time out');
  });

  test('suppression skips spans', () async {
    await runWithoutSplitInstrumentationAsync(() async {
      await tracedSplit<String>(
        operation: 'splits.list',
        invoke: () async => const SplitCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('split '), isEmpty);
  });
}
