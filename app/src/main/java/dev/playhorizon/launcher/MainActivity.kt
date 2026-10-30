package dev.playhorizon.launcher

import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.appcompat.app.AppCompatActivity
import dev.playhorizon.launcher.core.AssetManagerService
import dev.playhorizon.launcher.core.LaunchManager

class MainActivity : AppCompatActivity() {

    private lateinit var assetManager: AssetManagerService
    private var vibrator: Vibrator? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        assetManager = AssetManagerService(this)
        try {
            assetManager.prepareDirectories()
        } catch (ignored: Exception) {}

        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        triggerHaptic()

        // INSTANT NATIVE BOOT: Saat aplikasi dibuka, langsung masuk ke Minecraft
        LaunchManager.launchHorizonDirect(this)
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
