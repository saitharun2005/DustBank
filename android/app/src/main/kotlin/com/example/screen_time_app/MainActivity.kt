// android/app/src/main/kotlin/com/example/screen_time_app/MainActivity.kt

// IMPORTANT: Replace 'com.example.screen_time_app' with your actual package name.
// You can find your actual package name in your AndroidManifest.xml or build.gradle (app level).
package com.example.screen_time_app 

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import java.util.concurrent.TimeUnit

class MainActivity: FlutterActivity() {
    // Define the MethodChannel name. This must match the one in Dart.
    // IMPORTANT: Ensure 'com.example.screen_time_app' matches your actual package name.
    private val CHANNEL = "com.example.screen_time_app/usage_stats"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "checkUsagePermission" -> {
                    // Check if the PACKAGE_USAGE_STATS permission is granted
                    val granted = hasUsageStatsPermission()
                    result.success(granted)
                }
                "requestUsagePermission" -> {
                    // Direct user to the Usage Access settings
                    val success = requestUsageStatsPermission()
                    result.success(success)
                }
                "getAppUsageStats" -> {
                    // Get the package name of the current app from arguments to exclude it
                    val currentAppPackageName = call.argument<String>("packageName") ?: ""
                    val usageStats = getAppUsageStats(currentAppPackageName)
                    result.success(usageStats)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // Function to check if PACKAGE_USAGE_STATS permission is granted
    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    // Function to request PACKAGE_USAGE_STATS permission by opening settings
    private fun requestUsageStatsPermission(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    // Function to get app usage statistics
    private fun getAppUsageStats(currentAppPackageName: String): List<Map<String, Any>> {
        if (!hasUsageStatsPermission()) {
            // If permission is not granted, return empty list.
            // The Flutter side will handle showing the permission dialog.
            return emptyList()
        }

        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val calendar = Calendar.getInstance()

        // Set start time to the beginning of today
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val startTime = calendar.timeInMillis

        // Set end time to now
        val endTime = System.currentTimeMillis()

        // Map to store total foreground time for each app
        val appUsageMap = mutableMapOf<String, Long>() // PackageName to TotalTimeInForeground

        // Query usage events
        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()

        // Keep track of the last time an app was in the foreground
        val lastForegroundEventMap = mutableMapOf<String, Long>()

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)

            // Exclude the current app's usage from tracking
            if (event.packageName == currentAppPackageName) {
                continue
            }

            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    lastForegroundEventMap[event.packageName] = event.timeStamp
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val lastForegroundTime = lastForegroundEventMap[event.packageName]
                    if (lastForegroundTime != null) {
                        val duration = event.timeStamp - lastForegroundTime
                        if (duration > 0) {
                            appUsageMap[event.packageName] = appUsageMap.getOrDefault(event.packageName, 0L) + duration
                        }
                        lastForegroundEventMap.remove(event.packageName) // Clear after use
                    }
                }
                // Consider adding screen on/off events for more robust tracking if needed
                // UsageEvents.Event.SCREEN_INTERACTIVE -> {}
                // UsageEvents.Event.SCREEN_NON_INTERACTIVE -> {}
            }
        }

        // Handle apps that are still in foreground when querying (i.e., no MOVE_TO_BACKGROUND event yet)
        for ((pkgName, foregroundTime) in lastForegroundEventMap) {
            val duration = endTime - foregroundTime
            if (duration > 0) {
                appUsageMap[pkgName] = appUsageMap.getOrDefault(pkgName, 0L) + duration
            }
        }

        // Prepare the list of maps to send back to Flutter
        val resultList = mutableListOf<Map<String, Any>>()
        val packageManager = applicationContext.packageManager

        for ((packageName, totalTimeInForeground) in appUsageMap) {
            try {
                // Get application name from package manager
                val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                val appName = packageManager.getApplicationLabel(appInfo).toString()
                resultList.add(mapOf(
                    "packageName" to packageName,
                    "appName" to appName,
                    "totalTimeInForeground" to totalTimeInForeground // in milliseconds
                ))
            } catch (e: PackageManager.NameNotFoundException) {
                // This can happen if an app was uninstalled or is a system component without a typical label
                resultList.add(mapOf(
                    "packageName" to packageName,
                    "appName" to "Unknown App ($packageName)", // Fallback name with package
                    "totalTimeInForeground" to totalTimeInForeground
                ))
                e.printStackTrace()
            } catch (e: Exception) {
                // Catch any other unexpected errors
                resultList.add(mapOf(
                    "packageName" to packageName,
                    "appName" to "Error Getting Name ($packageName)", // Fallback name
                    "totalTimeInForeground" to totalTimeInForeground
                ))
                e.printStackTrace()
            }
        }
        return resultList
    }
}
