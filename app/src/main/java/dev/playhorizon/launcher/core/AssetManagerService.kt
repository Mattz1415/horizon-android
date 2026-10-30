package dev.playhorizon.launcher.core

import android.content.Context
import android.os.Environment
import android.system.Os
import android.util.Log
import java.io.File

class AssetManagerService(private val context: Context) {

    companion object {
        private const val TAG = "AssetManagerService"
        val SDCARD_HORIZON_DIR = File(Environment.getExternalStorageDirectory(), "horizon")
        val SDCARD_RESOURCES_DIR = File(SDCARD_HORIZON_DIR, "local/horizon-client/26.3")
    }

    val externalFilesDir: File
        get() = File(context.getExternalFilesDir(null), "horizon")

    val internalFilesDir: File
        get() = File(context.filesDir, "horizon")

    fun prepareDirectories() {
        try {
            SDCARD_HORIZON_DIR.mkdirs()
            externalFilesDir.mkdirs()
            internalFilesDir.mkdirs()
        } catch (ignored: Exception) {}

        // Setup environment variables for native Rust engine
        val targetResources = findValidResourcesDir()
        if (targetResources != null) {
            Log.i(TAG, "Found Minecraft assets at: ${targetResources.absolutePath}")
            try {
                Os.setenv("HORIZON_RESOURCES", targetResources.absolutePath, true)
                Os.setenv("HORIZON_HOME", SDCARD_HORIZON_DIR.absolutePath, true)
                Os.setenv("HORIZON_DATA_DIR", SDCARD_HORIZON_DIR.absolutePath, true)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to setenv: ${e.message}")
            }
        } else {
            Log.w(TAG, "Notice: horizon-resources.json not yet detected in standard paths")
        }
    }

    fun findValidResourcesDir(): File? {
        val candidates = listOf(
            SDCARD_RESOURCES_DIR,
            File(externalFilesDir, "local/horizon-client/26.3"),
            File(internalFilesDir, "local/horizon-client/26.3"),
            File("/data/data/com.termux/files/home/horizon/.local/horizon-client/26.3")
        )

        for (candidate in candidates) {
            val marker = File(candidate, "horizon-resources.json")
            if (marker.exists() && marker.length() > 0) {
                return candidate
            }
        }
        return null
    }

    fun isAssetsReady(): Boolean = findValidResourcesDir() != null
}
