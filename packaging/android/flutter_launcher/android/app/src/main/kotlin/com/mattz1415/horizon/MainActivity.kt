package com.mattz1415.horizon

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "com.vasysik.horizon/launcher"
        const val PROGRESS_EVENT_CHANNEL = "com.vasysik.horizon/progress"

        @JvmStatic
        var currentInstance: MainActivity? = null
            private set
    }

    private val downloader: ResourceDownloader by lazy {
        ResourceDownloader(applicationContext)
    }
    private var progressEventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val REQUEST_SAF_ZIP = 4102

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_SAF_ZIP && resultCode == Activity.RESULT_OK) {
            val uri = data?.data
            if (uri != null) {
                downloader.importPreparedZip(uri, createDownloaderListener())
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        currentInstance = this
        shieldFromGallery(filesDir)
        shieldFromGallery(File(filesDir, "resources"))
        shieldFromGallery(File(filesDir, "resources/26.3"))
        shieldFromGallery(File(filesDir, "game_data"))
    }

    private fun shieldFromGallery(dir: File) {
        try {
            if (!dir.exists()) dir.mkdirs()
            val nomedia = File(dir, ".nomedia")
            if (!nomedia.exists()) nomedia.createNewFile()
        } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PROGRESS_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    progressEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    progressEventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "checkResources" -> {
                            val prepared = downloader.isPrepared()
                            val shaFile = File(downloader.targetDir, ".prepared_sha256")
                            val sha = if (shaFile.exists()) shaFile.readText().trim() else ""
                            result.success(
                                mapOf(
                                    "isPrepared" to prepared,
                                    "sha256" to sha,
                                    "path" to downloader.targetDir.absolutePath
                                )
                            )
                        }

                        "startDownload" -> {
                            downloader.startDownload(createDownloaderListener())
                            result.success(true)
                        }

                        "pauseDownload" -> {
                            downloader.pauseDownload()
                            result.success(true)
                        }

                        "importResourcesZip" -> {
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/zip"
                            }
                            startActivityForResult(intent, REQUEST_SAF_ZIP)
                            result.success(true)
                        }

                        "getAccounts" -> {
                            val accountsFile = File(downloader.gameDataDir, "accounts.json")
                            if (accountsFile.exists()) {
                                result.success(accountsFile.readText())
                            } else {
                                result.success("[\"HorizonPlayer\",\"Steve\"]")
                            }
                        }

                        "saveAccounts" -> {
                            val json = call.argument<String>("json") ?: "[]"
                            val accountsFile = File(downloader.gameDataDir, "accounts.json")
                            accountsFile.parentFile?.mkdirs()
                            accountsFile.writeText(json)
                            result.success(true)
                        }

                        "getMods" -> {
                            val modsDir = File(downloader.gameDataDir, "mods").apply { mkdirs() }
                            val list = mutableListOf<Map<String, Any>>()
                            modsDir.listFiles()?.filter { it.extension == "hmod" || it.name.endsWith(".hmod.disabled") }?.forEach { f ->
                                val enabled = !f.name.endsWith(".disabled")
                                list.add(
                                    mapOf(
                                        "name" to f.name.removeSuffix(".disabled"),
                                        "fileName" to f.name,
                                        "size" to f.length(),
                                        "enabled" to enabled
                                    )
                                )
                            }
                            result.success(list)
                        }

                        "installModFromUrl" -> {
                            val url = call.argument<String>("url")
                            if (url == null) {
                                result.error("INVALID_URL", "URL mod tidak boleh kosong", null)
                                return@setMethodCallHandler
                            }
                            scope.launch {
                                try {
                                    installMod(url)
                                    withContext(Dispatchers.Main) { result.success(true) }
                                } catch (e: Exception) {
                                    withContext(Dispatchers.Main) {
                                        result.error("INSTALL_FAILED", e.message, null)
                                    }
                                }
                            }
                        }

                        "toggleMod" -> {
                            val fileName = call.argument<String>("fileName")
                            if (fileName == null) {
                                result.error("INVALID_NAME", "Filename kosong", null)
                                return@setMethodCallHandler
                            }
                            val modsDir = File(downloader.gameDataDir, "mods")
                            val file = File(modsDir, fileName)
                            if (file.exists()) {
                                if (fileName.endsWith(".disabled")) {
                                    file.renameTo(File(modsDir, fileName.removeSuffix(".disabled")))
                                } else {
                                    file.renameTo(File(modsDir, "$fileName.disabled"))
                                }
                                result.success(true)
                            } else {
                                result.error("NOT_FOUND", "File mod tidak ditemukan", null)
                            }
                        }

                        "getLogs" -> {
                            val crashLog = File(downloader.gameDataDir, "crash.log")
                            val latestLog = File(downloader.gameDataDir, "logs/latest.log")
                            val content = when {
                                crashLog.exists() -> "=== CRASH LOG ===\n" + crashLog.readText().takeLast(3500)
                                latestLog.exists() -> "=== LATEST LOG ===\n" + latestLog.readText().takeLast(3500)
                                else -> "Belum ada catatan crash. Engine berjalan normal."
                            }
                            result.success(content)
                        }

                        "clearLogs" -> {
                            val crashLog = File(downloader.gameDataDir, "crash.log")
                            if (crashLog.exists()) crashLog.delete()
                            result.success(true)
                        }

                        "launchGame" -> {
                            if (!downloader.isPrepared()) {
                                result.error("NOT_PREPARED", "Resources 26.3 belum terverifikasi 100%", null)
                                return@setMethodCallHandler
                            }

                            val ramMb = call.argument<Int>("ramMb") ?: 2048
                            val threads = call.argument<Int>("workerThreads") ?: 4
                            val backend = call.argument<String>("backend") ?: "vulkan"
                            val touchScheme = call.argument<Int>("touchScheme") ?: 0
                            val username = call.argument<String>("username") ?: "HorizonPlayer"

                            val launchIntent = Intent(this, HorizonGameActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_DOCUMENT or Intent.FLAG_ACTIVITY_MULTIPLE_TASK
                                putExtra("EXTRA_RESOURCES_DIR", downloader.targetDir.absolutePath)
                                putExtra("EXTRA_RAM_MB", ramMb)
                                putExtra("EXTRA_WORKER_THREADS", threads)
                                putExtra("EXTRA_BACKEND", backend)
                                putExtra("EXTRA_TOUCH_SCHEME", touchScheme)
                                putExtra("EXTRA_USERNAME", username)
                            }
                            startActivity(launchIntent)
                            result.success(true)
                        }

                        else -> result.notImplemented()
                    }
                } catch (t: Throwable) {
                    android.util.Log.e("MainActivity", "MethodChannel error: ${t.message}", t)
                    result.error("EXCEPTION", t.message, null)
                }
            }
    }

    private fun createDownloaderListener() = object : ResourceDownloader.ProgressListener {
        override fun onProgress(stage: String, progress: Double, speedBytesPerSec: Long, detail: String) {
            mainHandler.post {
                progressEventSink?.success(
                    mapOf(
                        "status" to "downloading",
                        "stage" to stage,
                        "progress" to progress,
                        "speed" to speedBytesPerSec,
                        "detail" to detail
                    )
                )
            }
        }

        override fun onComplete(resourcesPath: String, sha256: String) {
            mainHandler.post {
                progressEventSink?.success(
                    mapOf(
                        "status" to "completed",
                        "stage" to "Selesai",
                        "progress" to 1.0,
                        "speed" to 0L,
                        "detail" to "Resources 26.3 diverifikasi",
                        "path" to resourcesPath,
                        "sha256" to sha256
                    )
                )
            }
        }

        override fun onError(error: String) {
            mainHandler.post {
                progressEventSink?.success(
                    mapOf(
                        "status" to "error",
                        "error" to error
                    )
                )
            }
        }
    }

    private fun installMod(urlStr: String) {
        val client = OkHttpClient()
        val request = Request.Builder().url(urlStr).build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) throw java.io.IOException("Gagal download mod: HTTP ${response.code}")
            val body = response.body ?: throw java.io.IOException("Empty mod body")

            val filename = urlStr.substringAfterLast("/").takeIf { it.endsWith(".hmod") }
                ?: "mod_${System.currentTimeMillis()}.hmod"

            val modsDir = File(downloader.gameDataDir, "mods").apply { mkdirs() }
            val modFile = File(modsDir, filename)

            FileOutputStream(modFile).use { fos ->
                body.byteStream().use { it.copyTo(fos) }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        currentInstance = null
        scope.cancel()
    }
}
