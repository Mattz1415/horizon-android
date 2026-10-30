package com.mattz1415.horizon

import android.app.NativeActivity
import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Process
import android.provider.MediaStore
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.util.Log
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.FrameLayout
import java.io.File
import java.io.FileOutputStream

class HorizonGameActivity : NativeActivity() {

    companion object {
        private const val TAG = "HorizonGameActivity"

        init {
            System.loadLibrary("horizon_android")
        }

        @JvmStatic
        external fun nativeInitEnvironment(
            gameDataDir: String,
            resourcesDir: String,
            ramMb: Int,
            threads: Int,
            backend: String,
            touchScheme: Int
        )

        @JvmStatic
        external fun nativeOnImeInput(text: String)

        @JvmStatic
        external fun nativeOnImeBackspace()

        @JvmStatic
        external fun nativeOnImeDone()

        @JvmStatic
        var currentInstance: HorizonGameActivity? = null
            private set

        @JvmStatic
        fun requestShowIme(initialText: String) {
            currentInstance?.runOnUiThread {
                currentInstance?.showIme(initialText)
            }
        }

        @JvmStatic
        fun requestHideIme() {
            currentInstance?.runOnUiThread {
                currentInstance?.hideIme()
            }
        }

        @JvmStatic
        fun saveScreenshotMediaStore(pngBytes: ByteArray, filename: String): Boolean {
            val act = currentInstance ?: return false
            return act.saveToMediaStore(pngBytes, filename)
        }
    }

    private var imeProxyEditText: EditText? = null
    private var isImeUpdating = false

    private var wakeLock: android.os.PowerManager.WakeLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        currentInstance = this

        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val pm = getSystemService(Context.POWER_SERVICE) as? android.os.PowerManager
        wakeLock = pm?.newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, "horizon:game_active_wakelock")?.apply {
            setReferenceCounted(false)
            acquire(4 * 60 * 60 * 1000L) // Pin CPU wake for up to 4 hours of gameplay
        }

        GameService.start(this)

        val gameDataDir = File(filesDir, "game_data").apply { mkdirs() }.absolutePath
        val resourcesDir = intent.getStringExtra("EXTRA_RESOURCES_DIR")
            ?: File(filesDir, "resources/26.3").absolutePath
        val ramMb = intent.getIntExtra("EXTRA_RAM_MB", 2048)
        val threads = intent.getIntExtra("EXTRA_WORKER_THREADS", 4)
        val backend = intent.getStringExtra("EXTRA_BACKEND") ?: "vulkan"
        val touchScheme = intent.getIntExtra("EXTRA_TOUCH_SCHEME", 0)

        nativeInitEnvironment(
            gameDataDir,
            resourcesDir,
            ramMb,
            threads,
            backend,
            touchScheme
        )

        setupImeProxy()
        hideSystemUi()
        setupControlOverlay()
    }

    private var controlOverlay: com.mattz1415.horizon.ui.ControlOverlay? = null

    private fun setupControlOverlay() {
        try {
            val overlay = com.mattz1415.horizon.ui.ControlOverlay(this)
            controlOverlay = overlay
            addContentView(
                overlay,
                ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT
                )
            )
            Log.i(TAG, "Zalith/Pojav ControlOverlay attached successfully!")
        } catch (e: Exception) {
            Log.e(TAG, "Error displaying ControlOverlay: ${e.message}", e)
        }
    }

    private fun setupImeProxy() {
        val root = window.decorView as ViewGroup
        val editText = EditText(this).apply {
            layoutParams = FrameLayout.LayoutParams(1, 1)
            visibility = View.VISIBLE
            alpha = 0.0f
            isFocusable = true
            isFocusableInTouchMode = true
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
            imeOptions = EditorInfo.IME_ACTION_DONE or EditorInfo.IME_FLAG_NO_EXTRACT_UI

            addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                    if (isImeUpdating) return
                    if (s != null && count > 0) {
                        val added = s.subSequence(start, start + count).toString()
                        nativeOnImeInput(added)
                    }
                }
                override fun afterTextChanged(s: Editable?) {}
            })

            setOnKeyListener { _, keyCode, event ->
                if (event.action == KeyEvent.ACTION_DOWN) {
                    if (keyCode == KeyEvent.KEYCODE_DEL) {
                        nativeOnImeBackspace()
                        return@setOnKeyListener true
                    } else if (keyCode == KeyEvent.KEYCODE_ENTER) {
                        nativeOnImeDone()
                        hideIme()
                        return@setOnKeyListener true
                    }
                }
                false
            }
        }
        root.addView(editText)
        imeProxyEditText = editText
    }

    private fun showIme(initialText: String) {
        imeProxyEditText?.let { et ->
            isImeUpdating = true
            et.setText(initialText)
            et.setSelection(initialText.length)
            isImeUpdating = false
            et.requestFocus()
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showSoftInput(et, InputMethodManager.SHOW_FORCED)
        }
    }

    private fun hideIme() {
        imeProxyEditText?.let { et ->
            et.clearFocus()
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            imm.hideSoftInputFromWindow(et.windowToken, 0)
        }
        hideSystemUi()
    }

    private fun hideSystemUi() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
            val controller = window.insetsController
            controller?.hide(
                android.view.WindowInsets.Type.statusBars() or
                        android.view.WindowInsets.Type.navigationBars()
            )
            controller?.systemBarsBehavior =
                android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                            or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            or View.SYSTEM_UI_FLAG_FULLSCREEN
                    )
        }
    }

    private fun saveToMediaStore(pngBytes: ByteArray, filename: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, filename)
                    put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                    put(
                        MediaStore.Images.Media.RELATIVE_PATH,
                        Environment.DIRECTORY_PICTURES + File.separator + "HorizonAndroid"
                    )
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }

                val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                    ?: return false

                contentResolver.openOutputStream(uri)?.use { os ->
                    os.write(pngBytes)
                }

                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                true
            } else {
                val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
                val targetDir = File(picturesDir, "HorizonAndroid").apply { mkdirs() }
                val targetFile = File(targetDir, filename)
                FileOutputStream(targetFile).use { it.write(pngBytes) }
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Gagal menyimpan screenshot ke MediaStore: ${e.message}")
            false
        }
    }

    override fun onDestroy() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: Exception) {}
        super.onDestroy()
        currentInstance = null
        GameService.stop(this)
        Process.killProcess(Process.myPid())
    }
}
