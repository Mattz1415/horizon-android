package dev.playhorizon.launcher

import android.annotation.SuppressLint
import android.app.NativeActivity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.system.Os
import android.util.Log
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import dev.playhorizon.launcher.core.HorizonNativeBridge
import dev.playhorizon.launcher.service.GameService
import dev.playhorizon.launcher.ui.ControlOverlay

class GameActivity : NativeActivity() {

    companion object {
        private const val TAG = "GameActivity"
        private const val GRAB_CHECK_INTERVAL_MS = 100L
    }

    private var controlOverlay: ControlOverlay? = null
    private var lastGrabbedState: Boolean? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val grabStatePoller = object : Runnable {
        override fun run() {
            checkGrabState()
            mainHandler.postDelayed(this, GRAB_CHECK_INTERVAL_MS)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Configure native environment variables before native library loads
        setupEnvironmentFromIntent(intent)

        super.onCreate(savedInstanceState)
        hideSystemUI()
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Start foreground game service to prevent OS from killing game process
        GameService.start(this)

        // Attach Zalith/Pojav style Virtual Controls Overlay
        setupControlOverlay()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent?.let { setupEnvironmentFromIntent(it) }
    }

    private fun setupEnvironmentFromIntent(intent: Intent?) {
        if (intent == null) return
        try {
            intent.getStringExtra("HORIZON_USERNAME")?.let {
                Os.setenv("HORIZON_USERNAME", it, true)
            }
            val threads = intent.getIntExtra("HORIZON_WORKER_THREADS", 4)
            Os.setenv("HORIZON_WORKER_THREADS", threads.toString(), true)

            intent.getStringExtra("HORIZON_RESOURCES_DIR")?.let {
                Os.setenv("HORIZON_RESOURCES_DIR", it, true)
                Os.setenv("HORIZON_RESOURCES", it, true)
            }

            val dataDir = filesDir.absolutePath
            Os.setenv("HORIZON_DATA_DIR", dataDir, true)
            Os.setenv("HORIZON_HOME", dataDir, true)
        } catch (e: Exception) {
            Log.w(TAG, "Error configuring environment: ${e.message}")
        }
    }

    private fun setupControlOverlay() {
        try {
            val overlay = ControlOverlay(this)
            controlOverlay = overlay

            val scheme = intent?.getIntExtra("HORIZON_TOUCH_SCHEME", 2) ?: 2
            overlay.touchScheme = scheme

            addContentView(
                overlay,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
            )

            // Start grab-state poller to automatically toggle Menu vs In-Game controls
            mainHandler.removeCallbacks(grabStatePoller)
            mainHandler.post(grabStatePoller)

            Log.i(TAG, "ControlOverlay attached successfully in :game process!")
        } catch (e: Exception) {
            Log.e(TAG, "Error displaying ControlOverlay: ${e.message}", e)
        }
    }

    private fun checkGrabState() {
        val isGrabbed = HorizonNativeBridge.isCursorGrabbed()
        if (lastGrabbedState == null || isGrabbed != lastGrabbedState) {
            lastGrabbedState = isGrabbed
            controlOverlay?.updateGrabState(isGrabbed)
        }
    }

    private fun hideSystemUI() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or android.view.View.SYSTEM_UI_FLAG_FULLSCREEN
            )
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(grabStatePoller)
        GameService.stop(this)
        super.onDestroy()

        // Clean process termination in :game process so all Rust/JVM/GPU memory is completely reclaimed
        Log.i(TAG, "GameActivity destroyed: killing :game process cleanly")
        Process.killProcess(Process.myPid())
    }
}
