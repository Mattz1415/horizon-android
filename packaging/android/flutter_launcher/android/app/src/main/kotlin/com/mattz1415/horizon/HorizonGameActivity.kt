// HorizonGameActivity.kt
// Kotlin / Android / NativeActivity host for the Rust engine (:game process)
package com.mattz1415.horizon

import android.app.NativeActivity
import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.PowerManager
import android.provider.MediaStore
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import java.io.File
import java.io.FileOutputStream

class HorizonGameActivity : NativeActivity() {

    companion object {
        private const val TAG = "HorizonGameActivity"

        init {
            System.loadLibrary("horizon_android")
        }

        external fun nativeInitEnvironment(
            gameDataDir: String,
            resourcesDir: String,
            ramMb: Int,
            threads: Int,
            backend: String,
            touchScheme: Int,
            username: String
        )

        /** Hides the system IME owned by the engine (crates/horizon-client/src/android/native_ime.rs). */
        @JvmStatic
        external fun nativeHideKeyboard()

        @JvmStatic
        var currentInstance: HorizonGameActivity? = null
            private set

        /**
         * The engine owns the only EditText that is allowed to hold focus. Kotlin must not
         * add a second one: the IME only serves the view that has focus, so a competing
         * proxy silently blocks the keyboard (that was the "keyboard never appears" bug).
         */
        @JvmStatic
        fun requestHideIme() {
            currentInstance?.runOnUiThread {
                try {
                    nativeHideKeyboard()
                } catch (t: Throwable) {
                    Log.w(TAG, "requestHideIme: ${t.message}")
                }
            }
        }

        @JvmStatic
        fun saveScreenshotMediaStore(pngBytes: ByteArray, filename: String): Boolean {
            val act = currentInstance ?: return false
            return act.saveToMediaStore(pngBytes, filename)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var controlOverlay: com.mattz1415.horizon.ui.ControlOverlay? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        val gameDataDir = File(filesDir, "game_data").apply { mkdirs() }.absolutePath
        val resourcesDir = intent.getStringExtra("EXTRA_RESOURCES_DIR")
            ?: File(filesDir, "resources/26.3").absolutePath
        val ramMb = intent.getIntExtra("EXTRA_RAM_MB", 2048)
        val threads = intent.getIntExtra("EXTRA_WORKER_THREADS", 4)
        val backend = intent.getStringExtra("EXTRA_BACKEND") ?: "vulkan"
        val touchScheme = intent.getIntExtra("EXTRA_TOUCH_SCHEME", 0)
        val username = intent.getStringExtra("EXTRA_USERNAME") ?: "HorizonPlayer"

        nativeInitEnvironment(gameDataDir, resourcesDir, ramMb, threads, backend, touchScheme, username)

        super.onCreate(savedInstanceState)
        currentInstance = this

        // The IME must be allowed to resize this window, otherwise the engine never
        // learns the keyboard height and the editor stays hidden behind it.
        window.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or
                    WindowManager.LayoutParams.SOFT_INPUT_STATE_UNSPECIFIED
        )
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
        wakeLock = pm?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "horizon:game_active")?.apply {
            setReferenceCounted(false)
        }

        try {
            GameService.start(this)
        } catch (t: Throwable) {
            Log.w(TAG, "Foreground service unavailable: ${t.message}")
        }

        // Defer the overlay inflation to the next frame: building ~40 buttons inside
        // onCreate delays the engine's first frame and shows up as a startup ANR.
        window.decorView.post { attachControlOverlay() }
    }

    override fun onResume() {
        super.onResume()
        acquireWakeLock()
        hideSystemUi()
        // The engine may still be starting; the overlay is idempotent.
        if (controlOverlay == null) window.decorView.post { attachControlOverlay() }
    }

    override fun onPause() {
        releaseWakeLock()
        super.onPause()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) hideSystemUi()
    }

    private fun acquireWakeLock() {
        try {
            if (wakeLock?.isHeld != true) wakeLock?.acquire()
        } catch (t: Throwable) {
            Log.w(TAG, "Wake lock: ${t.message}")
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (t: Throwable) {
            Log.w(TAG, "Wake lock release: ${t.message}")
        }
    }

    private fun attachControlOverlay() {
        if (controlOverlay != null) return
        try {
            val overlay = com.mattz1415.horizon.ui.ControlOverlay(this)
            controlOverlay = overlay
            addContentView(
                overlay,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
            )
        } catch (t: Throwable) {
            Log.e(TAG, "Control overlay failed: ${t.message}", t)
        }
    }

    private fun hideSystemUi() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
            val controller = window.insetsController ?: return
            controller.hide(
                android.view.WindowInsets.Type.statusBars() or
                        android.view.WindowInsets.Type.navigationBars()
            )
            controller.systemBarsBehavior =
                android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                            or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            or View.SYSTEM_UI_FLAG_FULLSCREEN
                    )
        }
    }

    private fun saveToMediaStore(pngBytes: ByteArray, filename: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, filename)
                    put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                    put(
                        MediaStore.Images.Media.RELATIVE_PATH,
                        Environment.DIRECTORY_PICTURES + File.separator + "Horizon"
                    )
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }

                val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                    ?: return false

                contentResolver.openOutputStream(uri)?.use { os ->
                    os.write(pngBytes)
                }

                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                true
            } else {
                val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
                val targetDir = File(picturesDir, "Horizon").apply { mkdirs() }
                FileOutputStream(File(targetDir, filename)).use { it.write(pngBytes) }
                true
            }
        } catch (t: Throwable) {
            Log.e(TAG, "Screenshot: ${t.message}")
            false
        }
    }

    override fun onDestroy() {
        controlOverlay = null
        releaseWakeLock()
        super.onDestroy()
        currentInstance = null
        try {
            GameService.stop(this)
        } catch (_: Throwable) {
        }
        // Never Process.killProcess here. Android calls onDestroy for configuration
        // changes and recents swipes; killing the process there produced the endless
        // "Horizon has stopped" / ANR loop the phone kept showing.
    }
}
