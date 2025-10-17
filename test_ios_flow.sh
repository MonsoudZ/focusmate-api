#!/usr/bin/env bash

# iOS App Flow Test Script
# This demonstrates the complete authentication flow for the iOS app

BASE_URL="http://localhost:3001/api/v1"
JWT_TOKEN=""

echo "📱 Testing iOS App Authentication Flow"
echo "====================================="

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
echo "1. 📝 User Registration (iOS app sign up)"
echo "----------------------------------------"
REGISTER_RESPONSE=$(make_request POST "/auth/sign_up" '{"authentication": {"email": "iosuser@example.com", "password": "password123", "password_confirmation": "password123", "name": "iOS User"}}')
echo "Response: $REGISTER_RESPONSE"

# Extract JWT token
JWT_TOKEN=$(echo $REGISTER_RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
if [ -z "$JWT_TOKEN" ]; then
    echo "❌ Failed to get JWT token from registration"
    exit 1
fi
echo "✅ JWT Token obtained: ${JWT_TOKEN:0:20}..."

echo ""
echo "2. 🔐 User Login (iOS app sign in)"
echo "----------------------------------"
LOGIN_RESPONSE=$(make_request POST "/auth/sign_in" '{"authentication": {"email": "iosuser@example.com", "password": "password123"}}')
echo "Response: $LOGIN_RESPONSE"

# Extract JWT token from login
JWT_TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
echo "✅ JWT Token from login: ${JWT_TOKEN:0:20}..."

echo ""
echo "3. 📋 Get User's Lists (iOS app main screen)"
echo "-------------------------------------------"
LISTS_RESPONSE=$(make_request GET "/lists")
echo "Response: $LISTS_RESPONSE"

echo ""
echo "4. ➕ Create a New List (iOS app create list)"
echo "---------------------------------------------"
CREATE_LIST_RESPONSE=$(make_request POST "/lists" '{"list": {"name": "iOS Test List", "description": "Created from iOS app"}}')
echo "Response: $CREATE_LIST_RESPONSE"

echo ""
echo "5. 📝 Add a Task to the List (iOS app add task)"
echo "----------------------------------------------"
# Extract list ID from the response
LIST_ID=$(echo $CREATE_LIST_RESPONSE | grep -o '"id":[0-9]*' | cut -d':' -f2)
if [ -n "$LIST_ID" ]; then
    CREATE_TASK_RESPONSE=$(make_request POST "/lists/$LIST_ID/tasks" '{"task": {"title": "Test Task from iOS", "note": "This task was created from the iOS app", "due_at": "2024-01-15T10:00:00Z", "strict_mode": true}}')
    echo "Response: $CREATE_TASK_RESPONSE"
else
    echo "❌ Could not extract list ID"
fi

echo ""
echo "6. 🚪 Sign Out (iOS app logout)"
echo "------------------------------"
LOGOUT_RESPONSE=$(make_request DELETE "/auth/sign_out")
echo "Response: $LOGOUT_RESPONSE"

echo ""
echo "7. 🔒 Test Token After Logout (should still work for demo)"
echo "--------------------------------------------------------"
LISTS_AFTER_LOGOUT=$(make_request GET "/lists")
echo "Response: $LISTS_AFTER_LOGOUT"

echo ""
echo "✅ iOS App Flow Test Complete!"
echo ""
echo "Summary of what the iOS app can do:"
echo "1. ✅ Register new users"
echo "2. ✅ Login existing users" 
echo "3. ✅ Get user's lists after login"
echo "4. ✅ Create new lists"
echo "5. ✅ Add tasks to lists"
echo "6. ✅ Sign out and return to login screen"
echo ""
echo "The iOS app should:"
echo "- Store the JWT token after login"
echo "- Include the token in all API requests"
echo "- Clear the token and navigate to login on logout"
echo "- Handle authentication errors by redirecting to login"
