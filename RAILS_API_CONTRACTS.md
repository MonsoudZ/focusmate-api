# Rails API Contracts - Complete Reference

**Generated**: October 31, 2025
**API Version**: v1
**Base URL**: `http://localhost:3000/api/v1`

---

## 🔐 Authentication Endpoints

### Sign Up
```
POST /api/v1/auth/sign_up
```

**Request Body**:
```json
{
  "authentication": {
    "email": "user@example.com",
    "password": "password123",
    "password_confirmation": "password123",
    "name": "John Doe",
    "timezone": "America/New_York"  // REQUIRED
  }
}
```

**Success Response (201)**:
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe",
    "role": "client",
    "timezone": "America/New_York"
  },
  "token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

**Validation Error (422)**:
```json
{
  "code": "validation_error",
  "message": "Validation failed",
  "details": {
    "email": ["has already been taken"],
    "timezone": ["can't be blank"]
  }
}
```

### Sign In
```
POST /api/v1/auth/sign_in
```

**Request Body**:
```json
{
  "authentication": {
    "email": "user@example.com",
    "password": "password123"
  }
}
```

**Success Response (200)**:
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe",
    "role": "client",
    "timezone": "America/New_York"
  },
  "token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

**Error Response (401)**:
```json
{
  "error": {
    "message": "Invalid email or password"
  }
}
```

### Sign Out
```
DELETE /api/v1/auth/sign_out
```

**Headers**: `Authorization: Bearer <token>`

**Response**: `204 No Content`

### Get Profile
```
GET /api/v1/profile
```

**Headers**: `Authorization: Bearer <token>`

**Response (200)**:
```json
{
  "id": 1,
  "email": "user@example.com",
  "name": "John Doe",
  "role": "client",
  "timezone": "America/New_York",
  "created_at": "2025-01-15T10:30:00Z",
  "accessible_lists_count": 5
}
```

---

## 📋 Lists Endpoints

### Get All Lists
```
GET /api/v1/lists
```

**Headers**: `Authorization: Bearer <token>`

**Query Params** (optional):
- `since` - ISO8601 timestamp to filter lists modified since

**Response (200)**:
```json
{
  "lists": [
    {
      "id": 1,
      "name": "My Tasks",
      "description": "Personal task list",
      "visibility": "private",
      "user_id": 1,
      "deleted_at": null,
      "created_at": "2025-01-15T10:30:00Z",
      "updated_at": "2025-01-20T14:45:00Z"
    }
  ],
  "tombstones": []
}
```

### Get Single List
```
GET /api/v1/lists/:id
```

**Headers**: `Authorization: Bearer <token>`

**Response (200)**:
```json
{
  "id": 1,
  "name": "My Tasks",
  "description": "Personal task list",
  "visibility": "private",
  "user_id": 1,
  "deleted_at": null,
  "created_at": "2025-01-15T10:30:00Z",
  "updated_at": "2025-01-20T14:45:00Z",
  "tasks": [
    {
      "id": 1,
      "title": "Complete report",
      "note": "Q4 report",
      "due_at": "2025-01-25T17:00:00Z",
      "status": "pending",
      "created_at": "2025-01-20T10:00:00Z",
      "updated_at": "2025-01-20T10:00:00Z"
    }
  ]
}
```

**Not Found (404)**:
```json
{
  "error": {
    "message": "List not found"
  }
}
```

**Forbidden (403)**:
```json
{
  "error": {
    "message": "Unauthorized"
  }
}
```

### Create List
```
POST /api/v1/lists
```

**Headers**: `Authorization: Bearer <token>`

**Request Body** (flat or nested):
```json
{
  "list": {
    "name": "My New List",
    "description": "Optional description",
    "visibility": "private"
  }
}
```

OR flat:
```json
{
  "name": "My New List",
  "description": "Optional description",
  "visibility": "private"
}
```

**Response (201)**: Same as Get Single List

### Update List
```
PATCH /api/v1/lists/:id
```

**Headers**: `Authorization: Bearer <token>`

**Request Body**:
```json
{
  "list": {
    "name": "Updated Name",
    "description": "Updated description",
    "visibility": "shared"
  }
}
```

**Response (200)**: Same as Get Single List

### Delete List
```
DELETE /api/v1/lists/:id
```

**Headers**: `Authorization: Bearer <token>`

**Response**: `204 No Content`

