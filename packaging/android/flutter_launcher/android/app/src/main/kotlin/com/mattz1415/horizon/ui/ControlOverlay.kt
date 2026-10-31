// ControlOverlay.kt
// Kotlin / Android / on-screen gamepad for the Rust engine
package com.mattz1415.horizon.ui

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.os.SystemClock
import android.util.AttributeSet
import android.view.InputDevice
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import com.mattz1415.horizon.R

@SuppressLint("ClickableViewAccessibility")
class ControlOverlay @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    var touchpadView: VirtualTouchpadView? = null
        private set

    private var leftContainer: View? = null
    private var rightContainer: View? = null
    private var hotbarContainer: View? = null
    private var topBar: ViewGroup? = null
    private var btnGui: Button? = null
    private var btnMouse: Button? = null

    /** Keys currently held by the overlay, so repeated pointer events never double-fire. */
    private val heldKeys = HashSet<Int>()
    private var heldPrimary = false
    private var heldSecondary = false

    var isGuiVisible = true
        private set

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
            if (isGuiVisible) {
                leftContainer?.visibility = View.VISIBLE
                rightContainer?.visibility = View.VISIBLE
                hotbarContainer?.visibility = View.VISIBLE
            }
            touchpadView?.isMouseMode = false
            btnMouse?.setBackgroundResource(R.drawable.bg_control_button)
        } else {
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
        btnGui?.setOnClickListener {
            it.performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
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

        btnMouse?.setOnClickListener {
            it.performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
            touchpadView?.let { tp ->
                tp.isMouseMode = !tp.isMouseMode
                btnMouse?.setBackgroundResource(
                    if (tp.isMouseMode) R.drawable.bg_control_button_active else R.drawable.bg_control_button
                )
            }
        }

        // The engine owns the soft keyboard. Opening the chat screen is what makes the
        // engine ask for it, so this button sends T and lets the game raise the IME.
        bindKeyButton(R.id.btnKbd, KeyEvent.KEYCODE_T)

        bindKeyButton(R.id.btnEsc, KeyEvent.KEYCODE_ESCAPE)
        bindKeyButton(R.id.btnF3, KeyEvent.KEYCODE_F3)
        bindKeyButton(R.id.btnF5, KeyEvent.KEYCODE_F5)
        bindKeyButton(R.id.btnChat, KeyEvent.KEYCODE_T)
        bindKeyButton(R.id.btnTab, KeyEvent.KEYCODE_TAB)
        bindKeyButton(R.id.btnInv, KeyEvent.KEYCODE_E)
    }

    private fun setupMovement() {
        bindKeyButton(R.id.btnUp, KeyEvent.KEYCODE_W)
        bindKeyButton(R.id.btnLeft, KeyEvent.KEYCODE_A)
        bindKeyButton(R.id.btnDown, KeyEvent.KEYCODE_S)
        bindKeyButton(R.id.btnRight, KeyEvent.KEYCODE_D)
        bindKeyButton(R.id.btnSneak, KeyEvent.KEYCODE_SHIFT_LEFT)
        bindKeyButton(R.id.btnSprint, KeyEvent.KEYCODE_CTRL_LEFT)
    }

    private fun setupActions() {
        bindMouseButton(R.id.btnAttack, primary = true)
        bindMouseButton(R.id.btnPlace, primary = false)
        bindKeyButton(R.id.btnJump, KeyEvent.KEYCODE_SPACE)
        bindKeyButton(R.id.btnDrop, KeyEvent.KEYCODE_Q)
    }

    private fun setupHotbar() {
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
                MotionEvent.ACTION_DOWN -> {
                    button.isPressed = true
                    if (heldKeys.add(androidKeyCode)) sendKeyEvent(androidKeyCode, isDown = true)
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    button.isPressed = false
                    if (heldKeys.remove(androidKeyCode)) sendKeyEvent(androidKeyCode, isDown = false)
                    true
                }
                else -> false
            }
        }
    }

    private fun bindMouseButton(buttonId: Int, primary: Boolean) {
        val button = findViewById<Button>(buttonId) ?: return
        button.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    button.isPressed = true
                    if (primary) {
                        if (!heldPrimary) {
                            heldPrimary = true
                            sendMouseButton(primary = true, isDown = true)
                        }
                    } else if (!heldSecondary) {
                        heldSecondary = true
                        sendMouseButton(primary = false, isDown = true)
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    button.isPressed = false
                    if (primary) {
                        if (heldPrimary) {
                            heldPrimary = false
                            sendMouseButton(primary = true, isDown = false)
                        }
                    } else if (heldSecondary) {
                        heldSecondary = false
                        sendMouseButton(primary = false, isDown = false)
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun sendKeyEvent(keyCode: Int, isDown: Boolean) {
        val act = context as? Activity ?: return
        try {
            val action = if (isDown) KeyEvent.ACTION_DOWN else KeyEvent.ACTION_UP
            act.dispatchKeyEvent(KeyEvent(action, keyCode))
        } catch (t: Throwable) {
            android.util.Log.w("ControlOverlay", "Key $keyCode dispatch failed: ${t.message}")
        }
    }

    private fun sendMouseButton(primary: Boolean, isDown: Boolean) {
        val act = context as? Activity ?: return
        val x = touchpadView?.mouseX ?: (width / 2f)
        val y = touchpadView?.mouseY ?: (height / 2f)
        try {
            // Generic motion first: the engine reads mouse button state from it.
            val generic = obtainMouseEvent(primary, isDown, x, y)
            val handled = act.dispatchGenericMotionEvent(generic)
            generic.recycle()
            if (!handled) {
                val touch = obtainMouseEvent(primary, isDown, x, y)
                act.dispatchTouchEvent(touch)
                touch.recycle()
            }
        } catch (t: Throwable) {
            android.util.Log.w("ControlOverlay", "Mouse dispatch failed: ${t.message}")
        }
    }

    private fun obtainMouseEvent(primary: Boolean, isDown: Boolean, x: Float, y: Float): MotionEvent {
        val now = SystemClock.uptimeMillis()
        val buttonState = if (primary) MotionEvent.BUTTON_PRIMARY else MotionEvent.BUTTON_SECONDARY
        val action = if (isDown) MotionEvent.ACTION_DOWN else MotionEvent.ACTION_UP
        val properties = arrayOf(MotionEvent.PointerProperties().apply {
            id = 0
            toolType = MotionEvent.TOOL_TYPE_MOUSE
        })
        val coords = arrayOf(MotionEvent.PointerCoords().apply {
            this.x = x
            this.y = y
            pressure = if (isDown) 1.0f else 0.0f
        })
        return MotionEvent.obtain(
            now, now, action,
            1, properties, coords,
            0, buttonState, 1.0f, 1.0f,
            0, 0, InputDevice.SOURCE_MOUSE or InputDevice.SOURCE_TOUCHSCREEN, 0
        )
    }
}
