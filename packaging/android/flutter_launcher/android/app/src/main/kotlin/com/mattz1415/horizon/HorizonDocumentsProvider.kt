package com.mattz1415.horizon

import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.DocumentsProvider
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.io.FileNotFoundException
import java.util.ArrayList

/** Android SAF adapter. The allowlist, paths and file operations live in Rust. */
class HorizonDocumentsProvider : DocumentsProvider() {

    companion object {
        init {
            try {
                System.loadLibrary("horizon_android")
            } catch (_: Throwable) {}
        }

        private val ROOT_COLUMNS = arrayOf(
            "root_id", "document_id", "title", "flags", "mime_types", "icon"
        )
        private val DOCUMENT_COLUMNS = arrayOf(
            "document_id", "_display_name", "mime_type", "flags", "_size", "last_modified"
        )

        @JvmStatic
        @Throws(FileNotFoundException::class)
        private external fun nativeCall(home: String, operation: String, id: String, arg: String): String

        @JvmStatic
        @Throws(FileNotFoundException::class)
        private external fun nativeOpen(home: String, id: String, mode: String): Int
    }

    override fun onCreate(): Boolean = true

    @Throws(FileNotFoundException::class)
    private fun call(operation: String, id: String, arg: String): String {
        val filesDir = context?.filesDir?.absolutePath ?: throw FileNotFoundException("Context unavailable")
        return nativeCall(filesDir, operation, id, arg)
    }

    @Throws(FileNotFoundException::class)
    override fun queryRoots(projection: Array<String>?): Cursor {
        val cols = projection ?: ROOT_COLUMNS
        val cursor = MatrixCursor(cols)
        try {
            val rows = JSONArray(call("roots", "", ""))
            for (i in 0 until rows.length()) {
                val data = rows.getJSONObject(i)
                val row = cursor.newRow()
                for (col in cols) {
                    var value: Any? = data.opt(col)
                    if ("icon" == col) value = context?.applicationInfo?.icon
                    row.add(col, if (value == JSONObject.NULL) null else value)
                }
            }
        } catch (_: JSONException) {
            cursor.close()
            throw FileNotFoundException("Invalid Horizon document response")
        }
        return cursor
    }

    @Throws(FileNotFoundException::class)
    override fun queryDocument(documentId: String, projection: Array<String>?): Cursor {
        val cols = projection ?: DOCUMENT_COLUMNS
        val cursor = MatrixCursor(cols)
        try {
            val rows = JSONArray(call("document", documentId, ""))
            for (i in 0 until rows.length()) {
                val data = rows.getJSONObject(i)
                val row = cursor.newRow()
                for (col in cols) {
                    var value: Any? = data.opt(col)
                    if ("icon" == col) value = context?.applicationInfo?.icon
                    row.add(col, if (value == JSONObject.NULL) null else value)
                }
            }
        } catch (_: JSONException) {
            cursor.close()
            throw FileNotFoundException("Invalid document response")
        }
        return cursor
    }

    @Throws(FileNotFoundException::class)
    override fun queryChildDocuments(
        parentDocumentId: String,
        projection: Array<String>?,
        sortOrder: String?
    ): Cursor {
        val cols = projection ?: DOCUMENT_COLUMNS
        val cursor = MatrixCursor(cols)
        try {
            val rows = JSONArray(call("children", parentDocumentId, ""))
            for (i in 0 until rows.length()) {
                val data = rows.getJSONObject(i)
                val row = cursor.newRow()
                for (col in cols) {
                    var value: Any? = data.opt(col)
                    if ("icon" == col) value = context?.applicationInfo?.icon
                    row.add(col, if (value == JSONObject.NULL) null else value)
                }
            }
            val ctx = context
            if (ctx != null) {
                val children = DocumentsContract.buildChildDocumentsUri(
                    "${ctx.packageName}.documents",
                    parentDocumentId
                )
                cursor.setNotificationUri(ctx.contentResolver, children)
            }
        } catch (_: JSONException) {
            cursor.close()
            throw FileNotFoundException("Invalid children response")
        }
        return cursor
    }

    override fun isChildDocument(parentDocumentId: String, documentId: String): Boolean {
        return try {
            "true" == call("child", parentDocumentId, documentId)
        } catch (_: FileNotFoundException) {
            false
        }
    }

    @Throws(FileNotFoundException::class)
    override fun findDocumentPath(
        parentDocumentId: String?,
        childDocumentId: String
    ): DocumentsContract.Path {
        return try {
            val ids = JSONArray(call("path", childDocumentId, parentDocumentId ?: ""))
            val path = ArrayList<String>()
            for (i in 0 until ids.length()) {
                path.add(ids.getString(i))
            }
            DocumentsContract.Path(if (parentDocumentId == null) "horizon" else null, path)
        } catch (_: JSONException) {
            throw FileNotFoundException("Invalid document path")
        }
    }

    @Throws(FileNotFoundException::class)
    override fun openDocument(
        documentId: String,
        mode: String,
        signal: CancellationSignal?
    ): ParcelFileDescriptor {
        signal?.throwIfCanceled()
        val filesDir = context?.filesDir?.absolutePath ?: throw FileNotFoundException("Context unavailable")
        val fd = nativeOpen(filesDir, documentId, mode)
        if (fd < 0) throw FileNotFoundException("Could not open $documentId")
        return ParcelFileDescriptor.adoptFd(fd)
    }

    @Throws(FileNotFoundException::class)
    override fun createDocument(
        parentDocumentId: String,
        mimeType: String,
        displayName: String
    ): String {
        val op = if (DocumentsContract.Document.MIME_TYPE_DIR == mimeType) "mkdir" else "create"
        val response = call(op, parentDocumentId, displayName)
        notifyDocChanged(parentDocumentId, op)
        return try {
            JSONArray("[$response]").optString(0, null)
        } catch (_: JSONException) {
            throw FileNotFoundException("Invalid document ID")
        }
    }

    @Throws(FileNotFoundException::class)
    override fun renameDocument(documentId: String, displayName: String): String {
        val response = call("rename", documentId, displayName)
        notifyDocChanged(documentId, "rename")
        return try {
            JSONArray("[$response]").optString(0, null)
        } catch (_: JSONException) {
            throw FileNotFoundException("Invalid document ID")
        }
    }

    @Throws(FileNotFoundException::class)
    override fun deleteDocument(documentId: String) {
        call("delete", documentId, "")
        notifyDocChanged(documentId, "delete")
    }

    private fun notifyDocChanged(documentId: String, op: String) {
        val ctx = context ?: return
        val pkg = ctx.packageName
        ctx.contentResolver.notifyChange(DocumentsContract.buildRootsUri("$pkg.documents"), null)
        val parent = if (documentId.lastIndexOf('/') < 0) "horizon" else documentId.substringBeforeLast('/')
        val target = if (op == "create" || op == "mkdir") documentId else parent
        ctx.contentResolver.notifyChange(DocumentsContract.buildChildDocumentsUri("$pkg.documents", target), null)
    }
}
