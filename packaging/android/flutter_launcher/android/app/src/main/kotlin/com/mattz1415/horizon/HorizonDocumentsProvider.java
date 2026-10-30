package com.mattz1415.horizon;

import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.CancellationSignal;
import android.os.ParcelFileDescriptor;
import android.provider.DocumentsContract;
import android.provider.DocumentsProvider;
import java.io.FileNotFoundException;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public final class HorizonDocumentsProvider extends DocumentsProvider {
    static { System.loadLibrary("horizon_android"); }

    private static native String nativeCall(String method, String arg);
    private static native int nativeOpen(String documentId, String mode);

    private static final String[] DEFAULT_ROOT_PROJECTION = {
        DocumentsContract.Root.COLUMN_ROOT_ID,
        DocumentsContract.Root.COLUMN_MIME_TYPES,
        DocumentsContract.Root.COLUMN_FLAGS,
        DocumentsContract.Root.COLUMN_ICON,
        DocumentsContract.Root.COLUMN_TITLE,
        DocumentsContract.Root.COLUMN_SUMMARY,
        DocumentsContract.Root.COLUMN_DOCUMENT_ID,
        DocumentsContract.Root.COLUMN_AVAILABLE_BYTES,
    };

    private static final String[] DEFAULT_DOCUMENT_PROJECTION = {
        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
        DocumentsContract.Document.COLUMN_MIME_TYPE,
        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        DocumentsContract.Document.COLUMN_FLAGS,
        DocumentsContract.Document.COLUMN_SIZE,
    };

    @Override public boolean onCreate() { return true; }

    @Override public Cursor queryRoots(String[] projection) {
        MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_ROOT_PROJECTION);
        try {
            String json = nativeCall("queryRoots", "");
            if (json == null) return result;
            JSONArray array = new JSONArray(json);
            for (int i = 0; i < array.length(); i++) {
                JSONObject o = array.getJSONObject(i);
                MatrixCursor.RowBuilder row = result.newRow();
                for (String col : result.getColumnNames()) {
                    if (o.has(col)) row.add(col, o.get(col));
                }
            }
        } catch (JSONException e) {
            // Empty cursor on JSON error
        }
        return result;
    }

    @Override public Cursor queryDocument(String documentId, String[] projection) throws FileNotFoundException {
        MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_DOCUMENT_PROJECTION);
        try {
            String json = nativeCall("queryDocument", documentId);
            if (json == null) throw new FileNotFoundException(documentId);
            JSONObject o = new JSONObject(json);
            MatrixCursor.RowBuilder row = result.newRow();
            for (String col : result.getColumnNames()) {
                if (o.has(col)) row.add(col, o.get(col));
            }
        } catch (JSONException e) {
            throw new FileNotFoundException(documentId);
        }
        return result;
    }

    @Override public Cursor queryChildDocuments(String parentDocumentId, String[] projection, String sortOrder) throws FileNotFoundException {
        MatrixCursor result = new MatrixCursor(projection != null ? projection : DEFAULT_DOCUMENT_PROJECTION);
        try {
            String json = nativeCall("queryChildDocuments", parentDocumentId);
            if (json == null) throw new FileNotFoundException(parentDocumentId);
            JSONArray array = new JSONArray(json);
            for (int i = 0; i < array.length(); i++) {
                JSONObject o = array.getJSONObject(i);
                MatrixCursor.RowBuilder row = result.newRow();
                for (String col : result.getColumnNames()) {
                    if (o.has(col)) row.add(col, o.get(col));
                }
            }
        } catch (JSONException e) {
            throw new FileNotFoundException(parentDocumentId);
        }
        return result;
    }

    @Override public ParcelFileDescriptor openDocument(String documentId, String mode, CancellationSignal signal) throws FileNotFoundException {
        int fd = nativeOpen(documentId, mode);
        if (fd < 0) throw new FileNotFoundException(documentId);
        return ParcelFileDescriptor.adoptFd(fd);
    }
}
