import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../models/todo.dart';
import '../main.dart';
import '../screens/alarm_screen.dart';

class NotificationService with WidgetsBindingObserver {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName.identifier));
      debugPrint('Local timezone set to: ${timeZoneName.identifier}');
    } catch (e) {
      debugPrint('Failed to set local timezone: $e. Fallback to UTC.');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const WindowsInitializationSettings windowsSettings =
        WindowsInitializationSettings(
          appName: 'Todo',
          appUserModelId: 'com.company.todo',
          guid: '12345678-1234-1234-1234-123456789012',
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: androidSettings,
          windows: windowsSettings,
        );

    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await _notifications.getNotificationAppLaunchDetails();

    // Initialize plugins
    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          debugPrint('Notification clicked with payload: ${details.payload}');
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => AlarmScreen(payload: details.payload!),
            ),
          );
        }
      },
    );

    // FIX: Cancel the test alarm ID to prevent crashes from missing resources
    // if it was scheduled in a previous run with a bad configuration.
    try {
      await _notifications.cancel(999999);
      debugPrint('Cleaned up potential test alarm (ID: 999999)');
    } catch (e) {
      debugPrint('Error canceling test alarm cleanup: $e');
    }

    // Handle case where app was launched by the notification (e.g. full screen intent)
    if (notificationAppLaunchDetails != null &&
        notificationAppLaunchDetails.didNotificationLaunchApp &&
        notificationAppLaunchDetails.notificationResponse?.payload != null) {
      final payload =
          notificationAppLaunchDetails.notificationResponse!.payload!;
      debugPrint('App launched with payload: $payload');
      // Delay slightly to ensure navigator is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => AlarmScreen(payload: payload)),
        );
      });
    }

    await requestPermissions();
  }

  Future<void> requestPermissions() async {
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImpl != null) {
      final bool? notificationsGranted = await androidImpl
          .requestNotificationsPermission();
      debugPrint('Notifications Permission Granted: $notificationsGranted');

      // Request exact alarms permission (might open settings)
      await androidImpl.requestExactAlarmsPermission();

      final bool? canScheduleExact = await androidImpl
          .canScheduleExactNotifications();
      debugPrint('Can Schedule Exact Alarms: $canScheduleExact');
    }
  }

  /// -------------------------------
  /// SCHEDULE ALARM
  /// -------------------------------
  Future<void> scheduleAlarm(Todo todo) async {
    // Check if notifications are enabled
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final bool? granted = await androidImpl?.areNotificationsEnabled();
    debugPrint('[NotificationService] Notifications enabled: $granted');
    if (granted == false) {
      debugPrint(
        'WARNING: Notifications are explicitly disabled for this app.',
      );
    }

    DateTime? scheduledDateTime;

    if (todo.isRoutine) {
      if (todo.scheduledTimeMinutes == null) {
        debugPrint(
          '[NotificationService] Skipping - routine with no time: ${todo.title}',
        );
        return;
      }

      final now = DateTime.now();
      scheduledDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        todo.scheduledTimeMinutes! ~/ 60,
        todo.scheduledTimeMinutes! % 60,
      );

      // If time has passed today, schedule for tomorrow
      if (scheduledDateTime.isBefore(now)) {
        debugPrint(
          '[NotificationService] Time passed today, scheduling for tomorrow: ${todo.title}',
        );
        scheduledDateTime = scheduledDateTime.add(const Duration(days: 1));
      }
    } else {
      if (todo.dueDate == null) {
        debugPrint(
          '[NotificationService] Skipping - task with no due date: ${todo.title}',
        );
        return;
      }
      scheduledDateTime = todo.dueDate!;
    }

    if (scheduledDateTime.isBefore(DateTime.now())) {
      debugPrint(
        '[NotificationService] Skipping alarm for ${todo.title} - time is in the past: $scheduledDateTime vs NOW ${DateTime.now()}',
      );
      return;
    }

    // Verify exact alarm permission again right before scheduling
    final bool? canScheduleExact = await androidImpl
        ?.canScheduleExactNotifications();
    debugPrint(
      '[NotificationService] Can schedule exact alarms: $canScheduleExact',
    );
    debugPrint('[NotificationService] Current Timezone: ${tz.local.name}');

    final int notificationId = todo.id;

    // Use a fresh channel ID to ensure settings (sound, vibration) are applied
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'todo_channel_v7', // NEW CHANNEL ID
          'Todo Reminders',
          channelDescription: 'Important reminders for your tasks',
          importance: Importance.max,
          priority: Priority.max, // MAX PRIORITY
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          visibility: NotificationVisibility.public,
          ticker: 'Task Reminder',
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'complete',
              'Mark Complete',
              showsUserInterface: true, // Make sure it wakes up UI if needed
            ),
          ],
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    final targetTZDate = tz.TZDateTime.from(scheduledDateTime, tz.local);

    debugPrint(
      'Scheduling alarm for $notificationId at $targetTZDate (${todo.title})',
    );

    try {
      debugPrint(
        '[NotificationService] Attempting to schedule for $targetTZDate',
      );
      await _notifications.zonedSchedule(
        notificationId,
        todo.title,
        todo.description ?? 'Time to complete your task!',
        targetTZDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        matchDateTimeComponents: todo.isRoutine
            ? DateTimeComponents.time
            : null,
        payload: '${todo.id}|${todo.title}',
      );
      debugPrint(
        '[NotificationService] SUCCESS: Alarm scheduled for ${todo.title} at $targetTZDate',
      );
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] ERROR scheduling alarm: $e');
      debugPrint('[NotificationService] Stack trace: $stackTrace');
    }
  }

  Future<void> scheduleTestAlarm() async {
    final now = DateTime.now().add(const Duration(seconds: 15));
    final targetTZDate = tz.TZDateTime.from(now, tz.local);

    debugPrint('Scheduling TEST alarm for $targetTZDate');

    const AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'todo_channel_v7_test', // CHANGED: New channel ID to update settings
      'Todo Reminders',
      channelDescription: 'Important reminders for your tasks',
      importance: Importance.max,
      priority: Priority.high, // UPDATED
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      visibility: NotificationVisibility.public,
      ticker: 'Test Alarm',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'complete_action',
          'Complete',
          titleColor: const Color.fromARGB(255, 255, 0, 0),
          // icon: DrawableResourceAndroidBitmap('secondary_icon'), // REMOVED: Caused crash (resource missing)
        ),
      ],
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      debugPrint('--- DEBUG NOTIFICATION ---');
      debugPrint('Current Time (DateTime.now): ${DateTime.now()}');
      debugPrint('Current Time (TZ): ${tz.TZDateTime.now(tz.local)}');
      debugPrint('Target Time (TZ): $targetTZDate');
      debugPrint('Timezone: ${tz.local.name}');

      // Check permissions again
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl != null) {
        final canExact = await androidImpl.canScheduleExactNotifications();
        debugPrint('Can Schedule Exact Alarms: $canExact');
        final settings = await androidImpl.getNotificationAppLaunchDetails();
        debugPrint(
          'Did notification launch app: ${settings?.didNotificationLaunchApp}',
        );
      }

      await _notifications.zonedSchedule(
        999999, // Test ID
        'Test Alarm',
        'This is a test alarm to verify functionality.',
        targetTZDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: '999999|Test Alarm',
      );
      debugPrint('Test alarm scheduled successfully via zonedSchedule');
      debugPrint('--------------------------');
    } catch (e, stack) {
      debugPrint('Error scheduling TEST alarm: $e');
      debugPrint('Stack: $stack');
    }
  }

  /// -------------------------------
  /// CANCEL ALARM
  /// -------------------------------
  Future<void> cancelAlarm(int id) async {
    await _notifications.cancel(id);
    debugPrint('Canceled alarm for ID: $id');
  }

  /// -------------------------------
  /// TEST NOTIFICATION (DEBUG)
  /// -------------------------------
  Future<void> showInstantNotification({
    String title = 'Test Notification',
    String body = 'If you see this, notifications are working!',
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'todo_channel_v7', // Use existing channel for consistency
          'Todo Reminders', // Channel name
          importance: Importance.max,
          priority: Priority.max,
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );
    await _notifications.show(
      99999, // ID
      title,
      body,
      details,
    );
  }

  /// -------------------------------
  /// LIFECYCLE HANDLER
  /// -------------------------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationLaunch();
    }
  }

  Future<void> _checkNotificationLaunch() async {
    final details = await _notifications.getNotificationAppLaunchDetails();
    if (details != null &&
        details.didNotificationLaunchApp &&
        details.notificationResponse?.payload != null) {
      final payload = details.notificationResponse!.payload!;
      debugPrint('App resumed with notification payload: $payload');

      // Verify if the notification is still active
      final int? id = int.tryParse(payload.split('|')[0]);
      if (id != null) {
        final List<ActiveNotification> activeNotifications =
            await _notifications.getActiveNotifications();
        final bool isActive = activeNotifications.any((n) => n.id == id);

        if (isActive) {
          debugPrint(
            'Notification $id is still active. Navigating to AlarmScreen.',
          );
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => AlarmScreen(payload: payload)),
          );
        } else {
          debugPrint('Notification $id is NOT active. Ignoring stale intent.');
        }
      }
    }
  }
}
