# Focusmate API Documentation

## Base URL
```
https://your-domain.com/api/v1
```

## Authentication
All protected endpoints require a JWT token in the Authorization header:
```
Authorization: Bearer <jwt_token>
```

---

## 🔐 Authentication Endpoints

### POST /login
**Alias:** `POST /auth/sign_in`

**Description:** Authenticate user and receive JWT token

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**Response (200 OK):**
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

**Response (401 Unauthorized):**
```json
{
  "error": "Invalid email or password"
}
```

### POST /register
**Alias:** `POST /auth/sign_up`

**Description:** Create new user account

**Request Body:**
```json
{
  "user": {
    "email": "user@example.com",
    "password": "password123",
    "password_confirmation": "password123",
    "name": "John Doe",
    "role": "client",
    "timezone": "America/New_York"
  }
}
```

**Response (201 Created):**
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

**Response (422 Unprocessable Entity):**
```json
{
  "errors": ["Email has already been taken", "Password is too short"]
}
```

### GET /profile
**Description:** Get current user profile

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "id": 1,
  "email": "user@example.com",
  "name": "John Doe",
  "role": "client",
  "timezone": "America/New_York"
}
```

### DELETE /logout
**Alias:** `DELETE /auth/sign_out`

**Description:** Logout user (client-side token removal)

**Headers:** `Authorization: Bearer <token>`

**Response (204 No Content)**

---

## 📱 Device Management

### POST /devices/register
**Description:** Register device for push notifications

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "apns_token": "device_token_here",
  "platform": "ios",
  "bundle_id": "com.yourapp.focusmate"
}
```

**Response (201 Created):**
```json
{
  "device": {
    "id": 1,
    "platform": "ios",
    "bundle_id": "com.yourapp.focusmate",
    "created_at": "2025-01-15T10:30:00Z"
  }
}
```

### DELETE /devices/:id
**Description:** Unregister device

**Headers:** `Authorization: Bearer <token>`

**Response (204 No Content)**

---

## 📋 Lists Management

### GET /lists
**Description:** Get all lists accessible to user

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "name": "Work Tasks",
    "description": "Daily work tasks",
    "owner": {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com"
    },
    "role": "owner",
    "shared_coaches": [
      {
        "id": 2,
        "name": "Coach Smith",
        "email": "coach@example.com"
      }
    ],
    "task_counts": {
      "total": 5,
      "pending": 3,
      "completed": 2,
      "overdue": 1
    },
    "created_at": "2025-01-15T10:30:00Z"
  }
]
```

### GET /lists/:id
**Description:** Get specific list with tasks

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "id": 1,
  "name": "Work Tasks",
  "description": "Daily work tasks",
  "owner": {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com"
  },
  "role": "owner",
  "shared_coaches": [...],
  "task_counts": {...},
  "tasks": [
    {
      "id": 1,
      "title": "Review project proposal",
      "description": "Review and provide feedback",
      "due_at": "2025-01-16T09:00:00Z",
      "completed_at": null,
      "priority": 2,
      "can_be_snoozed": false,
      "overdue": false,
      "minutes_overdue": null,
      "requires_explanation": false,
      "creator": {
        "id": 1,
        "name": "John Doe",
        "email": "john@example.com"
      },
      "created_by_coach": false,
      "can_edit": true,
      "can_delete": true,
      "can_complete": true,
      "escalation": null,
      "created_at": "2025-01-15T10:30:00Z",
      "updated_at": "2025-01-15T10:30:00Z"
    }
  ],
  "created_at": "2025-01-15T10:30:00Z"
}
```

### POST /lists
**Description:** Create new list

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "list": {
    "name": "Personal Tasks",
    "description": "My personal task list"
  }
}
```

**Response (201 Created):**
```json
{
  "id": 2,
  "name": "Personal Tasks",
  "description": "My personal task list",
  "owner": {...},
  "role": "owner",
  "shared_coaches": [],
  "task_counts": {
    "total": 0,
    "pending": 0,
    "completed": 0,
    "overdue": 0
  },
  "created_at": "2025-01-15T10:30:00Z"
}
```

### PATCH /lists/:id
**Description:** Update list

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "list": {
    "name": "Updated List Name",
    "description": "Updated description"
  }
}
```

