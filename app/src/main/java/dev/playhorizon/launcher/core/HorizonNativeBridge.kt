package dev.playhorizon.launcher.core

import android.util.Log

object HorizonNativeBridge {

    private const val TAG = "HorizonNativeBridge"
    private var isBridgeLoaded = false

    init {
        try {
            System.loadLibrary("horizon_client")
            isBridgeLoaded = true
            Log.i(TAG, "libhorizon_client.so loaded into bridge successfully!")
        } catch (e: Throwable) {
            Log.w(TAG, "Bridge notice: ${e.message}")
            try {
                System.loadLibrary("horizon_bridge")
                isBridgeLoaded = true
            } catch (ignored: Throwable) {}
        }
    }

    fun isLoaded(): Boolean = isBridgeLoaded

    // Mouse Buttons
    const val MOUSE_LEFT = 1   // Attack / Break (PRI)
    const val MOUSE_RIGHT = 2  // Place / Use (SEC)
    const val MOUSE_MIDDLE = 3 // Pick Block

    fun safeSendMouseMotion(deltaX: Float, deltaY: Float) {
        try {
            nativeSendMouseMotion(deltaX, deltaY)
        } catch (e: Throwable) {
            Log.w(TAG, "nativeSendMouseMotion notice: ${e.message}")
        }
    }

    fun safeSendCursorPos(x: Float, y: Float) {
        try {
            nativeSendCursorPos(x, y)
        } catch (e: Throwable) {
            Log.w(TAG, "nativeSendCursorPos notice: ${e.message}")
        }
    }

    fun safeSendMouseButton(button: Int, isPressed: Boolean) {
        try {
            nativeSendMouseButton(button, isPressed)
        } catch (e: Throwable) {
            Log.w(TAG, "nativeSendMouseButton notice: ${e.message}")
        }
    }

    private external fun nativeSendMouseMotion(deltaX: Float, deltaY: Float)
    private external fun nativeSendCursorPos(x: Float, y: Float)
    private external fun nativeSendMouseButton(button: Int, isPressed: Boolean)
}
