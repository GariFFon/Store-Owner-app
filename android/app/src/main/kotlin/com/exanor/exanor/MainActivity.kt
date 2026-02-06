package com.exanor.exanor

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.AudioAttributes
import android.content.Context
import android.content.res.AssetFileDescriptor
import android.os.Handler
import android.os.Looper

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.exanor.exanor/volume"
    private var mediaPlayer: MediaPlayer? = null
    private var originalAlarmVolume: Int = 0
    private val handler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playAlarmSoundAtMaxVolume" -> {
                    try {
                        playAlarmSound()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PLAY_ERROR", e.message, null)
                    }
                }
                "stopAlarmSound" -> {
                    try {
                        stopAlarmSound()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_ERROR", e.message, null)
                    }
                }
                "setAlarmVolumeMax" -> {
                    try {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                        val currentVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
                        audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)
                        result.success(currentVolume)
                    } catch (e: Exception) {
                        result.error("VOLUME_ERROR", e.message, null)
                    }
                }
                "restoreAlarmVolume" -> {
                    try {
                        val volume = call.argument<Int>("volume") ?: 0
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        audioManager.setStreamVolume(AudioManager.STREAM_ALARM, volume, 0)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("VOLUME_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun playAlarmSound() {
        // Stop any existing playback
        stopAlarmSound()

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        // Save current alarm volume
        originalAlarmVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
        
        // Set alarm volume to MAX
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)

        // Create MediaPlayer with STREAM_ALARM
        mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            
            // Load the asset file
            val afd: AssetFileDescriptor = assets.open("flutter_assets/assets/order_sound/WhatsApp Audio 2026-02-06 at 21.04.43.mpeg").use { inputStream ->
                // Create a temp approach - use setDataSource with asset
                val tempFile = java.io.File.createTempFile("alarm_sound", ".mp3", cacheDir)
                tempFile.outputStream().use { outputStream ->
                    inputStream.copyTo(outputStream)
                }
                tempFile.deleteOnExit()
                setDataSource(tempFile.absolutePath)
                tempFile
            }
            
            setVolume(1.0f, 1.0f) // Max volume on player
            prepare()
            start()
            
            setOnCompletionListener {
                // Restore original volume after playback
                restoreVolume()
            }
        }

        // Also restore volume after 15 seconds as backup
        handler.postDelayed({
            restoreVolume()
        }, 15000)
    }

    private fun stopAlarmSound() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
            restoreVolume()
        } catch (e: Exception) {
            // Ignore errors when stopping
        }
    }

    private fun restoreVolume() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, originalAlarmVolume, 0)
        } catch (e: Exception) {
            // Ignore errors
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAlarmSound()
        handler.removeCallbacksAndMessages(null)
    }
}
