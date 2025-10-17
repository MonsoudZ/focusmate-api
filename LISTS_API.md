# Lists & Memberships API Documentation

## Overview

This API provides functionality for creating and managing lists with user memberships. Users can create lists, invite other users, and control access through different roles.

## Authentication

All endpoints require JWT authentication. Include the JWT token in the Authorization header:
```
Authorization: Bearer <your_jwt_token>
```

## Models

### List
- **Owner**: The user who created the list (has full control)
- **Members**: Users invited to the list with specific roles
- **Roles**: `owner`, `editor`, `viewer`

### Membership
- **List**: Associated list
- **User**: Member user
- **Role**: `editor` (can edit and invite) or `viewer` (read-only)

## Endpoints

### Lists

#### GET /api/v1/lists
Get all lists accessible to the current user.

**Response:**
```json
{
  "lists": [
    {
      "id": 1,
      "name": "My Shopping List",
      "description": "Weekly grocery shopping items",
      "owner": {
        "id": 1,
        "email": "user@example.com"
      },
      "role": "owner",
      "members_count": 2,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

#### POST /api/v1/lists
Create a new list.

**Request Body:**
```json
{
  "list": {
    "name": "My Shopping List",
    "description": "Weekly grocery shopping items"
  }
}
```

**Response:** (201 Created)
```json
{
  "list": {
    "id": 1,
    "name": "My Shopping List",
    "description": "Weekly grocery shopping items",
    "owner": {
      "id": 1,
      "email": "user@example.com"
    },
    "role": "owner",
    "members_count": 0,
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

#### GET /api/v1/lists/:id
Get a specific list with its members.

**Response:**
```json
{
  "list": {
    "id": 1,
    "name": "My Shopping List",
    "description": "Weekly grocery shopping items",
    "owner": {
      "id": 1,
      "email": "user@example.com"
    },
    "role": "owner",
    "members": [
      {
        "id": 1,
        "user": {
          "id": 2,
          "email": "member@example.com"
        },
        "role": "editor",
        "created_at": "2024-01-01T00:00:00Z"
      }
    ],
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

#### PATCH/PUT /api/v1/lists/:id
Update a list (requires editor or owner role).

**Request Body:**
```json
{
  "list": {
    "name": "Updated List Name",
    "description": "Updated description"
  }
}
```

#### DELETE /api/v1/lists/:id
Delete a list (requires owner role).

**Response:** 204 No Content

### Memberships

#### GET /api/v1/lists/:list_id/memberships
Get all memberships for a list.

**Response:**
```json
{
  "memberships": [
    {
      "id": 1,
      "user": {
        "id": 2,
        "email": "member@example.com"
      },
      "role": "editor",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

#### POST /api/v1/lists/:list_id/memberships
Invite a user to the list.

**Request Body:**
```json
{
  "membership": {
    "user_identifier": "user@example.com",
    "role": "editor"
  }
}
```

**Parameters:**
- `user_identifier`: User email or ID
- `role`: `editor` or `viewer` (default: `viewer`)

**Response:** (201 Created)
```json
{
  "membership": {
    "id": 1,
    "user": {
      "id": 2,
      "email": "member@example.com"
    },
    "role": "editor",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

#### PATCH/PUT /api/v1/lists/:list_id/memberships/:id
Update a membership role.

**Request Body:**
```json
{
  "membership": {
    "role": "viewer"
  }
}
```

#### DELETE /api/v1/lists/:list_id/memberships/:id
Remove a user from the list.

**Response:** 204 No Content

## Authorization Rules

### List Access
- **Owner**: Full control (create, read, update, delete, invite)
- **Editor**: Can read, update, and invite members
- **Viewer**: Can only read

### Membership Management
- **Owner/Editor**: Can invite, update, and remove members
- **Self**: Can remove own membership

## Error Responses

### 401 Unauthorized
```json
{
  "error": "You need to sign in or sign up before continuing."
}
```

### 403 Forbidden
```json
{
  "error": "You are not authorized to perform this action."
}
```

### 404 Not Found
```json
{
  "error": "List not found"
}
```

### 422 Unprocessable Entity
```json
{
  "errors": ["Name can't be blank", "User is already a member of this list"]
}
```

## Example Usage

### 1. Create a List
```bash
curl -X POST http://localhost:3001/api/v1/lists \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt_token>" \
  -d '{
    "list": {
      "name": "My Shopping List",
      "description": "Weekly grocery shopping items"
    }
  }'
```

### 2. Invite a User
```bash
curl -X POST http://localhost:3001/api/v1/lists/1/memberships \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt_token>" \
  -d '{
    "membership": {
      "user_identifier": "friend@example.com",
      "role": "editor"
    }
  }'
```

### 3. Get List with Members
```bash
curl -X GET http://localhost:3001/api/v1/lists/1 \
  -H "Authorization: Bearer <jwt_token>"
```

## Testing

Run the test script to verify all functionality:
```bash
./test_api.sh
```

This will test:
- User registration and authentication
- List creation and management
- User invitation and membership management
- Authorization enforcement
