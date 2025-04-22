import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Callback type for processing notification data
typedef NotificationDataProcessor = void Function(Map<String, dynamic> data);

/// Callback type for handling notification tap
typedef NotificationTapHandler = void Function(Map<String, dynamic> data);

/// Helper class for managing Firebase Cloud Messaging across different applications
class CloudMessagingHelper {
  // MARK: - Constants
  static const String _kSubedTopicsKey = 'CloudMessagingSubscribedTopicsKey';
  static const String _kHasUserBeenAskedKey =
      'HasUserBeenAskedFCMPermissionKey';
  static const int _kMaxProcessedMessageIds = 100;

  // MARK: - Static fields
  static final _logger = Logger('CloudMessagingHelper');
  static final _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );
  static final Set<String> _processedMessageIds = {};

  // MARK: - Callback handlers
  static NotificationDataProcessor? _notificationDataProcessor;
  static NotificationTapHandler? _notificationTapHandler;

  /// Initialize FCM, setup notifications, request permissions
  ///
  /// [topicProvider] - Optional callback that returns a list of topics to subscribe to
  /// [dataProcessor] - Optional callback to process notification data as Map
  /// [tapHandler] - Optional callback to handle notification taps with data as Map
  static Future<void> init({
    Future<List<String>> Function()? topicProvider,
    NotificationDataProcessor? dataProcessor,
    NotificationTapHandler? tapHandler,
  }) async {
    _logger.fine('Initializing cloud messaging helper');

    // Set callback handlers
    _notificationDataProcessor = dataProcessor;
    _notificationTapHandler = tapHandler;

    await _setupNotificationChannels();
    await _setupMessageHandlers();
    await _requestNotificationPermissions();

    // Subscribe to topics if provider is available
    if (topicProvider != null) {
      final topics = await topicProvider();
      await subscribeToTopics(topics);
    }
  }

  /// Subscribe to a list of topics
  ///
  /// This method will:
  /// 1. Unsubscribe from any previously subscribed topics that are not in the new list
  /// 2. Subscribe to any new topics that weren't previously subscribed
  /// 3. Store the new list of subscribed topics in SharedPreferences
  ///
  /// [topics] - List of topic strings to subscribe to
  static Future<void> subscribeToTopics(List<String> topics) async {
    final prefs = await SharedPreferences.getInstance();
    final currentTopics = prefs.getStringList(_kSubedTopicsKey) ?? [];

    if (_areTopicListsEqual(currentTopics, topics)) {
      _logger.fine('Topics already synchronized, no changes needed');
      return;
    }

    final toUnsubscribe =
        currentTopics.where((topic) => !topics.contains(topic)).toList();

    final toSubscribe =
        topics.where((topic) => !currentTopics.contains(topic)).toList();

    try {
      // Unsubscribe from old topics
      if (toUnsubscribe.isNotEmpty) {
        await Future.wait(
          toUnsubscribe.map(_unsubscribeFromTopic),
          eagerError: true,
        );
        _logger.fine('Unsubscribed from topics: $toUnsubscribe');
      }

      // Subscribe to new topics
      if (toSubscribe.isNotEmpty) {
        await Future.wait(
          toSubscribe.map(_subscribeToTopic),
          eagerError: true,
        );
        _logger.fine('Subscribed to topics: $toSubscribe');
      }

      // Save the new list of topics
      await prefs.setStringList(_kSubedTopicsKey, topics);
      _logger.info('Successfully synchronized topic subscriptions');
    } catch (e) {
      _logger.shout('Error synchronizing topic subscriptions: $e');
      rethrow;
    }
  }

  /// Get the list of currently subscribed topics
  static Future<List<String>> getSubscribedTopics() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kSubedTopicsKey) ?? [];
  }

  /// Unsubscribe from all topics
  static Future<void> unsubscribeFromAllTopics() async {
    final prefs = await SharedPreferences.getInstance();
    final subedTopics = prefs.getStringList(_kSubedTopicsKey);
    if (subedTopics == null || subedTopics.isEmpty) return;

    try {
      await Future.wait(
        subedTopics.map(_unsubscribeFromTopic),
        eagerError: true,
      );
      await prefs.setStringList(_kSubedTopicsKey, []);
      _logger.info('Successfully unsubscribed from all topics');
    } catch (e) {
      _logger.shout('Error unsubscribing from topics: $e');
      rethrow;
    }
  }

  /// Subscribe to a single topic
  static Future<void> subscribeToTopic(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final currentTopics = prefs.getStringList(_kSubedTopicsKey) ?? [];

    if (currentTopics.contains(topic)) {
      _logger.fine('Already subscribed to topic: $topic');
      return;
    }

    try {
      await _subscribeToTopic(topic);

      currentTopics.add(topic);
      await prefs.setStringList(_kSubedTopicsKey, currentTopics);
      _logger.fine('Successfully subscribed to topic: $topic');
    } catch (e) {
      _logger.shout('Error subscribing to topic: $topic with error: $e');
      rethrow;
    }
  }

  /// Unsubscribe from a single topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final currentTopics = prefs.getStringList(_kSubedTopicsKey) ?? [];

    if (!currentTopics.contains(topic)) {
      _logger.fine('Not subscribed to topic: $topic');
      return;
    }

    try {
      await _unsubscribeFromTopic(topic);

      currentTopics.remove(topic);
      await prefs.setStringList(_kSubedTopicsKey, currentTopics);
      _logger.fine('Successfully unsubscribed from topic: $topic');
    } catch (e) {
      _logger.shout('Error unsubscribing from topic: $topic with error: $e');
      rethrow;
    }
  }

  /// Get the FCM token for this device
  static Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      _logger.shout('Error getting FCM token: $e');
      return null;
    }
  }

  // MARK: - Private methods

  // Notification setup
  static Future<void> _setupNotificationChannels() async {
    if (Platform.isAndroid) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_name'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );
  }

  // Message handlers setup
  static Future<void> _setupMessageHandlers() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Just show notifications when in foreground, don't process
    FirebaseMessaging.onMessage.listen(_showLocalNotificationOnForeground);

    // Process when user taps notification from background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _processMessageData(message.data, messageId: message.messageId);
    });

    // Process if app was opened by tapping notification from terminated state
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _processMessageData(
        initialMessage.data,
        messageId: initialMessage.messageId,
      );
    }
  }

  // Core message handler
  static void _showLocalNotificationOnForeground(RemoteMessage message) {
    _logger.fine('Show onForeground notif: ${message.messageId}');

    if (message.notification != null) {
      _showLocalNotification(
        message.notification!,
        null,
        message.messageId ?? '|${message.data}',
      );
    }
  }

  static void _showLocalNotification(
    RemoteNotification notification,
    AndroidNotificationDetails? android,
    String payload,
  ) {
    if (Platform.isAndroid) {
      _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: 'ic_stat_name',
          ),
        ),
        payload: payload,
      );
    }
  }

  static void _onDidReceiveNotificationResponse(NotificationResponse response) {
    _logger.info('User tapped on notification: ${response.payload}');

    // Extract messageId if available
    String? messageId;
    var payload = response.payload ?? '';

    if (payload.contains('|')) {
      final parts = payload.split('|');
      messageId = parts[0];
      payload = parts.sublist(1).join('|');
    }

    // Now process the data
    final data = {'payload': payload};
    _processMessageData(data, messageId: messageId);

    // Call the tap handlers if available
    if (_notificationTapHandler != null) {
      _notificationTapHandler!(data);
    }
  }

  static void _processMessageData(
    Map<String, dynamic> data, {
    String? messageId,
  }) {
    if (messageId != null && _processedMessageIds.contains(messageId)) {
      _logger.info('Skipping already processed message: $messageId');
      return;
    }

    _logger.info('Processing message data: $data');

    // Call the data processor if available
    if (_notificationDataProcessor != null) {
      _notificationDataProcessor!(data);
    }

    if (messageId != null) {
      _processedMessageIds.add(messageId);
      if (_processedMessageIds.length > _kMaxProcessedMessageIds) {
        _processedMessageIds.remove(_processedMessageIds.first);
      }
    }
  }

  // MARK: - Permissions
  static Future<void> _requestNotificationPermissions() async {
    final messaging = FirebaseMessaging.instance;
    var settings = await messaging.getNotificationSettings();
    final prefs = await SharedPreferences.getInstance();
    final hasUserBeenAsked = prefs.getBool(_kHasUserBeenAskedKey) ?? false;

    if (settings.authorizationStatus == AuthorizationStatus.notDetermined ||
        !hasUserBeenAsked) {
      settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );
      await prefs.setBool(_kHasUserBeenAskedKey, true);
      _logger.info('New authorization status: ${settings.authorizationStatus}');
    }
  }

  // MARK: - Topic subscription helpers
  static Future<void> _subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      _logger.fine('Subscribed to topic: $topic');
    } catch (e) {
      _logger.shout('Error subscribing to topic: $topic with error: $e');
      rethrow;
    }
  }

  static Future<void> _unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      _logger.fine('Unsubscribed from topic: $topic');
    } catch (e) {
      _logger.shout('Error unsubscribing from topic: $topic with error: $e');
      rethrow;
    }
  }

  // MARK: - Utility methods
  static bool _areTopicListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;

    final set1 = Set<String>.from(list1);
    final set2 = Set<String>.from(list2);

    return set1.difference(set2).isEmpty;
  }
}
