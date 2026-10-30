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
            HorizonNativeBridge.safeSendCursorPos(mouseX, mouseY)
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
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                startTouchX = event.x
                startTouchY = event.y
                lastTouchX = event.x
                lastTouchY = event.y
                touchStartTime = System.currentTimeMillis()
                isDragging = false
                return true
            }

            MotionEvent.ACTION_MOVE -> {
                val deltaX = event.x - lastTouchX
                val deltaY = event.y - lastTouchY

                val distFromStart = hypot((event.x - startTouchX).toDouble(), (event.y - startTouchY).toDouble())
                if (distFromStart > 4 * density) {
                    isDragging = true
                }

                if (isMouseMode) {
                    val w = if (width > 0) width.toFloat() else resources.displayMetrics.widthPixels.toFloat()
                    val h = if (height > 0) height.toFloat() else resources.displayMetrics.heightPixels.toFloat()
                    mouseX = max(0f, min(w, mouseX + deltaX * mouseSpeed))
                    mouseY = max(0f, min(h, mouseY + deltaY * mouseSpeed))
                    HorizonNativeBridge.safeSendCursorPos(mouseX, mouseY)
                    invalidate()
                } else {
                    HorizonNativeBridge.safeSendMouseMotion(deltaX * 1.5f, deltaY * 1.5f)
                }

                lastTouchX = event.x
                lastTouchY = event.y
                return true
            }

            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                val duration = System.currentTimeMillis() - touchStartTime
                val totalDist = hypot((event.x - startTouchX).toDouble(), (event.y - startTouchY).toDouble())

                if (!isDragging && duration < 280 && totalDist < 12 * density) {
                    if (isMouseMode) {
                        triggerHaptic()
                        HorizonNativeBridge.safeSendMouseButton(HorizonNativeBridge.MOUSE_LEFT, true)
                        postDelayed({
                            HorizonNativeBridge.safeSendMouseButton(HorizonNativeBridge.MOUSE_LEFT, false)
                        }, 50)
                    }
                }
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
