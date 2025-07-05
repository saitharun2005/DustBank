// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart'; // Required for MethodChannel
import 'package:permission_handler/permission_handler.dart'; // For permission handling
import 'package:package_info_plus/package_info_plus.dart'; // To get app package name
import 'package:screen_time_app/screens/all_apps_screen.dart'; // Import the new screen
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:intl/intl.dart'; // For date formatting

// Global app ID (from main.dart)
const String __app_id = String.fromEnvironment('APP_ID', defaultValue: 'default-app-id');

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Define the MethodChannel to communicate with native Android code
  static const MethodChannel _platform = MethodChannel('com.example.screen_time_app/usage_stats'); // IMPORTANT: Match your package name

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  String _userId = 'anonymous'; // Default for unauthenticated users

  List<Map<String, dynamic>> _appUsageStats = [];
  bool _isLoading = true;
  String _totalScreenTime = "0h 0m";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add lifecycle observer
    _setupFirebaseAuthListener(); // Listen for auth state changes
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove lifecycle observer
    super.dispose();
  }

  // Listen for Firebase Auth state changes to get the user ID
  void _setupFirebaseAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _userId = user?.uid ?? 'anonymous'; // Use UID or 'anonymous'
        });
        print("Auth state changed. User ID: $_userId");
        // After auth state is ready, check permissions and fetch data
        if (_userId != 'anonymous') { // Only proceed if a user is truly logged in
          _checkAndRequestUsagePermission();
        } else {
          setState(() {
            _isLoading = false; // Not logged in, so stop loading state
            _appUsageStats = [];
            _totalScreenTime = "N/A";
          });
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app resumes from being inactive or paused (e.g., after user grants permission)
    if (state == AppLifecycleState.resumed) {
      print("App resumed. Re-checking usage permission and fetching data.");
      if (_userId != 'anonymous') { // Only re-check if logged in
        _checkAndRequestUsagePermission();
      }
    }
  }

  Future<void> _checkAndRequestUsagePermission() async {
    // Ensure user ID is available before proceeding
    if (_userId == 'anonymous') {
      print("User not authenticated, cannot check permissions or fetch data.");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    final bool isGranted = await _platform.invokeMethod('checkUsagePermission');

    if (isGranted) {
      print("Usage stats permission already granted. Attempting to fetch/load data.");
      await _loadUsageStatsFromFirestore(); // Try loading from Firestore first
    } else {
      print("Usage stats permission not granted. Prompting user.");
      setState(() {
        _isLoading = false;
      });
      _showPermissionRequiredDialog();
    }
  }

  Future<void> _loadUsageStatsFromFirestore() async {
    final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = _firestore.collection('artifacts').doc(__app_id).collection('users').doc(_userId).collection('daily_usage').doc(todayDate);

    try {
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        final List<dynamic> storedApps = data['apps'] ?? [];
        final int storedTotalTime = data['totalTime'] ?? 0;

        List<Map<String, dynamic>> parsedStats = [];
        for (var item in storedApps) {
          if (item is Map) {
            parsedStats.add(Map<String, dynamic>.from(item));
          }
        }

        print("Loaded usage data from Firestore for $todayDate.");
        setState(() {
          _appUsageStats = parsedStats;
          _totalScreenTime = _formatDuration(storedTotalTime);
          _isLoading = false;
        });
        // After loading from Firestore, also fetch fresh data from native in background
        // to ensure it's up-to-date and save it back.
        _fetchUsageStats(forceNativeFetch: true);

      } else {
        print("No usage data found in Firestore for today. Fetching from native.");
        _fetchUsageStats(forceNativeFetch: true);
      }
    } catch (e) {
      print("Error loading from Firestore: $e. Attempting to fetch from native.");
      _fetchUsageStats(forceNativeFetch: true);
    }
  }


  void _showPermissionRequiredDialog() {
    if (Navigator.of(context).canPop() && ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Permission Required", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          content: Text("To track screen time, please grant 'Usage Access' permission in your phone settings. After granting, please return to the app.", style: GoogleFonts.montserrat()),
          actions: <Widget>[
            TextButton(
              child: Text("Go to Settings", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.of(context).pop();
                await _platform.invokeMethod('requestUsagePermission');
              },
            ),
            TextButton(
              child: Text("Re-check Permission", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                _checkAndRequestUsagePermission();
              },
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedDialog() {
    if (Navigator.of(context).canPop() && ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Permission Denied", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          content: Text("Screen time tracking requires 'Usage Access' permission. Please enable it manually in your device settings to use this feature.", style: GoogleFonts.montserrat()),
          actions: <Widget>[
            TextButton(
              child: Text("OK", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchUsageStats({bool forceNativeFetch = false}) async {
    // Only set loading state if it's a forced fetch or not already loading
    if (forceNativeFetch || !_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    // Ensure user ID is available before proceeding
    if (_userId == 'anonymous') {
      print("User ID not available for fetching usage stats.");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentPackageName = packageInfo.packageName;

      final List<dynamic>? result = await _platform.invokeMethod(
        'getAppUsageStats',
        {'packageName': currentPackageName},
      );

      if (result != null) {
        List<Map<String, dynamic>> parsedStats = [];
        int totalMilliseconds = 0;

        for (var item in result) {
          if (item is Map) {
            parsedStats.add(Map<String, dynamic>.from(item));
            totalMilliseconds += (item['totalTimeInForeground'] as int);
          }
        }

        parsedStats.sort((a, b) => (b['totalTimeInForeground'] as int).compareTo(a['totalTimeInForeground'] as int));

        _totalScreenTime = _formatDuration(totalMilliseconds);

        setState(() {
          _appUsageStats = parsedStats;
          _isLoading = false;
        });

        // Save to Firestore
        _saveUsageStatsToFirestore(parsedStats, totalMilliseconds);

      } else {
        setState(() {
          _isLoading = false;
          _appUsageStats = [];
          _totalScreenTime = "N/A";
        });
        print("Failed to get app usage stats: Result is null.");
      }
    } on PlatformException catch (e) {
      setState(() {
        _isLoading = false;
        _appUsageStats = [];
        _totalScreenTime = "Error";
      });
      print("Failed to get app usage stats: '${e.message}'.");
      if (e.code == "PERMISSION_DENIED") {
        _showPermissionDeniedDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: ${e.message}')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _appUsageStats = [];
        _totalScreenTime = "Error";
      });
      print("An unexpected error occurred: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e')),
      );
    }
  }

  Future<void> _saveUsageStatsToFirestore(List<Map<String, dynamic>> stats, int totalTime) async {
    final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = _firestore.collection('artifacts').doc(__app_id).collection('users').doc(_userId).collection('daily_usage').doc(todayDate);

    try {
      await docRef.set({
        'apps': stats,
        'totalTime': totalTime,
        'lastUpdated': FieldValue.serverTimestamp(), // Store server timestamp
      }, SetOptions(merge: true)); // Use merge to avoid overwriting other fields
      print("Usage stats saved to Firestore for $todayDate.");
    } catch (e) {
      print("Error saving to Firestore: $e");
    }
  }

  String _formatDuration(int milliseconds) {
    if (milliseconds <= 0) return "0h 0m";
    Duration duration = Duration(milliseconds: milliseconds);
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> top5Apps = _appUsageStats.take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Screen Time Dashboard',
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Screen Time Today',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          _totalScreenTime,
                          style: GoogleFonts.montserrat(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                  const SizedBox(height: 10),
                  Text(
                    'Compared to yesterday: +15%', // This is still mock data
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Top 5 Applications',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 15),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : top5Apps.isEmpty
                  ? Center(
                      child: Column(
                        children: [
                          Text(
                            "No usage data available or permission denied.",
                            style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _checkAndRequestUsagePermission,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Data / Grant Permission'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: top5Apps.length,
                      itemBuilder: (context, index) {
                        final app = top5Apps[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                app['appName'] != null && app['appName'].isNotEmpty
                                    ? app['appName'][0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                            title: Text(
                              app['appName'] as String? ?? 'Unknown App',
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              app['packageName'] as String? ?? '',
                              style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey),
                            ),
                            trailing: Text(
                              _formatDuration(app['totalTimeInForeground'] as int),
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        );
                      },
                    ),
          const SizedBox(height: 30),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllAppsScreen(
                      appUsageStats: _appUsageStats,
                      formatDuration: _formatDuration,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.analytics_rounded),
              label: const Text('View Full Analytics'),
            ),
          ),
        ],
      ),
    );
  }
}
