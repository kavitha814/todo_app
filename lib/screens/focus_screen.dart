// lib/screens/focus_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:device_apps/device_apps.dart';

import '../services/notification_service.dart';
import '../widgets/growing_tree.dart';

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
  List<String> _targetPackageNames = []; // Empty = This App (Todo)
  List<String> _targetAppNames = [];
  bool _isMonitoring = false;
  bool _hasEnteredApp = false;
  bool _isSessionCompleted = false;
  bool _isSessionFailed = false;
  String _failureReason = '';
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
    if (_isRunning && _targetPackageNames.isEmpty) {
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
      backgroundColor: const Color(0xFFF5F5F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: CustomTimePickerSheet(
          initialDuration: Duration(seconds: _initialSeconds),
          onDurationChanged: (duration) {
            setState(() {
              _initialSeconds = duration.inSeconds;
              _remainingSeconds = duration.inSeconds;
            });
          },
        ),
      ),
    );
  }

  void _startFocus(List<String> packageNames, List<String> appNames) async {
    // 1. Check/Grant Permissions for Usage Stats
    if (Platform.isAndroid && packageNames.isNotEmpty) {
      bool granted = await UsageStats.checkUsagePermission() ?? false;
      if (!granted) {
        if (mounted) {
          _showPermissionDialog();
        }
        return;
      }
    }

    // 2. Launch Target App (if external) BEFORE starting the timer
    if (packageNames.isNotEmpty) {
      try {
        await DeviceApps.openApp(packageNames.first);
        // Wait briefly for the OS to complete the app transition
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (e) {
        debugPrint('Could not launch app: $e');
        _failSession('Could not launch ${appNames.first}');
        return;
      }
    }

    // 3. Set State and Start Monitoring & Timer
    setState(() {
      _targetPackageNames = packageNames;
      _targetAppNames = appNames;
      _isRunning = true;
      _isMonitoring = true;
      _isSessionCompleted = false;
      _isSessionFailed = false;
      _failureReason = '';
      _hasEnteredApp = true; // Assume entered immediately (or about to)
      _sessionStartTime = DateTime.now(); // Grace period starts NOW
    });

    if (_targetPackageNames.isNotEmpty) {
      // Start monitoring
      _startExternalAppMonitor();
    }

    _startTimer();

    NotificationService().showInstantNotification(
      title: 'Focus Started ⏳',
      body:
          'Timer is running! Stay in ' +
          (_targetAppNames.isEmpty ? 'Todo App' : _targetAppNames.join(", ")),
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
        // Use the start of the session (minus a buffer) so we never "lose" the 
        // last known foreground app if the OS delays flushing the usage stats database!
        final DateTime start = _sessionStartTime.subtract(const Duration(seconds: 10));

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
            'Monitor: $_targetPackageNames vs Current: $currentPackage',
          );

          // Strict check:
          if (!_targetPackageNames.contains(currentPackage) &&
              currentPackage != 'com.example.todo' && // Default package
              currentPackage != 'com.company.todo' && // likely package
              !currentPackage.contains('inputmethod') &&
              !currentPackage.contains('launcher') &&
              !currentPackage.contains('systemui') &&
              !currentPackage.contains('nexuslauncher') &&
              !currentPackage.contains('pixel') &&
              !currentPackage.contains('home') &&
              !currentPackage.contains('recents')) {
            debugPrint('VIOLATION: Left $_targetAppNames for $currentPackage');
            _failSession('You left your allowed apps! Focus failed.');
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
      _isSessionCompleted = false;
      _isSessionFailed = false;
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
      _isSessionCompleted = false;
      _isSessionFailed = true;
      _failureReason = reason;
      _hasEnteredApp = false;
      _remainingSeconds = _initialSeconds; // Or 0, doesn't matter since failed
    });

    // Trigger Notification
    NotificationService().showInstantNotification(
      title: 'Focus Failed ❌',
      body: reason,
      payload: 'focus_failed',
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
          backgroundColor: const Color(0xFFF5F5F5),
          titleTextStyle: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          contentTextStyle: const TextStyle(color: Colors.black87),
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
      _isSessionCompleted = true;
      _hasEnteredApp = false;
      _remainingSeconds = 0;
    });

    // Notification on Completion
    NotificationService().showInstantNotification(
      title: 'Focus Session Complete! 🎉',
      body: 'You stayed focused for the whole session. Great job!',
      payload: 'focus_completed',
    );

    // Show Success
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Session Complete!'),
        content: const Text('Great job staying focused!'),
        backgroundColor: const Color(0xFFF5F5F5),
        titleTextStyle: const TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        contentTextStyle: const TextStyle(color: Colors.black87),
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

  void _showAppSelectionSheet() async {
    if (Platform.isAndroid) {
      bool granted = await UsageStats.checkUsagePermission() ?? false;
      if (!granted) {
        if (mounted) {
          _showPermissionDialog();
        }
        return;
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF5F5F5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        Set<String> selectedPackages = {};
        Map<String, String> packageToNameMap = {};

        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 600,
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Active Apps',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Focus on apps from your recent history:',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: FutureBuilder<List<Application>>(
                        future: _getRecentApps(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.history,
                                    color: Colors.black26,
                                    size: 48,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    "No recent apps found",
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            );
                          }

                          final apps = snapshot.data!;
                          for (var app in apps) {
                            packageToNameMap[app.packageName] = app.appName;
                          }

                          return ListView.builder(
                            itemCount: apps.length,
                            itemBuilder: (context, index) {
                              final app = apps[index];
                              final isSelected = selectedPackages.contains(
                                app.packageName,
                              );
                              return Card(
                                color: isSelected
                                    ? const Color(0xFF8875FF).withOpacity(0.2)
                                    : Colors.black12,
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  leading: app is ApplicationWithIcon
                                      ? Image.memory(
                                          app.icon,
                                          width: 40,
                                          height: 40,
                                        )
                                      : const Icon(
                                          Icons.android,
                                          color: Colors.black87,
                                          size: 40,
                                        ),
                                  title: Text(
                                    app.appName,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: Checkbox(
                                    value: isSelected,
                                    onChanged: (val) {
                                      setModalState(() {
                                        if (val == true) {
                                          selectedPackages.add(app.packageName);
                                        } else {
                                          selectedPackages.remove(
                                            app.packageName,
                                          );
                                        }
                                      });
                                    },
                                    activeColor: const Color(0xFF8875FF),
                                  ),
                                  onTap: () {
                                    setModalState(() {
                                      if (isSelected) {
                                        selectedPackages.remove(
                                          app.packageName,
                                        );
                                      } else {
                                        selectedPackages.add(app.packageName);
                                      }
                                    });
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8875FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          List<String> pkgs = selectedPackages.toList();
                          List<String> names = pkgs.map((p) => packageToNameMap[p]!).toList();
                          _startFocus(pkgs, names);
                        },
                        child: Text(
                          selectedPackages.isEmpty
                              ? 'Focus on Todo App Only'
                              : 'Launch & Start Focus (${selectedPackages.length})',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
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
                color: Colors.black87,
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
                          width: 280,
                          height: 280,
                          child: CircularProgressIndicator(
                            value:
                                _remainingSeconds /
                                (_initialSeconds > 0 ? _initialSeconds : 1),
                            strokeWidth: 8,
                            backgroundColor: const Color(0xFFF5F5F5),
                            color: const Color(0xFF8875FF),
                          ),
                        ),
                        Container(
                          width: 240,
                          height: 240,
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
                              children: [
                                // Top Half: The Tree
                                SizedBox(
                                  height: 110,
                                  width: 240,
                                  child: _isSessionFailed
                                      ? const Icon(Icons.do_disturb_alt, size: 80, color: Colors.redAccent)
                                      : GrowingTree(
                                          progress: _isSessionCompleted
                                              ? 1.0
                                              : (_isRunning
                                                  ? 1.0 -
                                                      (_remainingSeconds /
                                                          (_initialSeconds > 0
                                                              ? _initialSeconds
                                                              : 1))
                                                  : 0.05), // Tiny sprout
                                        ),
                                ),
                                // A little empty space between the tree and the timer
                                const SizedBox(height: 20),
                                // Bottom Half: Timer & Status
                                SizedBox(
                                  height: 110,
                                  width: 240,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0, vertical: 8.0),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Text(
                                            _isSessionFailed ? 'Failed' : (_isSessionCompleted ? 'Complete!' : _timerString),
                                            style: TextStyle(
                                              fontSize: (_isSessionCompleted || _isSessionFailed) ? 36 : 46,
                                              fontWeight: FontWeight.bold,
                                              color: _isSessionFailed 
                                                  ? Colors.redAccent 
                                                  : (_isSessionCompleted ? Colors.green[700] : Colors.black87),
                                              height: 1.0, // Tighter spacing
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _isSessionFailed
                                                ? 'Focus broken:\n$_failureReason' 
                                                : (_isSessionCompleted
                                                    ? 'Your tree is completely grown.\nCongratulations!'
                                                    : (_isRunning
                                                        ? (_hasEnteredApp
                                                            ? 'Focusing on:\n${_targetAppNames.isEmpty ? "Todo App" : _targetAppNames.join(", ")}'
                                                            : 'Waiting to enter\n${_targetAppNames.join(", ")}...')
                                                        : 'Tap timer to edit\nReady to Focus?')),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: _isSessionFailed ? Colors.red[800] : (_isSessionCompleted ? Colors.green[800] : Colors.black54),
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 60),
                    if (_isSessionFailed)
                      ElevatedButton(
                        onPressed: _stopSession, // Resets state using stop method
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Try Again',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else if (_isSessionCompleted)
                      ElevatedButton(
                        onPressed: _stopSession, // Resets state using stop method
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Plant Another Tree',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else if (!_isRunning)
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
                            color: Colors.black87,
                          ),
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: _stopSession,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: Colors.black54),
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
                            color: Colors.black87,
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
              color: Colors.black87,
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
            color: Colors.black87,
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
                    color: isSelected ? Colors.black87 : Colors.black26,
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