### DELETE /lists/:id
**Description:** Delete list

**Headers:** `Authorization: Bearer <token>`

**Response (204 No Content)**

---

## ✅ Tasks Management

### GET /lists/:list_id/tasks
**Description:** Get tasks in a list

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "title": "Review project proposal",
    "description": "Review and provide feedback",
    "due_at": "2025-01-16T09:00:00Z",
    "completed_at": null,
    "priority": 2,
    "can_be_snoozed": false,
    "notification_interval_minutes": 15,
    "requires_explanation_if_missed": true,
    "overdue": false,
    "minutes_overdue": null,
    "requires_explanation": false,
    "is_recurring": false,
    "location_based": false,
    "missed_reason": null,
    "creator": {...},
    "created_by_coach": false,
    "can_edit": true,
    "can_delete": true,
    "can_complete": true,
    "escalation": null,
    "has_subtasks": false,
    "subtasks_count": 0,
    "subtasks_completed_count": 0,
    "subtask_completion_percentage": 0,
    "created_at": "2025-01-15T10:30:00Z",
    "updated_at": "2025-01-15T10:30:00Z"
  }
]
```

### GET /lists/:list_id/tasks/:id
**Description:** Get specific task with subtasks

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "id": 1,
  "title": "Review project proposal",
  "description": "Review and provide feedback",
  "due_at": "2025-01-16T09:00:00Z",
  "completed_at": null,
  "priority": 2,
  "can_be_snoozed": false,
  "overdue": false,
  "requires_explanation": false,
  "creator": {...},
  "created_by_coach": false,
  "can_edit": true,
  "can_delete": true,
  "can_complete": true,
  "escalation": null,
  "has_subtasks": true,
  "subtasks_count": 2,
  "subtasks_completed_count": 1,
  "subtask_completion_percentage": 50,
  "subtasks": [
    {
      "id": 2,
      "title": "Read first 10 pages",
      "description": null,
      "due_at": "2025-01-16T09:00:00Z",
      "completed_at": "2025-01-15T14:30:00Z",
      "priority": 2,
      "can_be_snoozed": false,
      "overdue": false,
      "requires_explanation": false,
      "creator": {...},
      "created_by_coach": false,
      "can_edit": true,
      "can_delete": true,
      "can_complete": true,
      "escalation": null,
      "has_subtasks": false,
      "subtasks_count": 0,
      "subtasks_completed_count": 0,
      "subtask_completion_percentage": 0,
      "created_at": "2025-01-15T10:30:00Z",
      "updated_at": "2025-01-15T14:30:00Z"
    }
  ],
  "created_at": "2025-01-15T10:30:00Z",
  "updated_at": "2025-01-15T10:30:00Z"
}
```

### POST /lists/:list_id/tasks
**Description:** Create new task

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "task": {
    "title": "Complete project review",
    "description": "Review the project proposal and provide feedback",
    "due_at": "2025-01-16T09:00:00Z",
    "priority": 2,
    "can_be_snoozed": false,
    "notification_interval_minutes": 15,
    "requires_explanation_if_missed": true,
    "is_recurring": false,
    "location_based": false,
    "notify_on_arrival": false,
    "notify_on_departure": false
  },
  "subtasks": [
    "Read first 10 pages",
    "Write initial feedback",
    "Schedule follow-up meeting"
  ]
}
```

**Response (201 Created):**
```json
{
  "id": 3,
  "title": "Complete project review",
  "description": "Review the project proposal and provide feedback",
  "due_at": "2025-01-16T09:00:00Z",
  "completed_at": null,
  "priority": 2,
  "can_be_snoozed": false,
  "overdue": false,
  "requires_explanation": false,
  "creator": {...},
  "created_by_coach": false,
  "can_edit": true,
  "can_delete": true,
  "can_complete": true,
  "escalation": null,
  "has_subtasks": true,
  "subtasks_count": 3,
  "subtasks_completed_count": 0,
  "subtask_completion_percentage": 0,
  "created_at": "2025-01-15T10:30:00Z",
  "updated_at": "2025-01-15T10:30:00Z"
}
```

### PATCH /lists/:list_id/tasks/:id
**Description:** Update task

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "task": {
    "title": "Updated task title",
    "description": "Updated description",
    "due_at": "2025-01-17T09:00:00Z",
    "priority": 3
  }
}
```

