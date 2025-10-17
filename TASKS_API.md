# Tasks API Documentation - ADHD Management Tool

## Overview

This API provides a no-snooze task management system designed specifically for ADHD users. It enforces accountability through strict mode, audit trails, and prevents silent task postponement.

## Key Features

### 🧠 ADHD-Focused Design
- **No-Snooze Flow**: Tasks cannot be silently postponed
- **Strict Mode**: Requires reasons for reassignments
- **Audit Trail**: Every action is tracked with timestamps and reasons
- **Accountability**: Coaches can see reassignment patterns

### 🔒 Business Rules
- **Strict Mode**: Cannot reassign without providing a reason
- **Audit Trail**: Every action creates a TaskEvent record
- **Permissions**: Owner/Editor can modify, Viewer is read-only
- **Soft Delete**: Tasks are marked as deleted, not permanently removed

## Models

### Task
- **title**: Task name (required)
- **note**: Additional details (optional)
- **due_at**: Due date/time (required)
- **status**: `pending`, `done`, `deleted`
- **strict_mode**: Boolean (default: true)
- **list_id**: Associated list

### TaskEvent (Audit Trail)
- **task_id**: Associated task
- **user_id**: User who performed the action
- **kind**: `created`, `completed`, `reassigned`, `deleted`
- **reason**: Explanation for the action
- **occurred_at**: Timestamp of the action

## Endpoints

### Task Management

#### GET /api/v1/lists/:list_id/tasks
Get all active tasks in a list.

**Response:**
```json
{
  "tasks": [
    {
      "id": 1,
      "title": "Take medication",
      "note": "Take ADHD medication at 8 AM",
      "due_at": "2024-01-15T08:00:00Z",
      "status": "pending",
      "strict_mode": true,
      "created_at": "2024-01-15T07:00:00Z",
      "updated_at": "2024-01-15T07:00:00Z",
      "can_reassign": true
    }
  ]
}
```

#### POST /api/v1/lists/:list_id/tasks
Create a new task.

**Request Body:**
```json
{
  "task": {
    "title": "Take medication",
    "note": "Take ADHD medication at 8 AM",
    "due_at": "2024-01-15T08:00:00Z",
    "strict_mode": true
  }
}
```

**Response:** (201 Created)
```json
{
  "task": {
    "id": 1,
    "title": "Take medication",
    "note": "Take ADHD medication at 8 AM",
    "due_at": "2024-01-15T08:00:00Z",
    "status": "pending",
    "strict_mode": true,
    "created_at": "2024-01-15T07:00:00Z",
    "updated_at": "2024-01-15T07:00:00Z",
    "can_reassign": true
  }
}
```

#### GET /api/v1/tasks/:id
Get a specific task with audit trail.

**Response:**
```json
{
  "task": {
    "id": 1,
    "title": "Take medication",
    "note": "Take ADHD medication at 8 AM",
    "due_at": "2024-01-15T08:00:00Z",
    "status": "pending",
    "strict_mode": true,
    "list": {
      "id": 1,
      "name": "ADHD Daily Tasks"
    },
    "created_at": "2024-01-15T07:00:00Z",
    "updated_at": "2024-01-15T07:00:00Z",
    "can_reassign": true,
    "audit_trail": [
      {
        "id": 1,
        "kind": "created",
        "reason": null,
        "user": {
          "id": 1,
          "email": "user@example.com"
        },
        "occurred_at": "2024-01-15T07:00:00Z"
      }
    ]
  }
}
```

#### PATCH/PUT /api/v1/tasks/:id
Update task details (title, note, due date).

**Request Body:**
```json
{
  "task": {
    "title": "Updated task title",
    "note": "Updated note",
    "due_at": "2024-01-16T08:00:00Z"
  }
}
```

### No-Snooze Actions

#### POST /api/v1/tasks/:id/complete
Mark a task as completed.

**Request Body:**
```json
{
  "reason": "Successfully completed the task"
}
```

