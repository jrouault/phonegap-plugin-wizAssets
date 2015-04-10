/*
 *  __    __ _                  _     _                _                                                  ___ _             _
 * / / /\ \ (_)______ _ _ __ __| |   /_\  ___ ___  ___| |_    /\/\   __ _ _ __   __ _  __ _  ___ _ __    / _ \ |_   _  __ _(_)_ __
 * \ \/  \/ / |_  / _` | '__/ _` |  //_\\/ __/ __|/ _ \ __|  /    \ / _` | '_ \ / _` |/ _` |/ _ \ '__|  / /_)/ | | | |/ _` | | '_ \
 *  \  /\  /| |/ / (_| | | | (_| | /  _  \__ \__ \  __/ |_  / /\/\ \ (_| | | | | (_| | (_| |  __/ |    / ___/| | |_| | (_| | | | | |
 *   \/  \/ |_/___\__,_|_|  \__,_| \_/ \_/___/___/\___|\__| \/    \/\__,_|_| |_|\__,_|\__, |\___|_|    \/    |_|\__,_|\__, |_|_| |_|
 *                                                                                    |___/                           |___/
 * @author 	Ally Ogilvie
 * @copyright Wizcorp Inc. [ Incorporated Wizards ] 2012
 * @file	- wizAssetManagerPlugin.java
 * @about	- Handle JavaScript API calls from PhoneGap to WizAssetsPlugin
 */

package jp.wizcorp.phonegap.plugin.WizAssets;

import java.io.*;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.Date;
import java.util.zip.GZIPInputStream;

import android.annotation.SuppressLint;
import android.os.AsyncTask;
import android.os.Build;
import android.util.Base64;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import org.apache.http.Header;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.util.Log;

import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.entity.BufferedHttpEntity;
import org.apache.http.impl.client.DefaultHttpClient;

public class WizAssetsPlugin extends CordovaPlugin {

	private String TAG = "WizAssetsPlugin";
	private WizAssetManager wizAssetManager = null;

	private static final String DOWNLOAD_FILE_ACTION = "downloadFile";
	private static final String GET_FILE_URI_ACTION = "getFileURI";
	private static final String GET_FILE_URIS_ACTION = "getFileURIs";
	private static final String DELETE_FILE_ACTION = "deleteFile";
	private static final String DELETE_FILES_ACTION = "deleteFiles";
	private static final String GET_ASSETS_VERSION_ACTION = "getAssetsVersion";
	private static final String UPGRADE_ASSETS_ACTION = "upgradeAssets";

	private String pathToStorage;

	@Override
	public void initialize(CordovaInterface cordova, CordovaWebView webView) {
		super.initialize(cordova, webView);
		pathToStorage = cordova.getActivity().getApplicationContext().getCacheDir().getAbsolutePath() + File.separator;
	}