### DELETE /lists/:list_id/tasks/:id
**Description:** Delete task

**Headers:** `Authorization: Bearer <token>`

**Response (204 No Content)**

---

## 🎯 No-Snooze Actions

### POST /tasks/:id/complete
**Description:** Mark task as completed

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "id": 1,
  "title": "Review project proposal",
  "completed_at": "2025-01-15T14:30:00Z",
  "overdue": false,
  "requires_explanation": false,
  "can_complete": true,
  "escalation": null,
  "updated_at": "2025-01-15T14:30:00Z"
}
```

### PATCH /tasks/:id/uncomplete
**Description:** Undo task completion

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "id": 1,
  "title": "Review project proposal",
  "completed_at": null,
  "overdue": false,
  "requires_explanation": false,
  "can_complete": true,
  "escalation": null,
  "updated_at": "2025-01-15T14:30:00Z"
}
```

### POST /tasks/:id/reassign
**Description:** Reassign task to different list

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "list_id": 2,
  "reason": "Moving to different project list"
}
```

**Response (200 OK):**
```json
{
  "id": 1,
  "title": "Review project proposal",
  "list_id": 2,
  "updated_at": "2025-01-15T14:30:00Z"
}
```

### POST /tasks/:id/submit_explanation
**Description:** Submit explanation for missed task

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "reason": "Had an emergency meeting that ran over time"
}
```

**Response (200 OK):**
```json
{
  "id": 1,
  "title": "Review project proposal",
  "missed_reason": "Had an emergency meeting that ran over time",
  "missed_reason_submitted_at": "2025-01-15T14:30:00Z",
  "requires_explanation": false,
  "updated_at": "2025-01-15T14:30:00Z"
}
```

---

## 📊 Special Task Endpoints

### GET /tasks/blocking
**Description:** Get tasks currently blocking the app

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "title": "Critical task overdue",
    "escalation": {
      "level": "blocking",
      "notification_count": 5,
      "blocking_app": true,
      "coaches_notified": true,
      "became_overdue_at": "2025-01-15T10:00:00Z",
      "last_notification_at": "2025-01-15T14:00:00Z"
    }
  }
]
```

### GET /tasks/awaiting_explanation
**Description:** Get tasks requiring explanation

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
[
  {
    "id": 2,
    "title": "Missed deadline task",
    "requires_explanation": true,
    "overdue": true,
    "minutes_overdue": 120
  }
]
```

### GET /tasks/overdue
**Description:** Get all overdue tasks

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "title": "Overdue task 1",
    "overdue": true,
    "minutes_overdue": 60,
    "escalation": {
      "level": "warning",
      "notification_count": 2,
      "blocking_app": false
    }
  }
]
```

---

## 👥 Coaching Relationships

### GET /coaching_relationships
**Description:** Get coaching relationships

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "coach": {
      "id": 2,
      "name": "Coach Smith",
      "email": "coach@example.com"
    },
    "client": {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com"
    },
    "status": "active",
    "invited_by": "coach",
    "accepted_at": "2025-01-10T10:00:00Z",
    "notification_preferences": {
      "notify_on_completion": true,
      "notify_on_missed_deadline": true,
      "notify_on_new_task": true
    },
    "shared_lists_count": 2,
    "created_at": "2025-01-10T09:00:00Z"
  }
]
```

