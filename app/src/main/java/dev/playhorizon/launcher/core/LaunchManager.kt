package dev.playhorizon.launcher.core

import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast
import dev.playhorizon.launcher.GameActivity

object LaunchManager {

    private const val TAG = "LaunchManager"
    const val HORIZON_SCRIPT_PATH = "/data/data/com.termux/files/home/start-horizon.sh"

    /**
     * Menjalankan Horizon Engine di background dan membuka GameActivity native secara langsung.
     * Tidak lagi melompat ke aplikasi eksternal (Termux-X11), persis seperti Pojav/Zalith Launcher.
     */
    fun launchHorizon(context: Context) {
        Log.i(TAG, "Initiating Horizon Native In-App Game Session...")

        // 1. Jalankan engine background runner via Termux RUN_COMMAND jika tersedia
        try {
            val runIntent = Intent("com.termux.RUN_COMMAND").apply {
                setClassName("com.termux", "com.termux.app.RunCommandService")
                putExtra("com.termux.RUN_COMMAND_PATH", HORIZON_SCRIPT_PATH)
                putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
                putExtra("com.termux.RUN_COMMAND_SESSION_ACTION", "0")
            }
            context.startService(runIntent)
            Log.i(TAG, "Sent RUN_COMMAND intent to start Horizon engine in background")
        } catch (e: Exception) {
            Log.w(TAG, "Note: Background RUN_COMMAND service: ${e.message}")
        }

        // 2. Buka GameActivity langsung di dalam launcher APK (Native SurfaceView + Virtual Touch Controls)
        val gameIntent = Intent(context, GameActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(gameIntent)
        Toast.makeText(context, "Membuka Horizon Native Game...", Toast.LENGTH_SHORT).show()
    }
}
