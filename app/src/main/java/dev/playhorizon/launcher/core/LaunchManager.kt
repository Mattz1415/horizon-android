package dev.playhorizon.launcher.core

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast
import dev.playhorizon.launcher.GameActivity

object LaunchManager {

    private const val TAG = "LaunchManager"
    const val HORIZON_SCRIPT_PATH = "/data/data/com.termux/files/home/start-horizon.sh"

    fun isTermuxX11Installed(context: Context): Boolean {
        return try {
            context.packageManager.getPackageInfo("com.termux.x11", 0)
            true
        } catch (e: Exception) {
            false
        }
    }

    fun isTermuxInstalled(context: Context): Boolean {
        return try {
            context.packageManager.getPackageInfo("com.termux", 0)
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Menjalankan Horizon Engine via Termux RUN_COMMAND dan membuka layar game Termux:X11
     */
    fun launchHorizon(context: Context, useTouchOverlay: Boolean = false) {
        Log.i(TAG, "Initiating Horizon launch sequence (useTouchOverlay=$useTouchOverlay)...")

        // 1. Eksekusi script start-horizon.sh di Termux
        var termuxTriggered = false
        try {
            val runIntent = Intent("com.termux.RUN_COMMAND").apply {
                setClassName("com.termux", "com.termux.app.RunCommandService")
                putExtra("com.termux.RUN_COMMAND_PATH", HORIZON_SCRIPT_PATH)
                putExtra("com.termux.RUN_COMMAND_BACKGROUND", true)
                putExtra("com.termux.RUN_COMMAND_SESSION_ACTION", "0")
            }
            context.startService(runIntent)
            termuxTriggered = true
            Log.i(TAG, "Sent RUN_COMMAND intent to Termux successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Could not send RUN_COMMAND to Termux: ${e.message}")
        }

        // 2. Buka tampilan game
        if (useTouchOverlay) {
            // Mode Controller Overlay
            val gameIntent = Intent(context, GameActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(gameIntent)
        } else {
            // Mode Langsung ke Termux:X11
            val x11Intent = context.packageManager.getLaunchIntentForPackage("com.termux.x11")
                ?: Intent().apply {
                    component = ComponentName("com.termux.x11", "com.termux.x11.MainActivity")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }

            try {
                x11Intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(x11Intent)
                Toast.makeText(context, "Memuat Horizon Vulkan di Termux:X11...", Toast.LENGTH_SHORT).show()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to launch Termux:X11 directly, opening GameActivity: ${e.message}")
                val gameIntent = Intent(context, GameActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(gameIntent)
            }
        }
    }
}
