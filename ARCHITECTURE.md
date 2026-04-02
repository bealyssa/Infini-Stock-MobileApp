# Architecture Guide

Technical architecture and design patterns for the Infini-Stock Flutter mobile app.

## Table of Contents
1. [Project Structure](#project-structure)
2. [Architecture Layers](#architecture-layers)
3. [Design Patterns](#design-patterns)
4. [Data Flow](#data-flow)
5. [State Management](#state-management)
6. [Authentication Flow](#authentication-flow)
7. [Error Handling](#error-handling)
8. [Best Practices](#best-practices)

## Project Structure

```
lib/
├── main.dart                          # App entry point & routing
│
├── theme/
│   └── app_theme.dart                # Material theme definition
│
├── models/
│   └── models.dart                   # Data models with serialization
│
├── services/
│   └── api_client.dart               # HTTP client with interceptors
│
└── screens/
    ├── splash_screen.dart            # Initial auth check
    ├── login_screen.dart             # Authentication UI
    ├── home_screen.dart              # Main app shell with bottom nav
    ├── dashboard_screen.dart         # Overview & stats
    ├── monitors_screen.dart          # Monitor device management
    ├── system_units_screen.dart      # System unit management
    ├── activity_logs_screen.dart     # Transaction history
    └── qr_generator_screen.dart      # QR code tools
```

## Architecture Layers

### 1. Presentation Layer (UI)
**Location:** `lib/screens/`

Responsibilities:
- Display data to users
- Capture user input
- Navigate between screens
- Manage local UI state

Files:
- `splash_screen.dart` - Initial screen with auth routing
- `login_screen.dart` - Authentication form
- `home_screen.dart` - App shell with bottom navigation
- Screen files for each major section

### 2. Business Logic Layer (Services)
**Location:** `lib/services/`

Responsibilities:
- API communication
- Authentication token management
- Error handling
- Request/response transformation

Files:
- `api_client.dart` - Centralized HTTP client

### 3. Data Layer (Models)
**Location:** `lib/models/`

Responsibilities:
- Data model definitions
- JSON serialization/deserialization
- Type safety

Files:
- `models.dart` - All entity models (Monitor, SystemUnit, ActivityLog, User)

### 4. Presentation Configuration (Theme)
**Location:** `lib/theme/`

Responsibilities:
- App-wide styling
- Color palette
- Typography rules
- Component styling

Files:
- `app_theme.dart` - Material theme configuration

## Design Patterns

### 1. Service Locator Pattern (API Client)
```dart
// lib/services/api_client.dart
class ApiClient {
  static const String baseUrl = 'http://localhost:5000/api';
  static late Dio _dio;
  
  static Future<Map<String, dynamic>> login(...) async {
    // Centralized access point
  }
}
```

**Usage:**
- Single responsibility - all API logic in one place
- Easy to mock for testing
- Consistent error handling

**Example:**
```dart
final monitors = await ApiClient.getMonitors();
```

### 2. Repository Pattern (Implicit)
The `ApiClient` acts as a repository, abstracting HTTP details from UI.

### 3. Model-Driven Development
Data models define the contract between backend and frontend:

```dart
class Monitor {
  final String id;
  final String deviceName;
  
  Monitor.fromJson(Map<String, dynamic> json)
    : id = json['_id'],
      deviceName = json['deviceName'];
  
  Map<String, dynamic> toJson() => {
    'deviceName': deviceName,
  };
}
```

### 4. Theme Configuration Pattern
Centralized theme as a class with static properties:

```dart
class AppTheme {
  static const String bgDark = '#171717';
  static const String lavender600 = '#9333EA';
  
  static ThemeData get lightTheme => ThemeData(...);
}
```

### 5. Screen/Widget Hierarchy Pattern

```
MyApp (MaterialApp)
  ├── SplashScreen (Initial auth check)
  └── Routes:
      ├── LoginScreen (FutureBuilder for async login)
      └── HomeScreen (StatefulWidget with tab management)
          ├── DashboardScreen (FutureBuilder + RefreshIndicator)
          ├── MonitorsScreen (Stateful with filters)
          ├── SystemUnitsScreen (Stateful with filters)
          ├── ActivityLogsScreen (Stateful with filters)
          └── QRGeneratorScreen (Text input + display)
```

## Data Flow

### 1. Authentication Flow

```
SplashScreen
    ↓
    ├─→ Check SharedPreferences for auth token
    │   ├─→ Token exists → Navigate to /home
    │   └─→ No token → Navigate to /login
    │
LoginScreen
    ↓
    └─→ User enters credentials
        ↓
        ApiClient.login(email, password)
        ↓
        ├─→ Success: Save token to SharedPreferences
        │   └─→ Navigate to /home
        │
        └─→ Failure: Show error message
```

### 2. Data Fetching Flow (Example: Monitors)

```
MonitorsScreen (Stateful)
    ├─→ initState()
    │   └─→ _monitorsFuture = ApiClient.getMonitors()
    │
    └─→ FutureBuilder<List<Monitor>>
        ├─→ connectionState.waiting: Show loading spinner
        ├─→ hasError: Show error container
        ├─→ hasData: Build list with ExpansionTiles
        │
        └─→ Pull-to-refresh
            └─→ setState(() { _refresh() })
                └─→ Rebuild FutureBuilder with new future
```

### 3. User Interaction Flow (Example: Filter)

```
User taps filter pill
    ↓
FilterChip.onSelected callback
    ↓
setState(() { _selectedFilter = newValue })
    ↓
_filterMonitors() applies filters
    ↓
FutureBuilder rebuilds with filtered list
    ↓
UI updates with filtered items
```

## State Management

### 1. Local Widget State
Used for screen-specific state that doesn't need to persist:

```dart
class MonitorsScreen extends StatefulWidget {
  @override
  State<MonitorsScreen> createState() => _MonitorsScreenState();
}

class _MonitorsScreenState extends State<MonitorsScreen> {
  String _selectedFilter = 'all';  // Local state
  
  void _refresh() {
    setState(() {
      _monitorsFuture = ApiClient.getMonitors();
    });
  }
}
```

### 2. Persistent State (SharedPreferences)
Used for auth tokens and user data:

```dart
// Save
final prefs = await SharedPreferences.getInstance();
await prefs.setString('authToken', token);

// Retrieve
final prefs = await SharedPreferences.getInstance();
final token = prefs.getString('authToken');
```

### 3. Async State (FutureBuilder)
Used for API calls:

```dart
FutureBuilder<List<Monitor>>(
  future: _monitorsFuture,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return LoadingWidget();
    }
    if (snapshot.hasError) {
      return ErrorWidget(error: snapshot.error);
    }
    return DataWidget(data: snapshot.data);
  },
)
```

**Why not Provider?**
- Keep dependencies minimal for this project
- FutureBuilder is sufficient for current complexity
- Easier to understand for new developers
- Easy to migrate to Provider later if needed

## Authentication Flow

### Token Storage
```dart
// After successful login
final prefs = await SharedPreferences.getInstance();
await prefs.setString('authToken', response['token']);

// On app startup
final token = prefs.getString('authToken');
if (token != null) {
  // Route to home
} else {
  // Route to login
}
```

### Token Usage (Auto-injected)
```dart
class ApiClient {
  static Future<void> _setUpInterceptors() async {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('authToken');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }
}
```

### Logout Flow
```dart
// 1. Clear shared preferences
await prefs.remove('authToken');
await prefs.remove('user');

// 2. Navigate to login
Navigator.of(context).pushReplacementNamed('/login');
```

## Error Handling

### API Errors

```dart
try {
  final response = await ApiClient.login(email, password);
  // Success path
} catch (e) {
  // Error path - display to user
  setState(() {
    _errorMessage = 'Login error: ${e.toString()}';
  });
}
```

### Connection Errors

```dart
// In ApiClient
_dio.options.connectTimeout = Duration(seconds: 10);
_dio.options.receiveTimeout = Duration(seconds: 10);

// Interceptor handles connection errors
onError: (DioException error, handler) {
  // Log errors
  return handler.next(error);
}
```

### UI Error Display

```dart
if (_errorMessage != null)
  Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.1),
      border: Border.all(color: Colors.red),
    ),
    child: Text(
      _errorMessage!,
      style: TextStyle(color: Colors.red),
    ),
  )
```

## Best Practices

### 1. Model Serialization
Always use `fromJson()` and `toJson()`:

```dart
class Monitor {
  Monitor.fromJson(Map<String, dynamic> json)
    : id = json['_id'],
      deviceName = json['deviceName'];
  
  Map<String, dynamic> toJson() => {
    'deviceName': deviceName,
  };
}
```

### 2. API Consistency
Centralize all API calls in `ApiClient`:

```dart
// ✓ Good
await ApiClient.getMonitors();

// ✗ Bad
await http.get(Uri.parse('...'));
```

### 3. Error Handling
Always handle both sync and async errors:

```dart
try {
  final data = await ApiClient.loadData();
  setState(() { /* update */ });
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

### 4. Loading States
Show loading indicators during API calls:

```dart
if (snapshot.connectionState == ConnectionState.waiting) {
  return CircularProgressIndicator();
}
```

### 5. Resource Cleanup
Always dispose controllers and subscriptions:

```dart
@override
void dispose() {
  _searchController.dispose();
  super.dispose();
}
```

### 6. Constants
Keep magic strings in constants:

```dart
// ✓ Good
const String baseUrl = 'http://localhost:5000/api';

// ✗ Bad
Uri.parse('http://localhost:5000/api/monitors')
```

### 7. Type Safety
Use strong typing throughout:

```dart
// ✓ Good
List<Monitor> monitors = await ApiClient.getMonitors();

// ✗ Bad (dynamic)
List monitors = await getMonitors();
```

## Security Considerations

### 1. Token Storage
- Tokens stored in SharedPreferences (encrypted by OS)
- Consider KeyStore for sensitive data in future

### 2. HTTPS
- Use HTTPS in production
- Add certificate pinning if needed

### 3. Input Validation
- Validate user input before sending to API
- Don't expose sensitive error messages to users

### 4. API Base URL
- Use environment variables for different environments
- Never hardcode production URLs in debug mode

## Performance Optimization

### 1. Lazy Loading
Lists use `shrinkWrap: true` and efficient builders

### 2. Image Caching
QR codes are generated on-demand (lightweight in this app)

### 3. State Efficiency
- Use `const` for widgets where possible
- Avoid rebuilding expensive widgets

### 4. Network Optimization
- Timeouts prevent hanging requests
- Dio handles request cancellation

## Testing Strategy

### Unit Tests
```dart
// lib/services/api_client.dart
// Mock ApiClient for testing
class MockApiClient implements ApiClient {
  @override
  Future<List<Monitor>> getMonitors() async {
    return [/* mock data */];
  }
}
```

### Widget Tests
```dart
testWidgets('Dashboard loads stats', (WidgetTester tester) async {
  await tester.pumpWidget(const DashboardScreen());
  expect(find.text('Total Assets'), findsOneWidget);
});
```

### Integration Tests
```dart
void main() {
  testWidgets('Login flow', (WidgetTester tester) async {
    // Full app flow test
  });
}
```

## Extending the Architecture

### Adding a New Screen
1. Create file: `lib/screens/new_screen.dart`
2. Add route in `main.dart`
3. Add navigation to `home_screen.dart` if needed
4. Add API methods in `ApiClient` if needed

### Adding a New Model
1. Add to `lib/models/models.dart`
2. Implement `fromJson()` and `toJson()`
3. Add API methods to `ApiClient`

### Adding a New API Endpoint
1. Add method to `ApiClient`
2. Create model if needed
3. Use in screens with FutureBuilder

## Future Improvements

- [ ] Migrate to Provider for state management
- [ ] Add local database (Hive/Isar) for offline-first
- [ ] Implement Repository pattern explicitly
- [ ] Add comprehensive unit tests
- [ ] Add E2E integration tests
- [ ] Implement push notifications
- [ ] Add analytics tracking
- [ ] Implement biometric authentication

---

This architecture provides a solid foundation that's easy to understand, maintain, and extend.
