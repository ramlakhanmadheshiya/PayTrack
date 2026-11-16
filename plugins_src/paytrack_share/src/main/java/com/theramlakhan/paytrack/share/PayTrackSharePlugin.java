package com.theramlakhan.paytrack.share;

import android.app.Activity;
import android.content.Intent;
import android.database.Cursor;
import android.content.ContentResolver;
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
	 * Opens the system file picker in PickActivity (a small invisible screen
	 * that receives the chosen file itself, then closes). Godot asks
	 * pickStatus() until it is no longer "waiting".
	 */
	@UsedByGodot
	public boolean pickFile() {
		final Activity activity = getActivity();
		if (activity == null) {
			error = "no activity";
			return false;
		}
		try {
			PickActivity.status = "waiting";
			activity.runOnUiThread(() -> {
				try {
					activity.startActivity(new Intent(activity, PickActivity.class));
				} catch (Exception e) {
					PickActivity.status = "error:open " + e;
				}
			});
			return true;
		} catch (Exception e) {
			error = "pick: " + e;
			return false;
		}
	}

	/** "idle", "waiting", "done:<path>", "cancelled" or "error:<why>". */
	@UsedByGodot
	public String pickStatus() {
		String s = PickActivity.status;
		if (!s.equals("waiting") && !s.equals("idle")) {
			PickActivity.status = "idle";
		}
		return s;
	}
}
