# Infini-Stock Mobile App

A Flutter mobile application for IoT-based inventory tracking and asset management, seamlessly integrated with the Infini-Stock backend.

## 🎯 Features

### Core Functionality
- ✅ **Authentication**: Token-based login with persistent storage
- ✅ **Dashboard**: Real-time overview with stats and recent activity
- ✅ **Monitor Management**: View, create, and update monitoring devices
- ✅ **Unit Management**: Manage system units with location tracking
- ✅ **Activity Logs**: Complete audit trail of all asset movements
- ✅ **Dark Lavender Theme**: Matches web app design (accent: #9333ea)

### Integration
- ✅ **Backend Connectivity**: Configurable API URL for local network
- ✅ **State Management**: Provider pattern for reactive UI updates
- ✅ **Local Storage**: SharedPreferences for token persistence
- ✅ **HTTP Client**: Dio with interceptors for secure API calls

### Coming Soon
- 🚀 QR code scanning with mobile_scanner
- 🚀 QR code generation with visual export
- 🚀 Asset swap/move operations
- 🚀 Maintenance status management
- 🚀 Offline mode with caching
- 🚀 Real-time notifications via WebSocket

## 📲 Getting Started

### Prerequisites
- Flutter 3.0.0+ installed
- Connected device or emulator (Android 8.0+ or iOS 12.0+)
- Backend server running on local IP

### Installation

1. **Navigate to mobile app directory**
   ```bash
   cd mobile-app
   ```

2. **Get dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure backend IP**
   - Edit `lib/services/api_client.dart` line 13
   - Or configure in app login screen

4. **Run the app**
   ```bash
   flutter run
   ```

## 🎨 Design System

### Theme Colors
| Color | Hex | Usage |
|-------|-----|-------|
| Primary Background | #171717 | Main app background |
| Sidebar Background | #1a0f2e | Navigation areas |
| Primary Accent | #9333ea | Buttons, highlights |
| Border | #3d2e5c | Cards, dividers |
| Header Background | #2d1f4a | Table headers |
| Success | #10b981 | Active status |
| Warning | #f59e0b | Maintenance status |
| Error | #ef4444 | Broken/error status |

### Screens
1. **Login Screen**
   - Email/password input
   - Configurable backend URL
   - Connection settings help

2. **Home/Dashboard**
   - 4 tab navigation (Dashboard, Monitors, Units, Logs)
   - Stats cards (total counts, active status)
   - Recent activity timeline

3. **Monitors Tab**
   - List of all monitoring devices
   - Status indicators (active/maintenance/broken)
   - QR code viewing and edit actions

4. **Units Tab**
   - List of all system units
   - Location display
   - Status management

5. **Activity Logs Tab**
   - Complete history of asset movements
   - Action descriptions
   - Timestamp tracking

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point & routing
├── theme/
│   └── app_theme.dart                 # Dark Lavender theme definition
├── models/
│   ├── monitor_model.dart             # Monitor data structure
│   ├── unit_model.dart                # Unit data structure
│   ├── activity_log_model.dart        # Activity log data
│   └── user_model.dart                # User profile data
├── services/
│   └── api_client.dart                # Dio HTTP client with local IP support
├── providers/
│   ├── auth_provider.dart             # Authentication & token management
│   ├── monitor_provider.dart          # Monitor data fetching & management
│   ├── unit_provider.dart             # Unit data fetching & management
│   └── activity_log_provider.dart     # Activity log management
└── screens/
    ├── login_screen.dart              # Login & connection configuration
    └── home_screen.dart               # Main app with tab navigation

pubspec.yaml                           # Dependencies & configuration
SETUP_GUIDE.md                         # Detailed setup instructions
README.md                              # This file
```

## 🔐 Authentication

### Login Flow
1. User enters email and password on login screen
2. App sends credentials to backend API
3. Backend returns JWT token
4. Token is stored in SharedPreferences
5. Token is automatically included in all API requests
6. On logout, token is cleared and user returns to login

### Persistent Storage
- Tokens stored in SharedPreferences on login
- Automatically loaded on app restart
- Cleared on logout

### API Endpoints
- `POST /api/auth/login` - Authenticate user

## 🌐 Backend Integration

### API Base URL Configuration

**Default (update in code):**
```dart
// lib/services/api_client.dart line 13
_baseUrl = 'http://192.168.x.x:5000/api';
```

**At Runtime (via Login screen):**
- Expand "Connection Settings" on login screen
- Enter your PC's IP address
- Example: `http://192.168.1.100:5000/api`

### Available Endpoints

**Authentication**
- POST `/api/auth/login` - Login

**Monitors**
- GET `/api/monitors` - List all monitors
- POST `/api/monitors` - Create new monitor
- PATCH `/api/monitors/:id` - Update monitor
- DELETE `/api/monitors/:id` - Delete monitor

**Units**
- GET `/api/units` - List all units
- POST `/api/units` - Create new unit
- PATCH `/api/units/:id` - Update unit
- DELETE `/api/units/:id` - Delete unit

**Activity Logs**
- GET `/api/logs` - List activity logs with pagination
- POST `/api/logs` - Create activity log entry

**QR Codes**
- POST `/api/qr/generate` - Generate QR code
- POST `/api/qr/scan` - Process scanned QR code

**Admin**
- GET `/api/admin/users` - List users (admin only)
- POST `/api/admin/users` - Create user (admin only)
- DELETE `/api/admin/users/:id` - Delete user (admin only)

## 🔄 State Management

The app uses **Provider** pattern for state management:

### Providers
- **AuthProvider**: Manages login state, tokens, user profile
- **MonitorProvider**: Manages monitor list and operations
- **UnitProvider**: Manages unit list and operations
- **ActivityLogProvider**: Manages activity log display

### Usage Example
```dart
// Reading data
final monitors = context.read<MonitorProvider>().monitors;

// Listening to changes
Consumer<MonitorProvider>(
  builder: (context, provider, _) {
    return ListView.builder(
      itemCount: provider.monitors.length,
      itemBuilder: (context, index) {
        return MonitorTile(monitor: provider.monitors[index]);
      },
    );
  },
);

// Triggering actions
await context.read<MonitorProvider>().fetchMonitors();
```

## 📱 Device Network Setup

### For Physical Device Testing

1. **Connect phone to WiFi**
   - Phone must be on same network as PC

2. **Find your PC IP address**
   - Windows: `ipconfig` → Look for IPv4 Address (192.168.x.x)
   - Mac: `ifconfig` → Look for inet address
   - Linux: `hostname -I`

3. **Configure in app**
   - Login screen → Expand "Connection Settings"
   - Enter: `http://YOUR_IP:5000/api`
   - Example: `http://192.168.1.100:5000/api`

4. **Start backend server**
   ```bash
   cd backend
   npm start
   ```

### For Emulator Testing
- Android Emulator can reach localhost via `10.0.2.2`
- Use: `http://10.0.2.2:5000/api`
- Or configure your PC IP for consistency

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| Connection refused | Check backend is running, verify PC IP, check firewall |
| "Invalid token" | Re-login, check token expiration, verify API URL |
| Provider not found | Check MultiProvider wrapper in main.dart |
| Camera permission denied | Grant permissions in app settings |
| QR scanner not working | Some devices need runtime permission requests |
| HTTP errors | Check API responses in debug console (`flutter run -v`) |

## 🚀 Development Workflow

### Running with Logs
```bash
flutter run -v
```

### Hot Reload
- Press `r` in terminal to reload
- Press `R` for full restart

### Building for Production

**Android:**
```bash
flutter build apk --release
```

**iOS:**
```bash
flutter build ios --release
```

## 📊 Data Models

### Monitor
```dart
class Monitor {
  String id;
  String deviceName;
  String qrCode;
  String status;        // 'active', 'maintenance', 'broken'
  String? linkedUnit;
  DateTime? createdAt;
  DateTime? updatedAt;
}
```

### Unit
```dart
class Unit {
  String id;
  String deviceName;
  String qrCode;
  String status;        // 'active', 'maintenance', 'broken'
  String? location;
  String? linkedMonitor;
  DateTime? createdAt;
  DateTime? updatedAt;
}
```

### ActivityLog
```dart
class ActivityLog {
  String id;
  String assetId;
  String action;        // 'move', 'swap', 'repair', 'update'
  String? oldLocation;
  String? newLocation;
  String? oldStatus;
  String? newStatus;
  DateTime timestamp;
}
```

## 🎯 Next Development Steps

1. **QR Scanning**
   - Import mobile_scanner package
   - Create QR scanner screen
   - Parse QR codes for asset identification

2. **QR Display**
   - Use qr_flutter to generate QR codes
   - Create QR display dialog
   - Add share functionality

3. **Asset Operations**
   - Implement swap/move dialogs
   - Update status in one tap
   - Real-time updates

4. **Offline Support**
   - Local caching with sqflite
   - Sync when back online
   - Conflict resolution

5. **Advanced Features**
   - WebSocket for real-time updates
   - Voice commands integration
   - Barcode scanning support

## 📝 Code Style Guidelines

- Follow Flutter best practices
- Use Provider pattern for state
- Keep widgets small and focused
- Add error handling for all API calls
- Use consistent naming conventions

## 🔗 Related Documentation

- [Backend Setup](../backend/README.md)
- [Web App Documentation](../frontend/AUTH_DOCUMENTATION.md)
- [RBAC Guide](../backend/RBAC_GUIDE.md)
- [Setup Guide](./SETUP_GUIDE.md)

## 📄 Version

- **App Version**: 1.0.0
- **Flutter Version**: 3.0.0+
- **Dart Version**: 3.0.0+
- **Theme**: Dark Lavender (#171717, #1a0f2e, #9333ea)

## 👨‍💻 Development

Built with ❤️ for Infini-Stock inventory management system.

Sync status: ✅ Matches web app Dark Lavender theme and backend API structure
