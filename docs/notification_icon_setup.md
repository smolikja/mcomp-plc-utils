# Notification Icon Setup

This document describes how to properly set up an icon for notifications in an Android project.

## Android

For proper display of the icon in Android notifications, you need to:

1. Create an icon in the correct format
2. Place it in the appropriate folder in the Android project
3. Reference it in the code

### Creating the Icon

The icon for Android notifications should be:

- Transparent PNG
- White color only (for Android 5.0+)
- Recommended size: 24dp x 24dp (96x96 px for xxhdpi)

You can use the [Android Asset Studio](https://romannurik.github.io/AndroidAssetStudio/icons-notification.html) tool to create the icon.

### Placing the Icon

The icon needs to be placed in the `android/app/src/main/res/drawable` folder in your Flutter project. If the folder doesn't exist, create it.

#### Option 1: Vector Icon (recommended)

For modern Android devices, it's best to use a vector icon in XML format. An example of such an icon is included in the package in the file `example/android/app/src/main/res/drawable/ic_stat_name.xml`.

Simply copy this file to the `android/app/src/main/res/drawable` folder in your Flutter project.

#### Option 2: Raster Icon

If you prefer a raster icon, name the file `ic_stat_name.png` and create different sizes for different pixel densities:

- `drawable-mdpi/ic_stat_name.png` (24x24 px)
- `drawable-hdpi/ic_stat_name.png` (36x36 px)
- `drawable-xhdpi/ic_stat_name.png` (48x48 px)
- `drawable-xxhdpi/ic_stat_name.png` (72x72 px)
- `drawable-xxxhdpi/ic_stat_name.png` (96x96 px)

### Using the Icon in Code

In the `android/app/src/main/AndroidManifest.xml` file, add the following line to the `<application>` section:

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:label="Example App">
        
        <!-- Default icon for notifications -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_stat_name" />
            
        <!-- Other configuration -->
        
    </application>
</manifest>

```

This sets the default icon for all notifications from Firebase Cloud Messaging.

## iOS

On iOS, there is no need to set a special icon for notifications, as iOS uses the application icon.

## Usage in Code

In the `lib/src/cloud_messaging/cloud_messaging_helper.dart` file, the use of the icon is already set up:

```dart
AndroidNotificationDetails(
  _channel.id,
  _channel.name,
  channelDescription: _channel.description,
  icon: android?.icon ?? 'ic_stat_name',
),
```

If you want to use a custom icon, change `'ic_stat_name'` to the name of your icon.
