# mcomp plc utils

Set of utilities for client Flutter apps communicating with mComp's PLC. This package provides reusable components for configuration fetching, error reporting, push notifications, WebSocket communication, UI components, and more.

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  mcomp_plc_utils: ^1.6.1
```

## Dev

### build runner

Generate JSON serialization code:

```bash
dart run build_runner build --verbose --delete-conflicting-outputs
```

## Features

[Config Fetcher](#config-fetcher) - Fetch PLC configurations from Firebase
[Email Reporting](#email-reporting) - Send error reports via email
[Cloud Messaging Helper](#cloud-messaging-helper) - Handle push notifications
[Web Socket](#web-socket) - Communicate with PLCs via WebSockets
[Resizable Bottom Sheet](#resizable-bottom-sheet) - Display resizable bottom sheets
[Extensions](#extensions) - Utility extensions

---

### Config Fetcher

Fetches list of assigned PLCs that the app can communicate with from Firebase with support for caching, type safety, and repository pattern. The configurations can be returned as type-safe objects or as Maps for backward compatibility.

#### Dependencies

- Logger (needs to be set in the parent app)
- FirebaseAuth (user needs to be logged in the parent app)
- FirebaseStorage (where the config is fetched from)
- Firestore (database of user's configs)
- SharedPreferences (for caching configurations)

#### Features

- Fetches PLC configurations assigned to the current user
- Caches configurations locally for offline access and improved performance
- Provides type-safe access to configurations through the `PlcConfig` interface
- Implements repository pattern for better testability and flexibility
- Supports configurable cache validity duration
- Provides force refresh option to bypass cache
- Handles authentication and permission checks
- Provides error handling and logging

#### Implementation Details

- Uses Repository pattern with `ConfigRepository` interface
- Implements caching through `ConfigCache` interface with SharedPreferences
- Uses Firestore to find PLCs assigned to the user
- Downloads JSON configuration files from Firebase Storage
- Parses JSON into type-safe objects or Maps
- Supports error handling for network and permission issues
- Falls back to cache when network requests fail

#### Performance Improvements with Caching

Caching significantly improves performance by:

- Reducing network requests: Configurations are fetched from the network only when necessary
- Decreasing load times: Cached configurations load instantly without network latency
- Enabling offline access: Users can access configurations even without internet connection
- Reducing Firebase usage costs: Fewer reads from Firestore and Storage

The cache is updated:
- When the cache validity period expires (default: 1 hour)
- When `forceRefresh` is set to true
- When the app is first installed or cache is cleared

#### Example: Basic Usage

```dart
// Initialize with custom cache validity duration (optional)
ConfigFetcher.initialize(
  cacheValidityDuration: Duration(minutes: 30),
);

// Fetch PLC configurations for the current user (uses cache if valid)
final usersPlcsAsMap = await ConfigFetcher.fetchUsersPlcs();

// Convert to custom objects
final listOfPlcObjects = usersPlcsAsMap.map((userPlc) {
    return PlcObject.fromJson(userPlc);
}).toList();

// Force refresh from network, ignoring cache
final freshConfigs = await ConfigFetcher.fetchUsersPlcs(forceRefresh: true);

// Fetch a specific PLC by ID
final plcConfig = await ConfigFetcher.fetchPlc('plc123');

// Clear the cache
await ConfigFetcher.clearCache();
```

#### Example: Using with Custom Repository

```dart
// Create a custom repository implementation
class MockConfigRepository implements ConfigRepository {
  @override
  Future<List<PlcConfig>> fetchConfigs({bool forceRefresh = false}) {
    // Return mock data
    return Future.value([
      DefaultPlcConfig(id: 'mock1', data: {'name': 'Mock PLC 1'}),
      DefaultPlcConfig(id: 'mock2', data: {'name': 'Mock PLC 2'}),
    ]);
  }

  @override
  Future<PlcConfig?> fetchConfig(String id, {bool forceRefresh = false}) {
    // Return mock data for the specific ID
    return Future.value(
      DefaultPlcConfig(id: id, data: {'name': 'Mock PLC $id'}),
    );
  }

  @override
  Future<void> clearCache() => Future.value();
}

