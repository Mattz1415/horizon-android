package dev.playhorizon.launcher

import android.annotation.SuppressLint
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.Button
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import dev.playhorizon.launcher.core.AssetManagerService
import dev.playhorizon.launcher.core.HorizonNativeBridge

class GameActivity : AppCompatActivity(), SurfaceHolder.Callback {

    companion object {
        private const val TAG = "GameActivity"
    }

    private lateinit var surfaceView: SurfaceView
    private lateinit var assetManager: AssetManagerService
    private var vibrator: Vibrator? = null

    private var lastTouchX = 0f
    private var lastTouchY = 0f

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        hideSystemUI()

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(R.layout.activity_game)

        assetManager = AssetManagerService(this)
        try {
            assetManager.prepareDirectories()
        } catch (e: Exception) {
            Log.e(TAG, "prepareDirectories failed: ${e.message}")
        }

        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator

        surfaceView = findViewById(R.id.gameSurfaceView)
        surfaceView.holder.addCallback(this)

        setupTouchControls()
        setupCameraLookArea()
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

    @SuppressLint("ClickableViewAccessibility")
    private fun bindKeyButton(button: Button?, keyCode: Int) {
        button?.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    triggerHaptic()
                    HorizonNativeBridge.safeSendKeyEvent(keyCode, true)
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    HorizonNativeBridge.safeSendKeyEvent(keyCode, false)
                    true
                }
                else -> false
            }
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun bindMouseButton(button: Button?, mouseButton: Int) {
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

    private fun setupTouchControls() {
        // D-Pad Movement
        bindKeyButton(findViewById(R.id.btnUp), HorizonNativeBridge.KEY_W)
        bindKeyButton(findViewById(R.id.btnLeft), HorizonNativeBridge.KEY_A)
        bindKeyButton(findViewById(R.id.btnDown), HorizonNativeBridge.KEY_S)
        bindKeyButton(findViewById(R.id.btnRight), HorizonNativeBridge.KEY_D)
        bindKeyButton(findViewById(R.id.btnSneak), HorizonNativeBridge.KEY_SHIFT)

        // Action Buttons
        bindKeyButton(findViewById(R.id.btnJump), HorizonNativeBridge.KEY_SPACE)
        bindMouseButton(findViewById(R.id.btnAttack), HorizonNativeBridge.MOUSE_LEFT)
        bindMouseButton(findViewById(R.id.btnPlace), HorizonNativeBridge.MOUSE_RIGHT)

        // Top Utility Buttons
        bindKeyButton(findViewById(R.id.btnEsc), HorizonNativeBridge.KEY_ESC)
        bindKeyButton(findViewById(R.id.btnF3), HorizonNativeBridge.KEY_F3)
        bindKeyButton(findViewById(R.id.btnChat), HorizonNativeBridge.KEY_T)
        bindKeyButton(findViewById(R.id.btnInv), HorizonNativeBridge.KEY_E)

    }

    @SuppressLint("ClickableViewAccessibility")
    private fun setupCameraLookArea() {
        val cameraArea = findViewById<View>(R.id.touchCameraArea)
        cameraArea?.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    lastTouchX = event.x
                    lastTouchY = event.y
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.x - lastTouchX
                    val deltaY = event.y - lastTouchY
                    HorizonNativeBridge.safeSendMouseMotion(deltaX, deltaY)
                    lastTouchX = event.x
                    lastTouchY = event.y
                    true
                }
                else -> false
            }
        }
    }

    // --- SurfaceHolder.Callback Implementation ---
    override fun surfaceCreated(holder: SurfaceHolder) {
        val width = surfaceView.width.takeIf { it > 0 } ?: 1280
        val height = surfaceView.height.takeIf { it > 0 } ?: 720
        val dataDir = assetManager.horizonDataDir.absolutePath

        try {
            val ok = HorizonNativeBridge.safeInit(holder.surface, width, height, dataDir)
            if (!ok) {
                Log.w(TAG, "Native bridge initialized in standby mode (${width}x${height})")
            }
        } catch (e: Throwable) {
            Log.e(TAG, "surfaceCreated error: ${e.message}", e)
        }
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        try {
            HorizonNativeBridge.safeResize(width, height)
        } catch (e: Throwable) {
            Log.e(TAG, "surfaceChanged error: ${e.message}", e)
        }
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        try {
            HorizonNativeBridge.safeStop()
        } catch (e: Throwable) {
            Log.e(TAG, "surfaceDestroyed error: ${e.message}", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            HorizonNativeBridge.safeStop()
        } catch (e: Throwable) {
            Log.e(TAG, "onDestroy error: ${e.message}", e)
        }
    }
}
