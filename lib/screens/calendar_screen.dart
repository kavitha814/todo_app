// lib/screens/calendar_screen.dart
import 'package:flutter/material.dart';
import '../models/todo.dart';
import '../services/todo_database.dart';

class CalendarScreen extends StatelessWidget {
  final TodoDatabase database;

  const CalendarScreen({Key? key, required this.database}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Todo>>(
      stream: database.watchAllTodos(),
      builder: (context, snapshot) {
        final todos = snapshot.data ?? [];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Calendar',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 100,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Calendar View',
                          style: TextStyle(fontSize: 20, color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${todos.length} tasks scheduled',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
