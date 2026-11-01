package com.mattz1415.horizon

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import org.json.JSONObject
import java.io.File

/**
 * The files the engine reads at start, written the way the engine parses them:
 * `options.txt` (vanilla's `key:value` lines), `horizon-graphics.txt` (Horizon's own)
 * and the launcher's `launcher.json`. Unknown lines are kept untouched.
 */
class LauncherStore(private val gameData: File) {

    companion object {
        fun folderFor(type: String) = when (type) {
            "shader" -> "shaderpacks"
            "pack" -> "resourcepacks"
            else -> "horizon-mods"
        }

        // Ranges from crates/horizon-client-render/src/options_file.rs.
        private val INT_RANGES = mapOf(
            "renderDistance" to (2..64),
            "simulationDistance" to (2..32),
            "maxFps" to (10..260),
            "guiScale" to (0..8),
            "fov" to (30..110),
        )
    }

    private val optionsFile get() = File(gameData, "options.txt")
    private val graphicsFile get() = File(gameData, "horizon-graphics.txt")
    private val launcherFile get() = File(gameData, "launcher.json")

    fun readLauncher(): String =
        if (launcherFile.exists()) launcherFile.readText() else "{}"

    fun writeLauncher(json: String) {
        JSONObject(json)
        gameData.mkdirs()
        val tmp = File(gameData, "launcher.json.tmp")
        tmp.writeText(json)
        tmp.renameTo(launcherFile)
    }

    private fun readPairs(file: File): LinkedHashMap<String, String> {
        val map = LinkedHashMap<String, String>()
        if (!file.exists()) return map
        file.readLines().forEach { line ->
            val i = line.indexOf(':')
            if (i > 0) map[line.substring(0, i)] = line.substring(i + 1)
        }
        return map
    }

    private fun writePairs(file: File, map: Map<String, String>) {
        gameData.mkdirs()
        val tmp = File(file.parentFile, file.name + ".tmp")
        tmp.writeText(map.entries.joinToString("") { "${it.key}:${it.value}\n" })
        if (!tmp.renameTo(file)) {
            file.writeText(tmp.readText())
            tmp.delete()
        }
    }

    fun readGameOptions(): Map<String, Any?> {
        val o = readPairs(optionsFile)
        val g = readPairs(graphicsFile)
        val fov = o["fov"]?.toDoubleOrNull()?.let { (it * 40 + 70).toInt() } ?: 70
        return mapOf(
            "exists" to optionsFile.exists(),
            "renderDistance" to (o["renderDistance"]?.toIntOrNull() ?: 12),
            "simulationDistance" to (o["simulationDistance"]?.toIntOrNull() ?: 12),
            "maxFps" to (o["maxFps"]?.toIntOrNull() ?: 120),
            "guiScale" to (o["guiScale"]?.toIntOrNull() ?: 0),
            "fov" to fov,
            "lodDistance" to (g["lodDistance"]?.trim()?.toIntOrNull() ?: 0),
            "overlay" to (g["overlay"]?.trim() ?: "off"),
            "pickedShaderPack" to (g["pickedShaderPack"]?.trim() ?: ""),
        )
    }

    fun writeGameOptions(values: Map<String, Any?>) {
        val o = readPairs(optionsFile)
        if (!o.containsKey("version")) o["version"] = "5023"
        for ((key, range) in INT_RANGES) {
            val v = (values[key] as? Number)?.toInt() ?: continue
            val c = v.coerceIn(range)
            o[key] = if (key == "fov") ((c - 70) / 40.0).toString() else c.toString()
        }
        writePairs(optionsFile, o)

        val g = readPairs(graphicsFile)
        (values["lodDistance"] as? Number)?.toInt()?.let { g["lodDistance"] = it.coerceIn(0, 1024).toString() }
        (values["overlay"] as? String)?.takeIf { it in setOf("off", "fps", "graph") }?.let { g["overlay"] = it }
        if (values.containsKey("lodDistance") || values.containsKey("renderDistance")) {
            // A preset would overwrite these on the next start; the player picked values by hand.
            g["preset"] = "custom"
        }
        writePairs(graphicsFile, g)
    }

    fun pickedShader(): String = readPairs(graphicsFile)["pickedShaderPack"]?.trim() ?: ""

    fun setPickedShader(name: String) {
        val g = readPairs(graphicsFile)
        g["pickedShaderPack"] = name
        writePairs(graphicsFile, g)
    }

    /** `resourcePacks` from options.txt: a JSON list such as `["vanilla","file/x.zip"]`. */
    fun resourcePacks(): MutableList<String> {
        val raw = readPairs(optionsFile)["resourcePacks"] ?: return mutableListOf("vanilla")
        return try {
            val arr = org.json.JSONArray(raw)
            MutableList(arr.length()) { arr.getString(it) }
        } catch (_: Exception) {
            mutableListOf("vanilla")
        }
    }

    fun setResourcePacks(list: List<String>) {
        val o = readPairs(optionsFile)
        if (!o.containsKey("version")) o["version"] = "5023"
        o["resourcePacks"] = org.json.JSONArray(list).toString()
        writePairs(optionsFile, o)
    }

    fun worlds(): List<Map<String, Any>> {
        val saves = File(gameData, "saves")
        return saves.listFiles()
            ?.filter { it.isDirectory && File(it, "level.dat").exists() }
            ?.map { dir ->
                mapOf(
                    "name" to dir.name,
                    "modified" to (File(dir, "level.dat").lastModified()),
                    "size" to dir.walkTopDown().filter { it.isFile }.sumOf { it.length() },
                    "hasIcon" to File(dir, "icon.png").exists(),
                    "iconPath" to File(dir, "icon.png").absolutePath,
                )
            }
            ?.sortedByDescending { it["modified"] as Long }
            ?: emptyList()
    }

    fun deleteWorld(name: String): Boolean {
        if (name.isBlank() || name.contains('/') || name.startsWith(".")) return false
        val dir = File(File(gameData, "saves"), name)
        return dir.isDirectory && dir.deleteRecursively()
    }

    fun deviceInfo(context: Context, resources: File): Map<String, Any> {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mem = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
        return mapOf(
            "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "android" to Build.VERSION.RELEASE,
            "sdk" to Build.VERSION.SDK_INT,
            "abi" to (Build.SUPPORTED_ABIS.firstOrNull() ?: ""),
            "cores" to Runtime.getRuntime().availableProcessors(),
            "totalRam" to mem.totalMem,
            "availRam" to mem.availMem,
            "freeStorage" to context.filesDir.usableSpace,
            "gameDataSize" to gameData.walkTopDown().filter { it.isFile }.sumOf { it.length() },
            "resourcesSize" to if (resources.exists()) resources.walkTopDown().filter { it.isFile }.sumOf { it.length() } else 0L,
        )
    }
}
