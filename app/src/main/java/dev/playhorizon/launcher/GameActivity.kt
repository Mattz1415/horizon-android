package dev.playhorizon.launcher

import android.app.NativeActivity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.Button
import android.widget.Toast
import dev.playhorizon.launcher.core.AssetManagerService
import dev.playhorizon.launcher.core.HorizonNativeBridge

class GameActivity : NativeActivity() {

    companion object {
        private const val TAG = "GameActivity"
        private const val STORAGE_PERMISSION_CODE = 1001
    }

    private lateinit var assetManager: AssetManagerService
    private var vibrator: Vibrator? = null

    private var lastTouchX = 0f
    private var lastTouchY = 0f

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        hideSystemUI()
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        assetManager = AssetManagerService(this)
        try {
            assetManager.prepareDirectories()
        } catch (e: Exception) {
            Log.e(TAG, "prepareDirectories error: ${e.message}")
        }

        checkAndRequestStoragePermissions()

        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator

        // Inflate virtual touch controls overlay and add on top of native surface
        val overlayView = LayoutInflater.from(this).inflate(R.layout.activity_game, null)
        overlayView.findViewById<View>(R.id.gameSurfaceView)?.visibility = View.GONE

        addContentView(
            overlayView,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )

        setupTouchControls(overlayView)
        setupCameraLookArea(overlayView)
    }

    private fun checkAndRequestStoragePermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (!Environment.isExternalStorageManager()) {
                try {
                    val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                    Toast.makeText(this, "Izinkan akses file agar Horizon dapat memuat aset Minecraft", Toast.LENGTH_LONG).show()
                } catch (e: Exception) {
                    try {
                        val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                        startActivity(intent)
                    } catch (ignored: Exception) {}
                }
            }
        } else {
            requestPermissions(
                arrayOf(
                    android.Manifest.permission.READ_EXTERNAL_STORAGE,
                    android.Manifest.permission.WRITE_EXTERNAL_STORAGE
                ),
                STORAGE_PERMISSION_CODE
            )
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
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            )
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            hideSystemUI()
        }
    }

    private fun triggerHaptic() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createOneShot(12, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(12)
            }
        } catch (ignored: Exception) {}
    }

    private fun bindKeyButton(overlay: View, buttonId: Int, androidKeyCode: Int) {
        val button = overlay.findViewById<Button>(buttonId)
        button?.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    triggerHaptic()
                    val time = System.currentTimeMillis()
                    dispatchKeyEvent(KeyEvent(time, time, KeyEvent.ACTION_DOWN, androidKeyCode, 0))
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    val time = System.currentTimeMillis()
                    dispatchKeyEvent(KeyEvent(time, time, KeyEvent.ACTION_UP, androidKeyCode, 0))
                    true
                }
                else -> false
            }
        }
    }

    private fun bindMouseButton(overlay: View, buttonId: Int, mouseButton: Int) {
        val button = overlay.findViewById<Button>(buttonId)
        button?.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    triggerHaptic()
                    HorizonNativeBridge.safeSendMouseButton(mouseButton, true)
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    HorizonNativeBridge.safeSendMouseButton(mouseButton, false)
                    true
                }
                else -> false
            }
        }
    }

    private fun setupTouchControls(overlay: View) {
        // Left Virtual D-Pad
        bindKeyButton(overlay, R.id.btnUp, KeyEvent.KEYCODE_W)
        bindKeyButton(overlay, R.id.btnLeft, KeyEvent.KEYCODE_A)
        bindKeyButton(overlay, R.id.btnDown, KeyEvent.KEYCODE_S)
        bindKeyButton(overlay, R.id.btnRight, KeyEvent.KEYCODE_D)
        bindKeyButton(overlay, R.id.btnSneak, KeyEvent.KEYCODE_SHIFT_LEFT)

        // Right Action Buttons
        bindKeyButton(overlay, R.id.btnJump, KeyEvent.KEYCODE_SPACE)
        bindMouseButton(overlay, R.id.btnAttack, HorizonNativeBridge.MOUSE_LEFT)
        bindMouseButton(overlay, R.id.btnPlace, HorizonNativeBridge.MOUSE_RIGHT)

        // Top Utility Buttons
        bindKeyButton(overlay, R.id.btnEsc, KeyEvent.KEYCODE_ESCAPE)
        bindKeyButton(overlay, R.id.btnF3, KeyEvent.KEYCODE_F3)
        bindKeyButton(overlay, R.id.btnChat, KeyEvent.KEYCODE_T)
        bindKeyButton(overlay, R.id.btnInv, KeyEvent.KEYCODE_E)
    }

    private fun setupCameraLookArea(overlay: View) {
        val cameraArea = overlay.findViewById<View>(R.id.touchCameraArea)
        cameraArea?.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    lastTouchX = event.x
                    lastTouchY = event.y
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = (event.x - lastTouchX) * 1.5f
                    val deltaY = (event.y - lastTouchY) * 1.5f
                    HorizonNativeBridge.safeSendMouseMotion(deltaX, deltaY)
                    lastTouchX = event.x
                    lastTouchY = event.y
                    true
                }
                else -> false
            }
        }
    }
}
