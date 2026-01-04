// lib/widgets/todo_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import '../models/todo.dart';

class TodoCard extends StatelessWidget {
  final Todo todo;
  final Function(Id) onToggle;
  final Function(Id) onDelete;

  const TodoCard({
    Key? key,
    required this.todo,
    required this.onToggle,
    required this.onDelete,
  }) : super(key: key);

  Color _getPriorityColor() {
    switch (todo.priority) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon() {
    switch (todo.category.toLowerCase()) {
      case 'work':
        return Icons.work_outline;
      case 'health':
        return Icons.favorite_outline;
      case 'study':
        return Icons.school_outlined;
      case 'personal':
        return Icons.person_outline;
      default:
        return Icons.label_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D1D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Show task details
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                InkWell(
                  onTap: () => onToggle(todo.id),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: todo.isCompleted
                            ? const Color(0xFF8875FF)
                            : Colors.white.withOpacity(0.3),
                        width: 2.5,
                      ),
                      color: todo.isCompleted
                          ? const Color(0xFF8875FF)
                          : Colors.transparent,
                    ),
                    child: todo.isCompleted
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                ),

                const SizedBox(width: 16),

                // Task Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        todo.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: todo.isCompleted
                              ? Colors.white.withOpacity(0.4)
                              : Colors.white,
                          decoration: todo.isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: Colors.white.withOpacity(0.4),
                          decorationThickness: 2,
                        ),
                      ),

                      // Description
                      if (todo.description != null &&
                          todo.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          todo.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: todo.isCompleted
                                ? Colors.white.withOpacity(0.25)
                                : Colors.white.withOpacity(0.6),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Metadata Row
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Due Date
                          if (todo.dueDate != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: todo.isCompleted
                                    ? Colors.white.withOpacity(0.05)
                                    : const Color(0xFF2C2C2C),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: todo.isCompleted
                                        ? Colors.white.withOpacity(0.25)
                                        : Colors.white.withOpacity(0.5),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat(
                                      'MMM d, h:mm a',
                                    ).format(todo.dueDate!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: todo.isCompleted
                                          ? Colors.white.withOpacity(0.25)
                                          : Colors.white.withOpacity(0.5),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Category
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: todo.isCompleted
                                  ? Colors.white.withOpacity(0.05)
                                  : _getPriorityColor().withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getCategoryIcon(),
                                  size: 14,
                                  color: todo.isCompleted
                                      ? Colors.white.withOpacity(0.25)
                                      : _getPriorityColor(),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  todo.category,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: todo.isCompleted
                                        ? Colors.white.withOpacity(0.25)
                                        : _getPriorityColor(),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Priority Indicator
                          if (todo.priority > 0)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: todo.isCompleted
                                    ? Colors.white.withOpacity(0.25)
                                    : _getPriorityColor(),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Delete Button
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: todo.isCompleted
                        ? Colors.white.withOpacity(0.25)
                        : Colors.white.withOpacity(0.4),
                  ),
                  onPressed: () {
                    _showDeleteConfirmation(context);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Task',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete this task?',
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
              onDelete(todo.id);
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
}
