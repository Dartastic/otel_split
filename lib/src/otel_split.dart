// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_split_suppression.dart';

const _tracerName = 'dartastic_otel_libs_split';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class SplitResult {
  /// Creates a result.
  const SplitResult({
    this.splitName,
    this.treatment,
    this.environment,
    this.trafficType,
    this.evaluatedRule,
    this.impressionLabel,
    this.timedOut,
    this.fromCache,
    this.requestId,
    this.statusCode,
  });

  /// `split_name` evaluated.
  final String? splitName;

  /// Treatment served (`on` / `off` / custom).
  final String? treatment;

  /// `prod` / `staging` / `dev` — Split environment.
  final String? environment;

  /// `user` / `account` / custom — traffic type for the impression.
  final String? trafficType;

  /// Matched rule name (`default rule`, `whitelist`, `targeting rule N`).
  final String? evaluatedRule;

  /// `impressionLabel` (`targeting rule`, `not in split`, `definition
  /// not found`, `exception`, `client not ready`, `time out`).
  final String? impressionLabel;

  /// Whether `getTreatmentWithConfig` timed out and fell back to
  /// control (silent miss that breaks experiments).
  final bool? timedOut;

  /// Whether the evaluation came from in-memory cache (vs SDK fetch).
  final bool? fromCache;

  /// `X-Split-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class SplitCallResult<T> {
  /// Creates a call result.
  const SplitCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final SplitResult? result;
}

/// Wraps a Split.io API call in a CLIENT span. [operation] is one of
/// `treatment.get`, `treatments.get`, `treatment.with_config.get`,
/// `track`, `splits.list`, `splits.get`, `segments.list`,
/// `segments.update`, `impressions.bulk`, `events.bulk`,
/// `attributes.set`, `attributes.clear`, `client.ready`, `manager.split`.
Future<T> tracedSplit<T>({
  required String operation,
  required Future<SplitCallResult<T>> Function() invoke,
}) async {
  if (splitInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'split',
    'rpc.method': operation,
    'split.operation': operation,
  };

  final span = _tracer().startSpan(
    'split $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.splitName != null) {
        extras.add(OTelAPI.attributeString(
          'split.name',
          r.result!.splitName!,
        ));
      }
      if (r.result!.treatment != null) {
        extras.add(OTelAPI.attributeString(
          'split.treatment',
          r.result!.treatment!,
        ));
      }
      if (r.result!.environment != null) {
        extras.add(OTelAPI.attributeString(
          'split.environment',
          r.result!.environment!,
        ));
      }
      if (r.result!.trafficType != null) {
        extras.add(OTelAPI.attributeString(
          'split.traffic_type',
          r.result!.trafficType!,
        ));
      }
      if (r.result!.evaluatedRule != null) {
        extras.add(OTelAPI.attributeString(
          'split.rule',
          r.result!.evaluatedRule!,
        ));
      }
      if (r.result!.impressionLabel != null) {
        extras.add(OTelAPI.attributeString(
          'split.impression.label',
          r.result!.impressionLabel!,
        ));
      }
      if (r.result!.timedOut != null) {
        extras.add(OTelAPI.attributeBool(
          'split.timed_out',
          r.result!.timedOut!,
        ));
      }
      if (r.result!.fromCache != null) {
        extras.add(OTelAPI.attributeBool(
          'split.from_cache',
          r.result!.fromCache!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'split.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Split HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