### Share List
```
POST /api/v1/lists/:id/share
```

**Headers**: `Authorization: Bearer <token>`

**Request Body**:
```json
{
  "email": "coach@example.com",
  "can_view": true,
  "can_edit": true,
  "can_add_items": true,
  "can_delete_items": false
}
```

OR with user_id:
```json
{
  "user_id": 5,
  "can_view": true,
  "can_edit": true,
  "can_add_items": true,
  "can_delete_items": false
}
```

**Response (201)**:
```json
{
  "id": 1,
  "user_id": 5,
  "email": "coach@example.com",
  "can_view": true,
  "can_edit": true,
  "can_add_items": true,
  "can_delete_items": false,
  "status": "pending",
  "created_at": "2025-01-20T10:00:00Z",
  "updated_at": "2025-01-20T10:00:00Z"
}
```

### Get List Members
```
GET /api/v1/lists/:id/members
```

**Headers**: `Authorization: Bearer <token>`

**Response (200)**:
```json
{
  "members": [
    {
      "id": 1,
      "role": "owner"
    },
    {
      "id": 5,
      "role": "member",
      "can_edit": true
    }
  ]
}
```

---

## ✅ Tasks Endpoints

### Get Tasks in List
```
GET /api/v1/lists/:list_id/tasks
```

**Headers**: `Authorization: Bearer <token>`

**Query Params** (optional):
- `page` - Page number (default: 1)
- `per_page` - Items per page (max: 100)
- `status` - Filter by status: "pending", "in_progress", "done"
- `overdue` - "true" to show only overdue tasks
- `since` - ISO8601 timestamp

**Response (200)**:
```json
{
  "tasks": [
    {
      "id": 1,
      "title": "Complete report",
      "note": "Q4 report",
      "list_id": 1,
      "status": "pending",
      "due_at": "2025-01-25T17:00:00Z",
      "completed_at": null,
      "creator_id": 1,
      "assigned_to_id": null,
      "visibility": "visible_to_all",
      "strict_mode": false,
      "can_be_snoozed": true,
      "requires_explanation_if_missed": false,
      "created_at": "2025-01-20T10:00:00Z",
      "updated_at": "2025-01-20T10:00:00Z"
    }
  ],
  "tombstones": [],
  "pagination": {
    "page": 1,
    "per_page": 25,
    "total": 15,
    "total_pages": 1
  }
}
```

### Get All Tasks (Across All Lists)
```
GET /api/v1/tasks
```

**Headers**: `Authorization: Bearer <token>`

**Response**: Same format as Get Tasks in List

### Get Single Task
```
GET /api/v1/tasks/:id
```

**Headers**: `Authorization: Bearer <token>`

**Response (200)**:
```json
{
  "id": 1,
  "title": "Complete report",
  "note": "Q4 report details...",
  "list_id": 1,
  "status": "pending",
  "due_at": "2025-01-25T17:00:00Z",
  "completed_at": null,
  "creator_id": 1,
  "assigned_to_id": null,
  "visibility": "visible_to_all",
  "strict_mode": false,
  "can_be_snoozed": true,
  "requires_explanation_if_missed": false,
  "is_recurring": false,
  "location_based": false,
  "escalation": null,
  "subtasks": [],
  "created_at": "2025-01-20T10:00:00Z",
  "updated_at": "2025-01-20T10:00:00Z"
}
```

### Create Task
```
POST /api/v1/lists/:list_id/tasks
```

**Headers**: `Authorization: Bearer <token>`

**Request Body** (flat or nested):
```json
{
  "task": {
    "title": "New task",
    "note": "Optional note",
    "due_at": "2025-01-25T17:00:00Z",
    "visibility": "visible_to_all",
    "strict_mode": false,
    "can_be_snoozed": true,
    "requires_explanation_if_missed": false
  }
}
```

OR flat:
```json
{
  "title": "New task",
  "note": "Optional note",
  "due_at": "2025-01-25T17:00:00Z"
}
```

**Response (201)**: Same as Get Single Task

### Update Task
```
PATCH /api/v1/lists/:list_id/tasks/:id
```

**Headers**: `Authorization: Bearer <token>`

**Request Body**:
```json
{
  "task": {
    "title": "Updated title",
    "note": "Updated note",
    "due_at": "2025-01-26T17:00:00Z"
  }
}
```

**Response (200)**: Same as Get Single Task

