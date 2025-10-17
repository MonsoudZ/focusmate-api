#!/usr/bin/env bash

# Focusmate API Test Script
# This script demonstrates the Lists and Memberships functionality

BASE_URL="http://localhost:3001/api/v1"
JWT_TOKEN=""

echo "🧪 Testing Focusmate API - Lists & Memberships"
echo "=============================================="

# Function to make authenticated requests
make_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    if [ -n "$JWT_TOKEN" ]; then
        curl -s -X $method "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $JWT_TOKEN" \
            ${data:+-d "$data"}
    else
        curl -s -X $method "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            ${data:+-d "$data"}
    fi
}

echo ""
echo "1. Register a test user..."
echo "-------------------------"
REGISTER_RESPONSE=$(make_request POST "/register" '{"user": {"email": "test@example.com", "password": "password123", "password_confirmation": "password123"}}')
echo "Response: $REGISTER_RESPONSE"

echo ""
echo "2. Login to get JWT token..."
echo "----------------------------"
LOGIN_RESPONSE=$(make_request POST "/login" '{"email": "test@example.com", "password": "password123"}')
echo "Response: $LOGIN_RESPONSE"

# Extract JWT token (this is a simplified extraction)
JWT_TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"jti":"[^"]*"' | cut -d'"' -f4)
if [ -z "$JWT_TOKEN" ]; then
    echo "❌ Failed to get JWT token. Please check the login response."
    exit 1
fi
echo "✅ JWT Token obtained"

echo ""
echo "3. Create a new list..."
echo "-----------------------"
CREATE_LIST_RESPONSE=$(make_request POST "/lists" '{"list": {"name": "My Shopping List", "description": "Weekly grocery shopping items"}}')
echo "Response: $CREATE_LIST_RESPONSE"

# Extract list ID
LIST_ID=$(echo $CREATE_LIST_RESPONSE | grep -o '"id":[0-9]*' | cut -d':' -f2)
if [ -z "$LIST_ID" ]; then
    echo "❌ Failed to get list ID. Please check the create list response."
    exit 1
fi
echo "✅ List created with ID: $LIST_ID"

echo ""
echo "4. Get all lists..."
echo "------------------"
GET_LISTS_RESPONSE=$(make_request GET "/lists")
echo "Response: $GET_LISTS_RESPONSE"

echo ""
echo "5. Get specific list details..."
echo "-------------------------------"
GET_LIST_RESPONSE=$(make_request GET "/lists/$LIST_ID")
echo "Response: $GET_LIST_RESPONSE"

echo ""
echo "6. Update the list..."
echo "--------------------"
UPDATE_LIST_RESPONSE=$(make_request PATCH "/lists/$LIST_ID" '{"list": {"name": "Updated Shopping List", "description": "Updated weekly grocery shopping items"}}')
echo "Response: $UPDATE_LIST_RESPONSE"

echo ""
echo "7. Register another user for invitation..."
echo "------------------------------------------"
REGISTER_USER2_RESPONSE=$(make_request POST "/register" '{"user": {"email": "user2@example.com", "password": "password123", "password_confirmation": "password123"}}')
echo "Response: $REGISTER_USER2_RESPONSE"

echo ""
echo "8. Invite user to the list..."
echo "-----------------------------"
INVITE_RESPONSE=$(make_request POST "/lists/$LIST_ID/memberships" '{"membership": {"user_identifier": "user2@example.com", "role": "editor"}}')
echo "Response: $INVITE_RESPONSE"

echo ""
echo "9. Get list memberships..."
echo "-------------------------"
GET_MEMBERSHIPS_RESPONSE=$(make_request GET "/lists/$LIST_ID/memberships")
echo "Response: $GET_MEMBERSHIPS_RESPONSE"

echo ""
echo "✅ API testing completed!"
echo ""
echo "Summary of endpoints tested:"
echo "- POST /api/v1/register (user registration)"
echo "- POST /api/v1/login (user authentication)"
echo "- POST /api/v1/lists (create list)"
echo "- GET /api/v1/lists (list all lists)"
echo "- GET /api/v1/lists/:id (get specific list)"
echo "- PATCH /api/v1/lists/:id (update list)"
echo "- POST /api/v1/lists/:id/memberships (invite user)"
echo "- GET /api/v1/lists/:id/memberships (list memberships)"
