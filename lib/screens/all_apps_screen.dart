// lib/screens/all_apps_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AllAppsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> appUsageStats;
  final Function(int) formatDuration; // Function to format duration

  const AllAppsScreen({
    super.key,
    required this.appUsageStats,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'All Applications Screen Time',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: appUsageStats.isEmpty
          ? Center(
              child: Text(
                "No usage data available.",
                style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: appUsageStats.length,
              itemBuilder: (context, index) {
                final app = appUsageStats[index];
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
                      formatDuration(app['totalTimeInForeground'] as int),
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
