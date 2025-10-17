FCM_CLIENT = FCM.new(ENV['FCM_SERVER_KEY'])

# You'll get this from Firebase Console:
# 1. Go to Firebase Console (https://console.firebase.google.com)
# 2. Select your project
# 3. Go to Project Settings > Cloud Messaging
# 4. Copy the Server Key
# 5. Add to your .env file: FCM_SERVER_KEY=your_key_here
