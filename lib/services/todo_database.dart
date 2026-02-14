// lib/services/todo_database.dart
import 'package:isar/isar.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/todo.dart';
import 'notification_service.dart';

class TodoDatabase {
  static late Isar isar;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize database
  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open([TodoSchema], directory: dir.path);
  }

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Collection reference for Firestore
  CollectionReference get _userTodos =>
      _firestore.collection('users').doc(currentUserId).collection('todos');

  // Sync - Fetch from Firestore and update Isar
  Future<void> syncFromFirestore() async {
    final uid = currentUserId;
    if (uid == null) {
      print('[TodoDatabase] Sync aborted: No user logged in.');
      return;
    }

    try {
      print('[TodoDatabase] Starting sync from Firestore for user: $uid');
      final snapshot = await _userTodos.get();
      print(
        '[TodoDatabase] Firestore sync: Found ${snapshot.docs.length} documents in Firestore',
      );

      final List<Todo> syncedTodos = [];
      await isar.writeTxn(() async {
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          debugPrint(
            '[TodoDatabase] Processing doc: ${doc.id} - ${data['title']}',
          );

          // Handle Timestamp conversion for createdAt
          if (data['createdAt'] is Timestamp) {
            data['createdAt'] = (data['createdAt'] as Timestamp)
                .toDate()
                .toIso8601String();
          }

          // Handle Timestamp conversion for dueDate if applicable
          if (data['dueDate'] is Timestamp) {
            data['dueDate'] = (data['dueDate'] as Timestamp)
                .toDate()
                .toIso8601String();
          }

          final todo = Todo.fromJson(data);
          todo.userId = uid; // Ensure it's tagged correctly

          await isar.todos.put(todo);
          syncedTodos.add(todo);
        }
      });

      // Update alarms for synced todos
      print(
        '[TodoDatabase] Updating alarms for ${syncedTodos.length} synced todos...',
      );
      for (var todo in syncedTodos) {
        if (todo.isCompleted) {
          print(
            '[TodoDatabase] Canceling alarm (Task Completed): ${todo.title}',
          );
          await NotificationService().cancelAlarm(todo.id);
        } else {
          print('[TodoDatabase] Scheduling alarm (Task Active): ${todo.title}');
          await NotificationService().scheduleAlarm(todo);
        }
      }

      print(
        '[TodoDatabase] Firestore sync: Local Isar updated from Firestore successfully.',
      );
    } catch (e) {
      print('[TodoDatabase] Firestore sync error (down): $e');
    }

    // After pulling, push any local tasks that might not be in Firestore
    await pushLocalToFirestore();
  }

  // Push all local tasks for this user to Firestore
  Future<void> pushLocalToFirestore() async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      final localTodos = await isar.todos.filter().userIdEqualTo(uid).findAll();
      print(
        '[TodoDatabase] Firestore push: Found ${localTodos.length} local tasks to check/push',
      );
      for (var todo in localTodos) {
        await _pushToFirestore(todo);
      }
    } catch (e) {
      print('[TodoDatabase] Firestore sync error (up): $e');
    }
  }

  // Helper to push to Firestore (Your requested function)
  Future<void> _pushToFirestore(Todo todo) async {
    final user = _auth.currentUser;
    if (user == null) {
      print(
        '[TodoDatabase] Firestore push ERROR: Cannot push "${todo.title}" because user is null',
      );
      return;
    }

    try {
      print(
        '[TodoDatabase] Pushing task to Firestore: ${todo.title} (ID: ${todo.id})',
      );
      await _userTodos.doc(todo.id.toString()).set({
        'id': todo.id,
        'title': todo.title,
        'isDone': todo.isCompleted, // Using isDone for Firestore as requested
        'description': todo.description,
        'dueDate': todo.dueDate?.toIso8601String(),
        'priority': todo.priority,
        'category': todo.category,
        'isRoutine': todo.isRoutine,
        'userId': user.uid,
        'scheduledTimeMinutes': todo.scheduledTimeMinutes,
        'createdAt': FieldValue.serverTimestamp(), // Using serverTimestamp
      });
      print('[TodoDatabase] Firestore push SUCCESS: Task "${todo.title}"');
    } catch (e) {
      print('[TodoDatabase] Firestore push ERROR for task "${todo.title}": $e');
      print('DEBUG: UserID: ${_auth.currentUser?.uid}');
      print('DEBUG: Target Path: ${_userTodos.path}/${todo.id}');
    }
  }

  // Legacy name for compatibility
  Future<void> saveTodoToFirestore(Todo todo) => _pushToFirestore(todo);

  // Create - Add new todo (BOTH Isar + Firestore together)
  Future<void> addTodo(Todo todo) async {
    print('[TodoDatabase] Adding new todo: ${todo.title}');
    // 1️⃣ Save locally
    todo.userId = currentUserId;
    await isar.writeTxn(() async {
      await isar.todos.put(todo);
    });

    // 2️⃣ Save to cloud
    await _pushToFirestore(todo);

    // 3️⃣ Schedule alarm
    if (!todo.isCompleted) {
      print('[TodoDatabase] Scheduling initial alarm for: ${todo.title}');
      await NotificationService().scheduleAlarm(todo);
    } else {
      print(
        '[TodoDatabase] NOT Scheduling initial alarm (Completed): ${todo.title}',
      );
    }
  }

  // Read - Get all todos for current user
  Future<List<Todo>> getAllTodos() async {
    final uid = currentUserId;
    if (uid == null) return [];
    return await isar.todos.filter().userIdEqualTo(uid).findAll();
  }

  // Read - Get routine todos
  Future<List<Todo>> getRoutineTodos() async {
    final uid = currentUserId;
    if (uid == null) return [];
    return await isar.todos
        .filter()
        .userIdEqualTo(uid)
        .and()
        .isRoutineEqualTo(true)
        .findAll();
  }

  // Read - Get regular tasks
  Future<List<Todo>> getRegularTasks() async {
    final uid = currentUserId;
    if (uid == null) return [];
    return await isar.todos
        .filter()
        .userIdEqualTo(uid)
        .and()
        .isRoutineEqualTo(false)
        .findAll();
  }

  // Update - Toggle todo completion
  Future<void> toggleTodoComplete(Id id) async {
    final todo = await isar.todos.get(id);
    if (todo != null) {
      todo.isCompleted = !todo.isCompleted;
      await isar.writeTxn(() async {
        await isar.todos.put(todo);
      });
      await _pushToFirestore(todo);

      // Handle alarm
      if (todo.isCompleted) {
        await NotificationService().cancelAlarm(todo.id);
      } else {
        await NotificationService().scheduleAlarm(todo);
      }
    }
  }

  // Update - Update todo
  Future<void> updateTodo(Todo todo) async {
    todo.userId = currentUserId;
    await isar.writeTxn(() async {
      await isar.todos.put(todo);
    });
    await _pushToFirestore(todo);

    // Update alarm
    if (todo.isCompleted) {
      await NotificationService().cancelAlarm(todo.id);
    } else {
      await NotificationService().scheduleAlarm(todo);
    }
  }

  // Delete - Remove todo
  Future<void> deleteTodo(Id id) async {
    final uid = currentUserId;

    // Cancel alarm
    await NotificationService().cancelAlarm(id);

    await isar.writeTxn(() async {
      await isar.todos.delete(id);
    });

    if (uid != null) {
      try {
        await _userTodos.doc(id.toString()).delete();
      } catch (e) {
        print('Firestore delete error: $e');
      }
    }
  }

  // Delete all completed todos
  Future<void> deleteCompletedTodos() async {
    final uid = currentUserId;
    if (uid == null) return;

    final completed = await isar.todos
        .filter()
        .userIdEqualTo(uid)
        .and()
        .isCompletedEqualTo(true)
        .findAll();

    await isar.writeTxn(() async {
      for (var todo in completed) {
        await isar.todos.delete(todo.id);
        await _userTodos.doc(todo.id.toString()).delete();
      }
    });
  }

  // Stream - Listen to all todos changes for current user
  Stream<List<Todo>> watchAllTodos() {
    final uid = currentUserId;
    if (uid == null) return Stream.value([]);
    return isar.todos.filter().userIdEqualTo(uid).watch(fireImmediately: true);
  }

  // Stream - Listen to routine todos
  Stream<List<Todo>> watchRoutineTodos() {
    final uid = currentUserId;
    if (uid == null) return Stream.value([]);
    return isar.todos
        .filter()
        .userIdEqualTo(uid)
        .and()
        .isRoutineEqualTo(true)
        .watch(fireImmediately: true);
  }

  // Stream - Listen to regular tasks
  Stream<List<Todo>> watchRegularTasks() {
    final uid = currentUserId;
    if (uid == null) return Stream.value([]);
    return isar.todos
        .filter()
        .userIdEqualTo(uid)
        .and()
        .isRoutineEqualTo(false)
        .watch(fireImmediately: true);
  }

  // Clear local data (on logout)
  Future<void> clearLocalData() async {
    await isar.writeTxn(() async {
      await isar.clear();
    });
  }

  // Reschedule all alarms (for app restart)
  Future<void> rescheduleAllAlarms() async {
    final uid = currentUserId;
    if (uid == null) return;

    final todos = await isar.todos
        .filter()
        .userIdEqualTo(uid)
        .isCompletedEqualTo(false)
        .findAll();

    print('Rescheduling alarms for ${todos.length} tasks...');
    for (var todo in todos) {
      await NotificationService().scheduleAlarm(todo);
    }
  }
}
