// lib/screens/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:isar/isar.dart';
import '../models/todo.dart';
import '../services/todo_database.dart';
import '../widgets/todo_card.dart';

class CalendarScreen extends StatefulWidget {
  final TodoDatabase database;

  const CalendarScreen({Key? key, required this.database}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  /// Filter todos: exclude routines, ensure valid due date
  List<Todo> _getTodosForDay(DateTime day, List<Todo> allTodos) {
    return allTodos.where((todo) {
      if (todo.isRoutine) return false;
      if (todo.dueDate == null) return false;
      return isSameDay(todo.dueDate, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Todo>>(
      stream: widget.database.watchAllTodos(),
      builder: (context, snapshot) {
        final allTodos = snapshot.data ?? [];

        // Filter out routines efficiently for the whole calendar signals if needed,
        // but _getTodosForDay handles the specific day logic.
        // We can also create a map if performance becomes an issue, but for a personal todo list, this is fine.

        final selectedTodos = _getTodosForDay(_selectedDay!, allTodos);

        return Scaffold(
          backgroundColor:
              Colors.transparent, // Background handled by parent or theme
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    top: 16.0,
                    bottom: 8.0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Calendar',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                _buildCalendar(allTodos),
                const SizedBox(height: 16),
                Expanded(child: _buildTaskList(selectedTodos)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendar(List<Todo> allTodos) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF363636),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TableCalendar<Todo>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: _calendarFormat,
        eventLoader: (day) {
          return _getTodosForDay(day, allTodos);
        },
        startingDayOfWeek: StartingDayOfWeek.monday,
        calendarStyle: const CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: TextStyle(color: Colors.white),
          weekendTextStyle: TextStyle(color: Colors.white70),
          selectedDecoration: BoxDecoration(
            color: Color(0xFF8875FF),
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Color(
              0xFF8875FF,
            ), // Using same as selected for cohesive look, or lighter
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          markerDecoration: BoxDecoration(
            color: Color(0xFFA394FF), // Lighter purple for markers
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
          rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekendStyle: TextStyle(color: Colors.white54),
          weekdayStyle: TextStyle(color: Colors.white54),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          if (!isSameDay(_selectedDay, selectedDay)) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          }
        },
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() {
              _calendarFormat = format;
            });
          }
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
      ),
    );
  }

  Widget _buildTaskList(List<Todo> todos) {
    if (todos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_available, size: 80, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'No tasks for this day',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        return TodoCard(
          todo: todo,
          onToggle: (id) => widget.database.toggleTodoComplete(id),
          onDelete: (id) => widget.database.deleteTodo(id),
        );
      },
    );
  }
}