// Initialize with custom repository
ConfigFetcher.initialize(
  repository: MockConfigRepository(),
);

// Use ConfigFetcher as normal
final configs = await ConfigFetcher.fetchUsersPlcs();
```

#### Potential Issues

- Requires user to be logged in with Firebase Authentication
- Depends on specific Firestore collection structure (`plcs` collection with `users` array)
- Limited to 1MB file size for configuration files
- Cache might become stale if configurations change frequently

---

### Email Reporting

Composes and sends error reports via email with detailed information about the user, device, application, and error details. This is useful for collecting error reports from users in production environments.

#### Dependencies

- Logger (for logging events)
- battery_plus (for battery information)
- connectivity_plus (for network information)
- device_info_plus (for device details)
- firebase_auth (for user identification)
- package_info_plus (for app version information)
- url_launcher (for launching email client)
- mailto (for composing email)

#### Features

- Collects comprehensive device information
- Includes app version, build number, and flavor
- Captures user ID for identification
- Includes network connectivity status
- Reports battery level
- Formats error and stack trace for debugging
- Configurable app flavor without global variables
- Improved error handling and logging

#### Implementation Details

- Uses various platform plugins to gather system information
- Formats data in a readable format for debugging
- Launches the default email client with pre-filled content
- Handles errors if email client cannot be launched
- Provides initialization method for configuration
- Supports per-report app flavor override

#### Example: Basic Usage

```dart
// Initialize with app flavor (optional, can be done at app startup)
EmailReporting.initialize(appFlavor: 'dev');

// Report an error via email
await EmailReporting.composeAnErrorEmail(
  error: exception,  // The exception object
  stack: stackTrace,  // StackTrace object
  to: ['support@example.com', 'dev@example.com'],  // Recipients
  cc: ['manager@example.com'],  // Optional CC recipients
);
```

#### Example: With Custom Logger and Per-Report Flavor

```dart
// Initialize with custom logger
final logger = Logger('MyErrorReporting');
EmailReporting.initialize(logger: logger);

// Report an error with specific app flavor for this report only
await EmailReporting.composeAnErrorEmail(
  error: exception,
  stack: stackTrace,
  to: ['support@example.com'],
  appFlavor: 'production',  // Override app flavor for this report only
);
```

#### Potential Issues

- Requires an email client installed on the device
- May not work if URL launching is restricted
- Firebase Auth user ID will be 'unknown' if user is not logged in
- Email size limitations may truncate very large stack traces

---

### Cloud Messaging Helper

Helper class for managing Firebase Cloud Messaging (FCM) across different applications. Provides functionality for handling push notifications on both Android and iOS platforms.

#### Dependencies

- Logger (needs to be set in the parent app)
- Firebase Messaging
- Flutter Local Notifications
- Shared Preferences

#### Features

- Initialize FCM with customizable callbacks
- Subscribe/unsubscribe to/from topics
- Handle foreground and background notifications
- Process notification data with Map access
- Handle notification taps with Map access
- Request notification permissions
- Get device FCM token

#### Implementation Details

- Creates notification channels for Android
- Sets up handlers for different app states (foreground, background, terminated)
- Manages notification permissions
- Stores subscribed topics in SharedPreferences
- Prevents duplicate processing of notifications
- Provides callbacks for notification data processing and tap handling

#### Example

```dart
// Initialize the helper with custom handlers
await CloudMessagingHelper.init(
  // Provide topics to subscribe to
  topicProvider: () async {
    final homeIds = await getHomeIds();
    return homeIds.map((id) => 'homeID_$id').toList();
  },

  // Process notification data as Map
  dataProcessor: (data) {
    print('Received notification data: $data');
    // Access payload via data['payload']
    final payload = data['payload'] as String;
    // Store notification or update UI
  },

  // Handle notification taps with data as Map
  tapHandler: (data) {
    // Navigate based on notification data
    final payload = data['payload'] as String;
    if (payload.contains('home')) {
      navigateToHome(payload);
    }
  },
);

// Subscribe to a specific topic
await CloudMessagingHelper.subscribeToTopic('device_123');

// Get list of subscribed topics
final topics = await CloudMessagingHelper.getSubscribedTopics();
print('Currently subscribed to: $topics');

