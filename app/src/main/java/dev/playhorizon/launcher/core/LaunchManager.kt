package dev.playhorizon.launcher.core

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.Toast

object LaunchManager {

    private const val TAG = "LaunchManager"
    const val HORIZON_SCRIPT_PATH = "/data/data/com.termux/files/home/start-horizon.sh"

    fun isTermuxX11Installed(context: Context): Boolean = true
    fun isTermuxInstalled(context: Context): Boolean = true

    /**
     * Membuka game Minecraft Horizon secara instan saat aplikasi dibuka.
     * Mengirim RUN_COMMAND ke Termux untuk menjalankan engine di background
     * dan langsung membawa layar game ke foreground secara seamless.
     */
    fun launchHorizonDirect(activity: Activity) {
        Log.i(TAG, "Instant Boot: Launching Horizon Minecraft directly...")

        // 1. Eksekusi script start-horizon.sh di Termux via RunCommandService
        try {
            val runIntent = Intent("com.termux.RUN_COMMAND").apply {
                setClassName("com.termux", "com.termux.app.RunCommandService")
                putExtra("com.termux.RUN_COMMAND_PATH", HORIZON_SCRIPT_PATH)
                putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
                putExtra("com.termux.RUN_COMMAND_SESSION_ACTION", "0")
            }
            activity.startService(runIntent)
            Log.i(TAG, "Sent RUN_COMMAND to Termux")
        } catch (e: Exception) {
            Log.e(TAG, "Error triggering Termux RUN_COMMAND: ${e.message}")
        }

        // 2. Buka jendela game langsung ke layar depan
        val x11Intent = activity.packageManager.getLaunchIntentForPackage("com.termux.x11")
            ?: Intent().apply {
                component = ComponentName("com.termux.x11", "com.termux.x11.MainActivity")
            }
        x11Intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)

        try {
            activity.startActivity(x11Intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error launching game window: ${e.message}")
        }

        Toast.makeText(activity, "Memulai Horizon Minecraft (Adreno 619)...", Toast.LENGTH_SHORT).show()

        // Selesaikan activity launcher setelah transisi sehingga game langsung di layar
        Handler(Looper.getMainLooper()).postDelayed({
            activity.finish()
        }, 1000)
    }

    fun launchHorizon(context: Context) {
        if (context is Activity) {
            launchHorizonDirect(context)
        } else {
            val runIntent = Intent("com.termux.RUN_COMMAND").apply {
                setClassName("com.termux", "com.termux.app.RunCommandService")
                putExtra("com.termux.RUN_COMMAND_PATH", HORIZON_SCRIPT_PATH)
                putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
                putExtra("com.termux.RUN_COMMAND_SESSION_ACTION", "0")
            }
            context.startService(runIntent)
        }
    }
}
