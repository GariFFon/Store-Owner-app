package com.exanor.exanor

import io.flutter.app.FlutterApplication
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build

class ExanorApplication : FlutterApplication() {

    override fun onCreate() {
        super.onCreate()
        createOrderNotificationChannel()
    }

    private fun createOrderNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val notificationManager = getSystemService(NotificationManager::class.java) ?: return

                val channelId = "exanor_order_channel_v2"

                // Delete old channels so Android picks up new sound/settings
                try {
                    notificationManager.deleteNotificationChannel("exanor_order_channel")
                } catch (_: Exception) {}

                // Check if channel already exists
                val existingChannel = notificationManager.getNotificationChannel(channelId)
                if (existingChannel != null) {
                    android.util.Log.d("ExanorApp", "Notification channel already exists")
                    return
                }

                val channelName = "Order Notifications"
                val channelDescription = "Notifications for new store orders"

                val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_HIGH).apply {
                    description = channelDescription
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                    enableLights(true)
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC

                    // Set custom sound using ALARM stream (works even on silent mode)
                    val soundUri = Uri.parse("android.resource://${packageName}/raw/store_notification")
                    setSound(
                        soundUri,
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )

                    setBypassDnd(true)
                }

                notificationManager.createNotificationChannel(channel)
                android.util.Log.d("ExanorApp", "Order notification channel created with custom alarm sound")
            } catch (e: Exception) {
                android.util.Log.e("ExanorApp", "Failed to create notification channel: ${e.message}")
            }
        }
    }
}
