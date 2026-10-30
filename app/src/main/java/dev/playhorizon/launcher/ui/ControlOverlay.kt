package dev.playhorizon.launcher.ui

import android.annotation.SuppressLint
import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.AttributeSet
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.Toast
import dev.playhorizon.launcher.R
import dev.playhorizon.launcher.core.HorizonNativeBridge

/**
 * ControlOverlay:
 * Full Zalith/Pojav-style multi-touch virtual controls overlay.
 * Supports:
 * - Multi-touch tracking per pointer_id (simultaneous D-pad + camera aim + PRI attack/mine)
 * - Dual Mode: Menu (Virtual Mouse) vs In-Game (D-Pad & Actions)
 * - 4 Touch schemes (D-Pad / Joystick, Tap / Crosshair)
 * - Hotbar 1-9 direct selection
 */
@SuppressLint("ClickableViewAccessibility")
class ControlOverlay @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    private val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    var touchpadView: VirtualTouchpadView? = null
        private set

    private var leftContainer: View? = null
    private var rightContainer: View? = null
    private var hotbarContainer: View? = null
    private var topBar: ViewGroup? = null
    private var btnGui: Button? = null
    private var btnMouse: Button? = null

    var isGuiVisible = true
        private set

    var touchScheme: Int = 2 // 0: Joy+Tap, 1: Joy+Cross, 2: DPad+Tap, 3: DPad+Cross

    init {
        LayoutInflater.from(context).inflate(R.layout.activity_game, this, true)
        setupViews()
    }

    private fun setupViews() {
        touchpadView = findViewById(R.id.virtualTouchpadView)
        leftContainer = findViewById(R.id.leftControlsContainer)
        rightContainer = findViewById(R.id.rightControlsContainer)
        hotbarContainer = findViewById(R.id.hotbarContainer)
        topBar = findViewById(R.id.topBar)
        btnGui = findViewById(R.id.btnGui)
        btnMouse = findViewById(R.id.btnMouse)

        setupTopBar()
        setupMovement()
        setupActions()
        setupHotbar()
    }

    fun updateGrabState(isGrabbed: Boolean) {
        if (isGrabbed) {
            // In-game mode: show movement, enable camera freelook
            if (isGuiVisible) {
                leftContainer?.visibility = View.VISIBLE
                rightContainer?.visibility = View.VISIBLE
                hotbarContainer?.visibility = View.VISIBLE
            }
            touchpadView?.isMouseMode = false
            btnMouse?.setBackgroundResource(R.drawable.bg_control_button)
        } else {
            // Menu / inventory mode: hide movement, enable virtual mouse cursor
            leftContainer?.visibility = View.GONE
            hotbarContainer?.visibility = View.GONE
            if (isGuiVisible) {
                rightContainer?.visibility = View.VISIBLE
            }
            touchpadView?.isMouseMode = true
            btnMouse?.setBackgroundResource(R.drawable.bg_control_button_active)
        }
    }

    private fun setupTopBar() {
        // 1. GUI Visibility Toggle
        btnGui?.setOnClickListener {
            triggerHaptic()
            isGuiVisible = !isGuiVisible
            leftContainer?.visibility = if (isGuiVisible) View.VISIBLE else View.GONE
            rightContainer?.visibility = if (isGuiVisible) View.VISIBLE else View.GONE
            hotbarContainer?.visibility = if (isGuiVisible) View.VISIBLE else View.GONE

            topBar?.let { bar ->
                for (i in 0 until bar.childCount) {
                    val child = bar.getChildAt(i)
                    if (child.id != R.id.btnGui) {
                        child.visibility = if (isGuiVisible) View.VISIBLE else View.GONE
                    }
                }
            }
            btnGui?.alpha = if (isGuiVisible) 1.0f else 0.45f
        }

        // 2. Virtual Mouse Mode Toggle
        btnMouse?.setOnClickListener {
            triggerHaptic()
            touchpadView?.let { tp ->
                tp.isMouseMode = !tp.isMouseMode
                if (tp.isMouseMode) {
                    btnMouse?.setBackgroundResource(R.drawable.bg_control_button_active)
                    Toast.makeText(context, "Virtual Mouse ON", Toast.LENGTH_SHORT).show()
                } else {
                    btnMouse?.setBackgroundResource(R.drawable.bg_control_button)
                    Toast.makeText(context, "Freelook ON", Toast.LENGTH_SHORT).show()
                }
            }
        }

        // 3. Android Soft Keyboard Toggle
        findViewById<Button>(R.id.btnKbd)?.setOnClickListener {
            triggerHaptic()
            val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.toggleSoftInput(InputMethodManager.SHOW_FORCED, 0)
        }

        // 4. Utility Keys
        bindKeyButton(R.id.btnEsc, KeyEvent.KEYCODE_ESCAPE)
        bindKeyButton(R.id.btnF3, KeyEvent.KEYCODE_F3)
        bindKeyButton(R.id.btnF5, KeyEvent.KEYCODE_F5)
        bindKeyButton(R.id.btnChat, KeyEvent.KEYCODE_T)
        bindKeyButton(R.id.btnTab, KeyEvent.KEYCODE_TAB)
        bindKeyButton(R.id.btnInv, KeyEvent.KEYCODE_E)
    }

    private fun setupMovement() {
        // D-Pad Movement (W, A, S, D)
        bindKeyButton(R.id.btnUp, KeyEvent.KEYCODE_W)
        bindKeyButton(R.id.btnLeft, KeyEvent.KEYCODE_A)
        bindKeyButton(R.id.btnDown, KeyEvent.KEYCODE_S)
        bindKeyButton(R.id.btnRight, KeyEvent.KEYCODE_D)

        // Center Sneak Button (Shift)
        bindKeyButton(R.id.btnSneak, KeyEvent.KEYCODE_SHIFT_LEFT)

        // Sprint Button (Ctrl)
        bindKeyButton(R.id.btnSprint, KeyEvent.KEYCODE_CTRL_LEFT)
    }

    private fun setupActions() {
        // PRI: Attack / Mine (Left Click, continuous hold supported)
        bindMouseButton(R.id.btnAttack, HorizonNativeBridge.MOUSE_LEFT)

        // SEC: Use / Place / Eat (Right Click)
        bindMouseButton(R.id.btnPlace, HorizonNativeBridge.MOUSE_RIGHT)

        // JUMP: Space
        bindKeyButton(R.id.btnJump, KeyEvent.KEYCODE_SPACE)

        // DROP: Q
        bindKeyButton(R.id.btnDrop, KeyEvent.KEYCODE_Q)
    }

    private fun setupHotbar() {
        // Slots 1 through 9
        val hotbarIds = intArrayOf(
            R.id.slot1, R.id.slot2, R.id.slot3,
            R.id.slot4, R.id.slot5, R.id.slot6,
            R.id.slot7, R.id.slot8, R.id.slot9
        )
        val keyCodes = intArrayOf(
            KeyEvent.KEYCODE_1, KeyEvent.KEYCODE_2, KeyEvent.KEYCODE_3,
            KeyEvent.KEYCODE_4, KeyEvent.KEYCODE_5, KeyEvent.KEYCODE_6,
            KeyEvent.KEYCODE_7, KeyEvent.KEYCODE_8, KeyEvent.KEYCODE_9
        )

        for (i in hotbarIds.indices) {
            bindKeyButton(hotbarIds[i], keyCodes[i])
        }
    }

    private fun bindKeyButton(buttonId: Int, androidKeyCode: Int) {
        val button = findViewById<Button>(buttonId) ?: return
        button.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                    triggerHaptic()
                    button.isPressed = true
                    HorizonNativeBridge.safeSendKey(androidKeyCode, true)
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_CANCEL -> {
                    button.isPressed = false
                    HorizonNativeBridge.safeSendKey(androidKeyCode, false)
                    true
                }
                else -> false
            }
        }
    }

    private fun bindMouseButton(buttonId: Int, mouseButton: Int) {
        val button = findViewById<Button>(buttonId) ?: return
        button.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                    triggerHaptic()
                    button.isPressed = true
                    HorizonNativeBridge.safeSendMouseButton(mouseButton, true)
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_CANCEL -> {
                    button.isPressed = false
                    HorizonNativeBridge.safeSendMouseButton(mouseButton, false)
                    true
                }
                else -> false
            }
        }
    }

    private fun triggerHaptic() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createOneShot(14, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(14)
            }
        } catch (ignored: Exception) {}
    }
}