**Response:**
```json
{
  "task": {
    "id": 1,
    "title": "Take medication",
    "status": "done",
    "completed_at": "2024-01-15T08:30:00Z"
  },
  "message": "Task completed successfully"
}
```

#### POST /api/v1/tasks/:id/reassign
Reassign a task to a new due date.

**Request Body:**
```json
{
  "due_at": "2024-01-16T08:00:00Z",
  "reason": "Forgot to take medication yesterday"
}
```

**Parameters:**
- `due_at`: New due date (required)
- `reason`: Reason for reassignment (required in strict mode)

**Response:**
```json
{
  "task": {
    "id": 1,
    "title": "Take medication",
    "due_at": "2024-01-16T08:00:00Z",
    "status": "pending",
    "strict_mode": true
  },
  "message": "Task reassigned successfully"
}
```

#### DELETE /api/v1/tasks/:id
Soft delete a task.

**Request Body:**
```json
{
  "reason": "Task is no longer relevant"
}
```

**Response:**
```json
{
  "message": "Task deleted successfully"
}
```

## Business Rules & Validation

### Strict Mode Enforcement
- **Strict Mode ON**: Reassignment requires a reason
- **Strict Mode OFF**: Reassignment can be done without reason
- **Default**: All tasks start in strict mode

### Audit Trail Requirements
- Every action creates a TaskEvent record
- Reasons are required for reassignments in strict mode
- All actions are timestamped
- User who performed the action is tracked

### Permission Rules
- **Owner/Editor**: Can create, update, complete, reassign, delete tasks
- **Viewer**: Can only view tasks
- **Self-accountability**: Users can only modify tasks in lists they have access to

## Error Responses

### 422 Unprocessable Entity - Strict Mode Violation
```json
{
  "error": "Reason is required in strict mode"
}
```

### 422 Unprocessable Entity - Missing Due Date
```json
{
  "error": "New due date is required"
}
```

### 403 Forbidden - Permission Denied
```json
{
  "error": "You are not authorized to perform this action"
}
```

### 404 Not Found - Task Not Found
```json
{
  "error": "Task not found"
}
```

## Example Usage

### 1. Create a Strict Mode Task
```bash
curl -X POST http://localhost:3001/api/v1/lists/1/tasks \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt_token>" \
  -d '{
    "task": {
      "title": "Take medication",
      "note": "Take ADHD medication at 8 AM",
      "due_at": "2024-01-15T08:00:00Z",
      "strict_mode": true
    }
  }'
```

### 2. Reassign with Reason (Strict Mode)
```bash
curl -X POST http://localhost:3001/api/v1/tasks/1/reassign \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt_token>" \
  -d '{
    "due_at": "2024-01-16T08:00:00Z",
    "reason": "Forgot to take medication yesterday"
  }'
```

### 3. Complete Task
```bash
curl -X POST http://localhost:3001/api/v1/tasks/1/complete \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt_token>" \
  -d '{
    "reason": "Successfully took medication"
  }'
```

### 4. Get Task with Audit Trail
```bash
curl -X GET http://localhost:3001/api/v1/tasks/1 \
  -H "Authorization: Bearer <jwt_token>"
```

## ADHD Management Benefits

### 🎯 Accountability
- No silent postponements
- Every reassignment requires justification
- Audit trail shows patterns of behavior

### 📊 Coach Visibility
- Coaches can see reassignment reasons
- Track completion patterns
- Identify areas for improvement

### 🧠 ADHD-Friendly
- Prevents task avoidance
- Encourages honest self-reflection
- Builds consistent habits

## Testing

Run the comprehensive test script:
```bash
./test_tasks_api.sh
```

This tests:
- Task creation with strict mode
- Strict mode enforcement
- Non-strict mode flexibility
- Task completion and audit trails
- Soft deletion
- Authorization enforcement

## Use Cases

### For ADHD Users
- Create tasks with strict deadlines
- Cannot silently postpone without reason
- Build accountability through audit trails

### For Coaches
- Monitor task completion patterns
- See reassignment reasons
- Track progress over time

### For Families
- Understand task management challenges
- Support through structured approach
- Celebrate completed tasks
