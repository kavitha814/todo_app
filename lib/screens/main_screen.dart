// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../services/todo_database.dart';
import 'index_screen.dart';
import 'focus_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';
import '../widgets/add_task_sheet.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final TodoDatabase _database = TodoDatabase();
  ViewMode _indexViewMode = ViewMode.tasks;

  @override
  void initState() {
    super.initState();
    _database.syncFromFirestore();
    _database.rescheduleAllAlarms();
  }

  void _onItemTapped(int index) {
    if (index == 2) return; // Center button handled separately
    setState(() {
      _selectedIndex = index;
    });
  }

  void _addNewTodo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTaskSheet(
        onAdd: (todo) async {
          await _database.addTodo(todo);
        },
      ),
    );
  }

  void _toggleTodoComplete(Id id) async {
    await _database.toggleTodoComplete(id);
  }

  void _deleteTodo(Id id) async {
    await _database.deleteTodo(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          IndexScreen(
            key: const PageStorageKey('index_screen'),
            database: _database,
            onToggle: _toggleTodoComplete,
            onDelete: _deleteTodo,
            currentMode: _indexViewMode,
            onModeChanged: (mode) {
              setState(() {
                _indexViewMode = mode;
              });
            },
          ),
          CalendarScreen(
            key: const PageStorageKey('calendar_screen'),
            database: _database,
          ),
          const SizedBox(), // Placeholder for center button
          const FocusScreen(key: PageStorageKey('focus_screen')),
          ProfileScreen(
            key: const PageStorageKey('profile_screen'),
            database: _database,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewTodo,
        backgroundColor: const Color(0xFF8875FF),
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: const Color(0xFF363636),
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Index', 0),
              _buildNavItem(Icons.calendar_today, 'Calendar', 1),
              const SizedBox(width: 40), // Space for FAB
              _buildNavItem(Icons.access_time, 'Focus', 3),
              _buildNavItem(Icons.person, 'Profile', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFF8875FF) : Colors.white54,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? const Color(0xFF8875FF) : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}
