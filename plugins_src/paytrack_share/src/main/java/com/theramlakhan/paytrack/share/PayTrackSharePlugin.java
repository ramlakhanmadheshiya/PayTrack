package com.theramlakhan.paytrack.share;

import android.app.Activity;
import android.content.Intent;
import android.database.Cursor;
import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.ContentValues;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.MediaStore;
import android.provider.OpenableColumns;

import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.HashSet;

import org.json.JSONArray;
import org.json.JSONObject;
import java.util.Set;

/**
 * PayTrack's bridge to Android:
 *   share(path, mime, text)  opens the system share sheet (WhatsApp, Drive, ...) with a file
 *                            from the app's own storage (Godot's FileProvider covers user://).
 *   pickFile()               opens the system file picker; the chosen file is copied into the
 *                            app's cache and its path is sent with the "file_picked" signal.
 */
public class PayTrackSharePlugin extends GodotPlugin {
	private static final int PICK_REQUEST = 47301;
	private String error = "";

	public PayTrackSharePlugin(Godot godot) {
		super(godot);
	}

	@NonNull
	@Override
	public String getPluginName() {
		return "PayTrackShare";
	}

	@NonNull
	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> signals = new HashSet<>();
		signals.add(new SignalInfo("file_picked", String.class));
		signals.add(new SignalInfo("pick_failed", String.class));
		signals.add(new SignalInfo("pick_cancelled"));
		return signals;
	}

	@UsedByGodot
	public String lastError() {
		return error;
	}

	@UsedByGodot
	public boolean share(String path, String mime, String text) {
		final Activity activity = getActivity();
		if (activity == null) {
			error = "no activity";
			return false;
		}
		try {
			Intent send = new Intent(Intent.ACTION_SEND);
			if (text != null && !text.isEmpty()) {
				send.putExtra(Intent.EXTRA_TEXT, text);
			}
			Uri uri = FileProvider.getUriForFile(activity, activity.getPackageName() + ".fileprovider", new File(path));
			send.setType(mime);
			send.putExtra(Intent.EXTRA_STREAM, uri);
			send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
			final Intent chooser = Intent.createChooser(send, "PayTrack");
			chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
			activity.runOnUiThread(() -> activity.startActivity(chooser));
			return true;
		} catch (Exception e) {
			error = "share: " + e;
			return false;
		}
	}

	/** Copies a file from the app's storage into the phone's Downloads folder. */
	@UsedByGodot
	public boolean saveToDownloads(String path, String name, String mime) {
		final Activity activity = getActivity();
		if (activity == null) {
			error = "no activity";
			return false;
		}
		try {
			OutputStream os;
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				ContentResolver cr = activity.getContentResolver();
				ContentValues v = new ContentValues();
				v.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
				v.put(MediaStore.MediaColumns.MIME_TYPE, mime);
				v.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/PayTrack");
				Uri uri = cr.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, v);
				if (uri == null) {
					error = "save: no uri";
					return false;
				}
				os = cr.openOutputStream(uri);
			} else {
				File dir = new File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "PayTrack");
				dir.mkdirs();
				os = new FileOutputStream(new File(dir, name));
			}
			try (InputStream in = new FileInputStream(path); OutputStream out = os) {
				byte[] buf = new byte[64 * 1024];
				int n;
				while ((n = in.read(buf)) > 0) {
					out.write(buf, 0, n);
				}
			}
			return true;
		} catch (Exception e) {
			error = "save: " + e;
			return false;
		}
	}

	/**
	 * Backups PayTrack saved in Downloads/PayTrack (its own files, readable
	 * without any permission), newest first, as a JSON array of
	 * {name, uri, date (unix seconds), size}.
	 */
	@UsedByGodot
	public String listBackups() {
		JSONArray out = new JSONArray();
		final Activity activity = getActivity();
		if (activity == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
			return out.toString();
		}
		String[] cols = {MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DISPLAY_NAME, MediaStore.MediaColumns.DATE_MODIFIED, MediaStore.MediaColumns.SIZE};
		try (Cursor c = activity.getContentResolver().query(MediaStore.Downloads.EXTERNAL_CONTENT_URI, cols,
				MediaStore.MediaColumns.RELATIVE_PATH + " LIKE ?", new String[]{Environment.DIRECTORY_DOWNLOADS + "/PayTrack%"},
				MediaStore.MediaColumns.DATE_MODIFIED + " DESC")) {
			while (c != null && c.moveToNext()) {
				String name = c.getString(1);
				if (name == null || !(name.endsWith(".json") || name.endsWith(".paytrack"))) {
					continue;
				}
				JSONObject o = new JSONObject();
				o.put("name", name);
				o.put("uri", ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, c.getLong(0)).toString());
				o.put("date", c.getLong(2));
				o.put("size", c.getLong(3));
				out.put(o);
			}
		} catch (Exception e) {
			error = "list: " + e;
		}
		return out.toString();
	}

	/** Copies a content:// file into the app's cache; returns its path ("" on error, see lastError). */
	@UsedByGodot
	public String copyToCache(String uriText) {
		final Activity activity = getActivity();
		if (activity == null) {
			error = "no activity";
			return "";
		}
		try {
			File out = new File(activity.getCacheDir(), "import.json");
			try (InputStream in = activity.getContentResolver().openInputStream(Uri.parse(uriText));
				 OutputStream os = new FileOutputStream(out)) {
				if (in == null) {
					error = "cannot open";
					return "";
				}
				byte[] buf = new byte[64 * 1024];
				int n;
				while ((n = in.read(buf)) > 0) {
					os.write(buf, 0, n);
				}
			}
			return out.getAbsolutePath();
		} catch (Exception e) {
			error = "read: " + e;
			return "";
		}
	}

	@UsedByGodot
	public boolean pickFile() {
		final Activity activity = getActivity();
		if (activity == null) {
			error = "no activity";
			return false;
		}
		try {
			// GET_CONTENT through a chooser: Android asks which app to choose
			// with (Files, My Files, Drive…), and that app opens in "pick a
			// file" mode. Some phones' file managers opened by OPEN_DOCUMENT
			// only browse and never return the file.
			final Intent get = new Intent(Intent.ACTION_GET_CONTENT);
			get.addCategory(Intent.CATEGORY_OPENABLE);
			get.setType("*/*");
			final Intent chooser = Intent.createChooser(get, "PayTrack backup (.json)");
			activity.runOnUiThread(() -> activity.startActivityForResult(chooser, PICK_REQUEST));
			return true;
		} catch (Exception e) {
			error = "pick: " + e;
			return false;
		}
	}

	@Override
	public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
		super.onMainActivityResult(requestCode, resultCode, data);
		if (requestCode != PICK_REQUEST) {
			return;
		}
		if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
			runOnRenderThread(() -> emitSignal("pick_cancelled"));
			return;
		}
		Activity activity = getActivity();
		if (activity == null) {
			runOnRenderThread(() -> emitSignal("pick_failed", "no activity"));
			return;
		}
		Uri uri = data.getData();
		try {
			String name = "import.paytrack";
			try (Cursor c = activity.getContentResolver().query(uri, null, null, null, null)) {
				if (c != null && c.moveToFirst()) {
					int idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME);
					if (idx >= 0 && c.getString(idx) != null) {
						name = c.getString(idx).replaceAll("[^A-Za-z0-9._-]", "_");
					}
				}
			}
			File out = new File(activity.getCacheDir(), name);
			try (InputStream in = activity.getContentResolver().openInputStream(uri);
				 OutputStream os = new FileOutputStream(out)) {
				byte[] buf = new byte[64 * 1024];
				int n;
				while ((n = in.read(buf)) > 0) {
					os.write(buf, 0, n);
				}
			}
			final String picked = out.getAbsolutePath();
			// Signals go to the game thread, not Android's UI thread.
			runOnRenderThread(() -> emitSignal("file_picked", picked));
		} catch (Exception e) {
			final String msg = e.toString();
			runOnRenderThread(() -> emitSignal("pick_failed", msg));
		}
	}
}
