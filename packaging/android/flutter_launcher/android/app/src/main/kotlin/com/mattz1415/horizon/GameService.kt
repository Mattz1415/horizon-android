// GameService.kt
// Kotlin / Android / foreground service pinning the :game process
package com.mattz1415.horizon

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.Process
import android.util.Log
import androidx.core.app.NotificationCompat

class GameService : Service() {

    companion object {
        private const val TAG = "GameService"
        const val CHANNEL_ID = "horizon_game_service_channel"
        const val NOTIFICATION_ID = 26301
        const val ACTION_START = "com.mattz1415.horizon.ACTION_START_GAME_SERVICE"
        const val ACTION_STOP = "com.mattz1415.horizon.ACTION_STOP_GAME_SERVICE"
        const val ACTION_FORCE_KILL = "com.mattz1415.horizon.ACTION_FORCE_KILL_GAME"

        fun start(context: Context) {
            val intent = Intent(context, GameService::class.java).apply { action = ACTION_START }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, GameService::class.java))
            } catch (t: Throwable) {
                Log.w(TAG, "stop: ${t.message}")
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_FORCE_KILL -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                Process.killProcess(Process.myPid())
                return START_NOT_STICKY
            }

            else -> {
                val notification = buildNotification()
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        startForeground(
                            NOTIFICATION_ID,
                            notification,
                            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                        )
                    } else {
                        startForeground(NOTIFICATION_ID, notification)
                    }
                } catch (t: Throwable) {
                    // Android 14+ refuses SPECIAL_USE without the manifest property.
                    // Falling back keeps the session alive instead of crashing the
                    // :game process with a ForegroundServiceDidNotStartInTime error.
                    Log.w(TAG, "startForeground failed: ${t.message}")
                    return START_NOT_STICKY
                }
            }
        }
        // The activity owns the wake lock while it is resumed. A sticky service
        // restarting itself forever only re-pinned the CPU and made the phone throttle.
        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Sesi Horizon",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Menjaga game tetap hidup saat pindah aplikasi"
            setShowBadge(false)
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val killIntent = Intent(this, KillReceiver::class.java).apply { action = ACTION_FORCE_KILL }
        val killPendingIntent = PendingIntent.getBroadcast(
            this,
            101,
            killIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val resumeIntent = Intent(this, HorizonGameActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            102,
            resumeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Horizon sedang berjalan")
            .setContentText("Tekan untuk kembali ke game")
            .setSmallIcon(R.drawable.launcher_icon)
            .setContentIntent(contentPendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Tutup game",
                killPendingIntent
            )
            .build()
    }

    class KillReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent?) {
            if (intent?.action == ACTION_FORCE_KILL) {
                Process.killProcess(Process.myPid())
            }
        }
    }
}
