<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/global/otel-instrumentation.md and re-run profile-sync. -->
# OpenTelemetry Instrumentation Standards

## Overview

Structured logs tell you what happened. Traces tell you why it was slow. Metrics tell you how often it happens. OpenTelemetry is the vendor-neutral standard that connects all three signals through a shared `traceId`. This standard governs how DevOS projects instrument their code with the OTEL SDK — from bootstrap to span lifecycle to exporter configuration — and defines the correlation contract that binds OTEL traces to the structured log schema in `observability.md`.

**Sibling standards:**
- [`observability.md`](./observability.md) — structured log schema and the three-signal model; the `traceId` field in log records MUST match the active OTEL span's trace ID
- [`security.md`](./security.md) — secrets MUST NOT appear in span attributes or events; same rule applies to logs

## Scope

This standard covers OpenTelemetry SDK setup, span lifecycle (creation, attributes, status, events, end), exporter configuration via environment variables, metric instrument selection, sampling configuration, and the correlation contract between OTEL traces and `observability.md` structured logs. It does NOT cover infrastructure-level collector deployment (Jaeger, Tempo, Grafana), SLO/SLA alerting configuration, or language-specific APM agent setup (Datadog, New Relic, Sentry).

---

## Principles

1. **Correlation by default:** Every OTEL span MUST inject its `traceId` into any structured log record emitted during that span's lifetime. One request, one ID, three correlated signals.
2. **Config via environment:** No collector endpoints, service names, or sampling rates in source code. All OTEL configuration uses the standard `OTEL_*` env vars.
3. **Span at the right granularity:** Every external call and every request handler gets a span. Internal helper functions that don't cross a network or process boundary do not.
4. **Errors are recorded, not swallowed:** A span that catches an exception MUST record it and set its status to `ERROR` before the catch block exits.

---

## Rules

### Rule 1 — SDK bootstrap

**Node.js / TypeScript:**

**MUST** use `@opentelemetry/sdk-node` with auto-instrumentation for HTTP, gRPC, and database clients. Bootstrap MUST happen before any other `require`/`import` in the process entry point.

```typescript
// Entry point: instrumentation.ts — imported first in main.ts
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter(), // endpoint from OTEL_EXPORTER_OTLP_ENDPOINT
  instrumentations: [getNodeAutoInstrumentations()],
});
sdk.start();
```

**Python:**

**MUST** use `opentelemetry-sdk` with `opentelemetry-distro` for auto-instrumentation. Run `opentelemetry-instrument` as the process wrapper rather than patching `main.py`.

```bash
opentelemetry-instrument \
  --traces_exporter otlp \
  --service_name "$OTEL_SERVICE_NAME" \
  python app.py
```

**MUST NOT** call `sdk.start()` or `configure()` more than once per process. Duplicate bootstrap produces duplicate spans and corrupts trace IDs.

### Rule 2 — Required environment variables

**MUST** set these via environment (never hardcode in source):

| Variable | Purpose | Required |
|----------|---------|----------|
| `OTEL_SERVICE_NAME` | Identifies the service in traces and metrics | **MUST** |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Collector URL (e.g. `http://localhost:4318`) | **MUST** in non-dev |
| `OTEL_TRACES_SAMPLER` | Sampling strategy (default: `parentbased_traceidratio`) | SHOULD |
| `OTEL_TRACES_SAMPLER_ARG` | Sampling rate for ratio sampler (0.0–1.0) | SHOULD when sampler set |
| `OTEL_LOG_LEVEL` | SDK log verbosity (`info`, `debug`, `error`) | SHOULD in development |

**MUST NOT** set `OTEL_EXPORTER_OTLP_ENDPOINT` to a production collector in development environments. Use `localhost:4318` (a local collector) or disable export entirely with `OTEL_TRACES_EXPORTER=none`.

### Rule 3 — Span lifecycle

**MUST** create a span for every:
- Inbound HTTP request handler
- Outbound HTTP or gRPC call
- Database query (auto-instrumentation handles this for supported clients)
- Background job execution
- Any operation expected to appear in a performance flamegraph

**MUST NOT** create spans for:
- Pure in-memory computation with no I/O
- Utility/helper functions called multiple times per request (creates noise, not signal)

**MUST** set these attributes on every manually-created span:

| Attribute | Value | Example |
|-----------|-------|---------|
| `service.name` | From `OTEL_SERVICE_NAME` | `"capture-service"` |
| `http.method` | HTTP verb (for HTTP spans) | `"POST"` |
| `http.route` | Route template (not URL with IDs) | `"/captures/:id"` |
| `db.statement` | Sanitised query (no values for sensitive fields) | `"SELECT * FROM captures WHERE id = ?"` |

