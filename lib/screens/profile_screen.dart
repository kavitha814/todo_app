// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/todo.dart';
import '../services/todo_database.dart';
import 'signin_screen.dart';
import '../services/notification_service.dart';

class ProfileScreen extends StatefulWidget {
  final TodoDatabase? database;

  const ProfileScreen({Key? key, this.database}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TodoDatabase _database;

  @override
  void initState() {
    super.initState();
    _database = widget.database ?? TodoDatabase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Header
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Profile Avatar and Info
                StreamBuilder<List<Todo>>(
                  stream: _database.watchAllTodos(),
                  builder: (context, snapshot) {
                    final todos = snapshot.data ?? [];
                    final completedCount = todos
                        .where((t) => t.isCompleted)
                        .length;
                    final inProgressCount = todos
                        .where((t) => !t.isCompleted)
                        .length;
                    final categoriesCount = todos
                        .map((t) => t.category)
                        .toSet()
                        .length;

                    final user = FirebaseAuth.instance.currentUser;
                    final displayName = user?.displayName ?? 'User Data';
                    final email = user?.email ?? 'user@email.com';
                    final photoUrl = user?.photoURL;

                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1D1D),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF8875FF).withOpacity(0.8),
                                      const Color(0xFF8875FF),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  image: photoUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(photoUrl),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: photoUrl == null
                                    ? const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              /* Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF8875FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),*/
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Stats Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatItem('$completedCount', 'Tasks Done'),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white12,
                              ),
                              _buildStatItem('$inProgressCount', 'In Progress'),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white12,
                              ),
                              _buildStatItem('$categoriesCount', 'Categories'),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Settings Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _buildProfileItem(
                  icon: Icons.person_outline,
                  title: 'Account',
                  subtitle: 'Manage your account',
                  onTap: () {},
                ),
                _buildProfileItem(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Customize your notifications',
                  onTap: () {},
                ),
                _buildProfileItem(
                  icon: Icons.category_outlined,
                  title: 'Categories',
                  subtitle: 'Manage task categories',
                  onTap: () {},
                ),
                _buildProfileItem(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: 'Theme and colors',
                  onTap: () {},
                ),

                const SizedBox(height: 24),

                // Other Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Other',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _buildProfileItem(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  subtitle: 'Get help and support',
                  onTap: () {},
                ),
                _buildProfileItem(
                  icon: Icons.info_outline,
                  title: 'About',
                  subtitle: 'Learn more about UpTodo',
                  onTap: () {},
                ),
                _buildProfileItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  subtitle: 'Sign out of your account',
                  isDestructive: true,
                  onTap: () {
                    _showLogoutDialog(context);
                  },
                ),

                const SizedBox(height: 24),

                // Debug Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Debug',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _buildProfileItem(
                  icon: Icons.alarm_add,
                  title: 'Test Alarm (15s)',
                  subtitle: 'Schedule an alarm for 15s from now',
                  onTap: () async {
                    await NotificationService().scheduleTestAlarm();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Alarm scheduled for 15s! Close the app or lock screen to test.',
                          ),
                        ),
                      );
                    }
                  },
                ),
                _buildProfileItem(
                  icon: Icons.notifications_active,
                  title: 'Test Notification',
                  subtitle: 'Show an instant notification',
                  onTap: () async {
                    await NotificationService().showInstantNotification();
                  },
                ),
                _buildProfileItem(
                  icon: Icons.settings_applications,
                  title: 'Check Permissions',
                  subtitle: 'Re-request notification permissions',
                  onTap: () async {
                    await NotificationService().requestPermissions();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Permission request sent/checked.'),
                        ),
                      );
                    }
                  },
                ),

                const SizedBox(height: 24),
                const Text(
                  'Version 1.0.0',
                  style: TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8875FF),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF1D1D1D),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? Colors.red.withOpacity(0.1)
                        : const Color(0xFF8875FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isDestructive ? Colors.red : const Color(0xFF8875FF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDestructive ? Colors.red : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDestructive
                              ? Colors.red.withOpacity(0.6)
                              : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDestructive ? Colors.red : Colors.white38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to logout?',
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
            onPressed: () async {
              try {
                // Store the scaffold messenger if needed, but we'll use context.mounted
                debugPrint("Starting logout process...");

                // Pop the dialog first
                Navigator.of(context).pop();

                await FirebaseAuth.instance.signOut();
                debugPrint("Firebase signed out");

                try {
                  await GoogleSignIn().signOut();
                  debugPrint("Google signed out");
                } catch (e) {
                  debugPrint(
                    "Google sign out error (expected if not used): $e",
                  );
                }

                // Keep local data on logout. Data will be filtered by userId upon re-login.
                // await TodoDatabase().clearLocalData();
                // debugPrint("Local database cleared");

                if (context.mounted) {
                  debugPrint("Navigating to SignInScreen...");
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const SignInScreen(),
                    ),
                    (route) => false,
                  );
                }
              } catch (e) {
                debugPrint("Logout error: $e");
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error logging out: $e")),
                  );
                }
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