// Unsubscribe from all topics (e.g., at logout)
await CloudMessagingHelper.unsubscribeFromAllTopics();

// Get device FCM token
final token = await CloudMessagingHelper.getToken();
print('Device FCM token: $token');
```

#### Potential Issues

- Android notification icon may not display correctly if not properly configured
- iOS requires explicit user permission for notifications
- Topic names have limitations (no spaces, special characters)
- Payload size is limited to 4KB for FCM messages
- Background message handling requires additional setup in main.dart

---

### Web Socket

Manages WebSocket connections to PLC devices, allowing real-time communication and data exchange with automatic reconnection, heartbeat, and improved error handling.

#### Dependencies

- Logger (needs to be set in the parent app)
- PLC ID and PLC address for communication
- web_socket_channel package

#### Features

- Connect to multiple PLC devices simultaneously
- Send and receive messages in real-time
- Process different PLC data types (Bool, Int, DateTime, etc.)
- Automatic reconnection with exponential backoff
- Heartbeat mechanism to detect dead connections
- Robust error handling and recovery
- Memory-safe resource management
- Configurable connection parameters

#### Implementation Details

- Uses WebSocketChannel for communication
- Maintains a list of active connections with connection state tracking
- Provides methods for connecting, disconnecting, and sending messages
- Implements heartbeat with configurable interval
- Detects disconnections and automatically reconnects
- Uses exponential backoff for reconnection attempts
- Includes business objects for different PLC data types
- Supports JSON serialization for message exchange
- Properly disposes resources to prevent memory leaks

#### Security Considerations

The WebSocket implementation uses WSS (WebSocket Secure) protocol and supports authentication through the 'devs' protocol. For enhanced security in production environments, consider implementing:

- JWT or other token-based authentication
- Message signing or encryption
- IP whitelisting on the server side
- TLS certificate validation

#### Example: Basic Usage

```dart
// Configure global settings (optional)
WebSocketController.heartbeatInterval = 20000; // 20 seconds
WebSocketController.autoReconnect = true;
WebSocketController.maxReconnectAttempts = 5;

// Connect to multiple PLCs
WebSocketController().connectAll([
  (plcId: 'plcId_1', address: 'address_1'),
  (plcId: 'plcId_2', address: 'address_2'),
]);

// Connect to a single PLC
WebSocketController().connect(plcId: 'plcId_1', address: 'address_1');

// Send a message to a PLC
WebSocketController().sendMessage(
  plcId: 'plcId_1',
  message: '{"command": "getStatus"}',
);

// Update a device
WebSocketController().updateDevice(
  plcId: 'plcId_1',
  deviceId: 'device_1',
  update: {'power': true, 'temperature': 22.5},
);

// Request state update for specific devices
WebSocketController().requestStateUpdate(
  plcId: 'plcId_1',
  deviceIds: ['device_1', 'device_2'],
);

// Disconnect from a specific PLC
WebSocketController().disconnect('plcId_1');

// Disconnect from all PLCs
WebSocketController().disconnectAll();

// Dispose of all resources when done
WebSocketController().dispose();
```

#### Example: Processing Messages

```dart
// Create a list of streams for each channel
final streams = WebSocketController().channels.map((channel) async* {
  await for (final data in channel.channel.stream) {
    // Skip processing if the channel is not connected
    if (!channel.isConnected) continue;

    try {
      final messageData = jsonDecode(data.toString()) as Map<String, dynamic>;
      final message = WsMessageBO.fromJson(messageData);

      yield* _processMessageItems(
        message.items ?? [],
        cowsheds,
        channel.plcId,
        logger,
      );
      yield* _processMessageItems(
        message.differences ?? [],
        cowsheds,
        channel.plcId,
        logger,
      );
    } catch (e, stackTrace) {
      logger.severe('Error processing message: $e', e, stackTrace);
      // Continue processing other messages
    }
  }
});

