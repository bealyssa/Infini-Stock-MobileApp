# Infini-Stock Mobile App (Flutter)

A cross-platform mobile application for Infini-Stock QR-based inventory management system, built with Flutter and matching the web UI/UX design.

## Features

### ✨ Core Functionality
- **Authentication** - Secure login with session management
- **Dashboard** - Real-time inventory statistics and recent activity
- **Monitors Management** - View, search, and filter monitoring devices
- **System Units** - Manage system units with location tracking
- **QR Code Tools** - Generate and manage QR codes for assets
- **Activity Logs** - Complete transaction history with filters
- **Offline Support** - Cached data with SharedPreferences

### 🎨 Design
- **Dark Lavender Theme** - Matches web application perfectly
- **Material 3 Design** - Modern Material Design principles
- **Responsive UI** - Optimized for all device sizes
- **Bottom Navigation** - Easy navigation between major sections

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── theme/
│   └── app_theme.dart       # Theme colors and styling
├── models/
│   └── models.dart          # Data models (Monitor, SystemUnit, etc.)
├── services/
│   └── api_client.dart      # HTTP client with auth interceptor
└── screens/
    ├── splash_screen.dart   # Splash & auth routing
    ├── login_screen.dart    # Login form
    ├── home_screen.dart     # Main app with bottom nav
    ├── dashboard_screen.dart # Statistics & recent activity
    ├── monitors_screen.dart # Monitor device list
    ├── system_units_screen.dart # System unit list
    ├── activity_logs_screen.dart # Transaction history
    └── qr_generator_screen.dart # QR code generator
```

## Getting Started

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio / Xcode (for emulator/device testing)

### Installation

1. **Install dependencies**
   ```bash
   flutter pub get
   ```

2. **Run the app**
   ```bash
   # Development
   flutter run

   # Release mode
   flutter run --release
   ```

3. **Build for specific platform**
   ```bash
   # Android
   flutter build apk --release
   flutter build appbundle --release

   # iOS
   flutter build ios --release
   ```

## Screens

### 1. Splash Screen
- Initial loading screen
- Authenticates user from cached token
- Routes to Login or Home based on auth status

### 2. Login Screen
- Email and password input fields
- Dark lavender themed form
- Demo credentials (for testing)
- Error message display
- Loading state indication

### 3. Dashboard
- **Stats Cards** - Total, Active, In Repair, Inactive asset counts
- **Recent Activity** - Last 10 transactions with action icons
- Pull-to-refresh functionality
- Quick navigation to detailed views

### 4. Monitors Screen
- **List View** - All connected monitors with status
- **Search** - Filter by device name or QR code
- **Filter Pills** - All, Active, Maintenance, Inactive status
- **Expandable Cards** - Tap to view full details
- **QR Display** - Generate QR code for each monitor

### 5. System Units Screen
- **List View** - All system units with location
- **Search** - Filter by name, QR code, or location
- **Filter Pills** - Status-based filtering
- **Detail Grid** - QR code, location, status, creator
- **Linked Monitors** - Shows associated monitor device

### 6. Activity Logs Screen
- **Complete History** - All system transactions
- **Search** - Filter by QR code or asset ID
- **Action Filters** - Create, Update, Delete, Move operations
- **Detail Cards** - Shows before/after states for changes
- **User Info** - Who performed each action

### 7. QR Generator Screen
- **Text Input** - Any data (IDs, URLs, etc.)
- **Generate Button** - Creates QR code
- **QR Display** - Large displayable code
- **Share** - Share QR code with others
- **Tips Section** - Best practices for QR usage

## Theme System

### Color Palette (Dark Lavender)
```dart
Primary Background:     #171717
Dark Lavender (Header): #1A0F2E
Dark Container:         #0F0A1A
Primary Accent:         #9333EA (Lavender-600)
Accent Hover:           #7E22CE (Lavender-700)
Light Accent:           #A78BFA (Lavender-500)
Border Color:           #3D2E5C (Lavender-tinted)
Dark Border:            #2D1F4A (Table headers)
```

### Customizing Theme
Edit `lib/theme/app_theme.dart` to modify:
- Colors
- Typography
- Button styles
- Input decoration
- AppBar styling

## API Integration

### API Client Features
- **Base URL** - Configurable in `api_client.dart`
- **Authentication** - Auto-injects Bearer token from SharedPreferences
- **Interceptors** - Handles auth headers automatically
- **Error Handling** - Timeout and connection error management
- **CRUD Operations** - Full support for all entity types

### Available Endpoints
- **Auth** - Login, Logout
- **Monitors** - List, Create, Update, Delete
- **Units** - List, Create, Update, Delete
- **Logs** - List with pagination
- **Dashboard** - Stats endpoint
- **Users** - List, Create, Delete, Toggle status

## Data Models

### Monitor
```dart
- id: String
- deviceName: String
- qrCode: String
- status: String (active, maintenance, inactive)
- linkedUnit: String?
- description: String?
- createdBy: String
- createdAt: String
- updatedAt: String
```

### SystemUnit
```dart
- id: String
- deviceName: String
- qrCode: String
- status: String
- location: String
- linkedMonitor: String?
- description: String?
- createdBy: String
- createdAt: String
- updatedAt: String
```

### ActivityLog
```dart
- id: String
- action: String (create, update, delete, move)
- assetId: String
- assetQrCode: String
- oldLocation: String?
- newLocation: String?
- oldStatus: String?
- newStatus: String?
- userId: String?
- timestamp: String
```

## State Management

State is managed through:
- **Provider** - For complex state interactions
- **SharedPreferences** - For local persistence (auth tokens, user data)
- **FutureBuilder** - For async API calls
- **StatefulWidget** - For local screen state

## Dependencies

```yaml
# HTTP & API
http: ^1.1.0              # HTTP requests
dio: ^5.3.0               # Advanced HTTP client

