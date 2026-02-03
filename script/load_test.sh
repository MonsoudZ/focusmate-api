#!/bin/bash
# API Load Testing Script
# Usage: ./script/load_test.sh [base_url] [token]
#
# Prerequisites:
#   - Apache Bench (ab) installed (comes with macOS)
#   - Server running at base URL
#   - Valid JWT token for authenticated endpoints

set -e

BASE_URL="${1:-http://localhost:3000}"
TOKEN="${2}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "       API Load Testing Suite        "
echo "======================================"
echo ""
echo "Base URL: $BASE_URL"
echo "Token: ${TOKEN:+[PROVIDED]}${TOKEN:-[NOT PROVIDED]}"
echo ""

# Test configuration
REQUESTS=100
CONCURRENCY=10

print_header() {
  echo ""
  echo "${YELLOW}=== $1 ===${NC}"
}

run_test() {
  local name="$1"
  local endpoint="$2"
  local method="${3:-GET}"
  local auth="${4:-true}"

  echo ""
  echo "--- $name ---"
  echo "    $method $endpoint"

  local auth_header=""
  if [ "$auth" = "true" ] && [ -n "$TOKEN" ]; then
    auth_header="-H \"Authorization: Bearer $TOKEN\""
  fi

  if [ "$method" = "GET" ]; then
    if [ "$auth" = "true" ] && [ -n "$TOKEN" ]; then
      result=$(ab -n $REQUESTS -c $CONCURRENCY -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" "$BASE_URL$endpoint" 2>&1)
    else
      result=$(ab -n $REQUESTS -c $CONCURRENCY -H "Content-Type: application/json" "$BASE_URL$endpoint" 2>&1)
    fi

    rps=$(echo "$result" | grep "Requests per second" | awk '{print $4}')
    time_per_req=$(echo "$result" | grep "Time per request" | head -1 | awk '{print $4}')
    failed=$(echo "$result" | grep "Failed requests" | awk '{print $3}')

    if [ "$failed" = "0" ]; then
      echo "    ${GREEN}✓${NC} RPS: $rps | Avg: ${time_per_req}ms | Failed: $failed"
    else
      echo "    ${RED}✗${NC} RPS: $rps | Avg: ${time_per_req}ms | Failed: $failed"
    fi
  fi
}

# Health check first
print_header "Health Check"
if curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health" | grep -q "200"; then
  echo "${GREEN}✓ Server is healthy${NC}"
else
  echo "${RED}✗ Server health check failed${NC}"
  exit 1
fi

# Public endpoints (no auth required)
print_header "Public Endpoints"
run_test "Health endpoint" "/health" "GET" "false"
run_test "Invite preview" "/api/v1/invites/TEST123" "GET" "false"

# Check if token provided for authenticated tests
if [ -z "$TOKEN" ]; then
  echo ""
  echo "${YELLOW}⚠️  No token provided - skipping authenticated endpoints${NC}"
  echo "   Usage: ./script/load_test.sh $BASE_URL YOUR_JWT_TOKEN"
  echo ""
  exit 0
fi

# Authenticated endpoints
print_header "Authenticated Endpoints (Read)"
run_test "Get all lists" "/api/v1/lists"
run_test "Today's tasks" "/api/v1/tasks/today"
run_test "Get friends" "/api/v1/friends"
run_test "Get user profile" "/api/v1/users/me"

print_header "Authenticated Endpoints (List-specific)"
# Get first list ID
LIST_ID=$(curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/v1/lists" | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*')
if [ -n "$LIST_ID" ]; then
  run_test "Get list tasks" "/api/v1/lists/$LIST_ID/tasks"
  run_test "Get list members" "/api/v1/lists/$LIST_ID/memberships"
else
  echo "${YELLOW}⚠️  No lists found - skipping list-specific tests${NC}"
fi

# Summary
print_header "Load Test Complete"
echo ""
echo "Configuration used:"
echo "  - Requests: $REQUESTS"
echo "  - Concurrency: $CONCURRENCY"
echo ""
echo "For more detailed testing, consider:"
echo "  - Increasing REQUESTS to 1000+"
echo "  - Using k6 or wrk for advanced scenarios"
echo "  - Testing POST/PUT/DELETE endpoints"
