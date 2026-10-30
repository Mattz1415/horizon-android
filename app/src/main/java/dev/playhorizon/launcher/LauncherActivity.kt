package dev.playhorizon.launcher

import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import dev.playhorizon.launcher.core.ResourcePreparer
import dev.playhorizon.launcher.service.GameService
import java.io.File

/**
 * LauncherActivity:
 * Modern Dual-Window Launcher for Horizon Minecraft 26.3 Rust Client.
 * Runs in the primary app process while GameActivity runs in `:game`.
 */
class LauncherActivity : AppCompatActivity() {

    private lateinit var prefs: SharedPreferences

    private lateinit var etUsername: EditText
    private lateinit var tvResourceStatus: TextView
    private lateinit var tvResourceDetail: TextView
    private lateinit var progressBar: ProgressBar
    private lateinit var tvProgressInfo: TextView

    private lateinit var btnDownloadMojang: Button
    private lateinit var btnImportZip: Button
    private lateinit var spnThreads: Spinner
    private lateinit var spnRenderScale: Spinner
    private lateinit var spnTouchScheme: Spinner
    private lateinit var cbVsync: CheckBox

    private lateinit var btnMods: Button
    private lateinit var btnLogs: Button
    private lateinit var btnLaunch: Button

    private val zipPicker = registerForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri != null) {
            importZipFile(uri)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_launcher)

        prefs = getSharedPreferences("horizon_launcher_prefs", Context.MODE_PRIVATE)

        initViews()
        loadSavedSettings()
        checkResourceStatus()
    }

    override fun onResume() {
        super.onResume()
        checkResourceStatus()
    }

    private fun initViews() {
        etUsername = findViewById(R.id.etUsername)
        tvResourceStatus = findViewById(R.id.tvResourceStatus)
        tvResourceDetail = findViewById(R.id.tvResourceDetail)
        progressBar = findViewById(R.id.progressBar)
        tvProgressInfo = findViewById(R.id.tvProgressInfo)

        btnDownloadMojang = findViewById(R.id.btnDownloadMojang)
        btnImportZip = findViewById(R.id.btnImportZip)
        spnThreads = findViewById(R.id.spnThreads)
        spnRenderScale = findViewById(R.id.spnRenderScale)
        spnTouchScheme = findViewById(R.id.spnTouchScheme)
        cbVsync = findViewById(R.id.cbVsync)

        btnMods = findViewById(R.id.btnMods)
        btnLogs = findViewById(R.id.btnLogs)
        btnLaunch = findViewById(R.id.btnLaunch)

        // Spinners setup
        val threadsList = listOf("2 Threads", "4 Threads", "6 Threads", "8 Threads")
        spnThreads.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, threadsList)

        val scaleList = listOf("100% (Native)", "85%", "75%", "50%")
        spnRenderScale.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, scaleList)

        val schemesList = listOf("D-Pad + Tap Aim", "D-Pad + Crosshair", "Joystick + Tap Aim", "Joystick + Crosshair")
        spnTouchScheme.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, schemesList)

        btnDownloadMojang.setOnClickListener { startMojangDownload() }
        btnImportZip.setOnClickListener { zipPicker.launch("application/zip") }
        btnMods.setOnClickListener { showModsDialog() }
        btnLogs.setOnClickListener { showLogsDialog() }
        btnLaunch.setOnClickListener { launchGame() }
    }

    private fun loadSavedSettings() {
        etUsername.setText(prefs.getString("username", "Steve"))
        spnThreads.setSelection(prefs.getInt("threads_index", 1)) // default 4 threads
        spnRenderScale.setSelection(prefs.getInt("scale_index", 0)) // default 100%
        spnTouchScheme.setSelection(prefs.getInt("scheme_index", 0))
        cbVsync.isChecked = prefs.getBoolean("vsync", true)
    }

    private fun saveSettings() {
        prefs.edit().apply {
            putString("username", etUsername.text.toString().trim().ifEmpty { "Steve" })
            putInt("threads_index", spnThreads.selectedItemPosition)
            putInt("scale_index", spnRenderScale.selectedItemPosition)
            putInt("scheme_index", spnTouchScheme.selectedItemPosition)
            putBoolean("vsync", cbVsync.isChecked)
            apply()
        }
    }

    private fun checkResourceStatus() {
        val ready = ResourcePreparer.isResourcesReady(this)
        if (ready) {
            tvResourceStatus.text = "READY"
            tvResourceStatus.setTextColor(Color.parseColor("#4ADE80"))
            tvResourceDetail.text = "Minecraft 26.3 assets and tables are verified."
            btnLaunch.isEnabled = true
            btnLaunch.alpha = 1.0f
        } else {
            tvResourceStatus.text = "NOT READY"
            tvResourceStatus.setTextColor(Color.parseColor("#F59E0B"))
            tvResourceDetail.text = "Download or import resources before launching."
            btnLaunch.isEnabled = false
            btnLaunch.alpha = 0.5f
        }
    }

    private fun startMojangDownload() {
        progressBar.visibility = View.VISIBLE
        progressBar.isIndeterminate = false
        progressBar.progress = 0
        tvProgressInfo.visibility = View.VISIBLE
        btnDownloadMojang.isEnabled = false
        btnImportZip.isEnabled = false

        ResourcePreparer.downloadFastBundle(
            context = this,
            onProgress = { stage, percent, info ->
                runOnUiThread {
                    progressBar.progress = percent
                    tvProgressInfo.text = "[$stage] $info"
                }
            },
            onComplete = { success, error ->
                runOnUiThread {
                    progressBar.visibility = View.GONE
                    tvProgressInfo.visibility = View.GONE
                    btnDownloadMojang.isEnabled = true
                    btnImportZip.isEnabled = true

                    if (success) {
                        Toast.makeText(this, "Resources prepared successfully!", Toast.LENGTH_LONG).show()
                        checkResourceStatus()
                    } else {
                        Toast.makeText(this, "Download failed: $error", Toast.LENGTH_LONG).show()
                    }
                }
            }
        )
    }

    private fun importZipFile(uri: Uri) {
        progressBar.visibility = View.VISIBLE
        progressBar.isIndeterminate = false
        progressBar.progress = 0
        tvProgressInfo.visibility = View.VISIBLE
        btnDownloadMojang.isEnabled = false
        btnImportZip.isEnabled = false

        ResourcePreparer.importPreparedZip(
            context = this,
            uri = uri,
            onProgress = { percent, status ->
                runOnUiThread {
                    progressBar.progress = percent
                    tvProgressInfo.text = status
                }
            },
            onComplete = { success, error ->
                runOnUiThread {
                    progressBar.visibility = View.GONE
                    tvProgressInfo.visibility = View.GONE
                    btnDownloadMojang.isEnabled = true
                    btnImportZip.isEnabled = true

                    if (success) {
                        Toast.makeText(this, "Resources imported successfully!", Toast.LENGTH_LONG).show()
                        checkResourceStatus()
                    } else {
                        Toast.makeText(this, "Import failed: $error", Toast.LENGTH_LONG).show()
                    }
                }
            }
        )
    }

    private fun showModsDialog() {
        val modsDir = File(filesDir, "mods")
        if (!modsDir.exists()) modsDir.mkdirs()

        val files = modsDir.listFiles { _, name -> name.endsWith(".hmod") || name.endsWith(".hmod.disabled") } ?: emptyArray()

        if (files.isEmpty()) {
            AlertDialog.Builder(this)
                .setTitle("Horizon Mods (.hmod)")
                .setMessage("No .hmod mods installed yet.\nPlace WebAssembly .hmod files in:\n${modsDir.absolutePath}")
                .setPositiveButton("OK", null)
                .show()
            return
        }

        val fileNames = files.map { it.name }.toTypedArray()
        val checkedItems = files.map { !it.name.endsWith(".disabled") }.toBooleanArray()

        AlertDialog.Builder(this)
            .setTitle("Manage Mods (.hmod)")
            .setMultiChoiceItems(fileNames, checkedItems) { _, which, isChecked ->
                val f = files[which]
                if (isChecked && f.name.endsWith(".disabled")) {
                    val newName = f.name.removeSuffix(".disabled")
                    f.renameTo(File(f.parentFile, newName))
                } else if (!isChecked && !f.name.endsWith(".disabled")) {
                    f.renameTo(File(f.parentFile, "${f.name}.disabled"))
                }
            }
            .setPositiveButton("Done", null)
            .show()
    }

    private fun showLogsDialog() {
        val crashLog = File(filesDir, "crash.log")
        val latestLog = File(filesDir, "logs/latest.log")

        val logText = when {
            crashLog.exists() -> "=== CRASH LOG ===\n" + crashLog.readText().takeLast(3000)
            latestLog.exists() -> "=== LATEST LOG ===\n" + latestLog.readText().takeLast(3000)
            else -> "No logs recorded yet. Logs will appear here after a game session."
        }

        val textView = TextView(this).apply {
            text = logText
            setTextColor(Color.WHITE)
            textSize = 11f
            setPadding(30, 20, 30, 20)
        }
        val scrollView = ScrollView(this).apply { addView(textView) }

        AlertDialog.Builder(this)
            .setTitle("Engine Logs")
            .setView(scrollView)
            .setPositiveButton("Close", null)
            .setNeutralButton("Clear Logs") { _, _ ->
                if (crashLog.exists()) crashLog.delete()
                if (latestLog.exists()) latestLog.delete()
                Toast.makeText(this, "Logs cleared", Toast.LENGTH_SHORT).show()
            }
            .show()
    }

    private fun launchGame() {
        saveSettings()

        val username = etUsername.text.toString().trim().ifEmpty { "Steve" }
        val threads = when (spnThreads.selectedItemPosition) {
            0 -> 2
            1 -> 4
            2 -> 6
            3 -> 8
            else -> 4
        }
        val scheme = spnTouchScheme.selectedItemPosition

        // 1. Start foreground GameService in :game process
        GameService.start(this)

        // 2. Launch GameActivity with DUAL-WINDOW / SEPARATE PROCESS flags
        val intent = Intent(this, GameActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_DOCUMENT or Intent.FLAG_ACTIVITY_MULTIPLE_TASK
            putExtra("HORIZON_USERNAME", username)
            putExtra("HORIZON_WORKER_THREADS", threads)
            putExtra("HORIZON_TOUCH_SCHEME", scheme)
            putExtra("HORIZON_RESOURCES_DIR", ResourcePreparer.getResourcesDir(this@LauncherActivity).absolutePath)
        }
        startActivity(intent)
    }
}