# State Management
provider: ^6.1.0          # State management

# UI & Design
google_fonts: ^6.1.0      # Google Fonts support
flutter_svg: ^2.0.0       # SVG rendering

# QR Codes
qr_flutter: ^4.1.0        # QR code generation
mobile_scanner: ^3.5.0    # QR code scanning

# Local Storage
shared_preferences: ^2.2.0 # LocalStorage

# Share
share_plus: ^7.2.0        # Share functionality

# Utilities
intl: ^0.19.0             # Internationalization
logger: ^2.0.0            # Logging
```

## Demo Credentials

For testing purposes, use:
```
Email: admin@infini.local
Password: Password@123
```

## Troubleshooting

### Build Issues
- Clean build: `flutter clean && flutter pub get`
- Update dependencies: `flutter pub upgrade`
- Rebuild: `flutter run --no-fast-start`

### Connection Issues
- Verify backend is running on the configured URL
- Check API base URL in `lib/services/api_client.dart`
- Ensure firewall allows the connection

### Auth Issues
- Clear app cache: Device Settings > Apps > Infini-Stock > Storage > Clear Data
- Manually clear SharedPreferences in app
- Perform fresh login

## Platform Support

- **Android** - 5.0+ (API 21+)
- **iOS** - 11.0+
- **Web** - Not currently supported

## Development Tips

### Hot Reload
```bash
flutter run
# Press 'r' for hot reload
# Press 'R' for hot restart
```

### Debug Mode
```bash
flutter run -v  # Verbose output
flutter run --profile  # Profile mode for performance testing
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/api_client_test.dart
```

## Future Enhancements

- [ ] QR Code Scanner integration
- [ ] Offline-first architecture
- [ ] Push notifications
- [ ] Advanced analytics
- [ ] Multi-language support
- [ ] Biometric authentication
- [ ] User profile customization
- [ ] Export/Import functionality

## Performance Optimization

- Lazy loading for long lists
- Image caching for QR codes
- Debounced search functionality
- SharedPreferences for offline data
- Efficient state management

## License

Same license as main Infini-Stock project

## Support

For issues, feature requests, or questions:
- Create an issue in the project repository
- Contact development team
- Check documentation in main README.md

---

Built with ❤️ using Flutter and Dart
