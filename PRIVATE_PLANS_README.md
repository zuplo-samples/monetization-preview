# Private Plans: Invite-Only Subscriptions

This guide shows how to create and use private plans in Zuplo Monetization.
Private plans are hidden from the public pricing table and can only be accessed
by users you explicitly invite.

If you have not completed the base setup yet, start with the main
[Getting Started guide](./README.md), especially:

- [Create features](./README.md#create-features)
- [Create plans](./README.md#create-plans)
- [Publish your plans](./README.md#publish-your-plans)

## Prerequisites

Before continuing, make sure you already have:

- `ZUPLO_API_KEY`
- `ZUPLO_BUCKET_ID`
- The `api` and `monthly_fee` features created from `README.md`

## Create a private plan

A plan becomes private when you set `"zuplo_private_plan": "true"` in
`metadata`.

Example: create an invite-only Developer plan.

```bash
curl -X POST "https://dev.zuplo.com/v3/metering/${ZUPLO_BUCKET_ID}/plans" \
  -H "Authorization: Bearer ${ZUPLO_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "billingCadence": "P1M",
    "currency": "USD",
    "description": "1000 requests per month with overages",
    "key": "private_developer",
    "metadata": {
      "zuplo_plan_order": "4",
      "zuplo_private_plan": "true"
    },
    "name": "Private Developer",
    "proRatingConfig": {
      "enabled": false,
      "mode": "prorate_prices"
    },
    "phases": [
      {
        "duration": null,
        "key": "default",
        "name": "Default",
        "rateCards": [
          {
            "billingCadence": "P1M",
            "featureKey": "monthly_fee",
            "key": "monthly_fee",
            "name": "Monthly Fee",
            "price": {
              "amount": "9.99",
              "paymentTerm": "in_advance",
              "type": "flat"
            },
            "type": "flat_fee"
          },
          {
            "billingCadence": "P1M",
            "entitlementTemplate": {
              "isSoftLimit": true,
              "issueAfterReset": 1000,
              "preserveOverageAtReset": false,
              "type": "metered",
              "usagePeriod": "P1M"
            },
            "featureKey": "api",
            "key": "api",
            "name": "api",
            "price": {
              "mode": "graduated",
              "tiers": [
                {
                  "flatPrice": {
                    "amount": "0",
                    "type": "flat"
                  },
                  "unitPrice": null,
                  "upToAmount": "155000"
                },
                {
                  "flatPrice": null,
                  "unitPrice": {
                    "amount": "0.10",
                    "type": "unit"
                  }
                }
              ],
              "type": "tiered"
            },
            "type": "usage_based"
          }
        ]
      }
    ]
  }'
```

Save the returned `id` as `PRIVATE_DEVELOPER_PLAN_ID`.

## Publish your private plan

Like standard plans, private plans are created as drafts. Publish the plan
before users can subscribe:

```bash
curl -X POST "https://dev.zuplo.com/v3/metering/${ZUPLO_BUCKET_ID}/plans/${PRIVATE_DEVELOPER_PLAN_ID}/publish" \
  -H "Authorization: Bearer ${ZUPLO_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{}'
```

## Invite a user to a private plan

After publishing, create an invite tied to the user's email address. The user
does not need to exist yet in Zuplo, but they must sign in with the invited
email to see the private plan.

```bash
curl -X POST "https://dev.zuplo.com/v3/metering/${ZUPLO_BUCKET_ID}/plan-invites" \
  -H "Authorization: Bearer ${ZUPLO_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test-user@example.com",
    "planId": "${PRIVATE_DEVELOPER_PLAN_ID}"
  }'
```

Once the invite is created, the invited user will see this plan in the
Developer Portal pricing page after logging in.

## Related guides

- Main walkthrough: [README.md](./README.md)
- Continue end-user testing from: [Subscribe to a plan](./README.md#subscribe-to-a-plan)