	@Override
	public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {

		if (wizAssetManager == null) {
			wizAssetManager = new WizAssetManager(cordova.getActivity().getApplicationContext());
		}

		if (action.equals(DOWNLOAD_FILE_ACTION)) {
			final String url = args.getString(0);
			final String fileURL = args.getString(1);
			final CallbackContext _callbackContext = callbackContext;
			cordova.getThreadPool().execute(new Runnable() {
				public void run() {
					// Split by "/"
					String[] splitURL = fileURL.split("/");
					// Last element is name
					String fileName = splitURL[splitURL.length - 1];

					String dirName = "";
					for (int i=0; i < splitURL.length-1; i++) {
						dirName = dirName + splitURL[i] + "/";
					}
					String uri = dirName + fileName;
					String filePath = buildAssetFilePathFromUri(uri);
					String asset = getAssetFilePathFromUri(uri);
					File file = new File(filePath);
					if (asset != null && file.exists()) {
						Log.d(TAG, "[Is in cache] " + fileURL);
						// File is already in cache folder, don't download it

						// Update the modification date of the file
						file.setLastModified(new Date().getTime());

						String result = "file://" + file.getAbsolutePath();

						_callbackContext.success(result);
					} else {
						// File is not in cache folder, download it

						PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
						result.setKeepCallback(true);
						_callbackContext.sendPluginResult(result);
						downloadUrl(url, dirName, fileName, "true", _callbackContext);
					}
				}
			});
			return true;

		} else if (action.equals(GET_FILE_URI_ACTION)) {

			Log.d(TAG, "[getFileURI] search full file path for: "+ args.toString() );
			String asset = null;

			try {
				String relativePath = args.getString(0);
				asset = getAssetFilePathFromUri(relativePath);
			} catch (JSONException e) {
				Log.d(TAG, "[getFileURI] error: " + e.toString());
				callbackContext.error(e.toString());
			}

			if (asset == null) {
				callbackContext.error("NotFoundError");
			} else {
				Log.d(TAG, "[getFileURI] Returning full path: " + asset);
				callbackContext.success(asset);
			}
			return true;

		} else if (action.equals(GET_FILE_URIS_ACTION)) {

			// Return all assets as asset map object
			Log.d(TAG, "[getFileURIs] *********** >>>>>>> ");
			JSONObject assetObject = wizAssetManager.getAllAssets();
			Log.d(TAG, "[getFileURIs] RETURN *********** >>>>>>> " + assetObject.toString());
			callbackContext.success(assetObject);
			return true;

		} else if (action.equals(DELETE_FILES_ACTION)) {

			// Delete all files from given array
			Log.d(TAG, "[deleteFiles] *********** ");
			deleteAssets(args, false, new DeleteAssetsCallback(callbackContext));

			return true;

		} else if (action.equals(DELETE_FILE_ACTION)) {

			Log.d(TAG, "[deleteFile] *********** " + args.getString(0));
			String filePath = args.getString(0);
			try {
				deleteAsset(filePath, false);
			} catch (IOException e) {
				callbackContext.error("Deleting file failed.");
				return true;
			}

			// Callback success for any outcome.
			callbackContext.success();
			return true;

		} else if (action.equals(GET_ASSETS_VERSION_ACTION)) {
			String assetsVersion;
			try {
				assetsVersion = wizAssetManager.getAssetsVersion();
			} catch (Exception e) {
				callbackContext.error("Get assets version failed.");
				return true;
			}

			callbackContext.success(assetsVersion);
			return true;
		} else if (action.equals(UPGRADE_ASSETS_ACTION)) {
			if (args.length() < 2) {
				callbackContext.error("Not enough parameters.");
				return true;
			}

			String newVersion;
			JSONArray changedFiles;
			try {
				newVersion = args.getString(0);
				changedFiles = args.getJSONArray(1);
			} catch (JSONException e) {
				callbackContext.error("Wrong parameters type.");
				return true;
			}

			deleteAssets(changedFiles, true, new UpdateAssetsCallback(callbackContext, newVersion));

			return true;
		}

		return false;  // Returning false results in a "MethodNotFound" error.
	}

	private String getAssetFilePathFromUri(String file) {
		String asset = wizAssetManager.getFile(file);
		if (asset == null || asset == "" || asset.contains("NotFoundError")) {
			return null;
		}

		return asset;
	}

	private String buildAssetFilePathFromUri(String uri) {
		return pathToStorage + uri;
	}

	private void deleteAssets(JSONArray files, boolean isUri, DeleteAssetsCallback callback) {
		AsyncDelete asyncDelete = new AsyncDelete(callback, isUri);
		asyncDelete.execute(files);
	}

	private void deleteAsset(String filePath, boolean isUri) throws IOException {
		// If file is in bundle we cannot delete so ignore and protect whole cache folder from being deleted
		if (filePath != "" && !filePath.contains("www/assets")) {
			if (isUri) {
				filePath = buildAssetFilePathFromUri(filePath);
			}
			File file = new File(filePath);
			deleteFile(file);
			// Delete from database
			wizAssetManager.deleteFile(filePath);
		}
	}

