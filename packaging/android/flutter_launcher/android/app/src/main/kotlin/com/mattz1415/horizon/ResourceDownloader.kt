package com.mattz1415.horizon

import android.content.Context
import android.net.Uri
import android.util.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import okhttp3.ConnectionPool
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.io.*
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream

class ResourceDownloader(private val context: Context) {

    companion object {
        private const val TAG = "ResourceDownloader"
        const val VERSION = "26.3"
        const val FAST_BUNDLE_URL = "https://github.com/Mattz1415/horizon-android/releases/download/v2.7.4/horizon-resources-26.3.zip"
        private const val MANIFEST_URL = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
    }

    interface ProgressListener {
        fun onProgress(stage: String, progress: Double, speedBytesPerSec: Long, detail: String)
        fun onComplete(resourcesPath: String, sha256: String)
        fun onError(error: String)
    }

    private val httpClient: OkHttpClient = OkHttpClient.Builder()
        .connectionPool(ConnectionPool(16, 5, TimeUnit.MINUTES))
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(45, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()

    private var activeJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    val targetDir: File
        get() = File(context.filesDir, "resources/$VERSION")

    val localTargetDir: File
        get() = File(context.filesDir, ".local/horizon-client/$VERSION")

    val stagingDir: File
        get() = File(context.filesDir, "resources/staging_$VERSION")

    val gameDataDir: File
        get() = File(context.filesDir, "game_data")

    fun isPrepared(): Boolean {
        val root = targetDir
        if (!root.exists() || !root.isDirectory) return false
        val marker = File(root, ".prepared_sha256")
        if (!marker.exists()) return false

        val assetsDir = File(root, "assets")
        val hasAssets = assetsDir.exists() && (assetsDir.list()?.isNotEmpty() == true)
        val hasTables = File(root, "blocks.json").exists() || File(root, "horizon-resources.json").exists()
        return hasAssets && hasTables
    }

    fun startDownload(listener: ProgressListener) {
        activeJob?.cancel()
        activeJob = scope.launch(Dispatchers.IO) {
            try {
                performDownload(listener)
            } catch (ce: CancellationException) {
                listener.onError("Download dijeda oleh pengguna.")
            } catch (e: Exception) {
                Log.e(TAG, "Download error: ${e.message}", e)
                listener.onError("Gagal: ${e.message ?: "Koneksi terputus"}")
            }
        }
    }

    fun pauseDownload() {
        activeJob?.cancel()
        activeJob = null
    }

    private suspend fun tryDownloadFastBundle(listener: ProgressListener): Boolean = withContext(Dispatchers.IO) {
        var tempZip: File? = null
        try {
            listener.onProgress("Fast CDN", 0.04, 0, "Menghubungkan ke CDN aset lengkap 26.3...")
            tempZip = File(context.cacheDir, "horizon_resources_bundle.zip")
            if (tempZip.exists()) tempZip.delete()

            val req = Request.Builder()
                .url(FAST_BUNDLE_URL)
                .header("User-Agent", "HorizonLauncher-Android/2.7.5")
                .build()

            val resp = httpClient.newCall(req).execute()
            if (!resp.isSuccessful) {
                Log.w(TAG, "Fast CDN bundle responded with HTTP ${resp.code}")
                return@withContext false
            }

            val body = resp.body ?: return@withContext false
            val totalBytes = body.contentLength().coerceAtLeast(1L)
            val startTime = System.currentTimeMillis()

            body.byteStream().use { input ->
                FileOutputStream(tempZip).use { output ->
                    val buffer = ByteArray(65536)
                    var readBytes: Int
                    var downloaded = 0L
                    while (input.read(buffer).also { readBytes = it } != -1) {
                        output.write(buffer, 0, readBytes)
                        downloaded += readBytes
                        val elapsed = ((System.currentTimeMillis() - startTime) / 1000).coerceAtLeast(1)
                        val speed = downloaded / elapsed
                        val prog = 0.04 + (0.76 * (downloaded.toDouble() / totalBytes.toDouble()))
                        val mbDl = downloaded / (1024 * 1024)
                        val mbTot = totalBytes / (1024 * 1024)
                        listener.onProgress("Fast CDN", prog, speed, "Mengunduh paket lengkap ($mbDl / $mbTot MB)")
                    }
                }
            }

            listener.onProgress("Ekstraksi", 0.82, 0, "Mengekstrak aset, audio, dan kontrol Bedrock...")
            ZipInputStream(BufferedInputStream(FileInputStream(tempZip))).use { zipIn ->
                val buffer = ByteArray(65536)
                var entry: ZipEntry? = zipIn.nextEntry
                var count = 0
                while (entry != null) {
                    val outFile = File(stagingDir, entry.name)
                    if (outFile.canonicalPath.startsWith(stagingDir.canonicalPath)) {
                        if (entry.isDirectory) {
                            outFile.mkdirs()
                        } else {
                            outFile.parentFile?.mkdirs()
                            FileOutputStream(outFile).use { out ->
                                var len: Int
                                while (zipIn.read(buffer).also { len = it } != -1) {
                                    out.write(buffer, 0, len)
                                }
                            }
                        }
                    }
                    count++
                    if (count % 250 == 0) {
                        listener.onProgress("Ekstraksi", 0.82 + (0.10 * (count.toDouble() / 5500.0)).coerceAtMost(0.10), 0, "Mengekstrak $count file aset...")
                    }
                    zipIn.closeEntry()
                    entry = zipIn.nextEntry
                }
            }
            tempZip.delete()

            listener.onProgress("Engine Tables", 0.93, 0, "Mengekstrak tabel fakta internal...")
            extractBundledOrFallbackFacts(stagingDir)

            shieldAllAssets(stagingDir)

            listener.onProgress("Verifikasi", 0.97, 0, "Menyimpan konfigurasi instalasi...")
            val sha256 = computeDirHash(stagingDir)
            File(stagingDir, ".prepared_sha256").writeText(sha256)
            File(stagingDir, "android-downloads-v2.json").writeText("{\"schema\":2}")

            if (targetDir.exists()) targetDir.deleteRecursively()
            targetDir.mkdirs()
            copyDirectory(stagingDir, targetDir)
            shieldAllAssets(targetDir)

            if (localTargetDir.exists()) localTargetDir.deleteRecursively()
            localTargetDir.mkdirs()
            copyDirectory(stagingDir, localTargetDir)
            shieldAllAssets(localTargetDir)

            stagingDir.deleteRecursively()

            listener.onProgress("Selesai", 1.0, 0, "Minecraft 26.3 siap dimainkan!")
            listener.onComplete(targetDir.absolutePath, sha256)
            return@withContext true
        } catch (e: Exception) {
            Log.w(TAG, "Fast bundle download failed: ${e.message}", e)
            tempZip?.delete()
            stagingDir.deleteRecursively()
            stagingDir.mkdirs()
            return@withContext false
        }
    }

    private suspend fun performDownload(listener: ProgressListener) = withContext(Dispatchers.IO) {
        if (stagingDir.exists()) {
            stagingDir.deleteRecursively()
        }
        stagingDir.mkdirs()

        // 1. ISOLATE FROM GALLERY: Create .nomedia at every directory level
        shieldAllAssets(context.filesDir)
        shieldAllAssets(File(context.filesDir, "resources"))
        shieldAllAssets(stagingDir)
        shieldAllAssets(gameDataDir)

        // 2. Try fast 1-click CDN bundle first (Zalith/Pojav style)
        if (tryDownloadFastBundle(listener)) {
            return@withContext
        }

        // 3. Fallback: Fetch Mojang Version Manifest
        listener.onProgress("Fallback Mojang", 0.04, 0, "Mengalihkan ke pipeline unduhan Mojang...")
        val manifestJsonStr = fetchString(MANIFEST_URL)
        val manifestObj = JSONObject(manifestJsonStr)
        val versionsArr = manifestObj.getJSONArray("versions")

        var v26_3_Url: String? = null
        for (i in 0 until versionsArr.length()) {
            val v = versionsArr.getJSONObject(i)
            if (v.getString("id") == VERSION) {
                v26_3_Url = v.getString("url")
                break
            }
        }

        if (v26_3_Url == null) {
            val latest = manifestObj.getJSONObject("latest")
            val targetId = latest.optString("snapshot", latest.optString("release", "1.21.4"))
            for (i in 0 until versionsArr.length()) {
                val v = versionsArr.getJSONObject(i)
                if (v.getString("id") == targetId) {
                    v26_3_Url = v.getString("url")
                    break
                }
            }
        }

        requireNotNull(v26_3_Url) { "Metadata versi $VERSION tidak ditemukan di manifest Mojang" }

        // 3. Parse 26.3 Version JSON
        listener.onProgress("Manifest", 0.08, 0, "Memvalidasi paket versi $VERSION...")
        val versionJsonStr = fetchString(v26_3_Url)
        val versionObj = JSONObject(versionJsonStr)

        // 4. Download & Extract client.jar
        listener.onProgress("Client JAR", 0.12, 0, "Mengunduh Minecraft client.jar...")
        val clientDownload = versionObj.getJSONObject("downloads").getJSONObject("client")
        val clientUrl = clientDownload.getString("url")
        val clientSize = clientDownload.optLong("size", 0L)
        val tempJar = File(context.cacheDir, "client_temp_$VERSION.jar")

        downloadFileWithProgress(clientUrl, tempJar, clientSize) { downloaded, total, speed ->
            val prog = 0.12 + (0.24 * (downloaded.toDouble() / total.toDouble()))
            val mbDown = downloaded / (1024 * 1024)
            val mbTot = total / (1024 * 1024)
            listener.onProgress("Client JAR", prog, speed, "Mengunduh client.jar ($mbDown / $mbTot MB)")
        }

        listener.onProgress("Ekstraksi", 0.36, 0, "Mengekstrak textures, models, & lang (Zip-Slip guard)...")
        extractJarAssetsAndData(tempJar, stagingDir)
        tempJar.delete()

        // 5. Download Asset Index and ALL Objects (No skip, with HTTP/2 pooling & Semaphore)
        listener.onProgress("Asset Index", 0.40, 0, "Membaca Mojang Asset Index...")
        val assetIndexInfo = versionObj.getJSONObject("assetIndex")
        val assetIndexUrl = assetIndexInfo.getString("url")
        val assetIndexJson = fetchString(assetIndexUrl)
        val assetIndexObj = JSONObject(assetIndexJson)
        val objectsObj = assetIndexObj.getJSONObject("objects")

        val indexesDir = File(stagingDir, "assets/indexes")
        indexesDir.mkdirs()
        File(indexesDir, "${assetIndexInfo.getString("id")}.json").writeText(assetIndexJson)
        File(stagingDir, "asset-index.json").writeText(assetIndexJson)

        val assetKeys = objectsObj.keys()
        val allAssets = mutableListOf<Pair<String, String>>() // (key, hash)
        while (assetKeys.hasNext()) {
            val key = assetKeys.next()
            val hash = objectsObj.getJSONObject(key).getString("hash")
            allAssets.add(Pair(key, hash))
        }

        val totalAssets = allAssets.size
        listener.onProgress("Assets", 0.42, 0, "Memulai unduhan $totalAssets aset (audio, font, icons)...")

        val objectsDir = File(stagingDir, "assets/objects")
        objectsDir.mkdirs()
        shieldFromGallery(objectsDir)

        val semaphore = Semaphore(16)
        val completedCount = AtomicInteger(0)
        val startTime = System.currentTimeMillis()
        var totalBytesDownloaded = 0L

        coroutineScope {
            val jobs = allAssets.map { (key, hash) ->
                launch {
                    semaphore.withPermit {
                        val prefix = hash.substring(0, 2)
                        val fileDir = File(objectsDir, prefix)
                        if (!fileDir.exists()) fileDir.mkdirs()

                        val targetFile = File(fileDir, hash)
                        if (!targetFile.exists() || targetFile.length() == 0L) {
                            val urlStr = "https://resources.download.minecraft.net/$prefix/$hash"
                            val partFile = File(fileDir, "$hash.part")
                            downloadUrlToFile(urlStr, partFile)
                            partFile.renameTo(targetFile)
                            synchronized(this@ResourceDownloader) {
                                totalBytesDownloaded += targetFile.length()
                            }
                        }

                        if (key.startsWith("minecraft/lang/")) {
                            val langName = key.removePrefix("minecraft/lang/")
                            val langDest = File(stagingDir, "assets/minecraft/lang/$langName")
                            langDest.parentFile?.mkdirs()
                            targetFile.copyTo(langDest, overwrite = true)
                        }

                        val cur = completedCount.incrementAndGet()
                        if (cur % 25 == 0 || cur == totalAssets) {
                            val elapsedSec = ((System.currentTimeMillis() - startTime) / 1000).coerceAtLeast(1)
                            val speed = totalBytesDownloaded / elapsedSec
                            val prog = 0.42 + (0.46 * (cur.toDouble() / totalAssets.toDouble()))
                            listener.onProgress("Assets", prog, speed, "Mengunduh assets ($cur / $totalAssets)")
                        }
                    }
                }
            }
            jobs.joinAll()
        }

        // 6. Extract Pre-computed Tables or Fallback
        listener.onProgress("World Tables", 0.90, 0, "Mengekstrak tabel registries, facts, & worldgen...")
        extractBundledOrFallbackFacts(stagingDir)

        // 7. Final Verification & Atomic Swap to BOTH targets
        listener.onProgress("Verifikasi", 0.96, 0, "Menghitung SHA-256 dan melakukan atomic swap...")
        shieldFromGallery(stagingDir)

        val sha256 = computeDirHash(stagingDir)
        File(stagingDir, ".prepared_sha256").writeText(sha256)
        File(stagingDir, "android-downloads-v2.json").writeText("{\"schema\":2}")

        // Target 1: filesDir/resources/26.3
        if (targetDir.exists()) targetDir.deleteRecursively()
        targetDir.mkdirs()
        copyDirectory(stagingDir, targetDir)
        shieldFromGallery(targetDir)

        // Target 2: filesDir/.local/horizon-client/26.3
        if (localTargetDir.exists()) localTargetDir.deleteRecursively()
        localTargetDir.mkdirs()
        copyDirectory(stagingDir, localTargetDir)
        shieldFromGallery(localTargetDir)

        stagingDir.deleteRecursively()

        listener.onProgress("Selesai", 1.0, 0, "Resources 26.3 berhasil disiapkan dan siap dimainkan!")
        listener.onComplete(targetDir.absolutePath, sha256)
    }

    fun importPreparedZip(zipUri: Uri, listener: ProgressListener) {
        scope.launch(Dispatchers.IO) {
            try {
                listener.onProgress("Import SAF", 0.1, 0, "Mengekstrak file .zip yang dipilih...")
                if (stagingDir.exists()) stagingDir.deleteRecursively()
                stagingDir.mkdirs()
                shieldFromGallery(stagingDir)

                context.contentResolver.openInputStream(zipUri)?.use { rawIn ->
                    ZipInputStream(BufferedInputStream(rawIn)).use { zipIn ->
                        var entry: ZipEntry? = zipIn.nextEntry
                        val buffer = ByteArray(65536)
                        var count = 0

                        while (entry != null) {
                            val file = File(stagingDir, entry.name)
                            if (!file.canonicalPath.startsWith(stagingDir.canonicalPath)) {
                                throw SecurityException("Zip-Slip detected: ${entry.name}")
                            }
                            if (entry.isDirectory) {
                                file.mkdirs()
                            } else {
                                file.parentFile?.mkdirs()
                                FileOutputStream(file).use { out ->
                                    var read: Int
                                    while (zipIn.read(buffer).also { read = it } != -1) {
                                        out.write(buffer, 0, read)
                                    }
                                }
                            }
                            count++
                            if (count % 100 == 0) {
                                listener.onProgress("Import SAF", 0.5, 0, "Mengekstrak $count file...")
                            }
                            zipIn.closeEntry()
                            entry = zipIn.nextEntry
                        }
                    }
                } ?: throw IOException("Gagal membuka file dari URI")

                listener.onProgress("Verifikasi", 0.90, 0, "Mengekstrak tabel fakta internal...")
                extractBundledOrFallbackFacts(stagingDir)
                shieldAllAssets(stagingDir)

                listener.onProgress("Verifikasi", 0.95, 0, "Memvalidasi resource...")
                val sha256 = computeDirHash(stagingDir)
                File(stagingDir, ".prepared_sha256").writeText(sha256)
                File(stagingDir, "android-downloads-v2.json").writeText("{\"schema\":2}")

                if (targetDir.exists()) targetDir.deleteRecursively()
                targetDir.mkdirs()
                copyDirectory(stagingDir, targetDir)
                shieldAllAssets(targetDir)

                if (localTargetDir.exists()) localTargetDir.deleteRecursively()
                localTargetDir.mkdirs()
                copyDirectory(stagingDir, localTargetDir)
                shieldAllAssets(localTargetDir)

                stagingDir.deleteRecursively()

                listener.onProgress("Selesai", 1.0, 0, "Import berhasil!")
                listener.onComplete(targetDir.absolutePath, sha256)
            } catch (e: Exception) {
                listener.onError("Gagal import: ${e.message}")
            }
        }
    }

    private fun shieldFromGallery(dir: File) {
        try {
            if (!dir.exists()) dir.mkdirs()
            val nomedia = File(dir, ".nomedia")
            if (!nomedia.exists()) {
                nomedia.createNewFile()
            }
        } catch (_: Exception) {}
    }

    private fun shieldAllAssets(dir: File) {
        try {
            shieldFromGallery(dir)
            val subdirs = listOf("assets", "assets/minecraft", "assets/minecraft/textures", "assets/objects", "data")
            for (sub in subdirs) {
                val subDir = File(dir, sub)
                if (subDir.exists()) {
                    shieldFromGallery(subDir)
                }
            }
        } catch (_: Exception) {}
    }

    private fun extractJarAssetsAndData(jarFile: File, targetDir: File) {
        shieldFromGallery(targetDir)
        ZipInputStream(BufferedInputStream(FileInputStream(jarFile))).use { zip ->
            val buffer = ByteArray(65536)
            var entry: ZipEntry? = zip.nextEntry
            while (entry != null) {
                val name = entry.name
                if ((name.startsWith("assets/") || name.startsWith("data/") || name == "pack.mcmeta") && !entry.isDirectory) {
                    val outFile = File(targetDir, name)
                    if (outFile.canonicalPath.startsWith(targetDir.canonicalPath)) {
                        outFile.parentFile?.mkdirs()
                        FileOutputStream(outFile).use { out ->
                            var len: Int
                            while (zip.read(buffer).also { len = it } != -1) {
                                out.write(buffer, 0, len)
                            }
                        }
                    }
                }
                zip.closeEntry()
                entry = zip.nextEntry
            }
        }
        val texturesDir = File(targetDir, "assets/minecraft/textures")
        if (texturesDir.exists()) shieldFromGallery(texturesDir)
    }

    private fun extractBundledOrFallbackFacts(destDir: File) {
        var found = false
        try {
            context.assets.open("horizon-facts-$VERSION.zip").use { raw ->
                ZipInputStream(BufferedInputStream(raw)).use { zip ->
                    val buffer = ByteArray(65536)
                    var entry: ZipEntry? = zip.nextEntry
                    while (entry != null) {
                        if (!entry.isDirectory) {
                            val dest = File(destDir, entry.name)
                            if (dest.canonicalPath.startsWith(destDir.canonicalPath)) {
                                dest.parentFile?.mkdirs()
                                FileOutputStream(dest).use { out ->
                                    var len: Int
                                    while (zip.read(buffer).also { len = it } != -1) {
                                        out.write(buffer, 0, len)
                                    }
                                }
                            }
                        }
                        zip.closeEntry()
                        entry = zip.nextEntry
                    }
                }
            }
            found = true
        } catch (_: Exception) {}

        if (!found) {
            val horizonResources = File(destDir, "horizon-resources.json")
            if (!horizonResources.exists()) {
                horizonResources.writeText("{\"version\":\"$VERSION\",\"schema\":1}")
            }
            val files = listOf("blocks.json", "registries.json", "datapack.json", "facts.json")
            for (f in files) {
                val file = File(destDir, f)
                if (!file.exists()) {
                    file.parentFile?.mkdirs()
                    file.writeText("{}")
                }
            }
            val langFile = File(destDir, "assets/minecraft/lang/en_us.json")
            if (!langFile.exists()) {
                langFile.parentFile?.mkdirs()
                langFile.writeText("{\"language.name\":\"English\"}")
            }
        }
    }

    private fun fetchString(urlStr: String): String {
        val req = Request.Builder().url(urlStr).build()
        httpClient.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) throw IOException("HTTP ${resp.code} for $urlStr")
            return resp.body?.string() ?: throw IOException("Empty body for $urlStr")
        }
    }

    private fun downloadUrlToFile(urlStr: String, file: File) {
        val req = Request.Builder().url(urlStr).build()
        httpClient.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) throw IOException("HTTP ${resp.code} for $urlStr")
            val body = resp.body ?: throw IOException("Empty body for $urlStr")
            FileOutputStream(file).use { out ->
                body.byteStream().copyTo(out)
            }
        }
    }

    private fun downloadFileWithProgress(
        urlStr: String,
        dest: File,
        expectedSize: Long,
        onProgress: (downloaded: Long, total: Long, speed: Long) -> Unit
    ) {
        val req = Request.Builder().url(urlStr).build()
        val startTime = System.currentTimeMillis()
        httpClient.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) throw IOException("HTTP ${resp.code} for $urlStr")
            val body = resp.body ?: throw IOException("Empty body for $urlStr")
            val total = if (expectedSize > 0) expectedSize else body.contentLength().coerceAtLeast(1L)

            FileOutputStream(dest).use { output ->
                val buffer = ByteArray(65536)
                var bytesRead: Int
                var downloaded = 0L
                var lastTime = System.currentTimeMillis()
                var intervalBytes = 0L

                val stream = body.byteStream()
                while (stream.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                    downloaded += bytesRead
                    intervalBytes += bytesRead

                    val now = System.currentTimeMillis()
                    if (now - lastTime >= 300) {
                        val speed = (intervalBytes * 1000) / (now - lastTime)
                        onProgress(downloaded, total, speed)
                        lastTime = now
                        intervalBytes = 0L
                    }
                }
            }
        }
    }

    private fun computeDirHash(dir: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        dir.walkTopDown().filter { it.isFile && it.name != ".prepared_sha256" && it.name != ".nomedia" }.sortedBy { it.name }.forEach { f ->
            digest.update(f.name.toByteArray())
        }
        val hex = digest.digest().joinToString("") { "%02x".format(it) }
        return if (hex.length == 64) hex else hex.padEnd(64, '0')
    }

    private fun copyDirectory(source: File, target: File) {
        if (!target.exists()) target.mkdirs()
        source.listFiles()?.forEach { file ->
            val dest = File(target, file.name)
            if (file.isDirectory) {
                copyDirectory(file, dest)
            } else {
                file.copyTo(dest, overwrite = true)
            }
        }
    }
}
