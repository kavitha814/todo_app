import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../models/todo.dart';
import '../main.dart';
import '../screens/alarm_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName.identifier));
      debugPrint('Local timezone set to: ${timeZoneName.identifier}');
    } catch (e) {
      debugPrint(
        'Failed to set local timezone (${timeZoneName.identifier}): $e',
      );
      // Fallback to UTC if local timezone is not found
      tz.setLocalLocation(tz.getLocation('UTC'));
      debugPrint('Local timezone fallback to: UTC');
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

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => AlarmScreen(payload: details.payload!),
            ),
          );
        }
      },
    );

    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();
    }
  }

  /// -------------------------------
  /// SCHEDULE ALARM
  /// -------------------------------
  Future<void> scheduleAlarm(Todo todo) async {
    DateTime? scheduledDateTime;

    if (todo.isRoutine) {
      if (todo.scheduledTimeMinutes == null) return;

      final now = DateTime.now();
      scheduledDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        todo.scheduledTimeMinutes! ~/ 60,
        todo.scheduledTimeMinutes! % 60,
      );

      if (scheduledDateTime.isBefore(now)) {
        scheduledDateTime = scheduledDateTime.add(const Duration(days: 1));
      }
    } else {
      if (todo.dueDate == null) return;
      scheduledDateTime = todo.dueDate!;
    }

    if (scheduledDateTime.isBefore(DateTime.now())) return;

    final int notificationId = todo.id;

    const AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'todo_channel_v3', // Fresh channel
      'Todo Reminders',
      channelDescription: 'Important reminders for your tasks',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      // sound: RawResourceAndroidNotificationSound('notification_sound'), // If you had one
      playSound: true,
      enableVibration: true,
      enableLights: true,
      visibility: NotificationVisibility.public,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    // Use a small buffer to ensure we don't schedule in the very immediate past
    final targetTZDate = tz.TZDateTime.from(scheduledDateTime, tz.local);
    if (targetTZDate.isBefore(
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
    )) {
      debugPrint(
        'Warning: Target time is too close or in the past. Scheduling with 10s buffer.',
      );
      // Optionally skip or add a small buffer if it's a test
    }
    await _notifications.zonedSchedule(
      notificationId,
      todo.title,
      todo.description ?? 'Time to complete your task!',
      targetTZDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: todo.isRoutine ? DateTimeComponents.time : null,
      payload: '${todo.id}|${todo.title}',
    );

    debugPrint(
      'Alarm scheduled for: $targetTZDate (Target location: ${tz.local.name})',
    );
    debugPrint('Current System Time: ${DateTime.now()}');
  }

  /// -------------------------------
  /// CANCEL ALARM
  /// -------------------------------
  Future<void> cancelAlarm(int id) async {
    await _notifications.cancel(id);
  }
}
