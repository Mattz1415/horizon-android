package com.mattz1415.horizon

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.*
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import kotlinx.coroutines.*
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

class LauncherActivity : AppCompatActivity() {

    companion object {
        const val PREFS_NAME = "horizon_launcher_prefs"
        @JvmStatic
        var currentInstance: LauncherActivity? = null
            private set
    }

    private lateinit var prefs: SharedPreferences
    private lateinit var downloader: ResourceDownloader
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val mainHandler = Handler(Looper.getMainLooper())

    // UI Navigation
    private lateinit var viewFlipper: ViewFlipper
    private lateinit var navPlay: LinearLayout
    private lateinit var navDownloader: LinearLayout
    private lateinit var navAccounts: LinearLayout
    private lateinit var navMods: LinearLayout
    private lateinit var navSettings: LinearLayout
    private var currentNavIndex = 0

    // Page 1: Play Dashboard Views
    private lateinit var dotStatus: View
    private lateinit var tvVerificationStatus: TextView
    private lateinit var sbRam: SeekBar
    private lateinit var tvRamVal: TextView
    private lateinit var spnThreads: Spinner
    private lateinit var spnBackend: Spinner
    private lateinit var spnTouchScheme: Spinner
    private lateinit var etUsername: EditText
    private lateinit var btnLaunchGame: Button

    // Page 2: Downloader Views
    private lateinit var tvDownloaderStage: TextView
    private lateinit var pbDownload: ProgressBar
    private lateinit var tvDownloadDetail: TextView
    private lateinit var tvDownloadSpeed: TextView
    private lateinit var btnStartDownload: Button
    private lateinit var btnImportZip: Button
    private lateinit var btnCheckResources: Button

    // Page 3: Accounts Views
    private lateinit var etNewAccount: EditText
    private lateinit var btnAddAccount: Button
    private lateinit var lvAccounts: ListView
    private val accountsList = mutableListOf<String>()

    // Page 4: Mods Views
    private lateinit var etModUrl: EditText
    private lateinit var btnInstallMod: Button
    private lateinit var lvMods: ListView
    private val modsList = mutableListOf<String>()

    // Page 5: Logs Views
    private lateinit var tvLogOutput: TextView
    private lateinit var btnCopyLogs: Button
    private lateinit var btnClearLogs: Button

    private var isDownloading = false

    private val safZipPicker = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val uri: Uri? = result.data?.data
            if (uri != null) {
                downloader.importPreparedZip(uri, createDownloaderListener())
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        currentInstance = this
        setContentView(R.layout.activity_launcher)

        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        downloader = ResourceDownloader(applicationContext)

        initViews()
        setupNavigation()
        loadSavedSettings()
        refreshVerificationStatus()
        loadAccounts()
        loadMods()
        loadLogs()
    }

    private fun initViews() {
        viewFlipper = findViewById(R.id.viewFlipper)
        navPlay = findViewById(R.id.navPlay)
        navDownloader = findViewById(R.id.navDownloader)
        navAccounts = findViewById(R.id.navAccounts)
        navMods = findViewById(R.id.navMods)
        navSettings = findViewById(R.id.navSettings)

        // Page 1
        dotStatus = findViewById(R.id.dotStatus)
        tvVerificationStatus = findViewById(R.id.tvVerificationStatus)
        sbRam = findViewById(R.id.sbRam)
        tvRamVal = findViewById(R.id.tvRamVal)
        spnThreads = findViewById(R.id.spnThreads)
        spnBackend = findViewById(R.id.spnBackend)
        spnTouchScheme = findViewById(R.id.spnTouchScheme)
        etUsername = findViewById(R.id.etUsername)
        btnLaunchGame = findViewById(R.id.btnLaunchGame)

        // Page 2
        tvDownloaderStage = findViewById(R.id.tvDownloaderStage)
        pbDownload = findViewById(R.id.pbDownload)
        tvDownloadDetail = findViewById(R.id.tvDownloadDetail)
        tvDownloadSpeed = findViewById(R.id.tvDownloadSpeed)
        btnStartDownload = findViewById(R.id.btnStartDownload)
        btnImportZip = findViewById(R.id.btnImportZip)
        btnCheckResources = findViewById(R.id.btnCheckResources)

        // Page 3
        etNewAccount = findViewById(R.id.etNewAccount)
        btnAddAccount = findViewById(R.id.btnAddAccount)
        lvAccounts = findViewById(R.id.lvAccounts)

        // Page 4
        etModUrl = findViewById(R.id.etModUrl)
        btnInstallMod = findViewById(R.id.btnInstallMod)
        lvMods = findViewById(R.id.lvMods)

        // Page 5
        tvLogOutput = findViewById(R.id.tvLogOutput)
        btnCopyLogs = findViewById(R.id.btnCopyLogs)
        btnClearLogs = findViewById(R.id.btnClearLogs)

        // Setup Spinners
        val threads = listOf("2 Threads", "4 Threads (Snapdragon 695)", "6 Threads", "8 Threads")
        spnThreads.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, threads)

