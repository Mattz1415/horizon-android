// DownloadService.kt
// Kotlin / Android / foreground service that keeps the resource install alive
package com.mattz1415.horizon

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Promotes the main process while game files download or import, so switching to
 * another app no longer lets Android freeze the process and drop the socket.
 */
class DownloadService : Service() {

    companion object {
        private const val TAG = "DownloadService"
        const val CHANNEL_ID = "horizon_install_channel"
        const val NOTIFICATION_ID = 26302
        const val ACTION_START = "com.mattz1415.horizon.ACTION_START_INSTALL"
        const val ACTION_PAUSE = "com.mattz1415.horizon.ACTION_PAUSE_INSTALL"

        fun start(context: Context) {
            val intent = Intent(context, DownloadService::class.java).apply { action = ACTION_START }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (t: Throwable) {
                // Started from the background on Android 12+: the job still runs, only unprotected.
                Log.w(TAG, "start: ${t.message}")
            }
        }
    }

    private var wifiLock: WifiManager.WifiLock? = null
    private var lastPost = 0L
    private var lastPercent = -1
    private val sink = InstallHub.Sink { onEvent(it) }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_PAUSE) {
            InstallHub.pause(this)
            finish()
            return START_NOT_STICKY
        }
        val n = build("Menyiapkan unduhan", "Horizon sedang memasang file game", 0, true)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(NOTIFICATION_ID, n)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "startForeground failed: ${t.message}")
            stopSelf()
            return START_NOT_STICKY
        }
        holdWifi()
        InstallHub.attach(sink)
        return START_NOT_STICKY
    }

    private fun onEvent(e: Map<String, Any?>) {
        when (e["status"]) {
            "downloading" -> {
                val p = ((e["progress"] as? Number)?.toDouble() ?: 0.0).coerceIn(0.0, 1.0)
                val pct = (p * 100).toInt()
                val now = SystemClock.elapsedRealtime()
                // Notification updates are rate limited by the system; one a second is plenty.
                if (pct == lastPercent && now - lastPost < 1000) return
                if (now - lastPost < 500) return
                lastPost = now
                lastPercent = pct
                val stage = e["stage"] as? String ?: "Mengunduh"
                val detail = e["detail"] as? String ?: ""
                notify(build("$stage, $pct%", detail, pct, false))
            }
            "completed" -> {
                done("File game siap", "Buka Horizon untuk mulai main")
            }
            "paused" -> finish()
            "error" -> {
                val msg = e["error"] as? String ?: "Pemasangan berhenti"
                done("Pemasangan berhenti", msg)
            }
        }
    }

    private fun done(title: String, text: String) {
        finish()
        val n = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setSmallIcon(R.drawable.launcher_icon)
            .setContentIntent(openApp())
            .setAutoCancel(true)
            .setSilent(true)
            .build()
        notify(n, NOTIFICATION_ID + 1)
    }

    private fun finish() {
        InstallHub.detach(sink)
        releaseWifi()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun notify(n: Notification, id: Int = NOTIFICATION_ID) {
        try {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(id, n)
        } catch (_: Throwable) {}
    }

    private fun openApp(): PendingIntent {
        val open = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(this, 201, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun build(title: String, text: String, percent: Int, indeterminate: Boolean): Notification {
        val pause = PendingIntent.getService(
            this, 202,
            Intent(this, DownloadService::class.java).apply { action = ACTION_PAUSE },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.drawable.launcher_icon)
            .setContentIntent(openApp())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setProgress(100, percent, indeterminate)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .addAction(android.R.drawable.ic_media_pause, "Jeda", pause)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(CHANNEL_ID, "Pemasangan file game", NotificationManager.IMPORTANCE_LOW).apply {
            description = "Progres unduhan dan import file Minecraft 26.3"
            setShowBadge(false)
        }
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
    }

    @Suppress("DEPRECATION")
    private fun holdWifi() {
        if (wifiLock?.isHeld == true) return
        try {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return
            wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "horizon:install").apply {
                setReferenceCounted(false)
                acquire()
            }
        } catch (t: Throwable) {
            Log.w(TAG, "wifi lock: ${t.message}")
        }
    }

    private fun releaseWifi() {
        try { if (wifiLock?.isHeld == true) wifiLock?.release() } catch (_: Throwable) {}
        wifiLock = null
    }

    override fun onDestroy() {
        InstallHub.detach(sink)
        releaseWifi()
        super.onDestroy()
    }
}