### Delete Task
```
DELETE /api/v1/lists/:list_id/tasks/:id
```

**Headers**: `Authorization: Bearer <token>`

**Response**: `204 No Content`

### Complete Task ✅
```
POST /api/v1/tasks/:id/complete
```
OR
```
PATCH /api/v1/tasks/:id/complete
```

**Headers**: `Authorization: Bearer <token>`

**Request Body** (optional):
```json
{
  "completed": true
}
```

OR empty body:
```json
{}
```

**Response (200)**: Same as Get Single Task (with `completed_at` populated)

### Uncomplete Task
```
PATCH /api/v1/tasks/:id/uncomplete
```

**Headers**: `Authorization: Bearer <token>`

**Response (200)**: Same as Get Single Task (with `completed_at` set to null)

### Get Overdue Tasks
```
GET /api/v1/tasks/overdue
```

**Headers**: `Authorization: Bearer <token>`

**Response**: Same format as Get All Tasks

### Get Blocking Tasks
```
GET /api/v1/tasks/blocking
```

**Headers**: `Authorization: Bearer <token>`

**Response**: Same format as Get All Tasks

---

## 📱 Device Registration Endpoints

### Register Device
```
POST /api/v1/devices
```

**Headers**: `Authorization: Bearer <token>`

**Request Body** (Option A - Nested):
```json
{
  "device": {
    "platform": "ios",
    "apns_token": "abc123...",
    "device_name": "John's iPhone",
    "os_version": "17.2",
    "app_version": "1.0.0",
    "bundle_id": "com.example.focusmate",
    "locale": "en_US"
  }
}
```

**Request Body** (Option B - Flat):
```json
{
  "platform": "ios",
  "apns_token": "abc123...",
  "device_name": "John's iPhone",
  "os_version": "17.2",
  "app_version": "1.0.0",
  "bundle_id": "com.example.focusmate",
  "locale": "en_US"
}
```

**Response (201)**:
```json
{
  "id": 1,
  "user_id": 1,
  "platform": "ios",
  "apns_token": "abc123...",
  "device_name": "John's iPhone",
  "os_version": "17.2",
  "app_version": "1.0.0",
  "bundle_id": "com.example.focusmate",
  "locale": "en_US",
  "active": true,
  "last_seen_at": "2025-01-20T10:00:00Z",
  "created_at": "2025-01-20T10:00:00Z",
  "updated_at": "2025-01-20T10:00:00Z"
}
```

### Register Device (Legacy)
```
POST /api/v1/devices/register
```

Same as above but legacy endpoint for backward compatibility.

### Get All Devices
```
GET /api/v1/devices
```

**Headers**: `Authorization: Bearer <token>`

**Query Params** (optional):
- `platform` - "ios" or "android"
- `active` - "true" or "false"
- `search` - Search device name, OS version, or app version
- `page` - Page number
- `per_page` - Items per page (max: 50)

**Response (200)**:
```json
{
  "devices": [
    {
      "id": 1,
      "user_id": 1,
      "platform": "ios",
      "apns_token": "abc123...",
      "device_name": "John's iPhone",
      "os_version": "17.2",
      "app_version": "1.0.0",
      "active": true,
      "last_seen_at": "2025-01-20T10:00:00Z",
      "created_at": "2025-01-20T10:00:00Z",
      "updated_at": "2025-01-20T10:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 25,
    "total": 3,
    "total_pages": 1
  }
}
```

---

## 🚨 Error Response Formats

### Unauthorized (401)
```json
{
  "error": {
    "message": "Invalid email or password"
  }
}
```

With WWW-Authenticate header:
```
WWW-Authenticate: Bearer realm="Application"
```

### Forbidden (403)
```json
{
  "error": {
    "message": "Unauthorized"
  }
}
```

### Not Found (404)
```json
{
  "error": {
    "message": "List not found"
  }
}
```

OR
```json
{
  "error": {
    "message": "Resource not found"
  }
}
```

### Validation Error (422)
```json
{
  "code": "validation_error",
  "message": "Validation failed",
  "details": {
    "title": ["can't be blank"],
    "due_at": ["can't be in the past"]
  }
}
```

OR simpler format:
```json
{
  "errors": {
    "title": ["can't be blank"],
    "due_at": ["can't be in the past"]
  }
}
```

OR with error wrapper:
```json
{
  "error": {
    "message": "Validation failed",
    "details": {
      "title": ["can't be blank"]
    }
  }
}
```

