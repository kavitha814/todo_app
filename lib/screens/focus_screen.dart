// lib/screens/focus_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:device_apps/device_apps.dart';

import '../services/notification_service.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({Key? key}) : super(key: key);

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver {
  // Timer State
  Timer? _timer;
  int _remainingSeconds = 25 * 60; // Default 25 minutes
  int _initialSeconds = 25 * 60;
  bool _isRunning = false;

  // App Monitoring State
  Timer? _monitorTimer;
  String? _targetPackageName; // Null = This App (Todo)
  String? _targetAppName;
  bool _isMonitoring = false;
  bool _hasEnteredApp = false;
  DateTime _sessionStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _monitorTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// App Lifecycle check (Used when focusing on THIS app)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isRunning && _targetPackageName == null) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        // User left the app!
        _failSession('You left the app! Focus session failed.');
      }
    }
  }

  /// Show Timer Picker
  void _showTimerPicker() {
    if (_isRunning) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF363636),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CustomTimePickerSheet(
        initialDuration: Duration(seconds: _initialSeconds),
        onDurationChanged: (duration) {
          setState(() {
            _initialSeconds = duration.inSeconds;
            _remainingSeconds = duration.inSeconds;
          });
        },
      ),
    );
  }

  /// Start the Focus Session
  void _startFocus(String? packageName, String appName) async {
    // 1. Check/Grant Permissions for Usage Stats
    if (Platform.isAndroid && packageName != null) {
      bool granted = await UsageStats.checkUsagePermission() ?? false;
      if (!granted) {
        if (mounted) {
          _showPermissionDialog();
        }
        return;
      }
    }

    setState(() {
      _targetPackageName = packageName;
      _targetAppName = appName;
      _isRunning = true;
      _isMonitoring = true;
      _hasEnteredApp = true; // Assume entered immediately (or about to)
      _sessionStartTime = DateTime.now();
    });

    // 2. Launch Target App (if external)
    if (_targetPackageName != null) {
      try {
        await DeviceApps.openApp(_targetPackageName!);
      } catch (e) {
        debugPrint('Could not launch app: $e');
        _failSession('Could not launch $appName');
        return;
      }

      // Start monitoring
      _startExternalAppMonitor();
    }

    // 3. Start Timer Immediately
    _startTimer();

    NotificationService().showInstantNotification(
      title: 'Focus Started ⏳',
      body: 'Timer is running! Stay in $_targetAppName.',
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _completeSession();
      }
    });
  }

  /// Monitor external app usage logic
  void _startExternalAppMonitor() {
    _monitorTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isRunning) {
        timer.cancel();
        return;
      }

      // Grace period check (5 seconds)
      if (DateTime.now().difference(_sessionStartTime).inSeconds < 5) {
        return;
      }

      try {
        final DateTime end = DateTime.now();
        final DateTime start = end.subtract(const Duration(seconds: 10));

        final List<EventUsageInfo> events = await UsageStats.queryEvents(
          start,
          end,
        );

        // Sort events by timestamp descending to get latest
        events.sort(
          (a, b) => int.parse(
            b.timeStamp ?? '0',
          ).compareTo(int.parse(a.timeStamp ?? '0')),
        );

        String? currentPackage;

        // Find the latest MOVE_TO_FOREGROUND event
        for (var event in events) {
          if (event.eventType == '1') {
            // 1 = MOVE_TO_FOREGROUND
            currentPackage = event.packageName;
            break;
          }
        }

        if (currentPackage != null) {
          debugPrint(
            'Monitor: $_targetPackageName vs Current: $currentPackage',
          );

          // Strict check:
          if (currentPackage != _targetPackageName &&
              currentPackage != 'com.example.todo' && // Default package
              currentPackage != 'com.company.todo' && // likely package
              !currentPackage.contains('inputmethod') &&
              !currentPackage.contains('launcher') &&
              !currentPackage.contains('systemui') &&
              !currentPackage.contains('nexuslauncher') &&
              !currentPackage.contains('pixel')) {
            debugPrint('VIOLATION: Left $_targetAppName for $currentPackage');
            _failSession('You left $_targetAppName! Focus failed.');
          }
        }
      } catch (e) {
        debugPrint('Error monitoring usage: $e');
      }
    });
  }

  void _stopSession() {
    _timer?.cancel();
    _monitorTimer?.cancel();
    setState(() {
      _isRunning = false;
      _isMonitoring = false;
      _hasEnteredApp = false;
      _remainingSeconds = _initialSeconds;
    });
  }

  void _failSession(String reason) {
    _timer?.cancel();
    _monitorTimer?.cancel();
    setState(() {
      _isRunning = false;
      _isMonitoring = false;
      _hasEnteredApp = false;
      _remainingSeconds = _initialSeconds;
    });

    // Trigger Notification
    NotificationService().showInstantNotification(
      title: 'Focus Failed ❌',
      body: reason,
    );

    // Also show dialog if inside app (helpful context)
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text(
            'Focus Failed',
            style: TextStyle(color: Colors.red),
          ),
          content: Text(reason),
          backgroundColor: const Color(0xFF363636),
          titleTextStyle: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          contentTextStyle: const TextStyle(color: Colors.white70),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _completeSession() {
    _timer?.cancel();
    _monitorTimer?.cancel();
    setState(() {
      _isRunning = false;
      _isMonitoring = false;
      _hasEnteredApp = false;
      _remainingSeconds = _initialSeconds;
    });

    // Notification on Completion
    NotificationService().showInstantNotification(
      title: 'Focus Session Complete! 🎉',
      body: 'You stayed focused for the whole session. Great job!',
    );

    // Show Success
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Session Complete!'),
        content: const Text('Great job staying focused!'),
        backgroundColor: const Color(0xFF363636),
        titleTextStyle: const TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        contentTextStyle: const TextStyle(color: Colors.white70),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Awesome'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPermissionDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'To monitor which app you are using, please grant "Usage Access" permission in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              UsageStats.grantUsagePermission();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Get Recently Used Apps logic (Robust: Events + UsageStats)
  Future<List<Application>> _getRecentApps() async {
    try {
      DateTime endDate = DateTime.now();
      // Look back 24 hours to ensure we catch everything
      DateTime startDate = endDate.subtract(const Duration(hours: 24));

      // 1. Query Events for precise order (Recents Stack order)
      List<EventUsageInfo> events = await UsageStats.queryEvents(
        startDate,
        endDate,
      );

      // Sort specific events by timestamp (Newest first)
      events.sort(
        (a, b) => int.parse(
          b.timeStamp ?? '0',
        ).compareTo(int.parse(a.timeStamp ?? '0')),
      );

      Set<String> packageNames = {};
      List<String> orderedPackages = [];

      // Filter for MOVE_TO_FOREGROUND (1) events
      for (var event in events) {
        if (event.eventType == '1' && // MOVE_TO_FOREGROUND
            event.packageName != null &&
            !packageNames.contains(event.packageName)) {
          packageNames.add(event.packageName!);
          orderedPackages.add(event.packageName!);
        }
      }

      // 2. Query Aggregate Usage Stats as a backup/filler
      // (Sometimes events get truncated, but usage stats remain)
      List<UsageInfo> usageStats = await UsageStats.queryUsageStats(
        startDate,
        endDate,
      );

      // Sort by last time used
      usageStats.sort(
        (a, b) => int.parse(
          b.lastTimeUsed ?? '0',
        ).compareTo(int.parse(a.lastTimeUsed ?? '0')),
      );

      for (var usage in usageStats) {
        if (usage.packageName != null &&
            (int.tryParse(usage.lastTimeUsed ?? '0') ?? 0) > 0 &&
            !packageNames.contains(usage.packageName)) {
          packageNames.add(usage.packageName!);
          orderedPackages.add(usage.packageName!);
        }
      }

      // Limit to top 20 to avoid overwhelming list
      if (orderedPackages.length > 20) {
        orderedPackages = orderedPackages.sublist(0, 20);
      }

      List<Application> recentApps = [];

      for (var pkg in orderedPackages) {
        // Skip common system UIs and ourselves
        if (pkg.contains('com.android.systemui') ||
            pkg.contains('nexuslauncher') ||
            pkg.contains('pixel.launcher') ||
            pkg.contains('launcher') ||
            pkg == 'com.company.todo') {
          continue;
        }

        try {
          // check if we can open it (has launch intent)
          // We use DeviceApps to verify it's a real launchable app
          bool isInstalled = await DeviceApps.isAppInstalled(pkg);
          if (isInstalled) {
            Application? app = await DeviceApps.getApp(pkg, true);
            if (app != null && app is ApplicationWithIcon) {
              // Only show apps we can actually help the user identify
              recentApps.add(app);
            } else if (app != null) {
              recentApps.add(app);
            }
          }
        } catch (e) {
          // ignore
        }
      }
      return recentApps;
    } catch (e) {
      debugPrint('Error getting recent apps: $e');
      return [];
    }
  }

  void _showAppSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF363636),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Active App',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Focus on an app from your recent history:',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Application>>(
                  future: _getRecentApps(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.history,
                              color: Colors.white24,
                              size: 48,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "No recent apps found",
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      );
                    }

                    final apps = snapshot.data!;

                    return ListView.builder(
                      itemCount: apps.length,
                      itemBuilder: (context, index) {
                        final app = apps[index];
                        return Card(
                          color: Colors.white10,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: app is ApplicationWithIcon
                                ? Image.memory(app.icon, width: 40, height: 40)
                                : const Icon(
                                    Icons.android,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                            title: Text(
                              app.appName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: const Text(
                              'Recently used',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _startFocus(app.packageName, app.appName);
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _startFocus(null, 'Todo App');
                  },
                  child: const Text(
                    'Focus on This App instead',
                    style: TextStyle(color: Color(0xFF8875FF)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String get _timerString {
    final minutes = (_remainingSeconds / 60).floor().toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Focus Mode',
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
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 250,
                          height: 250,
                          child: CircularProgressIndicator(
                            value:
                                _remainingSeconds /
                                (_initialSeconds > 0 ? _initialSeconds : 1),
                            strokeWidth: 8,
                            backgroundColor: const Color(0xFF363636),
                            color: const Color(0xFF8875FF),
                          ),
                        ),
                        Container(
                          width: 200,
                          height: 200,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors
                                .transparent, // Ensure it has a "body" to tap
                          ),
                          child: GestureDetector(
                            onTap: _showTimerPicker,
                            behavior: HitTestBehavior
                                .opaque, // Catch all taps within bounds
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _timerString,
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isRunning
                                      ? (_hasEnteredApp
                                            ? 'Focusing on:\n${_targetAppName ?? "Common"}'
                                            : 'Waiting to enter\n${_targetAppName}...')
                                      : 'Tap timer to edit\nReady to Focus?',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 60),
                    if (!_isRunning)
                      ElevatedButton(
                        onPressed: _showAppSelectionSheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8875FF),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Select App & Start',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: _stopSession,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Stop Focus',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
  }
}

class CustomTimePickerSheet extends StatefulWidget {
  final Duration initialDuration;
  final ValueChanged<Duration> onDurationChanged;

  const CustomTimePickerSheet({
    Key? key,
    required this.initialDuration,
    required this.onDurationChanged,
  }) : super(key: key);

  @override
  State<CustomTimePickerSheet> createState() => _CustomTimePickerSheetState();
}

class _CustomTimePickerSheetState extends State<CustomTimePickerSheet> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _secondController;

  @override
  void initState() {
    super.initState();
    final initialSeconds = widget.initialDuration.inSeconds;
    final h = initialSeconds ~/ 3600;
    final m = (initialSeconds % 3600) ~/ 60;
    final s = initialSeconds % 60;

    _hourController = FixedExtentScrollController(initialItem: h);
    _minuteController = FixedExtentScrollController(initialItem: m);
    _secondController = FixedExtentScrollController(initialItem: s);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    final h = _hourController.selectedItem;
    final m = _minuteController.selectedItem;
    final s = _secondController.selectedItem;
    final totalSeconds = (h * 3600) + (m * 60) + s;

    // Ensure at least 1 second? Or allow 0. User logic handles >0 usually.
    if (totalSeconds >= 0) {
      widget.onDurationChanged(Duration(seconds: totalSeconds));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Text(
            'Set Timer',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hours
                _buildPickerColumn(
                  controller: _hourController,
                  count: 100, // 0-99
                  label: 'hr',
                  flex: 2,
                ),
                _buildColon(),
                // Minutes
                _buildPickerColumn(
                  controller: _minuteController,
                  count: 60,
                  label: 'min',
                  flex: 2,
                ),
                _buildColon(),
                // Seconds
                _buildPickerColumn(
                  controller: _secondController,
                  count: 60,
                  label: 'sec',
                  flex: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColon() {
    return const SizedBox(
      width: 20,
      child: Center(
        child: Text(
          ':',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildPickerColumn({
    required FixedExtentScrollController controller,
    required int count,
    required String label,
    required int flex,
  }) {
    return Expanded(
      flex: flex,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CupertinoPicker.builder(
            scrollController: controller,
            itemExtent: 50,
            selectionOverlay: const SizedBox(), // Hide default overlay
            onSelectedItemChanged: (index) {
              _notifyChange();
              setState(() {}); // specific rebuild for active color update
            },
            childCount: count,
            itemBuilder: (context, index) {
              final isSelected = controller.selectedItem == index;
              return Center(
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white24,
                    fontSize: isSelected ? 32 : 24, // Large font for selected
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
