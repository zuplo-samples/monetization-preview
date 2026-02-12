#!/bin/bash

# =============================================================================
# Zuplo Monetization Setup Script
# =============================================================================
# This script sets up meters, features, plans, and Stripe integration for
# Zuplo's monetization feature.
#
# Usage:
#   ./setup-monetization.sh
#
# The script will prompt you for the required values.
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Base URL for the Zuplo API
BASE_URL="https://dev.zuplo.com"

# =============================================================================
# Helper Functions
# =============================================================================

print_step() {
    echo -e "\n${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Prompt for input with a default value
prompt() {
    local var_name=$1
    local prompt_text=$2
    local default_value=$3
    local is_secret=$4

    if [ -n "$default_value" ]; then
        prompt_text="${prompt_text} [${default_value}]"
    fi

    echo -en "${CYAN}?${NC} ${prompt_text}: "

    if [ "$is_secret" = "true" ]; then
        read -s value
        echo ""
    else
        read value
    fi

    # Use default if empty
    if [ -z "$value" ] && [ -n "$default_value" ]; then
        value="$default_value"
    fi

    eval "$var_name=\"$value\""
}

# Make an API call and extract the ID from the response
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4

    echo -e "  ${description}..."

    response=$(curl -s -X "$method" "${BASE_URL}${endpoint}" \
        -H "Authorization: Bearer ${ZUPLO_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$data")

    # Check for errors in response
    if echo "$response" | grep -q '"error"'; then
        print_error "Failed: $response"
        return 1
    fi

    echo "$response"
}

# =============================================================================
# Welcome & Input Collection
# =============================================================================

echo -e "${BLUE}"
echo "============================================="
echo "  Zuplo Monetization Setup"
echo "============================================="
echo -e "${NC}"
echo "This script will set up meters, features, plans, and Stripe"
echo "integration for your Zuplo project."
echo ""
echo "You'll need:"
echo "  • Your Zuplo API key (from portal.zuplo.com)"
echo "  • Your bucket ID (from your project settings)"
echo "  • Your Stripe test key (sk_test_...)"
echo ""

# Prompt for values (use env vars as defaults if set)
prompt ZUPLO_API_KEY "Enter your Zuplo API key" "$ZUPLO_API_KEY" "true"

if [ -z "$ZUPLO_API_KEY" ]; then
    print_error "Zuplo API key is required"
    exit 1
fi

prompt ZUPLO_BUCKET_ID "Enter your bucket ID" "$ZUPLO_BUCKET_ID"

if [ -z "$ZUPLO_BUCKET_ID" ]; then
    print_error "Bucket ID is required"
    exit 1
fi

prompt STRIPE_KEY "Enter your Stripe secret key" "$STRIPE_KEY" "true"

if [ -z "$STRIPE_KEY" ]; then
    print_error "Stripe key is required"
    exit 1
fi

# Warn if not using a test Stripe key
if [[ ! "$STRIPE_KEY" == sk_test_* ]]; then
    echo ""
    print_warning "Your Stripe key doesn't start with 'sk_test_'."
    print_warning "Are you sure you want to use a live key?"
    echo -en "${CYAN}?${NC} Continue? (y/N): "
    read -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Confirm before proceeding
echo ""
echo -e "${YELLOW}Ready to set up monetization with:${NC}"
echo "  Bucket ID: $ZUPLO_BUCKET_ID"
echo "  Stripe Key: ${STRIPE_KEY:0:12}..."
echo ""
echo -en "${CYAN}?${NC} Proceed with setup? (Y/n): "
read -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

# =============================================================================
# Step 1: Create Meter
# =============================================================================

print_step "Creating meter..."

METER_RESPONSE=$(api_call POST "/v3/metering/${ZUPLO_BUCKET_ID}/meters" '{
    "slug": "api",
    "name": "API",
    "description": "API Calls",
    "eventType": "api",
    "aggregation": "SUM",
    "valueProperty": "$.total"
}' "Creating 'api' meter")

print_success "Meter created"

# =============================================================================
# Step 2: Create Features
# =============================================================================

print_step "Creating features..."

# API Feature (linked to meter)
api_call POST "/v3/metering/${ZUPLO_BUCKET_ID}/features" '{
    "key": "api",
    "name": "API",
    "meterSlug": "api"
}' "Creating 'api' feature" > /dev/null

print_success "API feature created"

# Monthly Fee Feature
api_call POST "/v3/metering/${ZUPLO_BUCKET_ID}/features" '{
    "key": "monthly_fee",
    "name": "Monthly Fee"
}' "Creating 'monthly_fee' feature" > /dev/null

print_success "Monthly Fee feature created"

# Metadata Support Feature
api_call POST "/v3/metering/${ZUPLO_BUCKET_ID}/features" '{
    "key": "metadata_support",
    "name": "Metadata Support"
}' "Creating 'metadata_support' feature" > /dev/null

print_success "Metadata Support feature created"

# =============================================================================
# Step 3: Create Plans
# =============================================================================

print_step "Creating plans..."

# Developer Plan
DEVELOPER_RESPONSE=$(api_call POST "/v3/metering/${ZUPLO_BUCKET_ID}/plans" '{
    "billingCadence": "P1M",
    "currency": "USD",
    "description": "1000 requests per month with overages",
    "key": "developer",
    "metadata": {
        "zuplo_plan_order": "1"
    },
    "name": "Developer",
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
                                "upToAmount": "1000"
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
}' "Creating Developer plan")