// Merge all streams into a single stream
await for (final value in StreamGroup.merge(streams)) {
  yield value;
}
```

#### Potential Issues

- Limited support for binary messages (JSON only)
- No built-in message compression
- Reconnection might not work in all network scenarios
- Heartbeat might increase data usage slightly

---

### Resizable Bottom Sheet

Shows a Material design bottom sheet that can be resized by the user. This component provides a flexible UI element for displaying additional content without navigating away from the current screen.

#### Features

- Resizable by dragging
- Customizable minimum and maximum heights
- Supports any Flutter widget as content
- Follows Material Design guidelines
- Handles gesture interactions

#### Implementation Details

- Uses DraggableScrollableSheet internally
- Provides smooth animations for resizing
- Handles gesture conflicts with inner scrollable content
- Supports both statically sized and scrollable content

#### Keyboard Avoidance Options

There are several approaches to handling keyboard avoidance with bottom sheets, each with different user experiences:

1. **MediaQuery Approach** (simplest)
   - Uses `MediaQuery.of(context).viewInsets.bottom` to detect keyboard height
   - Adds padding equal to keyboard height
   - **User Experience**: Content shifts upward when keyboard appears
   - **Pros**: Simple to implement, works with most layouts
   - **Cons**: Can feel jarring as content moves suddenly

2. **KeyboardAvoider Package** (recommended)
   - Uses a third-party package like `keyboard_avoider` or `flutter_keyboard_visibility`
   - Automatically adjusts the bottom sheet position
   - **User Experience**: Smooth transition as keyboard appears
   - **Pros**: Better user experience, handles complex cases
   - **Cons**: Adds external dependency

3. **Flexible Bottom Sheet** (advanced)
   - Implements a custom bottom sheet that resizes based on keyboard visibility
   - Uses `AnimatedContainer` for smooth transitions
   - **User Experience**: Bottom sheet resizes smoothly with keyboard
   - **Pros**: Most polished experience, highly customizable
   - **Cons**: Most complex to implement

Implementation example for MediaQuery approach:

```dart
Padding(
  padding: EdgeInsets.only(
    bottom: MediaQuery.of(context).viewInsets.bottom,
  ),
  child: yourBottomSheetContent,
)
```

#### Example: Basic Usage

```dart
// Show a resizable bottom sheet with custom content
return showResizableBottomSheet(
  context: context,
  minHeight: 200,
  maxHeight: 500,
  useBottomPadding: true,
  child: Column(
    children: [
      Text('Resizable Bottom Sheet'),
      Expanded(
        child: ListView.builder(
          itemCount: 20,
          itemBuilder: (context, index) => ListTile(
            title: Text('Item $index'),
          ),
        ),
      ),
    ],
  ),
);
```

#### Example: Advanced Customization

```dart
// Create a custom appearance
final appearance = BottomSheetAppearance(
  backgroundColor: Colors.blueGrey[50],
  elevation: 8.0,
  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  showDragHandle: true,
  barrierColor: Colors.black54,
);

// Show a customized bottom sheet with snap points
showResizableBottomSheet(
  context: context,
  appearance: appearance,
  enableKeyboardAvoidance: true,
  snapPoints: [0.3, 0.5, 0.8], // Snap to 30%, 50%, or 80% of screen height
  onClosed: () => print('Bottom sheet closed'),
  child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      children: [
        Text('Customized Bottom Sheet', style: Theme.of(context).textTheme.headlineSmall),
        TextField(decoration: InputDecoration(labelText: 'Type something...')),
        SizedBox(height: 16),
        ElevatedButton(onPressed: () {}, child: Text('Submit')),
      ],
    ),
  ),
);
```

#### Potential Issues

- May have gesture conflicts with nested scrollable widgets
- Basic keyboard avoidance implemented, but complex forms might need additional handling
- Some advanced Material 3 theming properties might require custom implementation

---

### Extensions

Utility extensions that provide additional functionality to existing classes.

#### URI Extension

Provides a convenient way to launch URLs in the browser.

```dart
// Launches the URL in the default browser
Uri('https://example.com').launchInBrowser();

// With error handling
try {
  await Uri('https://example.com').launchInBrowser();
} catch (e) {
  print('Could not launch URL: $e');
}
```

#### Potential Issues

- Requires the url_launcher package
- May not work if URL launching is restricted by the platform
- No fallback mechanism if the URL cannot be launched
