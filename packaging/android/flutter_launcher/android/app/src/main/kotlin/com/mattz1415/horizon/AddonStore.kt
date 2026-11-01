package com.mattz1415.horizon

import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.util.zip.ZipFile

/**
 * Mods, shader packs and resource packs in the folders the engine reads
 * (`horizon-mods`, `shaderpacks`, `resourcepacks` beside options.txt).
 *
 * How each kind is switched on matches the engine: a mod is loaded when its file ends
 * in `.hmod`, a shader pack when `pickedShaderPack` names it, and a resource pack when
 * `resourcePacks` in options.txt lists it as `file/<name>`.
 */
class AddonStore(private val gameData: File, private val store: LauncherStore) {

    companion object {
        private const val OFF = ".disabled"

        /** Earlier launchers saved into `mods/` and `shaders/`, which the engine never read. */
        fun migrateOldFolders(gameData: File) {
            for ((from, to) in listOf("mods" to "horizon-mods", "shaders" to "shaderpacks")) {
                val old = File(gameData, from)
                val files = old.listFiles() ?: continue
                val dest = File(gameData, to).apply { mkdirs() }
                for (f in files) {
                    val ok = f.name.endsWith(".hmod") || f.name.endsWith(".hmod$OFF") || f.name.endsWith(".hshader")
                    if (ok && !File(dest, f.name).exists()) f.renameTo(File(dest, f.name))
                }
            }
        }
    }

    private fun dir(type: String) = File(gameData, LauncherStore.folderFor(type)).apply { mkdirs() }

    private fun manifestOf(file: File, entry: String): Map<String, String> {
        if (!file.isFile) return emptyMap()
        return try {
            ZipFile(file).use { zip ->
                val e = zip.getEntry(entry) ?: return emptyMap()
                val text = zip.getInputStream(e).bufferedReader().readText()
                val out = mutableMapOf<String, String>()
                // Only the top table: stop at the first [section].
                for (line in text.lineSequence()) {
                    val t = line.trim()
                    if (t.startsWith("[")) break
                    val m = Regex("""^(\w+)\s*=\s*"(.*)"\s*$""").find(t) ?: continue
                    out[m.groupValues[1]] = m.groupValues[2]
                }
                out
            }
        } catch (_: Exception) {
            emptyMap()
        }
    }

    private fun wasmSize(file: File): Long = try {
        ZipFile(file).use { it.getEntry("mod.wasm")?.size ?: -1L }
    } catch (_: Exception) {
        -1L
    }

    fun list(): List<Map<String, Any>> {
        val out = mutableListOf<Map<String, Any>>()
        dir("mod").listFiles()?.sortedBy { it.name.lowercase() }?.forEach { f ->
            val on = f.name.endsWith(".hmod")
            if (!on && !f.name.endsWith(".hmod$OFF")) return@forEach
            val m = manifestOf(f, "horizon-mod.toml")
            val wasm = wasmSize(f)
            out += mapOf(
                "type" to "mod",
                "fileName" to f.name,
                "name" to (m["name"] ?: f.name.removeSuffix(OFF).removeSuffix(".hmod")),
                "version" to (m["version"] ?: ""),
                "description" to (m["description"] ?: ""),
                "size" to f.length(),
                "enabled" to on,
                // A component is never this small; such files load as nothing.
                "broken" to (wasm in 0..63),
            )
        }
        val picked = store.pickedShader()
        dir("shader").listFiles()?.sortedBy { it.name.lowercase() }?.forEach { f ->
            if (f.name.startsWith(".") || f.name.endsWith(".part")) return@forEach
            val isPack = f.name.endsWith(".hshader") || f.name.endsWith(".zip") ||
                File(f, "horizon-shaders.toml").exists() || File(f, "shaders").isDirectory
            if (!isPack) return@forEach
            val m = if (f.isFile) manifestOf(f, "horizon-shaders.toml") else emptyMap()
            out += mapOf(
                "type" to "shader",
                "fileName" to f.name,
                "name" to (m["name"] ?: f.name.removeSuffix(".hshader")),
                "version" to (m["version"] ?: ""),
                "description" to (m["description"] ?: ""),
                "size" to (if (f.isFile) f.length() else 0L),
                "enabled" to (picked == f.name),
                "broken" to false,
            )
        }
        val packs = store.resourcePacks()
        dir("pack").listFiles()?.sortedBy { it.name.lowercase() }?.forEach { f ->
            if (f.name.startsWith(".") || f.name.endsWith(".part")) return@forEach
            if (!(f.name.endsWith(".zip") || File(f, "pack.mcmeta").exists())) return@forEach
            val onlyMeta = f.isFile && try {
                ZipFile(f).use { z -> z.entries().asSequence().none { !it.isDirectory && it.name != "pack.mcmeta" && it.name != "pack.png" } }
            } catch (_: Exception) {
                true
            }
            out += mapOf(
                "type" to "pack",
                "fileName" to f.name,
                "name" to f.name.removeSuffix(".zip"),
                "version" to "",
                "description" to "",
                "size" to (if (f.isFile) f.length() else 0L),
                "enabled" to packs.contains("file/${f.name}"),
                "broken" to onlyMeta,
            )
        }
        return out
    }

    fun toggle(type: String, fileName: String): Boolean {
        val d = dir(type)
        val f = File(d, fileName)
        if (!f.exists() || fileName.contains('/')) return false
        return when (type) {
            "shader" -> {
                store.setPickedShader(if (store.pickedShader() == fileName) "" else fileName)
                true
            }
            "pack" -> {
                val list = store.resourcePacks()
                val id = "file/$fileName"
                if (!list.remove(id)) list.add(id)
                store.setResourcePacks(list)
                true
            }
            else -> if (fileName.endsWith(OFF)) f.renameTo(File(d, fileName.removeSuffix(OFF)))
            else f.renameTo(File(d, "$fileName$OFF"))
        }
    }

    fun delete(type: String, fileName: String): Boolean {
        if (fileName.isBlank() || fileName.contains('/') || fileName.startsWith(".")) return false
        val f = File(dir(type), fileName)
        if (!f.exists()) return false
        if (type == "shader" && store.pickedShader() == fileName) store.setPickedShader("")
        if (type == "pack") {
            val list = store.resourcePacks()
            if (list.remove("file/$fileName")) store.setResourcePacks(list)
        }
        return f.deleteRecursively()
    }

    /** Copies a picked file into the right folder by its extension. Returns the type, or throws. */
    fun import(resolver: ContentResolver, uri: Uri): Map<String, String> {
        var name = "addon"
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) name = c.getString(0) ?: name
        }
        name = name.substringAfterLast('/').replace(Regex("""[\\:*?"<>|]"""), "_")
        val type = when {
            name.endsWith(".hmod", true) -> "mod"
            name.endsWith(".hshader", true) -> "shader"
            name.endsWith(".zip", true) -> "pack"
            else -> throw IllegalArgumentException("Jenis file tidak dikenal: $name. Pakai .hmod, .hshader atau .zip.")
        }
        val dest = File(dir(type), name)
        val partial = File(dest.parentFile, "$name.part")
        resolver.openInputStream(uri)?.use { input ->
            partial.outputStream().use { input.copyTo(it) }
        } ?: throw IllegalStateException("File tidak bisa dibuka")
        dest.delete()
        partial.renameTo(dest)
        return mapOf("type" to type, "fileName" to name)
    }
}