DEVELOPER_PLAN_ID=$(echo "$DEVELOPER_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
print_success "Developer plan created (ID: $DEVELOPER_PLAN_ID)"

# Pro Plan
PRO_RESPONSE=$(api_call POST "/v3/metering/${ZUPLO_BUCKET_ID}/plans" '{
    "billingCadence": "P1M",
    "currency": "USD",
    "description": "5000 requests per month with overages",
    "key": "pro",
    "metadata": {
        "zuplo_plan_order": "2"
    },
    "name": "Pro",
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
                        "amount": "19.99",
                        "paymentTerm": "in_advance",
                        "type": "flat"
                    },
                    "type": "flat_fee"
                },
                {
                    "billingCadence": "P1M",
                    "entitlementTemplate": {
                        "isSoftLimit": true,
                        "issueAfterReset": 5000,
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
                                "upToAmount": "5000"
                            },
                            {
                                "flatPrice": null,
                                "unitPrice": {
                                    "amount": "0.05",
                                    "type": "unit"
                                }
                            }
                        ],
                        "type": "tiered"
                    },
                    "type": "usage_based"
                },
                {
                    "type": "flat_fee",
                    "key": "metadata_support",
                    "name": "Metadata Support",
                    "featureKey": "metadata_support",
                    "billingCadence": null,
                    "price": null,
                    "entitlementTemplate": {
                        "type": "boolean",
                        "config": true
                    }
                }
            ]
        }
    ]
}' "Creating Pro plan")

PRO_PLAN_ID=$(echo "$PRO_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
print_success "Pro plan created (ID: $PRO_PLAN_ID)"

# Business Plan
BUSINESS_RESPONSE=$(api_call POST "/v3/metering/${ZUPLO_BUCKET_ID}/plans" '{
    "billingCadence": "P1M",
    "currency": "USD",
    "description": "10000 requests per month with overages",
    "key": "business",
    "metadata": {
        "zuplo_plan_order": "3"
    },
    "name": "Business",
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
                        "amount": "29.99",
                        "paymentTerm": "in_advance",
                        "type": "flat"
                    },
                    "type": "flat_fee"
                },
                {
                    "billingCadence": "P1M",
                    "entitlementTemplate": {
                        "isSoftLimit": true,
                        "issueAfterReset": 10000,
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
                                "upToAmount": "10000"
                            },
                            {
                                "flatPrice": null,
                                "unitPrice": {
                                    "amount": "0.01",
                                    "type": "unit"
                                }
                            }
                        ],
                        "type": "tiered"
                    },
                    "type": "usage_based"
                },
                {
                    "type": "flat_fee",
                    "key": "metadata_support",
                    "name": "Metadata Support",
                    "featureKey": "metadata_support",
                    "billingCadence": null,
                    "price": null,
                    "entitlementTemplate": {
                        "type": "boolean",
                        "config": true
                    }
                }
            ]
        }
    ]
}' "Creating Business plan")

BUSINESS_PLAN_ID=$(echo "$BUSINESS_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
print_success "Business plan created (ID: $BUSINESS_PLAN_ID)"

# =============================================================================
# Step 4: Publish Plans
# =============================================================================

print_step "Publishing plans..."

api_call POST "/v3/metering/${ZUPLO_BUCKET_ID}/plans/${DEVELOPER_PLAN_ID}/publish" '{}' "Publishing Developer plan" > /dev/null
print_success "Developer plan published"

api_call POST "/v3/metering/${ZUPLO_BUCKET_ID}/plans/${PRO_PLAN_ID}/publish" '{}' "Publishing Pro plan" > /dev/null
print_success "Pro plan published"

api_call POST "/v3/metering/${ZUPLO_BUCKET_ID}/plans/${BUSINESS_PLAN_ID}/publish" '{}' "Publishing Business plan" > /dev/null
print_success "Business plan published"

# =============================================================================
# Step 5: Connect Stripe
# =============================================================================

print_step "Connecting Stripe..."

api_call POST "/v3/metering/${ZUPLO_BUCKET_ID}/setup/stripe" "{
    \"apiKey\": \"${STRIPE_KEY}\",
    \"name\": \"Monetization Getting Started\"
}" "Setting up Stripe integration" > /dev/null

print_success "Stripe connected"

# =============================================================================
# Done!
# =============================================================================

echo -e "\n${GREEN}"
echo "============================================="
echo "  Setup Complete!"
echo "============================================="
echo -e "${NC}"
echo "Your monetization setup is ready. Here's what was created:"
echo ""
echo "  Meter:"
echo "    • api (tracks API calls)"
echo ""
echo "  Features:"
echo "    • api (usage-based, linked to meter)"
echo "    • monthly_fee (flat rate)"
echo "    • metadata_support (boolean)"
echo ""
echo "  Plans:"
echo "    • Developer: \$9.99/mo, 1,000 requests, \$0.10 overage"
echo "    • Pro: \$19.99/mo, 5,000 requests, \$0.05 overage"
echo "    • Business: \$29.99/mo, 10,000 requests, \$0.01 overage"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Add the monetization policy to your routes (see README)"
echo "  2. Push your changes to trigger a deployment"
echo "  3. Have a user sign up and subscribe to a plan"
echo ""