```typescript
const tracer = trace.getTracer('capture-service');

const span = tracer.startSpan('capture.write', {
  attributes: {
    'capture.type': captureType,
    'capture.priority': priority,
  },
});

try {
  const result = await writeCapture(data);
  span.setStatus({ code: SpanStatusCode.OK });
  return result;
} catch (err) {
  span.recordException(err as Error);
  span.setStatus({ code: SpanStatusCode.ERROR, message: (err as Error).message });
  throw err;
} finally {
  span.end();
}
```

### Rule 4 — Trace ↔ log correlation contract

This is the binding rule between this standard and `observability.md`.

**MUST** inject the active OTEL span's `traceId` and `spanId` into every structured log record emitted during that span's lifetime, using the field names defined in `observability.md`:

```typescript
import { trace, context } from '@opentelemetry/api';

function log(level: string, message: string, fields: Record<string, unknown> = {}) {
  const span = trace.getActiveSpan();
  const spanContext = span?.spanContext();
  logger[level]({
    ...fields,
    traceId: spanContext?.traceId,   // matches observability.md field name
    spanId: spanContext?.spanId,
    message,
  });
}
```

**MUST NOT** invent an alternative correlation field name. `traceId` is the canonical field. Using `trace_id`, `requestId`, or `correlationId` as the sole correlation key breaks unified querying across logs and traces.

### Rule 5 — Error recording

**MUST** call `span.recordException(error)` AND `span.setStatus({ code: SpanStatusCode.ERROR })` before re-throwing any caught exception inside a span.

**MUST NOT** swallow exceptions to keep a span green. A span that catches an error and sets `OK` status is a lie; the trace hides a failure.

```typescript
// OFF-STANDARD: swallowed exception, span stays green
try {
  await riskyOperation();
} catch (e) {
  logger.error('something went wrong');
  // span ends without recording the error
}

// ON-STANDARD
try {
  await riskyOperation();
} catch (e) {
  span.recordException(e as Error);
  span.setStatus({ code: SpanStatusCode.ERROR, message: (e as Error).message });
  throw e;
}
```

### Rule 6 — Metric instruments

**MUST** use the correct instrument type:

| What to measure | Instrument | Example |
|----------------|-----------|---------|
| Event count (requests, errors) | `Counter` | `http.requests.total` |
| Duration / latency | `Histogram` | `http.request.duration` |
| Current queue depth | `UpDownCounter` | `queue.pending_jobs` |
| Derived ratio (error rate) | Computed from counters, not a Gauge | `errors / requests` |

**MUST NOT** use a `Gauge` for values that can be derived from counters or histograms. Gauges are for values that can both increase and decrease independently (e.g., CPU usage, active connections).

### Rule 7 — Sampling

**MUST** use `parentbased_traceidratio` as the default sampler in production. This respects upstream sampling decisions while applying a local rate to root spans.

**MUST** use `AlwaysOn` sampling only in development and CI environments. Sampling 100% in production causes collector overload at scale.

**MUST NOT** hardcode sampling rates in source. Use `OTEL_TRACES_SAMPLER_ARG`.

---

## Compliance test

- [ ] Does the process entry point import/run the OTEL SDK bootstrap before any application code (`instrumentation.ts` is the first import in `main.ts`, or `opentelemetry-instrument` wraps the Python process)?
- [ ] Does `command grep -rn "OTEL_EXPORTER_OTLP_ENDPOINT\|localhost:4318" .env* src/ app/ 2>/dev/null | command grep -v "\.env.example"` return zero results (no hardcoded collector endpoints in source)?
- [ ] Does every manually-created span call `span.recordException()` and `span.setStatus(ERROR)` inside its catch block before re-throwing?
- [ ] Does the structured log function inject `traceId` from the active OTEL span context (matching `observability.md` field name)?
- [ ] Does `command grep -rn "new Gauge\|createGauge" src/ app/ 2>/dev/null` return zero results, or are all Gauge usages justified with an inline comment explaining why a counter/histogram is insufficient?

If any check fails: fix before marking the feature shippable. A trace that doesn't correlate to logs is half an observability signal.

---

## References

- [OpenTelemetry Specification](https://opentelemetry.io/docs/specs/otel/) — canonical spec for spans, metrics, logs, and the data model
- [OTEL JS SDK](https://github.com/open-telemetry/opentelemetry-js) — Node.js/TypeScript SDK; `@opentelemetry/sdk-node` package
- [OTEL Python SDK](https://github.com/open-telemetry/opentelemetry-python) — Python SDK; `opentelemetry-sdk` package
- [OTEL Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/) — canonical attribute names (`http.method`, `db.statement`, etc.)
- [W3C TraceContext](https://www.w3.org/TR/trace-context/) — `traceId` format (32 hex chars) and propagation headers (`traceparent`)
- [`observability.md`](./observability.md) — DevOS structured log schema; the `traceId` field this standard populates
