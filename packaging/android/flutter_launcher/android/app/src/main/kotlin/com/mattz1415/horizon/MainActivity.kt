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
        const val REGISTRY_INDEX = "https://horizon-rust.github.io/horizon-mods/index.json"

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
    private val REQUEST_SAF_ADDON = 4103
    private var pendingImport: MethodChannel.Result? = null
    private val store by lazy { LauncherStore(downloader.gameDataDir) }
    private val addons by lazy { AddonStore(downloader.gameDataDir, store) }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_SAF_ZIP && resultCode == Activity.RESULT_OK) {
            val uri = data?.data
            if (uri != null) {
                downloader.importPreparedZip(uri, createDownloaderListener())
            }
        }
        if (requestCode == REQUEST_SAF_ADDON) {
            val pending = pendingImport
            pendingImport = null
            val uri = data?.data
            if (pending == null) return
            if (resultCode != Activity.RESULT_OK || uri == null) {
                pending.success(null)
                return
            }
            scope.launch {
                try {
                    val imported = addons.import(contentResolver, uri)
                    withContext(Dispatchers.Main) { pending.success(imported) }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) { pending.error("IMPORT_FAILED", e.message, null) }
                }
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
        AddonStore.migrateOldFolders(File(filesDir, "game_data"))
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
                            result.success(addons.list())
                        }

                        "fetchRegistry" -> scope.launch {
                            val cache = File(downloader.gameDataDir, "registry-index.json")
                            try {
                                val text = httpText(REGISTRY_INDEX)
                                JSONObject(text)
                                cache.parentFile?.mkdirs()
                                val tmp = File(cache.parentFile, cache.name + ".tmp")
                                tmp.writeText(text)
                                tmp.renameTo(cache)
                                withContext(Dispatchers.Main) {
                                    result.success(mapOf("json" to text, "cached" to false, "fetched" to cache.lastModified()))
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    if (cache.exists()) {
                                        result.success(mapOf("json" to cache.readText(), "cached" to true, "fetched" to cache.lastModified(), "error" to (e.message ?: "")))
                                    } else {
                                        result.error("REGISTRY_FAILED", e.message ?: "Tidak ada koneksi", null)
                                    }
                                }
                            }
                        }

                        "getScreenshots" -> scope.launch {
                            val dir = File(downloader.gameDataDir, "screenshots")
                            val shots = (dir.listFiles() ?: emptyArray())
                                .filter { it.isFile && it.name.endsWith(".png", ignoreCase = true) }
                                .sortedByDescending { it.lastModified() }
                                .map { mapOf("path" to it.absolutePath, "name" to it.name, "modified" to it.lastModified(), "size" to it.length()) }
                            withContext(Dispatchers.Main) { result.success(shots) }
                        }

                        "deleteScreenshot" -> {
                            val name = call.argument<String>("name") ?: ""
                            val dir = File(downloader.gameDataDir, "screenshots")
                            val f = File(dir, name)
                            if (name.isNotEmpty() && !name.contains('/') && f.canonicalFile.parentFile == dir.canonicalFile && f.delete()) result.success(true)
                            else result.error("NOT_FOUND", "Screenshot tidak ditemukan", null)
                        }

                        "openUrl" -> {
                            val url = call.argument<String>("url") ?: ""
                            if (!url.startsWith("https://")) {
                                result.error("INVALID_URL", "Hanya tautan https", null)
                                return@setMethodCallHandler
                            }
                            try {
                                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("NO_BROWSER", "Tidak ada aplikasi untuk membuka tautan", null)
                            }
                        }

                        "installModFromUrl" -> {
                            val url = call.argument<String>("url")
                            val type = call.argument<String>("type") ?: "mod"
                            val sha = call.argument<String>("sha256")
                            val name = call.argument<String>("fileName")
                            if (url == null) {
                                result.error("INVALID_URL", "URL tidak boleh kosong", null)
                                return@setMethodCallHandler
                            }
                            scope.launch {
                                try {
                                    val file = installAddon(url, LauncherStore.folderFor(type), sha, name)
                                    withContext(Dispatchers.Main) { result.success(file.name) }
                                } catch (e: Exception) {
                                    withContext(Dispatchers.Main) {
                                        result.error("INSTALL_FAILED", e.message, null)
                                    }
                                }
                            }
                        }

                        "toggleMod" -> {
                            val fileName = call.argument<String>("fileName")
                            val type = call.argument<String>("type") ?: "mod"
                            if (fileName == null) {
                                result.error("INVALID_NAME", "Filename kosong", null)
                                return@setMethodCallHandler
                            }
                            if (addons.toggle(type, fileName)) result.success(true)
                            else result.error("NOT_FOUND", "File tidak ditemukan", null)
                        }

                        "deleteAddon" -> {
                            val fileName = call.argument<String>("fileName") ?: ""
                            val type = call.argument<String>("type") ?: "mod"
                            if (addons.delete(type, fileName)) result.success(true)
                            else result.error("NOT_FOUND", "File tidak ditemukan", null)
                        }

                        "importAddon" -> {
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                            }
                            pendingImport?.error("CANCELLED", "Diganti impor baru", null)
                            pendingImport = result
                            startActivityForResult(intent, REQUEST_SAF_ADDON)
                        }

                        "getLauncherSettings" -> result.success(store.readLauncher())

                        "saveLauncherSettings" -> {
                            store.writeLauncher(call.argument<String>("json") ?: "{}")
                            result.success(true)
                        }

                        "getGameOptions" -> result.success(store.readGameOptions())

                        "saveGameOptions" -> {
                            @Suppress("UNCHECKED_CAST")
                            val values = call.arguments as? Map<String, Any?> ?: emptyMap()
                            store.writeGameOptions(values)
                            result.success(true)
                        }

                        "getWorlds" -> scope.launch {
                            val worlds = store.worlds()
                            withContext(Dispatchers.Main) { result.success(worlds) }
                        }

                        "deleteWorld" -> {
                            val name = call.argument<String>("name") ?: ""
                            if (store.deleteWorld(name)) result.success(true)
                            else result.error("NOT_FOUND", "Dunia tidak ditemukan", null)
                        }

                        "getDeviceInfo" -> scope.launch {
                            val info = store.deviceInfo(this@MainActivity, downloader.targetDir)
                            withContext(Dispatchers.Main) { result.success(info) }
                        }

                        "shareText" -> {
                            val text = call.argument<String>("text") ?: ""
                            val send = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            startActivity(Intent.createChooser(send, "Bagikan log"))
                            result.success(true)
                        }

                        "getLogs" -> {
                            val crashLog = File(downloader.gameDataDir, "crash.log")
                            val latestLog = File(downloader.gameDataDir, "logs/latest.log")
                            result.success(
                                mapOf(
                                    "crash" to (if (crashLog.exists()) crashLog.readText().takeLast(20000) else ""),
                                    "crashModified" to (if (crashLog.exists()) crashLog.lastModified() else 0L),
                                    "latest" to (if (latestLog.exists()) latestLog.readText().takeLast(20000) else ""),
                                    "latestModified" to (if (latestLog.exists()) latestLog.lastModified() else 0L)
                                )
                            )
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
                                // singleTask + intoExisting already reuse the running game.
                                // MULTIPLE_TASK used to spawn a second :game process, which
                                // doubled memory pressure and produced the ANR popups.
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                        Intent.FLAG_ACTIVITY_SINGLE_TOP
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

    private val http by lazy {
        OkHttpClient.Builder().followRedirects(true).followSslRedirects(true)
            .connectTimeout(15, java.util.concurrent.TimeUnit.SECONDS)
            .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
            .build()
    }

    private fun httpText(url: String): String =
        http.newCall(Request.Builder().url(url).build()).execute().use { r ->
            if (!r.isSuccessful) throw java.io.IOException("HTTP ${r.code}")
            r.body?.string() ?: throw java.io.IOException("Respons kosong")
        }

    private fun installAddon(urlStr: String, targetSubdir: String, expectedSha: String? = null, fileName: String? = null): File {
        val resolvedUrl = when {
            urlStr.contains("playhorizon.dev/shaders/golden-hour") -> "https://github.com/Mattz1415/horizon-android/releases/latest/download/golden-hour.hshader"
            urlStr.contains("playhorizon.dev/shaders/vanilla-enhanced") -> "https://github.com/Mattz1415/horizon-android/releases/latest/download/vanilla-enhanced.hshader"
            urlStr.contains("playhorizon.dev/packs/bare-bones") -> "https://github.com/Mattz1415/horizon-android/releases/latest/download/bare-bones-26.3.zip"
            urlStr.contains("playhorizon.dev/packs/programmer-art") -> "https://github.com/Mattz1415/horizon-android/releases/latest/download/programmer-art.zip"
            urlStr.contains("coords-hud.hmod") -> "https://github.com/Mattz1415/horizon-android/releases/latest/download/coords_hud-0.1.0.hmod"
            urlStr.contains("zoom.hmod") -> "https://github.com/Mattz1415/horizon-android/releases/latest/download/zoom.hmod"
            urlStr.contains("fullbright.hmod") -> "https://github.com/Mattz1415/horizon-android/releases/latest/download/fullbright.hmod"
            else -> urlStr
        }
        val request = Request.Builder().url(resolvedUrl).build()
        http.newCall(request).execute().use { response ->
            if (!response.isSuccessful) throw java.io.IOException("Gagal download: HTTP ${response.code}")
            val body = response.body ?: throw java.io.IOException("Empty body")

            val ext = when (targetSubdir) {
                "shaderpacks" -> ".hshader"
                "resourcepacks" -> ".zip"
                else -> ".hmod"
            }
            val filename = fileName?.takeIf { it.matches(Regex("[A-Za-z0-9._-]+")) && it.contains(".") }
                ?: resolvedUrl.substringAfterLast("/").takeIf { it.contains(".") }
                ?: "addon_${System.currentTimeMillis()}$ext"

            val dir = File(downloader.gameDataDir, targetSubdir).apply { mkdirs() }
            val destFile = File(dir, filename)

            val partial = File(dir, "$filename.part")
            val digest = java.security.MessageDigest.getInstance("SHA-256")
            FileOutputStream(partial).use { fos ->
                body.byteStream().use { input ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        digest.update(buf, 0, n)
                        fos.write(buf, 0, n)
                    }
                }
            }
            if (partial.length() == 0L) {
                partial.delete()
                throw java.io.IOException("File kosong dari server")
            }
            if (!expectedSha.isNullOrBlank()) {
                val got = digest.digest().joinToString("") { "%02x".format(it) }
                if (!got.equals(expectedSha.trim(), ignoreCase = true)) {
                    partial.delete()
                    throw java.io.IOException("Checksum tidak cocok, file ditolak")
                }
            }
            destFile.delete()
            if (!partial.renameTo(destFile)) throw java.io.IOException("Gagal menyimpan $filename")
            return destFile
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        currentInstance = null
        scope.cancel()
    }
}
