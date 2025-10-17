# Focusmate API Setup

This Rails API application has been configured with the following essential gems:

## Authentication & Authorization
- **Devise + JWT**: User authentication with JSON Web Tokens
- **Pundit**: Authorization policies for fine-grained access control

## Background Processing
- **Sidekiq**: Background job processing
- **Redis**: Caching and Sidekiq backend

## Security & Rate Limiting
- **Rack::Attack**: Rate limiting and security middleware

## Feature Flags
- **Flipper**: Feature flag management with ActiveRecord adapter

## Setup Instructions

### 1. Install Dependencies
```bash
bundle install
```

### 2. Setup Database
```bash
rails db:create
rails db:migrate
```

### 3. Start Redis (Required for Sidekiq and Rack::Attack)
```bash
redis-server
```

### 4. Start Sidekiq (in a separate terminal)
```bash
bundle exec sidekiq
```

### 5. Start Rails Server
```bash
rails server
```

## API Endpoints

### Authentication
- `POST /api/v1/login` - User login
- `POST /api/v1/register` - User registration
- `GET /api/v1/profile` - Get user profile (requires authentication)
- `DELETE /api/v1/logout` - User logout (requires authentication)

### Example Resource
- `GET /api/v1/examples` - List examples (requires authentication)
- `POST /api/v1/examples` - Create example (requires authentication)
- `GET /api/v1/examples/:id` - Show example (requires authentication)
- `PATCH/PUT /api/v1/examples/:id` - Update example (requires authentication)
- `DELETE /api/v1/examples/:id` - Delete example (requires authentication)

## Configuration

### JWT Secret
You'll need to set up a JWT secret in your Rails credentials:
```bash
rails credentials:edit
```

Add:
```yaml
devise_jwt_secret_key: your-secret-key-here
```

### Environment Variables
- `REDIS_URL`: Redis connection URL (default: `redis://localhost:6379/0`)

## Features Demonstrated

1. **JWT Authentication**: Secure token-based authentication
2. **Authorization**: Pundit policies control access to resources
3. **Background Jobs**: Sidekiq processes jobs asynchronously
4. **Rate Limiting**: Rack::Attack protects against abuse
5. **Feature Flags**: Flipper enables/disables features dynamically

## Example Usage

### Register a new user:
```bash
curl -X POST http://localhost:3000/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{"user": {"email": "test@example.com", "password": "password123", "password_confirmation": "password123"}}'
```

### Login:
```bash
curl -X POST http://localhost:3000/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "password123"}'
```

### Create an example (with JWT token):
```bash
curl -X POST http://localhost:3000/api/v1/examples \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"example": {"name": "Test Example", "description": "This is a test example"}}'
```