### POST /coaching_relationships
**Description:** Create coaching relationship

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "coaching_relationship": {
    "client_email": "client@example.com",
    "invited_by": "coach",
    "notification_preferences": {
      "notify_on_completion": true,
      "notify_on_missed_deadline": true,
      "notify_on_new_task": true
    }
  }
}
```

### PATCH /coaching_relationships/:id/accept
**Description:** Accept coaching invitation

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "id": 1,
  "status": "active",
  "accepted_at": "2025-01-15T10:30:00Z"
}
```

### PATCH /coaching_relationships/:id/decline
**Description:** Decline coaching invitation

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "id": 1,
  "status": "declined"
}
```

---

## 📍 Location Features

### GET /saved_locations
**Description:** Get user's saved locations

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "name": "Home",
    "latitude": 40.7128,
    "longitude": -74.0060,
    "radius_meters": 100,
    "address": "123 Main St, New York, NY",
    "created_at": "2025-01-15T10:30:00Z"
  }
]
```

### POST /saved_locations
**Description:** Create saved location

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "saved_location": {
    "name": "Office",
    "latitude": 40.7589,
    "longitude": -73.9851,
    "radius_meters": 50,
    "address": "456 Business Ave, New York, NY"
  }
}
```

### POST /users/location
**Description:** Update user's current location

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "latitude": 40.7128,
  "longitude": -74.0060,
  "accuracy": 5.0
}
```

**Response (204 No Content)**

### PATCH /users/fcm_token
**Description:** Update FCM token for Android notifications

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "fcm_token": "android_device_token_here"
}
```

**Response (204 No Content)**

---

## 🔄 Recurring Tasks

### GET /recurring_templates
**Description:** Get recurring task templates

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "title": "Daily standup",
    "description": "Team standup meeting",
    "recurrence_pattern": "daily",
    "recurrence_interval": 1,
    "recurrence_time": "09:00",
    "recurrence_days": ["monday", "tuesday", "wednesday", "thursday", "friday"],
    "is_active": true,
    "next_due_date": "2025-01-16T09:00:00Z",
    "instances_count": 5,
    "created_at": "2025-01-10T10:00:00Z"
  }
]
```

### POST /recurring_templates
**Description:** Create recurring task template

**Headers:** `Authorization: Bearer <token>`

**Request Body:**
```json
{
  "recurring_template": {
    "title": "Weekly team meeting",
    "description": "Weekly team sync",
    "recurrence_pattern": "weekly",
    "recurrence_interval": 1,
    "recurrence_time": "14:00",
    "recurrence_days": ["monday"],
    "recurrence_end_date": "2025-12-31T23:59:59Z"
  }
}
```

### POST /recurring_templates/:id/generate_instance
**Description:** Manually generate next instance

**Headers:** `Authorization: Bearer <token>`

**Response (201 Created):**
```json
{
  "id": 15,
  "title": "Weekly team meeting",
  "due_at": "2025-01-20T14:00:00Z",
  "is_recurring": true,
  "recurring_template_id": 1
}
```

---

## 🔔 Notifications

### GET /notifications
**Description:** Get user notifications

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "type": "task_completed",
    "title": "Task Completed",
    "message": "John Doe completed: Review project proposal",
    "read": false,
    "priority": "normal",
    "data": {
      "task_id": 1,
      "client_id": 1,
      "client_name": "John Doe"
    },
    "created_at": "2025-01-15T14:30:00Z"
  }
]
```

### PATCH /notifications/:id/mark_read
**Description:** Mark notification as read

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "id": 1,
  "read": true,
  "read_at": "2025-01-15T14:35:00Z"
}
```

### PATCH /notifications/mark_all_read
**Description:** Mark all notifications as read

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "message": "All notifications marked as read",
  "count": 5
}
```

---

## 📊 Dashboard & Analytics

### GET /dashboard
**Description:** Get dashboard data

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "user": {
    "id": 1,
    "name": "John Doe",
    "role": "client"
  },
  "stats": {
    "total_tasks": 25,
    "completed_tasks": 18,
    "pending_tasks": 5,
    "overdue_tasks": 2,
    "completion_rate": 72.0,
    "streak_days": 5
  },
  "recent_activity": [
    {
      "id": 1,
      "type": "task_completed",
      "title": "Review project proposal",
      "timestamp": "2025-01-15T14:30:00Z"
    }
  ],
  "upcoming_deadlines": [
    {
      "id": 2,
      "title": "Submit report",
      "due_at": "2025-01-16T17:00:00Z",
      "hours_until_due": 26.5
    }
  ]
}
```

