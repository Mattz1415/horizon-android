// ControlOverlay.kt
// Kotlin / Android / on-screen gamepad & custom touch layout studio for the Rust engine
package com.mattz1415.horizon.ui

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.SharedPreferences
import android.graphics.drawable.Drawable
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
import android.widget.TextView
import com.mattz1415.horizon.R
import org.json.JSONObject
import java.io.File

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
    private var dpadBox: View? = null

    private var btnGui: Button? = null
    private var btnMouse: Button? = null
    private var btnLayout: Button? = null

    // Touch Layout Studio
    private var editorPanel: ViewGroup? = null
    private var tvEditorTitle: TextView? = null
    private var isEditMode = false
    private var selectedView: View? = null

    private val customizableViews = mutableListOf<View>()
    private val originalBackgrounds = mutableMapOf<View, Drawable?>()

    /** Keys currently held by the overlay, so repeated pointer events never double-fire. */
    private val heldKeys = HashSet<Int>()
    private var heldPrimary = false
    private var heldSecondary = false

    var isGuiVisible = true
        private set

    private val prefs: SharedPreferences by lazy {
        context.getSharedPreferences("horizon_touch_layout", Context.MODE_PRIVATE)
    }

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
        dpadBox = findViewById(R.id.dpadBox)

        btnGui = findViewById(R.id.btnGui)
        btnMouse = findViewById(R.id.btnMouse)
        btnLayout = findViewById(R.id.btnLayout)
        editorPanel = findViewById(R.id.editorPanel)
        tvEditorTitle = findViewById(R.id.tvEditorTitle)

        // Register customizable view clusters
        dpadBox?.let { registerCustomizable(it) }
        findViewById<View>(R.id.btnSprint)?.let { registerCustomizable(it) }
        findViewById<View>(R.id.btnAttack)?.let { registerCustomizable(it) }
        findViewById<View>(R.id.btnPlace)?.let { registerCustomizable(it) }
        findViewById<View>(R.id.btnJump)?.let { registerCustomizable(it) }
        findViewById<View>(R.id.btnDrop)?.let { registerCustomizable(it) }
        hotbarContainer?.let { registerCustomizable(it) }

        setupTopBar()
        setupMovement()
        setupActions()
        setupHotbar()
        setupEditorControls()

        loadCustomLayout()
    }

    private fun registerCustomizable(view: View) {
        if (!customizableViews.contains(view)) {
            customizableViews.add(view)
            originalBackgrounds[view] = view.background
        }
    }

    fun updateGrabState(isGrabbed: Boolean) {
        if (isEditMode) return
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

        btnLayout?.setOnClickListener {
            it.performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
            toggleEditMode()
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
        bindKeyButton(R.id.btnUp, KeyEvent.KEYCODE_W, delegateToDpad = true)
        bindKeyButton(R.id.btnLeft, KeyEvent.KEYCODE_A, delegateToDpad = true)
        bindKeyButton(R.id.btnDown, KeyEvent.KEYCODE_S, delegateToDpad = true)
        bindKeyButton(R.id.btnRight, KeyEvent.KEYCODE_D, delegateToDpad = true)
        bindKeyButton(R.id.btnSneak, KeyEvent.KEYCODE_SHIFT_LEFT, delegateToDpad = true)
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
            bindKeyButton(hotbarIds[i], keyCodes[i], delegateToHotbar = true)
        }
    }

    private fun bindKeyButton(
        buttonId: Int,
        androidKeyCode: Int,
        delegateToDpad: Boolean = false,
        delegateToHotbar: Boolean = false
    ) {
        val button = findViewById<Button>(buttonId) ?: return
        button.setOnTouchListener { v, event ->
            if (isEditMode) {
                val target = when {
                    delegateToDpad -> dpadBox ?: v
                    delegateToHotbar -> hotbarContainer ?: v
                    else -> v
                }
                return@setOnTouchListener handleEditDrag(target, event)
            }
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
        button.setOnTouchListener { v, event ->
            if (isEditMode) {
                return@setOnTouchListener handleEditDrag(v, event)
            }
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

    // Touch Layout Studio Drag & Edit Logic
    private var dragStartX = 0f
    private var dragStartY = 0f
    private var initialTransX = 0f
    private var initialTransY = 0f

    private fun handleEditDrag(view: View, event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                dragStartX = event.rawX
                dragStartY = event.rawY
                initialTransX = view.translationX
                initialTransY = view.translationY
                selectView(view)
                view.performHapticFeedback(android.view.HapticFeedbackConstants.CLOCK_TICK)
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - dragStartX
                val dy = event.rawY - dragStartY
                view.translationX = initialTransX + dx
                view.translationY = initialTransY + dy
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                return true
            }
        }
        return false
    }

    private fun selectView(view: View) {
        if (selectedView != view) {
            clearSelectionHighlight()
            selectedView = view
            view.setBackgroundResource(R.drawable.bg_control_button_editing)
            val name = resources.getResourceEntryName(view.id)
            tvEditorTitle?.text = "TERPILIH: $name • GESER UNTUK ATUR POSISI"
        }
    }

    private fun clearSelectionHighlight() {
        selectedView?.let { v ->
            val orig = originalBackgrounds[v]
            if (orig != null) {
                v.background = orig
            } else {
                v.setBackgroundResource(R.drawable.bg_control_button)
            }
        }
        selectedView = null
    }

    private fun toggleEditMode() {
        if (isEditMode) {
            exitEditMode(save = true)
        } else {
            enterEditMode()
        }
    }

    private fun enterEditMode() {
        isEditMode = true
        btnLayout?.text = "SELESAI"
        btnLayout?.setBackgroundResource(R.drawable.bg_control_button_active)

        // Make all controls visible while editing
        leftContainer?.visibility = View.VISIBLE
        rightContainer?.visibility = View.VISIBLE
        hotbarContainer?.visibility = View.VISIBLE
        editorPanel?.visibility = View.VISIBLE

        tvEditorTitle?.text = "TOUCH LAYOUT STUDIO • SENTUH & GESER TOMBOL"
    }

    private fun exitEditMode(save: Boolean) {
        if (save) {
            saveCustomLayout()
        }
        clearSelectionHighlight()
        isEditMode = false
        btnLayout?.text = "LAYOUT"
        btnLayout?.setBackgroundResource(R.drawable.bg_control_button)
        editorPanel?.visibility = View.GONE
    }

    private fun setupEditorControls() {
        findViewById<Button>(R.id.btnPresetDefault)?.setOnClickListener {
            it.performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
            applyPreset("DEFAULT")
        }
        findViewById<Button>(R.id.btnPresetClaw)?.setOnClickListener {
            it.performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
            applyPreset("CLAW")
        }
        findViewById<Button>(R.id.btnPresetErgo)?.setOnClickListener {
            it.performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
            applyPreset("ERGO")
        }
        findViewById<Button>(R.id.btnPresetMinimal)?.setOnClickListener {
            it.performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
            applyPreset("MINIMAL")
        }

        findViewById<Button>(R.id.btnScaleDown)?.setOnClickListener {
            it.performHapticFeedback(android.view.HapticFeedbackConstants.CLOCK_TICK)
            adjustScale(-0.1f)
        }
        findViewById<Button>(R.id.btnScaleUp)?.setOnClickListener {
            it.performHapticFeedback(android.view.HapticFeedbackConstants.CLOCK_TICK)
            adjustScale(0.1f)
        }
        findViewById<Button>(R.id.btnAlphaDown)?.setOnClickListener {
            it.performHapticFeedback(android.view.HapticFeedbackConstants.CLOCK_TICK)
            adjustAlpha(-0.15f)
        }
        findViewById<Button>(R.id.btnAlphaUp)?.setOnClickListener {
            it.performHapticFeedback(android.view.HapticFeedbackConstants.CLOCK_TICK)
            adjustAlpha(0.15f)
        }
        findViewById<Button>(R.id.btnResetLayout)?.setOnClickListener {
            it.performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
            applyPreset("DEFAULT")
        }
        findViewById<Button>(R.id.btnSaveLayout)?.setOnClickListener {
            it.performHapticFeedback(android.view.HapticFeedbackConstants.VIRTUAL_KEY)
            exitEditMode(save = true)
        }
    }

    private fun adjustScale(delta: Float) {
        val targets = if (selectedView != null) listOf(selectedView!!) else customizableViews
        for (v in targets) {
            val s = (v.scaleX + delta).coerceIn(0.6f, 1.8f)
            v.scaleX = s
            v.scaleY = s
        }
    }

    private fun adjustAlpha(delta: Float) {
        val targets = if (selectedView != null) listOf(selectedView!!) else customizableViews
        for (v in targets) {
            v.alpha = (v.alpha + delta).coerceIn(0.2f, 1.0f)
        }
    }

    private fun applyPreset(preset: String) {
        when (preset) {
            "DEFAULT" -> {
                for (v in customizableViews) {
                    v.translationX = 0f
                    v.translationY = 0f
                    v.scaleX = 1.0f
                    v.scaleY = 1.0f
                    v.alpha = 1.0f
                }
            }
            "CLAW" -> {
                // 4-finger claw layout: Attack/Place top right, Jump bottom right, Sprint top left
                findViewById<View>(R.id.btnAttack)?.let {
                    it.translationX = 25f; it.translationY = -210f; it.scaleX = 1.15f; it.scaleY = 1.15f
                }
                findViewById<View>(R.id.btnPlace)?.let {
                    it.translationX = -65f; it.translationY = -210f; it.scaleX = 1.15f; it.scaleY = 1.15f
                }
                findViewById<View>(R.id.btnSprint)?.let {
                    it.translationX = -80f; it.translationY = -140f; it.scaleX = 1.1f; it.scaleY = 1.1f
                }
                findViewById<View>(R.id.btnJump)?.let {
                    it.translationX = -10f; it.translationY = 10f; it.scaleX = 1.25f; it.scaleY = 1.25f
                }
                findViewById<View>(R.id.btnDrop)?.let {
                    it.translationX = 15f; it.translationY = -95f; it.scaleX = 0.9f; it.scaleY = 0.9f
                }
                dpadBox?.let {
                    it.translationX = 10f; it.translationY = 0f; it.scaleX = 1.0f; it.scaleY = 1.0f
                }
            }
            "ERGO" -> {
                // Ergonomic natural thumb arcs
                dpadBox?.let {
                    it.translationX = 25f; it.translationY = -20f; it.scaleX = 1.05f; it.scaleY = 1.05f
                }
                findViewById<View>(R.id.btnSprint)?.let {
                    it.translationX = 15f; it.translationY = -15f; it.scaleX = 1.05f; it.scaleY = 1.05f
                }
                findViewById<View>(R.id.btnJump)?.let {
                    it.translationX = -15f; it.translationY = 10f; it.scaleX = 1.2f; it.scaleY = 1.2f
                }
                findViewById<View>(R.id.btnAttack)?.let {
                    it.translationX = -30f; it.translationY = -30f; it.scaleX = 1.15f; it.scaleY = 1.15f
                }
                findViewById<View>(R.id.btnPlace)?.let {
                    it.translationX = -45f; it.translationY = 20f; it.scaleX = 1.15f; it.scaleY = 1.15f
                }
                findViewById<View>(R.id.btnDrop)?.let {
                    it.translationX = 10f; it.translationY = -25f; it.scaleX = 0.95f; it.scaleY = 0.95f
                }
            }
            "MINIMAL" -> {
                // Clean screen: high transparency & compact borders
                for (v in customizableViews) {
                    v.scaleX = 0.8f
                    v.scaleY = 0.8f
                    v.alpha = 0.45f
                }
                dpadBox?.let { it.translationX = -15f; it.translationY = 15f }
                findViewById<View>(R.id.btnJump)?.let { it.translationX = 15f; it.translationY = 15f }
                findViewById<View>(R.id.btnAttack)?.let { it.translationX = 15f; it.translationY = 15f }
                findViewById<View>(R.id.btnPlace)?.let { it.translationX = 15f; it.translationY = 15f }
                hotbarContainer?.let { it.translationY = 15f }
            }
        }
        tvEditorTitle?.text = "PRESET '$preset' DITERAPKAN"
    }

    private fun saveCustomLayout() {
        try {
            val root = JSONObject()
            for (v in customizableViews) {
                val name = resources.getResourceEntryName(v.id)
                val obj = JSONObject().apply {
                    put("x", v.translationX.toDouble())
                    put("y", v.translationY.toDouble())
                    put("s", v.scaleX.toDouble())
                    put("a", v.alpha.toDouble())
                }
                root.put(name, obj)
            }
            val jsonStr = root.toString()
            prefs.edit().putString("layout_json", jsonStr).apply()

            // Also persist to game_data directory for engine synchronization
            val gameDataDir = File(context.filesDir, "game_data")
            if (gameDataDir.exists()) {
                File(gameDataDir, "horizon-touch-layout.json").writeText(jsonStr)
            }
        } catch (t: Throwable) {
            android.util.Log.e("ControlOverlay", "Failed to save layout: ${t.message}")
        }
    }

    private fun loadCustomLayout() {
        try {
            var jsonStr = prefs.getString("layout_json", null)
            if (jsonStr == null) {
                val gameDataDir = File(context.filesDir, "game_data")
                val file = File(gameDataDir, "horizon-touch-layout.json")
                if (file.exists()) {
                    jsonStr = file.readText()
                }
            }
            if (jsonStr.isNullOrEmpty()) return

            val root = JSONObject(jsonStr)
            for (v in customizableViews) {
                val name = resources.getResourceEntryName(v.id)
                if (root.has(name)) {
                    val obj = root.getJSONObject(name)
                    v.translationX = obj.optDouble("x", 0.0).toFloat()
                    v.translationY = obj.optDouble("y", 0.0).toFloat()
                    val s = obj.optDouble("s", 1.0).toFloat()
                    v.scaleX = s
                    v.scaleY = s
                    v.alpha = obj.optDouble("a", 1.0).toFloat()
                }
            }
        } catch (t: Throwable) {
            android.util.Log.w("ControlOverlay", "Failed to load layout: ${t.message}")
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
