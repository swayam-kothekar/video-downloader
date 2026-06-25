package com.example.video_downloader

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.OutputStream

class MainActivity : FlutterActivity() {
    private val STORAGE_CHANNEL = "com.example.video_downloader/storage"
    private val SHARE_CHANNEL = "com.example.video_downloader/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Storage channel for saving files to Downloads
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val filePath = call.argument<String>("filePath")
                    val displayName = call.argument<String>("displayName")
                    
                    if (filePath == null || displayName == null) {
                        result.error("INVALID_ARGUMENTS", "File path and display name are required", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        val savedUri = saveFileToDownloads(filePath, displayName)
                        result.success(savedUri)
                    } catch (e: Exception) {
                        result.error("SAVE_ERROR", "Failed to save file: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // Share channel for receiving shared URLs
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedUrl" -> {
                    val sharedUrl = handleIntent(intent)
                    result.success(sharedUrl)
                }
                else -> result.notImplemented()
            }
        }
        
        // Handle intent when app is first launched with a shared URL
        handleIntent(intent)
    }

    private fun saveFileToDownloads(sourceFilePath: String, displayName: String): String {
        val sourceFile = File(sourceFilePath)
        
        if (!sourceFile.exists()) {
            throw Exception("Source file does not exist: $sourceFilePath")
        }

        // Use MediaStore for Android 10+ (API 29+)
        val resolver = contentResolver
        val contentValues = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, displayName)
            put(MediaStore.Downloads.MIME_TYPE, "video/mp4")
            put(MediaStore.Downloads.IS_PENDING, 1)
        }

        // Insert the file into MediaStore
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val itemUri = resolver.insert(collection, contentValues)
            ?: throw Exception("Failed to create MediaStore entry")

        // Write the file content
        var outputStream: OutputStream? = null
        var inputStream: FileInputStream? = null
        
        try {
            outputStream = resolver.openOutputStream(itemUri)
                ?: throw Exception("Failed to open output stream")
            
            inputStream = FileInputStream(sourceFile)
            
            val buffer = ByteArray(8192)
            var bytesRead: Int
            while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                outputStream.write(buffer, 0, bytesRead)
            }
            
            outputStream.flush()
            
            // Mark the file as complete
            contentValues.clear()
            contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(itemUri, contentValues, null, null)
            
            return itemUri.toString()
        } finally {
            inputStream?.close()
            outputStream?.close()
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        
        val sharedUrl = when (intent.action) {
            Intent.ACTION_SEND -> {
                if (intent.type == "text/plain") {
                    intent.getStringExtra(Intent.EXTRA_TEXT)
                } else null
            }
            Intent.ACTION_VIEW -> {
                intent.dataString
            }
            else -> null
        }
        
        // Send the URL to Flutter via the share channel
        sharedUrl?.let { url ->
            if (isYouTubeUrl(url)) {
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, SHARE_CHANNEL).invokeMethod("onSharedUrl", url)
                }
            }
        }
    }
    
    private fun isYouTubeUrl(url: String): Boolean {
        return url.contains("youtube.com") || url.contains("youtu.be")
    }
}
