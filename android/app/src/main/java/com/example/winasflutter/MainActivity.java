package com.aidingnan.winas;

import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.database.Cursor;
import android.content.Intent;
import android.content.Context;
import android.content.ContentUris;
import android.provider.MediaStore;
import android.annotation.SuppressLint;
import android.provider.DocumentsContract;

import java.io.File;
import java.util.Random;
import java.nio.ByteBuffer;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Array;
import java.io.FileOutputStream;

import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.ActivityLifecycleListener;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugins.GeneratedPluginRegistrant;
import io.flutter.util.PathUtils;

public class MainActivity extends FlutterActivity {

  public static final String TAG = "eventchannel";
  private String sharedFile;
  private EventChannel.EventSink channelEvents;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    GeneratedPluginRegistrant.registerWith(this);
    Intent intent = getIntent();
    String action = intent.getAction();
    String type = intent.getType();

    if (Intent.ACTION_SEND.equals(action) && type != null) {
      sharedFile = handleSendData(intent);
    }

    new MethodChannel(getFlutterView(), "app.channel.intent/init").setMethodCallHandler(new MethodCallHandler() {
      @Override
      public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (call.method.contentEquals("getSharedFile")) {
          result.success(sharedFile);
          sharedFile = null;
        }
      }
    });

    new EventChannel(getFlutterView(), "app.channel.intent/new").setStreamHandler(new EventChannel.StreamHandler() {
      @Override
      public void onListen(Object args, EventChannel.EventSink events) {
        channelEvents = events;
      }

      @Override
      public void onCancel(Object args) {
        channelEvents = null;
      }
    });
  }

  @Override
  protected void onNewIntent(Intent intent) {
    super.onNewIntent(intent);
    String action = intent.getAction();
    String type = intent.getType();
    if (Intent.ACTION_SEND.equals(action) && type != null) {
      String filePath = handleSendData(intent);
      if (channelEvents != null && filePath != null) {
        channelEvents.success(filePath);
      }
    }
  }

  private String handleSendData(Intent intent) {
    Uri uri = (Uri) intent.getExtras().get("android.intent.extra.STREAM");
    System.out.println("new Intent>>>>>>>>>>>>>>>>>>");
    System.out.println(uri);
    System.out.println(uri.getPath());

    // get fileName
    String path = uri.getPath();
    String absPath = getRealPathFromUri(this, uri);
    String fileName;

    if (absPath != null) {
      String arr[] = absPath.split("/");
      fileName= arr[arr.length - 1];
    } else {
      String arr[] = path.split("/");
      fileName = arr[arr.length - 1];
    }

    // get homeDir path and tmpFile path
    String homeDir = getPathProviderApplicationDocumentsDirectory();
    final int random = new Random().nextInt(100000);
    String saveDirPath = homeDir + File.separator + "trans" + File.separator + String.valueOf(random);
    String tmpFilePath = saveDirPath + File.separator + fileName;

    // copy file >>>>>>>>>>>>>>>>>>>>>>
    byte buffer[] = new byte[1024];
    int length = 0;
    try {
      File dir = new File(saveDirPath);
      dir.mkdirs();
      File f = new File(tmpFilePath);
      f.setWritable(true, false);
      OutputStream outputStream = new FileOutputStream(f);

      InputStream inputStream = getContentResolver().openInputStream(uri);
      while ((length = inputStream.read(buffer)) > 0) {
        outputStream.write(buffer, 0, length);
      }
      outputStream.close();
      inputStream.close();
    } catch (Exception e) {
      System.out.println("handle intent file error !!!");
      System.out.println(e.getMessage());
      tmpFilePath = null;
    }

    System.out.println("<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<tmpFile Path>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>");
    System.out.println(tmpFilePath);
    return tmpFilePath;

  }

  private String getPathProviderApplicationDocumentsDirectory() {
    return PathUtils.getDataDirectory(this);
  }

  /**
    * 根据Uri获取图片的绝对路径
    *
    * @param context 上下文对象
    * @param uri     图片的Uri
    * @return 如果Uri对应的图片存在, 那么返回该图片的绝对路径, 否则返回null
    */
  public static String getRealPathFromUri(Context context, Uri uri) {
      int sdkVersion = Build.VERSION.SDK_INT;
      if (sdkVersion >= 19) { // api >= 19
          return getRealPathFromUriAboveApi19(context, uri);
      } else { // api < 19
          return getRealPathFromUriBelowAPI19(context, uri);
      }
  }

  /**
    * 适配api19以下(不包括api19),根据uri获取图片的绝对路径
    *
    * @param context 上下文对象
    * @param uri     图片的Uri
    * @return 如果Uri对应的图片存在, 那么返回该图片的绝对路径, 否则返回null
    */
  private static String getRealPathFromUriBelowAPI19(Context context, Uri uri) {
      return getDataColumn(context, uri, null, null);
  }

  /**
    * 适配api19及以上,根据uri获取图片的绝对路径
    *
    * @param context 上下文对象
    * @param uri     图片的Uri
    * @return 如果Uri对应的图片存在, 那么返回该图片的绝对路径, 否则返回null
    */
  @SuppressLint("NewApi")
  private static String getRealPathFromUriAboveApi19(Context context, Uri uri) {
      String filePath = null;
      if (DocumentsContract.isDocumentUri(context, uri)) {
          // 如果是document类型的 uri, 则通过document id来进行处理
          String documentId = DocumentsContract.getDocumentId(uri);
          if (isMediaDocument(uri)) { // MediaProvider
              // 使用':'分割
              String id = documentId.split(":")[1];

              String selection = MediaStore.Images.Media._ID + "=?";
              String[] selectionArgs = {id};
              filePath = getDataColumn(context, MediaStore.Images.Media.EXTERNAL_CONTENT_URI, selection, selectionArgs);
          } else if (isDownloadsDocument(uri)) { // DownloadsProvider
              Uri contentUri = ContentUris.withAppendedId(Uri.parse("content://downloads/public_downloads"), Long.valueOf(documentId));
              filePath = getDataColumn(context, contentUri, null, null);
          }
      } else if ("content".equalsIgnoreCase(uri.getScheme())){
          // 如果是 content 类型的 Uri
          filePath = getDataColumn(context, uri, null, null);
      } else if ("file".equals(uri.getScheme())) {
          // 如果是 file 类型的 Uri,直接获取图片对应的路径
          filePath = uri.getPath();
      }
      return filePath;
  }

  /**
    * 获取数据库表中的 _data 列，即返回Uri对应的文件路径
    * @return
    */
  private static String getDataColumn(Context context, Uri uri, String selection, String[] selectionArgs) {
      String path = null;

      String[] projection = new String[]{MediaStore.Images.Media.DATA};
      Cursor cursor = null;
      try {
          cursor = context.getContentResolver().query(uri, projection, selection, selectionArgs, null);
          if (cursor != null && cursor.moveToFirst()) {
              int columnIndex = cursor.getColumnIndexOrThrow(projection[0]);
              path = cursor.getString(columnIndex);
          }
      } catch (Exception e) {
          if (cursor != null) {
              cursor.close();
          }
      }
      return path;
  }

  /**
    * @param uri the Uri to check
    * @return Whether the Uri authority is MediaProvider
    */
  private static boolean isMediaDocument(Uri uri) {
      return "com.android.providers.media.documents".equals(uri.getAuthority());
  }

  /**
    * @param uri the Uri to check
    * @return Whether the Uri authority is DownloadsProvider
    */
  private static boolean isDownloadsDocument(Uri uri) {
      return "com.android.providers.downloads.documents".equals(uri.getAuthority());
  }
}
