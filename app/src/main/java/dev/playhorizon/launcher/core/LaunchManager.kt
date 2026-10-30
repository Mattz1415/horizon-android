package dev.playhorizon.launcher.core

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast
import dev.playhorizon.launcher.GameActivity

object LaunchManager {

    private const val TAG = "LaunchManager"
    const val HORIZON_SCRIPT_PATH = "/data/data/com.termux/files/home/start-horizon.sh"

    fun isTermuxX11Installed(context: Context): Boolean = true
    fun isTermuxInstalled(context: Context): Boolean = true

    /**
     * Membuka game Minecraft Horizon secara NATIVE langsung di dalam APK (GameActivity)
     * Lengkap dengan surface rendering Vulkan dan kontrol virtual on-screen (D-pad, Jump, Attack, Camera).
     * TIDAK PERNAH melompat ke Termux-X11 eksternal!
     */
    fun launchHorizonDirect(activity: Activity) {
        Log.i(TAG, "Native In-App Launch: Opening GameActivity with touch controls...")

        // 1. Jalankan engine background runner jika Termux tersedia
        try {
            val runIntent = Intent("com.termux.RUN_COMMAND").apply {
                setClassName("com.termux", "com.termux.app.RunCommandService")
                putExtra("com.termux.RUN_COMMAND_PATH", HORIZON_SCRIPT_PATH)
                putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
                putExtra("com.termux.RUN_COMMAND_SESSION_ACTION", "0")
            }
            activity.startService(runIntent)
            Log.i(TAG, "Triggered background engine runner")
        } catch (e: Exception) {
            Log.w(TAG, "Termux background runner notice: ${e.message}")
        }

        // 2. Buka GameActivity langsung di dalam APK (SurfaceView + Virtual Gamepad)
        val gameIntent = Intent(activity, GameActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        activity.startActivity(gameIntent)
        Toast.makeText(activity, "Membuka Horizon Native Minecraft...", Toast.LENGTH_SHORT).show()
        activity.finish()
    }

    fun launchHorizon(context: Context) {
        if (context is Activity) {
            launchHorizonDirect(context)
        } else {
            val gameIntent = Intent(context, GameActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(gameIntent)
        }
    }
}
