# Infini-Stock Mobile App Setup Guide

## 📋 Prerequisites

- **Flutter SDK**: 3.0.0 or higher
- **Dart**: Latest version
- **Device/Emulator**: Android 8.0+ or iOS 12.0+
- **Backend Server**: Running on local IP (http://192.168.x.x:5000)

## 🚀 Quick Start

### 1. Get Your PC IP Address

**Windows:**
```cmd
ipconfig
```
Look for "IPv4 Address" (usually starts with 192.168.x.x)

**Mac/Linux:**
```bash
ifconfig
```

### 2. Configure Backend Connection

Update the API URL in `lib/services/api_client.dart`:
```dart
_baseUrl = 'http://YOUR_IP:5000/api';
```

Or use the app's Login screen to configure it dynamically.

### 3. Run the App

```bash
# Get dependencies
flutter pub get

# Run on emulator/device
flutter run

# Run with verbose output for debugging
flutter run -v
```

## 🏗️ Project Structure

```
lib/
├── main.dart                 # App entry point
├── theme/
│   └── app_theme.dart        # Dark Lavender theme (matching web)
├── models/
│   ├── monitor_model.dart    # Monitor data model
│   ├── unit_model.dart       # Unit data model
│   ├── activity_log_model.dart # Activity log model
│   └── user_model.dart       # User data model
├── services/
│   └── api_client.dart       # Dio HTTP client with local IP support
├── providers/
│   ├── auth_provider.dart    # Authentication state management
│   ├── monitor_provider.dart # Monitors data management
│   ├── unit_provider.dart    # Units data management
│   └── activity_log_provider.dart # Activity logs management
└── screens/
    ├── login_screen.dart     # Login & connection setup
    └── home_screen.dart      # Main app with 4 tabs
```

## 🎨 Design System

### Colors (Dark Lavender Theme)
- **Primary Background**: #171717
- **Sidebar Background**: #1a0f2e
- **Primary Accent**: #9333ea (Lavender)
- **Border Color**: #3d2e5c
- **Header Background**: #2d1f4a

### Screens
1. **Dashboard** - Overview with stats and recent activity
2. **Monitors** - List and manage monitoring devices
3. **Units** - List and manage system units
4. **Activity Logs** - Complete activity history

## 🔐 Authentication Flow

1. Login with email/password
2. Configure backend IP (or use default)
3. App stores JWT token locally
4. Token automatically included in API requests
5. Logout clears token and returns to login

## 📱 Features

### ✅ Implemented
- Dark Lavender theme matching web app
- Login/Authentication with token management
- Dashboard with stats and recent activity
- Monitor list view with status badges
- Unit list view with status badges
- Activity logs with filtering
- Dynamic backend IP configuration
- Persistent token storage

### 🚧 Next Steps
- QR code scanning functionality
- QR code generation/display
- Asset swap/move operations
- Maintenance status updates
- Search and filtering
- Offline mode with local caching
- Real-time updates via WebSocket

## 📡 Backend API Endpoints

The app connects to these endpoints:

```
POST   /api/auth/login              # Login
GET    /api/monitors                # List monitors
POST   /api/monitors                # Create monitor
PATCH  /api/monitors/:id            # Update monitor
DELETE /api/monitors/:id            # Delete monitor

GET    /api/units                   # List units
POST   /api/units                   # Create unit
PATCH  /api/units/:id               # Update unit
DELETE /api/units/:id               # Delete unit

GET    /api/logs                    # List activity logs
POST   /api/logs                    # Create activity log

POST   /api/qr/generate             # Generate QR code
POST   /api/qr/scan                 # Scan QR code

GET    /api/admin/users             # List users
POST   /api/admin/users             # Create user
DELETE /api/admin/users/:id         # Delete user
```

## 🖥️ Development Tips

### Debugging
```bash
# Enable debug logging
flutter run -v

# Inspect widget tree
flutter devtools
```

### Hot Reload
- Press `r` in terminal after code changes
- Press `R` for full restart

### Testing API Connection
1. Open Login screen
2. Expand "Connection Settings"
3. Enter your PC IP: `http://192.168.x.x:5000/api`
4. Try login with test credentials

### Emulator vs Physical Device
- **Emulator**: Use `http://localhost:5000/api` (if backend on same PC)
- **Physical Device**: Use `http://192.168.x.x:5000/api` (WiFi network)

## 📦 Dependencies Overview

- **flutter_provider**: State management
- **dio**: HTTP client with interceptors
- **qr_flutter**: QR code generation
- **mobile_scanner**: QR code scanning
- **shared_preferences**: Local token storage
- **sqflite**: Local database (future use)
- **google_fonts**: Typography

## 🐛 Troubleshooting

### Connection Refused
- Check backend is running: `npm start` (backend directory)
- Verify PC IP is correct (not 127.0.0.1)
- Ensure phone is on same WiFi network
- Firewall may block port 5000 - check Windows Defender settings

### "Provider not found" Error
- Ensure all providers are wrapped in MultiProvider at main.dart
- Check imports are correct for all providers

### QR Scanner Not Working
- Grant camera permissions in app settings
- Some Android 6-7 devices need runtime permissions

### Token Expiration
- App will clear token and return to login
- Login again to get new token

## 📚 Code Example: Adding New Data

### Creating a Monitor
```dart
final success = await context.read<MonitorProvider>()
    .createMonitor('Device XYZ', 'QR123456', 'active');

if (success) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Monitor created!')),
  );
}
```

### Fetching Activity Logs
```dart
await context.read<ActivityLogProvider>().fetchActivityLogs();
final logs = context.read<ActivityLogProvider>().logs;
```

## 🔄 State Management Pattern

Using Provider for reactive updates:

```dart
Consumer<MonitorProvider>(
  builder: (context, monitorProvider, _) {
    return ListView.builder(
      itemCount: monitorProvider.monitors.length,
      itemBuilder: (context, index) {
        return MonitorTile(
          monitor: monitorProvider.monitors[index],
        );
      },
    );
  },
)
```

## 📝 Git Workflow

```bash
# Create feature branch
git checkout -b feature/qr-scanning

# Make changes and test
flutter test

# Commit and push
git add .
git commit -m "feat: add QR scanning"
git push origin feature/qr-scanning
```

## 🚢 Deployment

### Android Build
```bash
flutter build apk --release
# Output: build/app/outputs/apk/release/app-release.apk
```

### iOS Build
```bash
flutter build ios --release
```

## 📞 Support

- Check error logs: `flutter run -v`
- Review API responses in Dio interceptor logs
- Verify backend connectivity with Postman

---

**Version**: 1.0.0  
**Last Updated**: 2024  
**Theme**: Dark Lavender (matching web app #171717, #1a0f2e, #9333ea)
