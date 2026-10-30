package dev.playhorizon.launcher

import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.View
import android.view.animation.OvershootInterpolator
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import dev.playhorizon.launcher.core.AssetManagerService
import dev.playhorizon.launcher.core.HorizonNativeBridge
import dev.playhorizon.launcher.core.LaunchManager

class MainActivity : AppCompatActivity() {

    private lateinit var assetManager: AssetManagerService
    private lateinit var tvStatus: TextView
    private lateinit var btnPlay: Button
    private lateinit var btnControls: Button
    private lateinit var headerLayout: LinearLayout
    private lateinit var mainContentGrid: LinearLayout
    private var vibrator: Vibrator? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        assetManager = AssetManagerService(this)
        try {
            assetManager.prepareDirectories()
        } catch (ignored: Exception) {}

        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator

        headerLayout = findViewById(R.id.headerLayout)
        mainContentGrid = findViewById(R.id.mainContentGrid)
        tvStatus = findViewById(R.id.tvStatus)
        btnPlay = findViewById(R.id.btnPlay)
        btnControls = findViewById(R.id.btnControls)

        setupUI()
        runEntranceAnimation()
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

    /**
     * Staggered Motion Physics (Pillar of Motion-Skills)
     */
    private fun runEntranceAnimation() {
        // Header slides down from -30dp
        headerLayout.translationY = -60f
        headerLayout.alpha = 0f
        headerLayout.animate()
            .translationY(0f)
            .alpha(1f)
            .setDuration(450)
            .setInterpolator(OvershootInterpolator(1.1f))
            .start()

        // Content cards slide up with layered elevation
        mainContentGrid.translationY = 40f
        mainContentGrid.alpha = 0f
        mainContentGrid.animate()
            .translationY(0f)
            .alpha(1f)
            .setStartDelay(100)
            .setDuration(500)
            .setInterpolator(OvershootInterpolator(1.0f))
            .start()

        // Play Button pop
        btnPlay.scaleX = 0.9f
        btnPlay.scaleY = 0.9f
        btnPlay.alpha = 0f
        btnPlay.animate()
            .scaleX(1.0f)
            .scaleY(1.0f)
            .alpha(1f)
            .setStartDelay(200)
            .setDuration(400)
            .setInterpolator(OvershootInterpolator(1.2f))
            .start()
    }

    private fun setupUI() {
        val hasTermuxX11 = LaunchManager.isTermuxX11Installed(this)
        if (hasTermuxX11) {
            tvStatus.text = "Engine Ready • Qualcomm Adreno 619 Hardware Vulkan (Turnip)"
        } else {
            tvStatus.text = "Engine Standby • Termux:X11 display recommended"
        }

        // Tactile Spring Click on Play Button
        btnPlay.setOnClickListener {
            triggerHaptic()

            btnPlay.animate()
                .scaleX(0.95f)
                .scaleY(0.95f)
                .setDuration(90)
                .withEndAction {
                    btnPlay.animate()
                        .scaleX(1.0f)
                        .scaleY(1.0f)
                        .setDuration(120)
                        .setInterpolator(OvershootInterpolator(1.5f))
                        .start()

                    executePlay()
                }
                .start()
        }

        // Virtual Controls Screen Button
        btnControls.setOnClickListener {
            triggerHaptic()
            btnControls.animate()
                .scaleX(0.95f)
                .scaleY(0.95f)
                .setDuration(80)
                .withEndAction {
                    btnControls.animate().scaleX(1f).scaleY(1f).setDuration(100).start()
                    LaunchManager.launchHorizon(this)
                }
                .start()
        }
    }

    private fun executePlay() {
        Toast.makeText(this, "Memulai Horizon Native Game...", Toast.LENGTH_SHORT).show()
        LaunchManager.launchHorizon(this)
    }
}