        val backends = listOf("Vulkan 1.1 (Recommended)", "OpenGL ES 3.1")
        spnBackend.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, backends)

        val schemes = listOf(
            "1. Joystick + Crosshair",
            "2. Joystick + Tap to Interact",
            "3. D-Pad + Crosshair",
            "4. D-Pad + Tap to Interact"
        )
        spnTouchScheme.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, schemes)

        // RAM Slider Listener
        sbRam.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                tvRamVal.text = "$progress MB"
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        // Action Listeners
        btnLaunchGame.setOnClickListener { onLaunchClicked() }
        btnStartDownload.setOnClickListener { onDownloadToggleClicked() }
        btnImportZip.setOnClickListener {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/zip"
            }
            safZipPicker.launch(intent)
        }
        btnCheckResources.setOnClickListener { refreshVerificationStatus() }

        btnAddAccount.setOnClickListener { onAddAccountClicked() }
        btnInstallMod.setOnClickListener { onInstallModClicked() }

        btnCopyLogs.setOnClickListener {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            cm.setPrimaryClip(ClipData.newPlainText("HorizonLogs", tvLogOutput.text))
            Toast.makeText(this, "Log disalin ke clipboard", Toast.LENGTH_SHORT).show()
        }
        btnClearLogs.setOnClickListener {
            val crashLog = File(downloader.gameDataDir, "crash.log")
            if (crashLog.exists()) crashLog.delete()
            loadLogs()
            Toast.makeText(this, "Log dibersihkan", Toast.LENGTH_SHORT).show()
        }
    }

    private fun setupNavigation() {
        val navButtons = listOf(navPlay, navDownloader, navAccounts, navMods, navSettings)
        navButtons.forEachIndexed { index, button ->
            button.setOnClickListener {
                if (currentNavIndex != index) {
                    navButtons[currentNavIndex].setBackgroundResource(R.drawable.bg_liquid_pill)
                    button.setBackgroundResource(R.drawable.bg_liquid_pill_selected)
                    currentNavIndex = index
                    viewFlipper.displayedChild = index
                    if (index == 4) loadLogs()
                }
            }
        }
    }

    private fun loadSavedSettings() {
        val savedName = prefs.getString("username", "HorizonPlayer") ?: "HorizonPlayer"
        etUsername.setText(savedName)

        val savedRam = prefs.getInt("ram_mb", 2048)
        sbRam.progress = savedRam
        tvRamVal.text = "$savedRam MB"

        spnThreads.setSelection(prefs.getInt("threads_idx", 1)) // default 4 threads
        spnBackend.setSelection(prefs.getInt("backend_idx", 0)) // default Vulkan
        spnTouchScheme.setSelection(prefs.getInt("scheme_idx", 0)) // default Joystick+Crosshair
    }

    private fun saveSettings() {
        prefs.edit().apply {
            putString("username", etUsername.text.toString().trim().ifEmpty { "HorizonPlayer" })
            putInt("ram_mb", sbRam.progress)
            putInt("threads_idx", spnThreads.selectedItemPosition)
            putInt("backend_idx", spnBackend.selectedItemPosition)
            putInt("scheme_idx", spnTouchScheme.selectedItemPosition)
            apply()
        }
    }

    private fun refreshVerificationStatus() {
        val ready = downloader.isPrepared()
        val shaFile = File(downloader.targetDir, ".prepared_sha256")
        val sha = if (shaFile.exists()) shaFile.readText().trim() else ""

        if (ready) {
            dotStatus.setBackgroundColor(Color.parseColor("#10B981"))
            val shortSha = if (sha.length >= 12) sha.substring(0, 12) else "verified"
            tvVerificationStatus.text = "Resources 26.3 Siap ($shortSha...)"
            btnLaunchGame.text = "PLAY 26.3"
            btnLaunchGame.isEnabled = true
            btnLaunchGame.alpha = 1.0f
        } else {
            dotStatus.setBackgroundColor(Color.parseColor("#F59E0B"))
            tvVerificationStatus.text = "Resources 26.3 Belum Lengkap"
            btnLaunchGame.text = "DOWNLOAD RESOURCES"
            btnLaunchGame.isEnabled = true
            btnLaunchGame.alpha = 0.9f
        }
    }

    private fun onLaunchClicked() {
        saveSettings()

        if (!downloader.isPrepared()) {
            // Pindah ke tab Downloader
            navDownloader.performClick()
            onDownloadToggleClicked()
            return
        }

        val ramMb = sbRam.progress
        val workerThreads = when (spnThreads.selectedItemPosition) {
            0 -> 2
            1 -> 4
            2 -> 6
            3 -> 8
            else -> 4
        }
        val backend = if (spnBackend.selectedItemPosition == 0) "vulkan" else "gles"
        val touchScheme = spnTouchScheme.selectedItemPosition
        val username = etUsername.text.toString().trim().ifEmpty { "HorizonPlayer" }

        val launchIntent = Intent(this, HorizonGameActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_DOCUMENT or Intent.FLAG_ACTIVITY_MULTIPLE_TASK
            putExtra("EXTRA_RESOURCES_DIR", downloader.targetDir.absolutePath)
            putExtra("EXTRA_RAM_MB", ramMb)
            putExtra("EXTRA_WORKER_THREADS", workerThreads)
            putExtra("EXTRA_BACKEND", backend)
            putExtra("EXTRA_TOUCH_SCHEME", touchScheme)
            putExtra("EXTRA_USERNAME", username)
        }
        startActivity(launchIntent)
    }

    private fun onDownloadToggleClicked() {
        if (isDownloading) {
            downloader.pauseDownload()
            isDownloading = false
            btnStartDownload.text = "RESUME DOWNLOAD 26.3"
            tvDownloaderStage.text = "Tahap: Dijeda"
        } else {
            isDownloading = true
            btnStartDownload.text = "PAUSE DOWNLOAD"
            downloader.startDownload(createDownloaderListener())
        }
    }

    private fun createDownloaderListener() = object : ResourceDownloader.ProgressListener {
        override fun onProgress(stage: String, progress: Double, speedBytesPerSec: Long, detail: String) {
            mainHandler.post {
                tvDownloaderStage.text = "Tahap: $stage"
                pbDownload.progress = (progress * 100).toInt()
                tvDownloadDetail.text = detail
                if (speedBytesPerSec > 0) {
                    val speedMb = speedBytesPerSec.toDouble() / (1024 * 1024)
                    tvDownloadSpeed.text = "%.2f MB/s".format(speedMb)
                }
            }
        }

        override fun onComplete(resourcesPath: String, sha256: String) {
            mainHandler.post {
                isDownloading = false
                btnStartDownload.text = "DOWNLOAD SELESAI"
                tvDownloaderStage.text = "Tahap: Selesai"
                pbDownload.progress = 100
                tvDownloadDetail.text = "Resources 26.3 berhasil diverifikasi. SHA-256: ${sha256.take(16)}..."
                tvDownloadSpeed.text = "0.00 MB/s"
                refreshVerificationStatus()
                Toast.makeText(this@LauncherActivity, "Resources 26.3 Siap Dimainkan!", Toast.LENGTH_LONG).show()
            }
        }

        override fun onError(error: String) {
            mainHandler.post {
                isDownloading = false
                btnStartDownload.text = "COBA LAGI"
                tvDownloaderStage.text = "Tahap: Error"
                tvDownloadDetail.text = "Gagal: $error"
                Toast.makeText(this@LauncherActivity, error, Toast.LENGTH_LONG).show()
            }
        }
    }

    // ================= ACCOUNTS =================
    private fun loadAccounts() {
        accountsList.clear()
        val accountsFile = File(downloader.gameDataDir, "accounts.json")
        if (accountsFile.exists()) {
            try {
                val array = JSONArray(accountsFile.readText())
                for (i in 0 until array.length()) {
                    accountsList.add(array.getString(i))
                }
            } catch (_: Exception) {}
        }
        if (accountsList.isEmpty()) {
            accountsList.add("HorizonPlayer")
            accountsList.add("Steve")
        }
        val adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, accountsList)
        lvAccounts.adapter = adapter
        lvAccounts.setOnItemClickListener { _, _, position, _ ->
            val selected = accountsList[position]
            etUsername.setText(selected)
            saveSettings()
            Toast.makeText(this, "Profil aktif diubah ke $selected", Toast.LENGTH_SHORT).show()
        }
    }

    private fun onAddAccountClicked() {
        val name = etNewAccount.text.toString().trim()
        if (name.isNotEmpty() && !accountsList.contains(name)) {
            accountsList.add(name)
            saveAccounts()
            etNewAccount.setText("")
            etUsername.setText(name)
            saveSettings()
            loadAccounts()
            Toast.makeText(this, "Akun $name ditambahkan", Toast.LENGTH_SHORT).show()
        }
    }

    private fun saveAccounts() {
        val accountsFile = File(downloader.gameDataDir, "accounts.json")
        accountsFile.parentFile?.mkdirs()
        val array = JSONArray(accountsList)
        accountsFile.writeText(array.toString())
    }

    // ================= MODS =================
    private fun loadMods() {
        modsList.clear()
        val modsDir = File(downloader.gameDataDir, "mods").apply { mkdirs() }
        modsDir.listFiles()?.forEach { file ->
            if (file.name.endsWith(".hmod") || file.name.endsWith(".hmod.disabled")) {
                modsList.add(file.name)
            }
        }
        val adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, modsList)
        lvMods.adapter = adapter
        lvMods.setOnItemClickListener { _, _, position, _ ->
            val name = modsList[position]
            val f = File(modsDir, name)
            if (f.exists()) {
                if (name.endsWith(".disabled")) {
                    f.renameTo(File(modsDir, name.removeSuffix(".disabled")))
                } else {
                    f.renameTo(File(modsDir, "$name.disabled"))
                }
                loadMods()
            }
        }
    }

    private fun onInstallModClicked() {
        val url = etModUrl.text.toString().trim()
        if (url.isEmpty()) return
        etModUrl.setText("")
        Toast.makeText(this, "Mengunduh mod...", Toast.LENGTH_SHORT).show()

        scope.launch {
            try {
                val client = OkHttpClient()
                val request = Request.Builder().url(url).build()
                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) throw Exception("HTTP ${response.code}")
                    val body = response.body ?: throw Exception("Body kosong")
                    val fileName = url.substringAfterLast("/").takeIf { it.endsWith(".hmod") }
                        ?: "mod_${System.currentTimeMillis()}.hmod"
                    val target = File(File(downloader.gameDataDir, "mods"), fileName)
                    FileOutputStream(target).use { body.byteStream().copyTo(it) }
                }
                withContext(Dispatchers.Main) {
                    loadMods()
                    Toast.makeText(this@LauncherActivity, "Mod berhasil dipasang!", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@LauncherActivity, "Gagal memasang mod: ${e.message}", Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    // ================= LOGS =================
    private fun loadLogs() {
        val crashLog = File(downloader.gameDataDir, "crash.log")
        val latestLog = File(downloader.gameDataDir, "logs/latest.log")

        val content = when {
            crashLog.exists() -> "=== CRASH LOG ===\n" + crashLog.readText().takeLast(4000)
            latestLog.exists() -> "=== LATEST LOG ===\n" + latestLog.readText().takeLast(4000)
            else -> "Belum ada crash atau log tercatat.\nEngine berjalan normal."
        }
        tvLogOutput.text = content
    }

    override fun onDestroy() {
        super.onDestroy()
        currentInstance = null
        scope.cancel()
    }
}
