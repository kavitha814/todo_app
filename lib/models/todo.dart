// lib/models/todo.dart
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

part 'todo.g.dart';

@collection
class Todo {
  Id id = Isar.autoIncrement; // Auto-increment ID for Isar

  String title = '';
  String? description;
  DateTime? dueDate;
  @enumerated
  int priority = 0; // 1: Low (Blue), 2: Medium (Orange), 3: High (Red)
  String category = 'Personal';
  bool isCompleted = false;
  bool isRoutine = false; // True for daily routine tasks
  String? userId; // To associate task with a user account
  DateTime createdAt = DateTime.now(); // Track when task was created

  // Store TimeOfDay as minutes since midnight
  int? scheduledTimeMinutes;

  // Ignore this field in Isar (computed property)
  @ignore
  TimeOfDay? get scheduledTime {
    if (scheduledTimeMinutes == null) return null;
    final hours = scheduledTimeMinutes! ~/ 60;
    final minutes = scheduledTimeMinutes! % 60;
    return TimeOfDay(hour: hours, minute: minutes);
  }

  set scheduledTime(TimeOfDay? time) {
    if (time == null) {
      scheduledTimeMinutes = null;
    } else {
      scheduledTimeMinutes = time.hour * 60 + time.minute;
    }
  }

  // Default constructor for Isar
  Todo({
    this.id = Isar.autoIncrement,
    this.title = '',
    this.description,
    this.dueDate,
    this.priority = 0,
    this.category = 'Personal',
    this.isCompleted = false,
    this.isRoutine = false,
    this.userId,
    TimeOfDay? scheduledTime,
  }) {
    this.scheduledTime = scheduledTime;
  }

  // Convert to JSON for backup/export
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'priority': priority,
      'category': category,
      'isCompleted': isCompleted,
      'isRoutine': isRoutine,
      'userId': userId,
      'scheduledTimeMinutes': scheduledTimeMinutes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory Todo.fromJson(Map<String, dynamic> json) {
    TimeOfDay? time;
    if (json['scheduledTimeMinutes'] != null) {
      final minutes = json['scheduledTimeMinutes'] as int;
      time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    }

    return Todo(
        id: json['id'] ?? Isar.autoIncrement,
        title: json['title'],
        description: json['description'],
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'])
            : null,
        priority: json['priority'],
        category: json['category'],
        isCompleted: json['isCompleted'],
        isRoutine: json['isRoutine'] ?? false,
        userId: json['userId'],
        scheduledTime: time,
      )
      ..createdAt = json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now();
  }

  // Copy with method for updates
  Todo copyWith({
    Id? id,
    String? title,
    String? description,
    DateTime? dueDate,
    int? priority,
    String? category,
    bool? isCompleted,
    bool? isRoutine,
    TimeOfDay? scheduledTime,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      isRoutine: isRoutine ?? this.isRoutine,
      userId: userId ?? this.userId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
    );
  }

  // Helper to get formatted time string
  String get formattedTime {
    if (scheduledTime == null) return '';
    final hour = scheduledTime!.hour;
    final minute = scheduledTime!.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
