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
    private var initialSharedUrl: String? = null

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
                    val urlToReturn = initialSharedUrl ?: processIntent(intent)
                    initialSharedUrl = null // Clear after returning once
                    result.success(urlToReturn)
                }
                else -> result.notImplemented()
            }
        }
        
        // Process intent when app is first launched
        val extracted = processIntent(intent)
        if (extracted != null) {
            initialSharedUrl = extracted
            // Also attempt to notify Flutter directly if listener is already registered
            flutterEngine.dartExecutor.binaryMessenger.let { messenger ->
                MethodChannel(messenger, SHARE_CHANNEL).invokeMethod("onSharedUrl", extracted)
            }
        }
    }

    private fun saveFileToDownloads(sourceFilePath: String, displayName: String): String {
        val sourceFile = File(sourceFilePath)
        
        if (!sourceFile.exists()) {
            throw Exception("Source file does not exist: $sourceFilePath")
        }

        // Determine MIME type from file extension
        val mimeType = when (displayName.substringAfterLast('.', "").lowercase()) {
            "mp4" -> "video/mp4"
            "webm" -> "video/webm"
            "mkv" -> "video/x-matroska"
            "mp3" -> "audio/mpeg"
            "m4a" -> "audio/mp4"
            "ogg" -> "audio/ogg"
            "srt" -> "application/x-subrip"
            "vtt" -> "text/vtt"
            else -> "application/octet-stream"
        }

        // Use MediaStore for Android 10+ (API 29+)
        val resolver = contentResolver
        val contentValues = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, displayName)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
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
        val extracted = processIntent(intent)
        if (extracted != null) {
            initialSharedUrl = extracted
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, SHARE_CHANNEL).invokeMethod("onSharedUrl", extracted)
            }
        }
    }
    
    private fun processIntent(intent: Intent?): String? {
        if (intent == null) return null
        
        val rawText = when (intent.action) {
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
        
        return extractYouTubeUrl(rawText)
    }
    
    private fun extractYouTubeUrl(text: String?): String? {
        if (text.isNullOrBlank()) return null
        // Regex to extract clean YouTube URL from shared text (e.g. "Check out this video https://youtu.be/xyz")
        val regex = Regex("""https?://(?:www\.|m\.)?(?:youtube\.com/(?:watch\?v=|shorts/|embed/)|youtu\.be/)[a-zA-Z0-9_-]+[^\s]*""")
        val match = regex.find(text)
        return match?.value ?: if (isYouTubeUrl(text)) text.trim() else null
    }
    
    private fun isYouTubeUrl(url: String): Boolean {
        return url.contains("youtube.com") || url.contains("youtu.be")
    }
}
