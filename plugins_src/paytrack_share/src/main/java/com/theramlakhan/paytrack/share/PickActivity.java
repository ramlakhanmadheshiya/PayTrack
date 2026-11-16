package com.theramlakhan.paytrack.share;

import android.app.Activity;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * An invisible screen that opens the system file picker, copies the chosen
 * file into the app's cache and closes. The result is left in `status` for
 * PayTrack to read (no callbacks between Android and Godot needed).
 */
public class PickActivity extends Activity {
	static volatile String status = "idle";
	private static final int REQUEST = 47302;

	@Override
	protected void onCreate(Bundle saved) {
		super.onCreate(saved);
		if (saved != null) {
			return; // re-created while the picker is open: wait for its result
		}
		try {
			Intent pick = new Intent(Intent.ACTION_OPEN_DOCUMENT);
			pick.addCategory(Intent.CATEGORY_OPENABLE);
			pick.setType("*/*");
			startActivityForResult(pick, REQUEST);
		} catch (Exception e) {
			status = "error:picker " + e;
			finish();
		}
	}

	@Override
	protected void onActivityResult(int requestCode, int resultCode, Intent data) {
		super.onActivityResult(requestCode, resultCode, data);
		if (requestCode != REQUEST) {
			return;
		}
		if (resultCode != RESULT_OK || data == null || data.getData() == null) {
			status = "cancelled";
			finish();
			return;
		}
		try {
			Uri uri = data.getData();
			String name = "import.json";
			try (Cursor c = getContentResolver().query(uri, null, null, null, null)) {
				if (c != null && c.moveToFirst()) {
					int idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME);
					if (idx >= 0 && c.getString(idx) != null) {
						name = c.getString(idx).replaceAll("[^A-Za-z0-9._-]", "_");
					}
				}
			} catch (Exception ignored) {
				// keep the default name
			}
			File out = new File(getCacheDir(), "picked-" + name);
			try (InputStream in = getContentResolver().openInputStream(uri);
				 OutputStream os = new FileOutputStream(out)) {
				if (in == null) {
					throw new Exception("cannot open the file");
				}
				byte[] buf = new byte[64 * 1024];
				int n;
				while ((n = in.read(buf)) > 0) {
					os.write(buf, 0, n);
				}
			}
			status = "done:" + out.getAbsolutePath();
		} catch (Exception e) {
			status = "error:copy " + e;
		}
		finish();
	}
}
