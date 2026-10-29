package dev.playhorizon.launcher

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import dev.playhorizon.launcher.core.AssetManagerService
import dev.playhorizon.launcher.core.HorizonNativeBridge

class MainActivity : AppCompatActivity() {

    private lateinit var assetManager: AssetManagerService
    private lateinit var tvStatus: TextView
    private lateinit var btnPlay: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        assetManager = AssetManagerService(this)
        assetManager.prepareDirectories()

        tvStatus = findViewById(R.id.tvStatus)
        btnPlay = findViewById(R.id.btnPlay)

        setupUI()
    }

    private fun setupUI() {
        val enginePath = HorizonNativeBridge.getEngineLibraryPath(this)
        if (enginePath != null) {
            tvStatus.text = "Horizon Rust Engine Bundled (Native ARM64)"
        } else {
            tvStatus.text = getString(R.string.status_ready)
        }

        btnPlay.setOnClickListener {
            // Animate click scale
            btnPlay.animate()
                .scaleX(0.95f)
                .scaleY(0.95f)
                .setDuration(80)
                .withEndAction {
                    btnPlay.animate()
                        .scaleX(1.0f)
                        .scaleY(1.0f)
                        .setDuration(80)
                        .start()

                    launchGame()
                }
                .start()
        }
    }

    private fun launchGame() {
        Toast.makeText(this, "Launching Horizon Vulkan Engine...", Toast.LENGTH_SHORT).show()
        val intent = Intent(this, GameActivity::class.java)
        startActivity(intent)
    }
}
