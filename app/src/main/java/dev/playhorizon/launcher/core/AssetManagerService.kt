package dev.playhorizon.launcher.core

import android.content.Context
import java.io.File

class AssetManagerService(private val context: Context) {

    val horizonDataDir: File
        get() = File(context.getExternalFilesDir(null), "horizon")

    val clientVersionDir: File
        get() = File(horizonDataDir, "local/horizon-client/26.3")

    fun isAssetsReady(): Boolean {
        return clientVersionDir.exists() && clientVersionDir.isDirectory
    }

    fun prepareDirectories() {
        if (!horizonDataDir.exists()) {
            horizonDataDir.mkdirs()
        }
        if (!clientVersionDir.exists()) {
            clientVersionDir.mkdirs()
        }
    }
}