### Bad Request (400)
```json
{
  "error": {
    "message": "Bad Request"
  }
}
```

### Server Error (500)
```json
{
  "error": {
    "message": "An unexpected error occurred",
    "status": 500,
    "timestamp": "2025-01-20T10:00:00Z"
  }
}
```

---

## 🔑 Key Points for iOS Integration

### 1. Authentication
- **Always wrap credentials** in `authentication` key
- **Timezone is REQUIRED** for sign up
- **JWT tokens expire in 1 hour**
- **Store token in Keychain** securely
- **Include token in all requests**: `Authorization: Bearer <token>`

### 2. Request Format Flexibility
Most endpoints accept **both flat and nested** parameters:
```json
// Nested (preferred)
{"list": {"name": "My List"}}

// Flat (also works)
{"name": "My List"}
```

### 3. Task Completion
- **Two endpoints available**: `POST` or `PATCH /api/v1/tasks/:id/complete`
- **Request body is optional**
- **Can include** `{"completed": true}` but not required
- **Empty body `{}` works fine**

### 4. Device Registration
- **Accepts nested or flat** parameters
- **Platform auto-detected** if `apns_token` present
- **Auto-generates token** if none provided (for testing)
- **Both `/devices` and `/devices/register` work**

### 5. Pagination
- **Default page size**: 25
- **Max page size**: 50-100 (depending on endpoint)
- **Always returns pagination metadata** in response

### 6. Date Formats
- **All dates in ISO8601 format**: `"2025-01-20T10:30:00Z"`
- **Rails returns UTC timestamps**
- **Client should handle timezone conversion**

### 7. Error Handling
- **Check status code first**
- **Error format varies slightly** between endpoints
- **Always look for `error.message` or `errors` key**
- **Validation errors include `details` hash**

---

## 📊 Complete Routes List

```
# Authentication
POST   /api/v1/auth/sign_in
POST   /api/v1/auth/sign_up
DELETE /api/v1/auth/sign_out
GET    /api/v1/profile

# Lists
GET    /api/v1/lists
POST   /api/v1/lists
GET    /api/v1/lists/:id
PATCH  /api/v1/lists/:id
DELETE /api/v1/lists/:id
POST   /api/v1/lists/:id/share
PATCH  /api/v1/lists/:id/unshare
GET    /api/v1/lists/:id/members
GET    /api/v1/lists/:id/tasks

# Tasks (nested under lists)
GET    /api/v1/lists/:list_id/tasks
POST   /api/v1/lists/:list_id/tasks
GET    /api/v1/lists/:list_id/tasks/:id
PATCH  /api/v1/lists/:list_id/tasks/:id
DELETE /api/v1/lists/:list_id/tasks/:id
POST   /api/v1/lists/:list_id/tasks/:id/complete
PATCH  /api/v1/lists/:list_id/tasks/:id/complete
PATCH  /api/v1/lists/:list_id/tasks/:id/uncomplete

# Tasks (global)
GET    /api/v1/tasks
POST   /api/v1/tasks
GET    /api/v1/tasks/:id
PATCH  /api/v1/tasks/:id
DELETE /api/v1/tasks/:id
POST   /api/v1/tasks/:id/complete
PATCH  /api/v1/tasks/:id/complete
PATCH  /api/v1/tasks/:id/uncomplete
GET    /api/v1/tasks/overdue
GET    /api/v1/tasks/blocking
GET    /api/v1/tasks/awaiting_explanation

# Devices
GET    /api/v1/devices
POST   /api/v1/devices
POST   /api/v1/devices/register
GET    /api/v1/devices/:id
PATCH  /api/v1/devices/:id
DELETE /api/v1/devices/:id
POST   /api/v1/devices/test_push

# Coaching
GET    /api/v1/coaching_relationships
POST   /api/v1/coaching_relationships
GET    /api/v1/coaching_relationships/:id
DELETE /api/v1/coaching_relationships/:id

# Dashboard
GET    /api/v1/dashboard
GET    /api/v1/dashboard/stats

# Notifications
GET    /api/v1/notifications
PATCH  /api/v1/notifications/:id/mark_read
PATCH  /api/v1/notifications/mark_all_read
```

---

**Status**: ✅ Complete
**Last Updated**: October 31, 2025
**Rails Version**: 8.0.3
**API Version**: v1
