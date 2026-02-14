import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../models/todo.dart';
import '../widgets/todo_card.dart';
import '../services/todo_database.dart';

enum ViewMode { routine, tasks }

class IndexScreen extends StatefulWidget {
  final TodoDatabase database;
  final Function(Id) onToggle;
  final Function(Id) onDelete;
  final ViewMode currentMode;
  final Function(ViewMode) onModeChanged;

  const IndexScreen({
    Key? key,
    required this.database,
    required this.onToggle,
    required this.onDelete,
    required this.currentMode,
    required this.onModeChanged,
  }) : super(key: key);

  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Todo>>(
      stream: widget.database.watchAllTodos(),
      builder: (context, snapshot) {
        final todos = snapshot.data ?? [];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Index',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                // Mode Toggle
                _buildModeToggle(),
                const SizedBox(height: 24),
                Expanded(
                  child: widget.currentMode == ViewMode.routine
                      ? _buildRoutineView(todos)
                      : _buildTasksView(todos),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF363636),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              'Daily Routine',
              ViewMode.routine,
              Icons.schedule,
            ),
          ),
          Expanded(
            child: _buildToggleButton('Tasks', ViewMode.tasks, Icons.task_alt),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, ViewMode mode, IconData icon) {
    final isSelected = widget.currentMode == mode;
    return InkWell(
      onTap: () => widget.onModeChanged(mode),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8875FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineView(List<Todo> todos) {
    final routineTodos = todos.where((t) => t.isRoutine).toList();

    // Sort by scheduled time
    routineTodos.sort((a, b) {
      if (a.scheduledTime == null) return 1;
      if (b.scheduledTime == null) return -1;
      final aMinutes = a.scheduledTime!.hour * 60 + a.scheduledTime!.minute;
      final bMinutes = b.scheduledTime!.hour * 60 + b.scheduledTime!.minute;
      return aMinutes.compareTo(bMinutes);
    });

    if (routineTodos.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.schedule, size: 120, color: Colors.white24),
              const SizedBox(height: 16),
              const Text(
                'No Daily Routine Set',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create routine tasks for your day',
                style: TextStyle(fontSize: 14, color: Colors.white38),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: routineTodos.length,
      itemBuilder: (context, index) {
        final todo = routineTodos[index];
        return _buildRoutineCard(todo);
      },
    );
  }

  Widget _buildRoutineCard(Todo todo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF363636),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: todo.isCompleted
              ? Colors.green.withOpacity(0.3)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Time indicator
          Container(
            width: 70,
            child: Text(
              todo.formattedTime,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8875FF),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Vertical line
          Container(
            width: 2,
            height: 40,
            color: const Color(0xFF8875FF).withOpacity(0.3),
          ),
          const SizedBox(width: 12),
          // Task info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    decoration: todo.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (todo.description != null &&
                    todo.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    todo.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      decoration: todo.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Checkbox
          InkWell(
            onTap: () => widget.onToggle(todo.id),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: todo.isCompleted ? Colors.green : Colors.white54,
                  width: 2,
                ),
                color: todo.isCompleted ? Colors.green : Colors.transparent,
              ),
              child: todo.isCompleted
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Delete Button
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.white54,
              size: 20,
            ),
            onPressed: () => _showDeleteConfirmation(context, todo),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Todo todo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Routine',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete this routine?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              widget.onDelete(todo.id);
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksView(List<Todo> todos) {
    final taskTodos = todos.where((t) => !t.isRoutine).toList();
    final incompleteTodos = taskTodos.where((t) => !t.isCompleted).toList();
    final completedTodos = taskTodos.where((t) => t.isCompleted).toList();

    return taskTodos.isEmpty
        ? Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/empty.png',
                    width: 200,
                    height: 200,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.check_circle_outline,
                      size: 120,
                      color: Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'What do you want to do today?',
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap + to add your tasks',
                    style: TextStyle(fontSize: 14, color: Colors.white38),
                  ),
                ],
              ),
            ),
          )
        : ListView(
            children: [
              if (incompleteTodos.isNotEmpty) ...[
                const Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                ...incompleteTodos.map(
                  (todo) => TodoCard(
                    key: ValueKey(todo.id),
                    todo: todo,
                    onToggle: widget.onToggle,
                    onDelete: widget.onDelete,
                  ),
                ),
              ],
              if (completedTodos.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                ...completedTodos.map(
                  (todo) => TodoCard(
                    key: ValueKey('comp_${todo.id}'),
                    todo: todo,
                    onToggle: widget.onToggle,
                    onDelete: widget.onDelete,
                  ),
                ),
              ],
            ],
          );
  }
}
