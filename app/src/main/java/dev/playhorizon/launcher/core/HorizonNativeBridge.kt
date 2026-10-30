package dev.playhorizon.launcher.core

import android.content.Context
import android.util.Log
import android.view.Surface
import java.io.File

object HorizonNativeBridge {

    private const val TAG = "HorizonNativeBridge"
    private var isBridgeLoaded = false

    init {
        try {
            // Coba muat c++_shared jika ada
            try {
                System.loadLibrary("c++_shared")
            } catch (ignored: Throwable) {}

            System.loadLibrary("horizon_bridge")
            isBridgeLoaded = true
            Log.i(TAG, "libhorizon_bridge.so loaded successfully!")
        } catch (e: Throwable) {
            Log.e(TAG, "Warning: Native bridge library not loaded: ${e.message}")
            isBridgeLoaded = false
        }
    }

    fun isLoaded(): Boolean = isBridgeLoaded

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

    fun safeInit(surface: Surface, width: Int, height: Int, dataDir: String): Boolean {
        if (!isBridgeLoaded) return false
        return try {
            nativeInit(surface, width, height, dataDir)
        } catch (e: Throwable) {
            Log.e(TAG, "nativeInit exception: ${e.message}", e)
            false
        }
    }

    fun safeSendKeyEvent(keyCode: Int, isPressed: Boolean) {
        if (!isBridgeLoaded) return
        try {
            nativeSendKeyEvent(keyCode, isPressed)
        } catch (e: Throwable) {
            Log.e(TAG, "nativeSendKeyEvent exception: ${e.message}")
        }
    }

    fun safeSendMouseMotion(deltaX: Float, deltaY: Float) {
        if (!isBridgeLoaded) return
        try {
            nativeSendMouseMotion(deltaX, deltaY)
        } catch (e: Throwable) {
            Log.e(TAG, "nativeSendMouseMotion exception: ${e.message}")
        }
    }

    fun safeSendMouseButton(button: Int, isPressed: Boolean) {
        if (!isBridgeLoaded) return
        try {
            nativeSendMouseButton(button, isPressed)
        } catch (e: Throwable) {
            Log.e(TAG, "nativeSendMouseButton exception: ${e.message}")
        }
    }

    fun safeResize(width: Int, height: Int) {
        if (!isBridgeLoaded) return
        try {
            nativeResize(width, height)
        } catch (e: Throwable) {
            Log.e(TAG, "nativeResize exception: ${e.message}")
        }
    }

    fun safeStop() {
        if (!isBridgeLoaded) return
        try {
            nativeStop()
        } catch (e: Throwable) {
            Log.e(TAG, "nativeStop exception: ${e.message}")
        }
    }

    private external fun nativeInit(surface: Surface, width: Int, height: Int, dataDir: String): Boolean
    private external fun nativeSendKeyEvent(keyCode: Int, isPressed: Boolean)
    private external fun nativeSendMouseMotion(deltaX: Float, deltaY: Float)
    private external fun nativeSendMouseButton(button: Int, isPressed: Boolean)
    private external fun nativeResize(width: Int, height: Int)
    private external fun nativeStop()
}
