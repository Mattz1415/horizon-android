package com.mattz1415.horizon.ui

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.drawable.Drawable
import android.os.SystemClock
import android.util.AttributeSet
import android.util.Log
import android.view.HapticFeedbackConstants
import android.view.InputDevice
import android.view.MotionEvent
import android.view.View
import androidx.core.content.ContextCompat
import com.mattz1415.horizon.R
import kotlin.math.hypot

@SuppressLint("ClickableViewAccessibility")
class VirtualTouchpadView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val pointerDrawable: Drawable? = ContextCompat.getDrawable(context, R.drawable.ic_mouse_pointer)
    private val density = resources.displayMetrics.density
    private val pointerWidth = (24 * density).toInt()
    private val pointerHeight = (36 * density).toInt()

    private val TAG = "VirtualTouchpad"

    private val cursorFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.FILL
    }
    private val cursorStrokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.BLACK
        style = Paint.Style.STROKE
        strokeWidth = 2.5f * density
        strokeJoin = Paint.Join.ROUND
    }
    private val cursorShadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(120, 0, 0, 0)
        style = Paint.Style.FILL
    }
    private val cursorPath = Path()

    var isMouseMode: Boolean = true
        set(value) {
            field = value
            invalidate()
        }

    var mouseX: Float = 0f
        private set
    var mouseY: Float = 0f
        private set

    private var trackedPointerId = MotionEvent.INVALID_POINTER_ID
    private var startTouchX = 0f
    private var startTouchY = 0f
    private var lastTouchX = 0f
    private var lastTouchY = 0f
    private var isDragging = false
    private var touchStartTime = 0L

    init {
        isClickable = true
        isFocusable = false
        setWillNotDraw(false)
        pointerDrawable?.setBounds(0, 0, pointerWidth, pointerHeight)
        initFallbackCursorPath()
    }

    private fun initFallbackCursorPath() {
        val s = density * 1.8f
        cursorPath.reset()
        cursorPath.moveTo(0f, 0f)
        cursorPath.lineTo(0f, 15f * s)
        cursorPath.lineTo(4.2f * s, 11.5f * s)
        cursorPath.lineTo(7.5f * s, 17f * s)
        cursorPath.lineTo(9.5f * s, 15.8f * s)
        cursorPath.lineTo(6.2f * s, 10.5f * s)
        cursorPath.lineTo(11f * s, 10.5f * s)
        cursorPath.close()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (w > 0 && h > 0) {
            if (mouseX == 0f && mouseY == 0f) {
                mouseX = w / 2f
                mouseY = h / 2f
            }
            invalidate()
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (isMouseMode) {
            canvas.save()
            canvas.translate(mouseX, mouseY)
            if (pointerDrawable != null) {
                pointerDrawable.draw(canvas)
            } else {
                canvas.save()
                canvas.translate(2f * density, 2f * density)
                canvas.drawPath(cursorPath, cursorShadowPaint)
                canvas.restore()

                canvas.drawPath(cursorPath, cursorFillPaint)
                canvas.drawPath(cursorPath, cursorStrokePaint)
            }
            canvas.restore()
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val w = if (width > 0) width.toFloat() else resources.displayMetrics.widthPixels.toFloat()
        val h = if (height > 0) height.toFloat() else resources.displayMetrics.heightPixels.toFloat()

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                val pointerIndex = 0
                trackedPointerId = event.getPointerId(pointerIndex)
                startTouchX = event.getX(pointerIndex)
                startTouchY = event.getY(pointerIndex)
                lastTouchX = startTouchX
                lastTouchY = startTouchY
                touchStartTime = System.currentTimeMillis()
                isDragging = false

                if (isMouseMode) {
                    mouseX = startTouchX.coerceIn(0f, w)
                    mouseY = startTouchY.coerceIn(0f, h)
                    invalidate()
                }
                return true
            }

            MotionEvent.ACTION_POINTER_DOWN -> {
                if (trackedPointerId == MotionEvent.INVALID_POINTER_ID) {
                    val pointerIndex = event.actionIndex
                    trackedPointerId = event.getPointerId(pointerIndex)
                    startTouchX = event.getX(pointerIndex)
                    startTouchY = event.getY(pointerIndex)
                    lastTouchX = startTouchX
                    lastTouchY = startTouchY
                    touchStartTime = System.currentTimeMillis()
                    isDragging = false
                }
                return true
            }

            MotionEvent.ACTION_MOVE -> {
                val pointerIndex = event.findPointerIndex(trackedPointerId)
                if (pointerIndex == -1) return true

                val curX = event.getX(pointerIndex)
                val curY = event.getY(pointerIndex)
                val deltaX = curX - lastTouchX
                val deltaY = curY - lastTouchY

                val dist = hypot((curX - startTouchX).toDouble(), (curY - startTouchY).toDouble())
                if (dist > 10 * density) isDragging = true

                if (isMouseMode) {
                    mouseX = curX.coerceIn(0f, w)
                    mouseY = curY.coerceIn(0f, h)
                    invalidate()
                }
                // Both modes forward the delta: the cursor position feeds menus, the
                // relative axes feed the camera. Mouse mode used to skip this and left
                // the player unable to turn around at all.
                sendMouseMotion(deltaX * 1.5f, deltaY * 1.5f)

                lastTouchX = curX
                lastTouchY = curY
                return true
            }

            MotionEvent.ACTION_POINTER_UP -> {
                val pointerIndex = event.actionIndex
                if (event.getPointerId(pointerIndex) == trackedPointerId) {
                    trackedPointerId = MotionEvent.INVALID_POINTER_ID
                    val newIndex = if (pointerIndex == 0) 1 else 0
                    if (newIndex < event.pointerCount) {
                        trackedPointerId = event.getPointerId(newIndex)
                        lastTouchX = event.getX(newIndex)
                        lastTouchY = event.getY(newIndex)
                    }
                }
                return true
            }

            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                val duration = System.currentTimeMillis() - touchStartTime
                val totalDist = hypot((lastTouchX - startTouchX).toDouble(), (lastTouchY - startTouchY).toDouble())

                if (isMouseMode && !isDragging && duration < 500 && totalDist < 20 * density) {
                    triggerHaptic()
                    sendMouseClick(1) // Left click on tap
                }

                trackedPointerId = MotionEvent.INVALID_POINTER_ID
                isDragging = false
                return true
            }
        }
        return false
    }

    private fun sendMouseMotion(deltaX: Float, deltaY: Float) {
        val act = context as? Activity ?: return
        val event = obtainMouseEvent(MotionEvent.ACTION_MOVE, buttonState = 0, isDown = true) {
            setAxisValue(MotionEvent.AXIS_RELATIVE_X, deltaX)
            setAxisValue(MotionEvent.AXIS_RELATIVE_Y, deltaY)
        }
        try {
            act.dispatchGenericMotionEvent(event)
        } catch (t: Throwable) {
            Log.w(TAG, "Mouse motion failed: ${t.message}")
        } finally {
            event.recycle()
        }
    }

    private fun sendMouseClick(button: Int) {
        val act = context as? Activity ?: return
        val buttonState = if (button == 1) MotionEvent.BUTTON_PRIMARY else MotionEvent.BUTTON_SECONDARY

        dispatchMouse(act, MotionEvent.ACTION_DOWN, buttonState, isDown = true)
        // The release keeps the button bit set on the DOWN frame only; a fresh event is
        // built for UP so the engine sees a matching down/up pair without reusing a
        // recycled MotionEvent (that reuse was destabilising the input queue).
        postDelayed({
            dispatchMouse(act, MotionEvent.ACTION_UP, buttonState, isDown = false)
        }, 50)
    }

    private fun dispatchMouse(act: Activity, action: Int, buttonState: Int, isDown: Boolean) {
        val generic = obtainMouseEvent(action, buttonState, isDown)
        try {
            if (act.dispatchGenericMotionEvent(generic)) return
        } catch (t: Throwable) {
            Log.w(TAG, "Mouse dispatch failed: ${t.message}")
            return
        } finally {
            generic.recycle()
        }

        val touch = obtainMouseEvent(action, buttonState, isDown)
        try {
            act.dispatchTouchEvent(touch)
        } catch (t: Throwable) {
            Log.w(TAG, "Touch dispatch failed: ${t.message}")
        } finally {
            touch.recycle()
        }
    }

    private fun obtainMouseEvent(
        action: Int,
        buttonState: Int,
        isDown: Boolean,
        configure: MotionEvent.PointerCoords.() -> Unit = {}
    ): MotionEvent {
        val now = SystemClock.uptimeMillis()
        val properties = arrayOf(MotionEvent.PointerProperties().apply {
            id = 0
            toolType = MotionEvent.TOOL_TYPE_MOUSE
        })
        val coords = arrayOf(MotionEvent.PointerCoords().apply {
            this.x = mouseX
            this.y = mouseY
            pressure = if (isDown) 1.0f else 0.0f
            configure()
        })
        return MotionEvent.obtain(
            now, now, action,
            1, properties, coords,
            0, buttonState, 1.0f, 1.0f,
            0, 0, InputDevice.SOURCE_MOUSE or InputDevice.SOURCE_TOUCHSCREEN, 0
        )
    }

    private fun triggerHaptic() {
        // View-level haptic feedback instead of a direct Vibrator binder call: the
        // per-touch Vibrator IPC was stalling the UI thread under rapid tapping.
        performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
    }
}
