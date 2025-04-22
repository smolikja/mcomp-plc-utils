import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:mailto/mailto.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Class for reporting errors via email
class EmailReporting {
  /// Initialize the EmailReporting with optional configuration
  ///
  /// [appFlavor] - The build flavor/scheme of the app (e.g., 'dev', 'prod')
  /// [logger] - Optional logger for logging events
  static void initialize({
    String? appFlavor,
    Logger? logger,
  }) {
    _appFlavor = appFlavor;
    _logger = logger ?? Logger('EmailReporting');
  }

  // Static configuration
  static String? _appFlavor;
  static Logger _logger = Logger('EmailReporting');

  /// Date and time of reporting
  static String get _dateTime => DateTime.now().toIso8601String();

  /// App ID
  static Future<String> get _appID async =>
      (await PackageInfo.fromPlatform()).packageName;

  /// App version
  static Future<String> get _appVersion async =>
      (await PackageInfo.fromPlatform()).version;

  /// App build number
  static Future<String> get _appBuild async =>
      (await PackageInfo.fromPlatform()).buildNumber;

  /// App build scheme
  static String get _appBuildScheme => _appFlavor ?? 'unknown';

  /// User ID
  static String get _userID =>
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

  /// Platform
  static Future<String> get _platform async => defaultTargetPlatform.toString();

  /// Device
  static Future<String> get _device async {
    final deviceInfo = DeviceInfoPlugin();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final manufacturer = (await deviceInfo.androidInfo).manufacturer;
        final model = (await deviceInfo.androidInfo).model;
        return '$manufacturer $model';
      case TargetPlatform.iOS:
        final name = (await deviceInfo.iosInfo).name;
        final model = (await deviceInfo.iosInfo).model;
        return '$name $model';
      default:
        return 'unknown';
    }
  }

  /// Device OS
  static Future<String> get _deviceOS async {
    final deviceInfo = DeviceInfoPlugin();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final release = (await deviceInfo.androidInfo).version.release;
        final sdkInt = (await deviceInfo.androidInfo).version.sdkInt;
        return 'Android $release (SDK $sdkInt)';
      case TargetPlatform.iOS:
        final systemName = (await deviceInfo.iosInfo).systemName;
        final version = (await deviceInfo.iosInfo).systemVersion;
        return '$systemName $version';
      default:
        return 'unknown';
    }
  }

  /// All device info
  static Future<String> get _deviceInfo async =>
      (await DeviceInfoPlugin().deviceInfo).toString();

  /// Connectivity
  static Future<String> get _connectivity async =>
      (await Connectivity().checkConnectivity()).toString();

  /// Battery
  static Future<String> get _battery async =>
      (await Battery().batteryLevel).toString();

  /// Compose the email body with all relevant information
  static Future<String> _composeBody(Object error, StackTrace stack) async {
    return '''
      date time: $_dateTime

      app ID: ${await _appID}
      app version: ${await _appVersion}
      app build: ${await _appBuild}
      app build scheme: $_appBuildScheme

      user ID: $_userID
      platform: ${await _platform}
      device: ${await _device}
      device OS: ${await _deviceOS}
      all device info: ${await _deviceInfo}

      connectivity: ${await _connectivity}
      battery: ${await _battery}

      error: $error

      stack trace: $stack
      ''';
  }

  /// Launch a URL
  static Future<void> _launchUrl(Uri url) async {
    try {
      if (!await launchUrl(url)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      _logger.severe('Error launching URL: $url', e);
      rethrow;
    }
  }

  /// Compose and send an error report via email
  ///
  /// [error] - The error object to report
  /// [stack] - The stack trace associated with the error
  /// [to] - List of recipient email addresses
  /// [cc] - Optional list of CC email addresses
  /// [appFlavor] - Optional app flavor to use for this specific report
  static Future<void> composeAnErrorEmail({
    required Object error,
    required StackTrace stack,
    required List<String> to,
    List<String>? cc,
    String? appFlavor,
  }) async {
    // Use provided appFlavor for this report if specified
    final previousFlavor = _appFlavor;
    if (appFlavor != null) {
      _appFlavor = appFlavor;
    }

    try {
      final mailtoLink = Mailto(
        to: to,
        cc: cc,
        subject: 'Application error reporting',
        body: await _composeBody(error, stack),
      );

      await _launchUrl(Uri.parse(mailtoLink.toString()));
      _logger.info('Error email composed and launched');
    } catch (e, st) {
      _logger.severe('Failed to compose error email', e, st);
      rethrow;
    } finally {
      // Restore previous flavor
      if (appFlavor != null) {
        _appFlavor = previousFlavor;
      }
    }
  }
}
