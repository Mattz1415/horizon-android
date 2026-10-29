package dev.playhorizon.launcher.core

import android.content.Context
import android.view.Surface
import java.io.File

object HorizonNativeBridge {

    init {
        try {
            System.loadLibrary("horizon_bridge")
        } catch (e: UnsatisfiedLinkError) {
            e.printStackTrace()
        }
    }

    // Key Codes mapping to standard Minecraft controls
    const val KEY_W = 87
    const val KEY_A = 65
    const val KEY_S = 83
    const val KEY_D = 68
    const val KEY_SPACE = 32
    const val KEY_SHIFT = 16
    const val KEY_ESC = 27
    const val KEY_E = 69
    const val KEY_T = 84
    const val KEY_F3 = 114

    // Mouse Buttons
    const val MOUSE_LEFT = 1   // Attack / Break (PRI)
    const val MOUSE_RIGHT = 2  // Place / Use (SEC)
    const val MOUSE_MIDDLE = 3 // Pick Block

    fun getEngineLibraryPath(context: Context): String? {
        val nativeDir = context.applicationInfo.nativeLibraryDir
        val engineFile = File(nativeDir, "libhorizon_client.so")
        return if (engineFile.exists()) engineFile.absolutePath else null
    }

    external fun nativeInit(surface: Surface, width: Int, height: Int, dataDir: String): Boolean
    external fun nativeSendKeyEvent(keyCode: Int, isPressed: Boolean)
    external fun nativeSendMouseMotion(deltaX: Float, deltaY: Float)
    external fun nativeSendMouseButton(button: Int, isPressed: Boolean)
    external fun nativeResize(width: Int, height: Int)
    external fun nativeStop()
}
