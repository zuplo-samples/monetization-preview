# Monetization Policy Reference

This guide expands on the monetization setup in `README.md` and covers advanced
options for `monetization-inbound`, including status-code filtering and dynamic
meter updates at runtime.

## Basic policy configuration

Start with a static meter configuration in `config/policies.json`:

```json
{
  "name": "monetization-inbound-policy",
  "policyType": "monetization-inbound",
  "options": {
    "meters": {
      "api": 1
    },
    "meterOnStatusCodes": "200-299"
  }
}
```

### Configuration options

- `meters` (optional): static meter increments applied when a request is
  metered.
- `meterOnStatusCodes`: status codes/ranges that should trigger metering.
- `authHeader` / `authScheme`: custom auth header settings for monetization
  checks.
- `cacheTtlSeconds`: cache TTL for monetization lookups.

## Runtime meter updates

You can set or update meter increments at different points in the request
lifecycle (for example in an inbound policy, handler, or outbound policy). The
monetization policy reads the latest values in its final hook before sending
usage.

### Set request meters (replace values)

Use `setMeters` when you want to replace the current runtime meter values:

```typescript
import { MonetizationInboundPolicy } from "@zuplo/runtime";

MonetizationInboundPolicy.setMeters(context, {
  input_tokens: 1000,
  output_tokens: 250,
});
```

### Add request meters (accumulate values)

Use `addMeters` when you want to increment values across multiple steps:

```typescript
import { MonetizationInboundPolicy } from "@zuplo/runtime";

MonetizationInboundPolicy.addMeters(context, { input_tokens: 500 });
MonetizationInboundPolicy.addMeters(context, { input_tokens: 300 });
```

### Read request meter values

You can inspect the current runtime meter map at any point:

```typescript
import { MonetizationInboundPolicy } from "@zuplo/runtime";

const meters = MonetizationInboundPolicy.getMeters(context);
```

## How meter values are merged

The final metering hook combines static and runtime values before usage is sent:

- `options.meters` provides the static base values.
- `setMeters` replaces the current runtime meter map and overrides matching
  static keys.
- `addMeters` accumulates into the runtime meter map and then combines
  additively with static values.
- If both static and runtime maps are empty, metering is skipped.

For a meter key like `api` with `options.meters.api = 1`:

- `setMeters(context, { api: 50 })` sends `api: 50`.
- `addMeters(context, { api: 50 })` sends `api: 51`.

## Prerequisites

Before enabling advanced metering behavior, make sure:

- `monetization-inbound` is enabled in your route or pipeline.
- Meter names match entitlement names on the subscription.
- Meter quantities are finite positive numbers.

## Additional notes

- Entitlements are validated before usage is recorded.
- `setMeters` is best when you compute a final value once.
- `addMeters` is best when multiple components contribute usage.
