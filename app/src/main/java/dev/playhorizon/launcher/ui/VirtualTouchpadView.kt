package dev.playhorizon.launcher.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.drawable.Drawable
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
    private val pointerWidth = (22 * density).toInt()
    private val pointerHeight = (33 * density).toInt()

    var isMouseMode: Boolean = true
        set(value) {
            field = value
            invalidate()
        }

    var mouseSpeed: Float = 1.3f

    var mouseX: Float = 0f
        private set
    var mouseY: Float = 0f
        private set

    private var lastTouchX = 0f
    private var lastTouchY = 0f
    private var isDragging = false
    private var touchStartTime = 0L

    init {
        pointerDrawable?.setBounds(0, 0, pointerWidth, pointerHeight)
        post {
            mouseX = width / 2f
            mouseY = height / 2f
            HorizonNativeBridge.safeSendCursorPos(mouseX, mouseY)
            invalidate()
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (isMouseMode && pointerDrawable != null) {
            canvas.save()
            canvas.translate(mouseX, mouseY)
            pointerDrawable.draw(canvas)
            canvas.restore()
        }
    }

    fun handleTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                lastTouchX = event.x
                lastTouchY = event.y
                touchStartTime = System.currentTimeMillis()
                isDragging = false
                return true
            }

            MotionEvent.ACTION_MOVE -> {
                val deltaX = event.x - lastTouchX
                val deltaY = event.y - lastTouchY

                if (hypot(deltaX.toDouble(), deltaY.toDouble()) > 3 * density) {
                    isDragging = true
                }

                if (isMouseMode) {
                    // Virtual Mouse Touchpad mode
                    mouseX = max(0f, min(width.toFloat(), mouseX + deltaX * mouseSpeed))
                    mouseY = max(0f, min(height.toFloat(), mouseY + deltaY * mouseSpeed))
                    HorizonNativeBridge.safeSendCursorPos(mouseX, mouseY)
                    invalidate()
                } else {
                    // FPS Camera Look mode
                    HorizonNativeBridge.safeSendMouseMotion(deltaX * 1.6f, deltaY * 1.6f)
                }

                lastTouchX = event.x
                lastTouchY = event.y
                return true
            }

            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                val duration = System.currentTimeMillis() - touchStartTime
                if (!isDragging && duration < 240) {
                    // Quick tap on touchpad triggers primary click in mouse mode
                    if (isMouseMode) {
                        HorizonNativeBridge.safeSendMouseButton(HorizonNativeBridge.MOUSE_LEFT, true)
                        postDelayed({
                            HorizonNativeBridge.safeSendMouseButton(HorizonNativeBridge.MOUSE_LEFT, false)
                        }, 40)
                    }
                }
                isDragging = false
                return true
            }
        }
        return false
    }
}