### GET /dashboard/stats
**Description:** Get detailed statistics

**Headers:** `Authorization: Bearer <token>`

**Response (200 OK):**
```json
{
  "completion_rates": {
    "today": 80.0,
    "this_week": 75.0,
    "this_month": 70.0
  },
  "task_distribution": {
    "by_priority": {
      "high": 3,
      "medium": 8,
      "low": 4
    },
    "by_status": {
      "completed": 18,
      "pending": 5,
      "overdue": 2
    }
  },
  "coaching_insights": {
    "active_relationships": 2,
    "shared_lists": 3,
    "coach_notifications_sent": 12
  }
}
```

---

## 🚨 Error Responses

### 400 Bad Request
```json
{
  "error": "Invalid request parameters"
}
```

### 401 Unauthorized
```json
{
  "error": "Invalid or missing authentication token"
}
```

### 403 Forbidden
```json
{
  "error": "You do not have permission to perform this action"
}
```

### 404 Not Found
```json
{
  "error": "Resource not found"
}
```

### 422 Unprocessable Entity
```json
{
  "errors": [
    "Title can't be blank",
    "Due date must be in the future"
  ]
}
```

### 429 Too Many Requests
```json
{
  "error": "Rate limit exceeded",
  "retry_after": 60
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal server error"
}
```

---

## 🔄 Real-time Updates (ActionCable)

### WebSocket Connection
```
wss://your-domain.com/cable?token=<jwt_token>
```

### List Channel Subscription
```javascript
// Subscribe to list updates
const subscription = cable.subscriptions.create(
  { channel: "ListChannel", list_id: 1 },
  {
    received: function(data) {
      // Handle real-time updates
      console.log('Task updated:', data);
    }
  }
);
```

### Broadcast Events
```json
{
  "type": "task.created",
  "task": {
    "id": 1,
    "title": "New task",
    "due_at": "2025-01-16T09:00:00Z",
    "status": "pending",
    "updated_at": "2025-01-15T10:30:00Z"
  }
}
```

---

## 📝 Rate Limiting

- **General API**: 100 requests per minute per IP
- **Authentication**: 5 requests per minute per IP
- **Password Reset**: 3 requests per hour per IP

Rate limit headers are included in responses:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200
```

---

## 🛠️ Development & Testing

### Test Endpoints (No Authentication Required)
- `GET /api/v1/test-profile` - Test user profile
- `GET /api/v1/test-lists` - Test lists endpoint
- `DELETE /api/v1/test-logout` - Test logout

### Health Check
- `GET /up` - Application health status

### Sidekiq Web UI (Production Protected)
- `GET /sidekiq` - Background job monitoring (requires authentication in production)

---

## 📱 Mobile App Integration

### iOS APNs Registration
```json
POST /api/v1/devices/register
{
  "apns_token": "ios_device_token",
  "platform": "ios",
  "bundle_id": "com.yourapp.focusmate"
}
```

### Android FCM Registration
```json
PATCH /api/v1/users/fcm_token
{
  "fcm_token": "android_device_token"
}
```

### Push Notification Payloads
```json
{
  "aps": {
    "alert": {
      "title": "Task Reminder",
      "body": "You have an overdue task: Review project proposal"
    },
    "sound": "default",
    "badge": 3,
    "category": "TASK_REMINDER"
  },
  "data": {
    "type": "task_reminder",
    "task_id": 1,
    "list_id": 1,
    "priority": 2
  }
}
```

---

This API provides a comprehensive ADHD management and coaching platform with real-time updates, location awareness, recurring tasks, and accountability features. All endpoints support proper error handling, rate limiting, and authentication.