	private void deleteFile(File file) throws IOException {
		if(file.isDirectory()) {
			//directory is empty, then delete it
			if(file.list().length == 0){
				file.delete();
			} else {
				//list all the directory contents
				String files[] = file.list();

				for (String temp : files) {
					//construct the file structure
					File fileDelete = new File(file, temp);
					//recursive delete
					deleteFile(fileDelete);
				}
				//check the directory again, if empty then delete it
				if(file.list().length == 0) {
					file.delete();
				}
			}
		} else {
			//if file, then delete it
			file.delete();
		}
	}

	@SuppressLint("NewApi")
	private void downloadUrl(String fileUrl, String dirName, String fileName, String overwrite, CallbackContext callbackContext){
		// Download files to sdcard, or phone if sdcard not exists
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
			new asyncDownload(fileUrl, dirName, fileName, overwrite, callbackContext).executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);
		} else {
			new asyncDownload(fileUrl, dirName, fileName, overwrite, callbackContext).execute();
		}
	}

	public class DeleteAssetsCallback {
		private CallbackContext callbackContext;

		public DeleteAssetsCallback(CallbackContext callbackContext) {
			this.callbackContext = callbackContext;
		}

		public void notify(int result) {
			if (result < AsyncDelete.NO_ERROR) {
				this.callbackContext.error(getErrorMessage(result));
				return;
			}
			this.callbackContext.success();
		}

		public String getErrorMessage(int errorCode) {
			switch (errorCode) {
			case AsyncDelete.JSON_TYPE_ERROR:
				return AsyncDelete.JSON_TYPE_ERROR_MESSAGE;
			case AsyncDelete.IO_ERROR:
				return AsyncDelete.IO_ERROR_MESSAGE;
			case AsyncDelete.DELETE_CANCELED_ERROR:
				return AsyncDelete.DELETE_CANCELED_ERROR_MESSAGE;
			case AsyncDelete.DELETE_PARAMETERS_LENGTH_ERROR:
				return AsyncDelete.DELETE_PARAMETERS_LENGTH_ERROR_MESSAGE;
			case AsyncDelete.CALLBACK_ERROR:
				return AsyncDelete.CALLBACK_ERROR_MESSAGE;
			default:
				return null;
			}
		}
	}

	public class UpdateAssetsCallback extends DeleteAssetsCallback {
		private String newVersion;

		public UpdateAssetsCallback(CallbackContext callbackContext, String newVersion) {
			super(callbackContext);
			this.newVersion = newVersion;
		}

		@Override
		public void notify(int result) {
			if (result == AsyncDelete.NO_ERROR) {
				try {
					wizAssetManager.updateAssetsVersion(newVersion);
				} catch (Exception e) {
					result = AsyncDelete.CALLBACK_ERROR;
				}
			}
			super.notify(result);
		}
	}

	private class AsyncDelete extends AsyncTask<JSONArray, Integer, Integer> {
		private DeleteAssetsCallback callback;
		private boolean isUri;

		private static final int NO_ERROR = 0;
		private static final int JSON_TYPE_ERROR = -1;
		private static final int IO_ERROR = -2;
		private static final int DELETE_CANCELED_ERROR = -3;
		private static final int DELETE_PARAMETERS_LENGTH_ERROR = -4;
		private static final int CALLBACK_ERROR = -5;

		private static final String JSON_TYPE_ERROR_MESSAGE = "Wrong parameters type.";
		private static final String IO_ERROR_MESSAGE = "Deleting files failed.";
		private static final String DELETE_CANCELED_ERROR_MESSAGE = "Deleting files canceled.";
		private static final String DELETE_PARAMETERS_LENGTH_ERROR_MESSAGE = "Number of parameters different than expected.";
		private static final String CALLBACK_ERROR_MESSAGE = "Call to delete callback failed.";

		// Constructor
		public AsyncDelete(DeleteAssetsCallback callback, boolean isUri) {
			this.callback = callback;
			this.isUri = isUri;
		}

		protected Integer doInBackground(JSONArray... jsonArrays) {
			int count = jsonArrays.length;
			if (count != 1) {
				return DELETE_PARAMETERS_LENGTH_ERROR;
			}

			// We only process one array, no more than one JSON array should be passed
			JSONArray jsonArray = jsonArrays[0];
			int countFiles = jsonArray.length();
			for (int i = 0; i < countFiles; i++) {
				try {
					deleteAsset(jsonArray.getString(i), isUri);
				} catch (JSONException e) {
					return JSON_TYPE_ERROR;
				} catch (IOException e) {
					return IO_ERROR;
				}

				// Escape early if cancel() is called
				if (isCancelled()) {
					return DELETE_CANCELED_ERROR;
				}
			}

			return NO_ERROR;
		}

		protected void onPostExecute(Integer result) {
			callback.notify(result);
		}
	}

	private class asyncDownload extends AsyncTask<File, String , String> {

		private String dirName;
		private String fileName;
		private String fileUrl;
		private String overwrite;
		private CallbackContext callbackContext;

		// Constructor
		public asyncDownload(String fileUrl, String dirName, String fileName, String overwrite, CallbackContext callbackContext) {
			// Assign class vars
			this.fileName = fileName;
			this.dirName = dirName;
			this.fileUrl = fileUrl;
			this.callbackContext = callbackContext;
			this.overwrite = overwrite;
		}

		@Override
		protected String doInBackground(File... params) {
			// Run async download task
			String result;
			File dir = new File(pathToStorage + this.dirName);
			if (!dir.exists()) {
				// Create the directory if not existing
				dir.mkdirs();
			}

			String filePath = buildAssetFilePathFromUri(this.dirName + this.fileName);
			File file = new File(filePath);
			Log.d(TAG, "[Downloading] " + file.getAbsolutePath());

			if (this.overwrite.equals("false") && file.exists()){
				Log.d(TAG, "File already exists.");
				result = "file already exists";
				this.callbackContext.success(result);
				return null;
			}

			try {
				URL url = new URL(this.fileUrl);
				HttpGet httpRequest = null;
				httpRequest = new HttpGet(url.toURI());

				HttpClient httpclient = new DefaultHttpClient();

				// Credential check
				String credentials = url.getUserInfo();
				if (credentials != null) {
					// Add Basic Authentication header
					httpRequest.setHeader("Authorization", "Basic " + Base64.encodeToString(credentials.getBytes(), Base64.NO_WRAP));
				}

				HttpResponse response = httpclient.execute(httpRequest);
				HttpEntity entity = response.getEntity();

				InputStream is;

				Header contentHeader = entity.getContentEncoding();
				if (contentHeader != null) {
					if (contentHeader.getValue().contains("gzip")) {
						Log.d(TAG, "GGGGGGGGGZIIIIIPPPPPED!");
						is = new GZIPInputStream(entity.getContent());
					} else {
						BufferedHttpEntity bufHttpEntity = new BufferedHttpEntity(entity);
						is = bufHttpEntity.getContent();
					}
				} else {
					BufferedHttpEntity bufHttpEntity = new BufferedHttpEntity(entity);
					is = bufHttpEntity.getContent();
				}
				byte[] buffer = new byte[1024];

				int len1 = 0;

				FileOutputStream fos = new FileOutputStream(file);

				while ( (len1 = is.read(buffer)) > 0 ) {
					fos.write(buffer,0, len1);
				}

				fos.close();
				is.close();
				result = "file://" + file.getAbsolutePath();

				this.callbackContext.success(result);

				// Tell Asset Manager to register this download to asset database
				Log.d(TAG, "[Downloaded ] " + file.getAbsolutePath());
				wizAssetManager.downloadedAsset(this.dirName + this.fileName, file.getAbsolutePath());

			} catch (MalformedURLException e) {
				Log.e("WizAssetsPlugin", "Bad url : ", e);
				result = "file:///android_asset/" + this.dirName +  this.fileName;
				this.callbackContext.error("notFoundError");
			} catch (Exception e) {
				Log.e("WizAssetsPlugin", "Error : " + e);
				e.printStackTrace();
				result = "file:///android_asset/" + this.dirName + this.fileName;
				this.callbackContext.error("unknownError");
			}
			return null;
		}
	}
}

