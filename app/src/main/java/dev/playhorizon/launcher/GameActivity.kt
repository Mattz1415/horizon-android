package dev.playhorizon.launcher

import android.annotation.SuppressLint
import android.app.NativeActivity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.PopupWindow
import android.widget.Toast
import dev.playhorizon.launcher.core.AssetManagerService
import dev.playhorizon.launcher.core.HorizonNativeBridge
import dev.playhorizon.launcher.ui.VirtualTouchpadView

class GameActivity : NativeActivity() {

    companion object {
        private const val TAG = "GameActivity"
        private const val STORAGE_PERMISSION_CODE = 1001
        private const val GRAB_CHECK_INTERVAL_MS = 100L
    }

    private lateinit var assetManager: AssetManagerService
    private var vibrator: Vibrator? = null
    private var touchpadView: VirtualTouchpadView? = null
    private var overlayRootView: View? = null
    private var isOverlayAttached = false

    private var isGuiVisible = true
    private var lastGrabbedState: Boolean? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val grabStatePoller = object : Runnable {
        override fun run() {
            checkGrabState()
            mainHandler.postDelayed(this, GRAB_CHECK_INTERVAL_MS)
        }
    }

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

        // Attach touch controls & virtual mouse directly to Activity content view hierarchy
        showTouchControlsOverlay()
    }

    private fun showTouchControlsOverlay() {
        if (isFinishing || isDestroyed || isOverlayAttached) return

        try {
            val inflater = LayoutInflater.from(this)
            val overlayView = inflater.inflate(R.layout.activity_game, null)
            overlayRootView = overlayView

            addContentView(
                overlayView,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
            )
            isOverlayAttached = true

            touchpadView = overlayView.findViewById(R.id.virtualTouchpadView)

            // Initial Menu state: hide gameplay D-pad, keep PRI/SEC action buttons available, enable virtual mouse
            overlayView.findViewById<View>(R.id.leftControlsContainer)?.visibility = View.GONE
            overlayView.findViewById<View>(R.id.rightControlsContainer)?.visibility = View.VISIBLE
            touchpadView?.isMouseMode = true
            overlayView.findViewById<Button>(R.id.btnMouse)?.setBackgroundResource(R.drawable.bg_control_button_active)

            setupTopBarControls(overlayView)
            setupMovementControls(overlayView)
            setupActionControls(overlayView)

            // Start grab-state poller to automatically toggle Menu vs In-Game controls
            mainHandler.removeCallbacks(grabStatePoller)
            mainHandler.post(grabStatePoller)

            Log.i(TAG, "Virtual touch controls and mouse overlay attached successfully via addContentView!")
        } catch (e: Exception) {
            Log.e(TAG, "Error displaying touch controls overlay: ${e.message}", e)
        }
    }

    private fun checkGrabState() {
        val isGrabbed = HorizonNativeBridge.isCursorGrabbed()
        if (lastGrabbedState == null || isGrabbed != lastGrabbedState) {
            lastGrabbedState = isGrabbed
            updateControlsForGrabState(isGrabbed)
        }
    }

    private fun updateControlsForGrabState(isGrabbed: Boolean) {
        val overlay = overlayRootView ?: return
        val leftControls = overlay.findViewById<View>(R.id.leftControlsContainer)
        val rightControls = overlay.findViewById<View>(R.id.rightControlsContainer)
        val btnMouse = overlay.findViewById<Button>(R.id.btnMouse)

        if (isGrabbed) {
            // IN-GAME / PLAYING (Cursor grabbed by engine):
            // Show gameplay buttons (D-Pad, Jump, Pri, Sec) if GUI overlay is enabled
            if (isGuiVisible) {
                leftControls?.visibility = View.VISIBLE
                rightControls?.visibility = View.VISIBLE
            }
            // Switch touchpad to 3D freelook / camera rotation
            touchpadView?.isMouseMode = false
            btnMouse?.setBackgroundResource(R.drawable.bg_control_button)
        } else {
            // MENU / TITLE SCREEN / INVENTORY (Cursor ungrabbed):
            // Hide movement D-pad, keep PRI/SEC action buttons available if GUI is enabled
            leftControls?.visibility = View.GONE
            rightControls?.visibility = if (isGuiVisible) View.VISIBLE else View.GONE
            // Switch touchpad to virtual mouse pointer (with direct tap-to-click)
            touchpadView?.isMouseMode = true
            btnMouse?.setBackgroundResource(R.drawable.bg_control_button_active)
        }
    }

    override fun dispatchTouchEvent(ev: MotionEvent): Boolean {
        if (window.superDispatchTouchEvent(ev)) {
            return true
        }
        return true
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val keyCode = event.keyCode
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || 
            keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || 
            keyCode == KeyEvent.KEYCODE_VOLUME_MUTE) {
            return super.dispatchKeyEvent(event)
        }
        val isPressed = event.action == KeyEvent.ACTION_DOWN
        HorizonNativeBridge.safeSendKey(keyCode, isPressed)
        return true
    }

    override fun onResume() {
        super.onResume()
        hideSystemUI()
        mainHandler.removeCallbacks(grabStatePoller)
        mainHandler.post(grabStatePoller)
    }

    override fun onPause() {
        mainHandler.removeCallbacks(grabStatePoller)
        super.onPause()
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
            if (!isOverlayAttached) {
                showTouchControlsOverlay()
            }
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacksAndMessages(null)
        overlayRootView = null
        touchpadView = null
        isOverlayAttached = false
        super.onDestroy()
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
    private fun bindKeyButton(overlay: View, buttonId: Int, androidKeyCode: Int) {
        val button = overlay.findViewById<Button>(buttonId) ?: return
        button.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    triggerHaptic()
                    button.isPressed = true
                    HorizonNativeBridge.safeSendKey(androidKeyCode, true)
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    button.isPressed = false
                    HorizonNativeBridge.safeSendKey(androidKeyCode, false)
                    true
                }
                else -> false
            }
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun bindMouseButton(overlay: View, buttonId: Int, mouseButton: Int) {
        val button = overlay.findViewById<Button>(buttonId) ?: return
        button.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    triggerHaptic()
                    button.isPressed = true
                    HorizonNativeBridge.safeSendMouseButton(mouseButton, true)
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    button.isPressed = false
                    HorizonNativeBridge.safeSendMouseButton(mouseButton, false)
                    true
                }
                else -> false
            }
        }
    }

    private fun setupTopBarControls(overlay: View) {
        // 1. GUI Button: Hide / Show on-screen controls
        val btnGui = overlay.findViewById<Button>(R.id.btnGui)
        val leftControls = overlay.findViewById<View>(R.id.leftControlsContainer)
        val rightControls = overlay.findViewById<View>(R.id.rightControlsContainer)
        val topBar = overlay.findViewById<ViewGroup>(R.id.topBar)

        btnGui?.setOnClickListener {
            triggerHaptic()
            isGuiVisible = !isGuiVisible
            val shouldShowGameControls = isGuiVisible && (lastGrabbedState == true)
            leftControls?.visibility = if (shouldShowGameControls) View.VISIBLE else View.GONE
            rightControls?.visibility = if (isGuiVisible) View.VISIBLE else View.GONE

            // Hide other buttons on top bar, keep only GUI button
            topBar?.let { bar ->
                for (i in 0 until bar.childCount) {
                    val child = bar.getChildAt(i)
                    if (child.id != R.id.btnGui) {
                        child.visibility = if (isGuiVisible) View.VISIBLE else View.GONE
                    }
                }
            }
            btnGui.alpha = if (isGuiVisible) 1.0f else 0.45f
        }

        // 2. MOUSE Button: Toggle Virtual Mouse pointer mode
        val btnMouse = overlay.findViewById<Button>(R.id.btnMouse)
        btnMouse?.setOnClickListener {
            triggerHaptic()
            touchpadView?.let { tp ->
                tp.isMouseMode = !tp.isMouseMode
                if (tp.isMouseMode) {
                    btnMouse.setBackgroundResource(R.drawable.bg_control_button_active)
                    Toast.makeText(this, "Virtual Mouse ON (Touchpad)", Toast.LENGTH_SHORT).show()
                } else {
                    btnMouse.setBackgroundResource(R.drawable.bg_control_button)
                    Toast.makeText(this, "Virtual Mouse OFF (Camera Look)", Toast.LENGTH_SHORT).show()
                }
            }
        }

        // 3. KBD Button: Open Android Soft Keyboard
        val btnKbd = overlay.findViewById<Button>(R.id.btnKbd)
        btnKbd?.setOnClickListener {
            triggerHaptic()
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.toggleSoftInput(InputMethodManager.SHOW_FORCED, 0)
        }

        // 4. Utility Keys
        bindKeyButton(overlay, R.id.btnEsc, KeyEvent.KEYCODE_ESCAPE)
        bindKeyButton(overlay, R.id.btnF3, KeyEvent.KEYCODE_F3)
        bindKeyButton(overlay, R.id.btnF5, KeyEvent.KEYCODE_F5)
        bindKeyButton(overlay, R.id.btnChat, KeyEvent.KEYCODE_T)
        bindKeyButton(overlay, R.id.btnTab, KeyEvent.KEYCODE_TAB)
        bindKeyButton(overlay, R.id.btnInv, KeyEvent.KEYCODE_E)
    }

    private fun setupMovementControls(overlay: View) {
        // D-Pad Movement (W, A, S, D + Sneak/Shift)
        bindKeyButton(overlay, R.id.btnUp, KeyEvent.KEYCODE_W)
        bindKeyButton(overlay, R.id.btnLeft, KeyEvent.KEYCODE_A)
        bindKeyButton(overlay, R.id.btnDown, KeyEvent.KEYCODE_S)
        bindKeyButton(overlay, R.id.btnRight, KeyEvent.KEYCODE_D)
        bindKeyButton(overlay, R.id.btnSneak, KeyEvent.KEYCODE_SHIFT_LEFT)

        // SPRINT Button (Ctrl)
        bindKeyButton(overlay, R.id.btnSprint, KeyEvent.KEYCODE_CTRL_LEFT)
    }

    private fun setupActionControls(overlay: View) {
        // Action Buttons (PRI, SEC, JUMP, DROP)
        bindMouseButton(overlay, R.id.btnAttack, HorizonNativeBridge.MOUSE_LEFT)
        bindMouseButton(overlay, R.id.btnPlace, HorizonNativeBridge.MOUSE_RIGHT)
        bindKeyButton(overlay, R.id.btnJump, KeyEvent.KEYCODE_SPACE)
        bindKeyButton(overlay, R.id.btnDrop, KeyEvent.KEYCODE_Q)
    }
}
