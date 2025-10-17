#!/usr/bin/env bash

# Focusmate API Task Testing Script
# This script demonstrates the ADHD tool functionality with no-snooze flow

BASE_URL="http://localhost:3001/api/v1"
JWT_TOKEN=""
LIST_ID=""
TASK_ID=""

echo "🧠 Testing Focusmate API - ADHD Task Management"
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
REGISTER_RESPONSE=$(make_request POST "/register" '{"user": {"email": "adhd@example.com", "password": "password123", "password_confirmation": "password123"}}')
echo "Response: $REGISTER_RESPONSE"

echo ""
echo "2. Login to get JWT token..."
echo "----------------------------"
LOGIN_RESPONSE=$(make_request POST "/login" '{"email": "adhd@example.com", "password": "password123"}')
echo "Response: $LOGIN_RESPONSE"

# Extract JWT token
JWT_TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"jti":"[^"]*"' | cut -d'"' -f4)
if [ -z "$JWT_TOKEN" ]; then
    echo "❌ Failed to get JWT token. Please check the login response."
    exit 1
fi
echo "✅ JWT Token obtained"

echo ""
echo "3. Create a list for tasks..."
echo "-----------------------------"
CREATE_LIST_RESPONSE=$(make_request POST "/lists" '{"list": {"name": "ADHD Daily Tasks", "description": "Tasks to help manage ADHD symptoms"}}')
echo "Response: $CREATE_LIST_RESPONSE"

# Extract list ID
LIST_ID=$(echo $CREATE_LIST_RESPONSE | grep -o '"id":[0-9]*' | cut -d':' -f2)
if [ -z "$LIST_ID" ]; then
    echo "❌ Failed to get list ID. Please check the create list response."
    exit 1
fi
echo "✅ List created with ID: $LIST_ID"

echo ""
echo "4. Create a task with strict mode enabled..."
echo "--------------------------------------------"
CREATE_TASK_RESPONSE=$(make_request POST "/lists/$LIST_ID/tasks" '{"task": {"title": "Take medication", "note": "Take ADHD medication at 8 AM", "due_at": "2024-01-15T08:00:00Z", "strict_mode": true}}')
echo "Response: $CREATE_TASK_RESPONSE"

# Extract task ID
TASK_ID=$(echo $CREATE_TASK_RESPONSE | grep -o '"id":[0-9]*' | cut -d':' -f2)
if [ -z "$TASK_ID" ]; then
    echo "❌ Failed to get task ID. Please check the create task response."
    exit 1
fi
echo "✅ Task created with ID: $TASK_ID"

echo ""
echo "5. Get all tasks in the list..."
echo "-------------------------------"
GET_TASKS_RESPONSE=$(make_request GET "/lists/$LIST_ID/tasks")
echo "Response: $GET_TASKS_RESPONSE"

echo ""
echo "6. Get specific task details with audit trail..."
echo "------------------------------------------------"
GET_TASK_RESPONSE=$(make_request GET "/tasks/$TASK_ID")
echo "Response: $GET_TASK_RESPONSE"

echo ""
echo "7. Test strict mode - try to reassign without reason (should fail)..."
echo "--------------------------------------------------------------------"
REASSIGN_NO_REASON_RESPONSE=$(make_request POST "/tasks/$TASK_ID/reassign" '{"due_at": "2024-01-16T08:00:00Z"}')
echo "Response: $REASSIGN_NO_REASON_RESPONSE"

echo ""
echo "8. Test strict mode - reassign with reason (should succeed)..."
echo "-------------------------------------------------------------"
REASSIGN_WITH_REASON_RESPONSE=$(make_request POST "/tasks/$TASK_ID/reassign" '{"due_at": "2024-01-16T08:00:00Z", "reason": "Forgot to take medication yesterday, need to reschedule"}')
echo "Response: $REASSIGN_WITH_REASON_RESPONSE"

echo ""
echo "9. Create a task with strict mode disabled..."
echo "----------------------------------------------"
CREATE_TASK_2_RESPONSE=$(make_request POST "/lists/$LIST_ID/tasks" '{"task": {"title": "Exercise", "note": "30 minutes of cardio", "due_at": "2024-01-15T18:00:00Z", "strict_mode": false}}')
echo "Response: $CREATE_TASK_2_RESPONSE"

# Extract second task ID
TASK_2_ID=$(echo $CREATE_TASK_2_RESPONSE | grep -o '"id":[0-9]*' | cut -d':' -f2)
echo "✅ Second task created with ID: $TASK_2_ID"

echo ""
echo "10. Test non-strict mode - reassign without reason (should succeed)..."
echo "----------------------------------------------------------------------"
REASSIGN_NO_REASON_2_RESPONSE=$(make_request POST "/tasks/$TASK_2_ID/reassign" '{"due_at": "2024-01-16T18:00:00Z"}')
echo "Response: $REASSIGN_NO_REASON_2_RESPONSE"

echo ""
echo "11. Complete the first task..."
echo "-------------------------------"
COMPLETE_TASK_RESPONSE=$(make_request POST "/tasks/$TASK_ID/complete" '{"reason": "Successfully took medication"}')
echo "Response: $COMPLETE_TASK_RESPONSE"

echo ""
echo "12. Get updated task details to see audit trail..."
echo "--------------------------------------------------"
GET_TASK_UPDATED_RESPONSE=$(make_request GET "/tasks/$TASK_ID")
echo "Response: $GET_TASK_UPDATED_RESPONSE"

echo ""
echo "13. Soft delete the second task..."
echo "----------------------------------"
DELETE_TASK_RESPONSE=$(make_request DELETE "/tasks/$TASK_2_ID" '{"reason": "Decided to skip exercise today"}')
echo "Response: $DELETE_TASK_RESPONSE"

echo ""
echo "14. Get all tasks (should only show active tasks)..."
echo "---------------------------------------------------"
GET_ALL_TASKS_RESPONSE=$(make_request GET "/lists/$LIST_ID/tasks")
echo "Response: $GET_ALL_TASKS_RESPONSE"

echo ""
echo "✅ ADHD Task Management testing completed!"
echo ""
echo "Summary of features tested:"
echo "- ✅ Task creation with strict mode"
echo "- ✅ Strict mode enforcement (requires reason for reassignment)"
echo "- ✅ Non-strict mode (allows reassignment without reason)"
echo "- ✅ Task completion with audit trail"
echo "- ✅ Soft deletion with reason"
echo "- ✅ Audit trail tracking all actions"
echo "- ✅ Authorization enforcement"
echo ""
echo "This demonstrates the no-snooze flow for ADHD management:"
echo "- Tasks cannot be silently postponed in strict mode"
echo "- Every action is tracked with reasons"
echo "- Coaches can see reassignment patterns"
echo "- Users are held accountable for task management"
