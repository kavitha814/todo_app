import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';

class AlarmScreen extends StatefulWidget {
  final String payload; // Expecting "taskId|title|description" or just title

  const AlarmScreen({super.key, required this.payload});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  late String _timeString;
  late String _amPmString;
  late Timer _timer;
  String _taskTitle = 'Alarm';
  int? _notificationId;

  @override
  void initState() {
    super.initState();
    _parsePayload();
    _updateTime();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer t) => _updateTime(),
    );
  }

  void _parsePayload() {
    if (widget.payload.contains('|')) {
      final parts = widget.payload.split('|');
      // parts[0] is ID, parts[1] is Title
      if (parts.isNotEmpty) {
        _notificationId = int.tryParse(parts[0]);
      }
      if (parts.length > 1) {
        _taskTitle = parts
            .sublist(1)
            .join('|'); // Join back in case title has |
      } else {
        _taskTitle = widget.payload;
      }
    } else {
      _taskTitle = widget.payload;
    }
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    final String formattedTime = DateFormat('h:mm').format(now);
    final String formattedAmPm = DateFormat('a').format(now);
    if (mounted) {
      setState(() {
        _timeString = formattedTime;
        _amPmString = formattedAmPm;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _handleDismiss() {
    if (_notificationId != null) {
      NotificationService().cancelAlarm(_notificationId!);
    }
    Navigator.of(context).pop();
  }

  void _handleSnooze() {
    if (_notificationId != null) {
      NotificationService().cancelAlarm(_notificationId!);
    }
    // Logic to reschedule notification would go here
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            // Time Display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _timeString,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 80,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -2,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _amPmString,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Task Label
            Text(
              _taskTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(flex: 4),
            // Action Buttons
            Padding(
              padding: const EdgeInsets.only(bottom: 60.0, left: 40, right: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Snoop/Sleep Icon (Left)
                  IconButton(
                    iconSize: 32,
                    onPressed: _handleSnooze,
                    icon: Icon(
                      Icons
                          .mode_night_outlined, // Zzz lookalike or use Icons.snooze
                      color: Colors.grey[400],
                      size: 30,
                    ),
                  ),

                  // Stop Button (Center - White Circle)
                  GestureDetector(
                    onTap: _handleDismiss,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white24,
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.query_builder, // Little alarm clock icon inside
                          color: Colors.black,
                          size: 32,
                        ),
                      ),
                    ),
                  ),

                  // Alarm Off Icon (Right)
                  IconButton(
                    iconSize: 32,
                    onPressed: _handleDismiss,
                    icon: Icon(
                      Icons.alarm_off_outlined,
                      color: Colors.grey[400],
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
