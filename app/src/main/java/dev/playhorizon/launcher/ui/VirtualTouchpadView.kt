package dev.playhorizon.launcher.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import androidx.core.content.ContextCompat
import dev.playhorizon.launcher.R
import dev.playhorizon.launcher.core.HorizonNativeBridge
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

class VirtualTouchpadView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val pointerDrawable: Drawable? = ContextCompat.getDrawable(context, R.drawable.ic_mouse_pointer)
    private val density = resources.displayMetrics.density
    private val pointerWidth = (24 * density).toInt()
    private val pointerHeight = (36 * density).toInt()

    private val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator

    // Fallback vector cursor if drawable is unavailable
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

    var mouseSpeed: Float = 1.35f

    var mouseX: Float = 0f
        private set
    var mouseY: Float = 0f
        private set

    // Multi-touch Pointer ID tracking (Pojav / Zalith PointerTracker pattern)
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
            val normX = (mouseX / w.toFloat()).coerceIn(0f, 1f)
            val normY = (mouseY / h.toFloat()).coerceIn(0f, 1f)
            HorizonNativeBridge.safeSendCursorPos(normX, normY)
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
        return handleTouchEvent(event)
    }

    fun handleTouchEvent(event: MotionEvent): Boolean {
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
                    // Update cursor to finger location immediately on touch down
                    mouseX = startTouchX.coerceIn(0f, w)
                    mouseY = startTouchY.coerceIn(0f, h)
                    val normX = if (w > 0) (mouseX / w).coerceIn(0f, 1f) else 0.5f
                    val normY = if (h > 0) (mouseY / h).coerceIn(0f, 1f) else 0.5f
                    HorizonNativeBridge.safeSendCursorPos(normX, normY)
                    invalidate()
                }
                return true
            }

            MotionEvent.ACTION_POINTER_DOWN -> {
                // If we don't have an active tracking pointer or if a new finger touches
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
                if (pointerIndex == -1) {
                    return true
                }

                val curX = event.getX(pointerIndex)
                val curY = event.getY(pointerIndex)
                val deltaX = curX - lastTouchX
                val deltaY = curY - lastTouchY

                val distFromStart = hypot((curX - startTouchX).toDouble(), (curY - startTouchY).toDouble())
                if (distFromStart > 12 * density) {
                    isDragging = true
                }

                if (isMouseMode) {
                    mouseX = curX.coerceIn(0f, w)
                    mouseY = curY.coerceIn(0f, h)
                    val normX = if (w > 0) (mouseX / w).coerceIn(0f, 1f) else 0.5f
                    val normY = if (h > 0) (mouseY / h).coerceIn(0f, 1f) else 0.5f
                    HorizonNativeBridge.safeSendCursorPos(normX, normY)
                    invalidate()
                } else {
                    HorizonNativeBridge.safeSendMouseMotion(deltaX * 1.5f, deltaY * 1.5f)
                }

                lastTouchX = curX
                lastTouchY = curY
                return true
            }

            MotionEvent.ACTION_POINTER_UP -> {
                val pointerIndex = event.actionIndex
                if (event.getPointerId(pointerIndex) == trackedPointerId) {
                    // Active pointer lifted; switch to another active pointer if available
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

                if (isMouseMode) {
                    // Tap detection: short tap with minimal movement (< 24dp, < 500ms) triggers Left Click!
                    if (!isDragging && duration < 500 && totalDist < 24 * density) {
                        triggerHaptic()
                        mouseX = startTouchX.coerceIn(0f, w)
                        mouseY = startTouchY.coerceIn(0f, h)
                        val normX = if (w > 0) (mouseX / w).coerceIn(0f, 1f) else 0.5f
                        val normY = if (h > 0) (mouseY / h).coerceIn(0f, 1f) else 0.5f
                        HorizonNativeBridge.safeSendCursorPos(normX, normY)
                        invalidate()

                        HorizonNativeBridge.safeSendMouseButton(HorizonNativeBridge.MOUSE_LEFT, true)
                        postDelayed({
                            HorizonNativeBridge.safeSendMouseButton(HorizonNativeBridge.MOUSE_LEFT, false)
                        }, 60)
                    }
                }
                trackedPointerId = MotionEvent.INVALID_POINTER_ID
                isDragging = false
                return true
            }
        }
        return false
    }

    private fun triggerHaptic() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createOneShot(15, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(15)
            }
        } catch (ignored: Exception) {}
    }
}
