package com.theramlakhan.paytrack.share;

import android.app.Activity;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;

import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;
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

	@UsedByGodot
	public boolean pickFile() {
		final Activity activity = getActivity();
		if (activity == null) {
			error = "no activity";
			return false;
		}
		try {
			final Intent pick = new Intent(Intent.ACTION_OPEN_DOCUMENT);
			pick.addCategory(Intent.CATEGORY_OPENABLE);
			pick.setType("*/*");
			activity.runOnUiThread(() -> activity.startActivityForResult(pick, PICK_REQUEST));
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
			return; // cancelled
		}
		Activity activity = getActivity();
		if (activity == null) {
			emitSignal("pick_failed", "no activity");
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
			emitSignal("file_picked", out.getAbsolutePath());
		} catch (Exception e) {
			emitSignal("pick_failed", e.toString());
		}
	}
}
