# iOS App Integration Guide

## Authentication Flow

Your iOS app needs to handle the following flow after successful login:

### 1. Login Response Structure
When the user successfully logs in, the API returns:

```json
{
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "user": {
    "id": 4,
    "email": "test3@test3.com"
  }
}
```

### 2. iOS App Should Do After Login:

1. **Extract the JWT token** from the response
2. **Store the token securely** (Keychain recommended)
3. **Store user data** (id, email) for the session
4. **Navigate to the main app screen** (lists view)
5. **Make authenticated API calls** using the token

### 3. API Endpoints for Main App:

#### Get User's Lists
```http
GET /api/v1/lists
Authorization: Bearer <JWT_TOKEN>
```

Response:
```json
{
  "lists": [
    {
      "id": 1,
      "name": "My Tasks",
      "description": "Personal task list",
      "owner": {
        "id": 4,
        "email": "test3@test3.com"
      },
      "role": "owner",
      "members_count": 0,
      "created_at": "2025-10-14T21:12:03.693Z",
      "updated_at": "2025-10-14T21:12:03.693Z"
    }
  ]
}
```

#### Create New List
```http
POST /api/v1/lists
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json

{
  "list": {
    "name": "New List",
    "description": "List description"
  }
}
```

#### Get Tasks in a List
```http
GET /api/v1/lists/{list_id}/tasks
Authorization: Bearer <JWT_TOKEN>
```

### 4. Logout Flow:

When user clicks "Sign Out":

1. **Call logout endpoint**:
```http
DELETE /api/v1/auth/sign_out
Authorization: Bearer <JWT_TOKEN>
```

2. **Handle logout response**:
```json
{
  "message": "Logout successful"
}
```

3. **iOS app should**:
   - Clear stored JWT token
   - Clear user data
   - Navigate back to login screen
   - Reset app state

### 5. Error Handling:

If any API call returns 401 Unauthorized:
- Clear stored token
- Navigate to login screen
- Show "Please log in again" message

### 6. Complete iOS Implementation Example:

```swift
// After successful login
func handleLoginResponse(_ response: LoginResponse) {
    // Store token securely
    KeychainHelper.storeToken(response.token)
    
    // Store user data
    UserDefaults.standard.set(response.user.id, forKey: "user_id")
    UserDefaults.standard.set(response.user.email, forKey: "user_email")
    
    // Navigate to main app
    DispatchQueue.main.async {
        // Navigate to lists view controller
        self.navigateToMainApp()
    }
}

// Make authenticated API calls
func fetchUserLists() {
    guard let token = KeychainHelper.getToken() else {
        // Redirect to login
        navigateToLogin()
        return
    }
    
    // Make API call with token
    let request = URLRequest(url: URL(string: "\(baseURL)/api/v1/lists")!)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    // Handle response...
}

// Handle logout
func logout() {
    // Call logout endpoint
    callLogoutAPI { [weak self] in
        // Clear stored data
        KeychainHelper.clearToken()
        UserDefaults.standard.removeObject(forKey: "user_id")
        UserDefaults.standard.removeObject(forKey: "user_email")
        
        // Navigate to login
        DispatchQueue.main.async {
            self?.navigateToLogin()
        }
    }
}
```

## Key Points:

1. **Always include the JWT token** in API requests after login
2. **Handle 401 errors** by redirecting to login
3. **Store tokens securely** (Keychain, not UserDefaults)
4. **Navigate to main app** after successful login
5. **Clear all data** on logout

The Rails API is working correctly - the issue is in the iOS app's navigation logic after receiving the login response.
