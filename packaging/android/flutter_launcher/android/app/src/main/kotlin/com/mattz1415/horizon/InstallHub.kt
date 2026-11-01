// InstallHub.kt
// Kotlin / Android / process-wide owner of the resource install job
package com.mattz1415.horizon

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper

/**
 * Lives as long as the main process, not as long as an activity. The download keeps
 * running when the launcher is closed or recreated, and whoever attaches later gets
 * the last event replayed so the progress bar never starts from zero.
 */
object InstallHub {

    fun interface Sink {
        fun onEvent(event: Map<String, Any?>)
    }

    private val main = Handler(Looper.getMainLooper())
    private val sinks = LinkedHashSet<Sink>()
    private var downloader: ResourceDownloader? = null

    @Volatile
    var last: Map<String, Any?>? = null
        private set

    @Volatile
    var busy = false
        private set

    fun downloader(context: Context): ResourceDownloader =
        downloader ?: ResourceDownloader(context.applicationContext).also { downloader = it }

    fun attach(sink: Sink) {
        main.post {
            sinks.add(sink)
            last?.let { if (busy) sink.onEvent(it) }
        }
    }

    fun detach(sink: Sink) {
        main.post { sinks.remove(sink) }
    }

    fun startDownload(context: Context) {
        val d = downloader(context)
        busy = true
        DownloadService.start(context)
        d.startDownload(listener)
    }

    fun importZip(context: Context, uri: Uri) {
        val d = downloader(context)
        busy = true
        DownloadService.start(context)
        d.importPreparedZip(uri, listener)
    }

    fun pause(context: Context) {
        downloader(context).pauseDownload()
    }

    private fun emit(event: Map<String, Any?>) {
        last = event
        main.post {
            sinks.toList().forEach { it.onEvent(event) }
        }
    }

    private val listener = object : ResourceDownloader.ProgressListener {
        override fun onProgress(stage: String, progress: Double, speedBytesPerSec: Long, detail: String) {
            busy = true
            emit(
                mapOf(
                    "status" to "downloading",
                    "stage" to stage,
                    "progress" to progress,
                    "speed" to speedBytesPerSec,
                    "detail" to detail
                )
            )
        }

        override fun onComplete(resourcesPath: String, sha256: String) {
            busy = false
            emit(
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

        override fun onError(error: String) {
            busy = false
            if (error.startsWith("Download dijeda")) emit(mapOf("status" to "paused"))
            else emit(mapOf("status" to "error", "error" to error))
        }
    }
}
