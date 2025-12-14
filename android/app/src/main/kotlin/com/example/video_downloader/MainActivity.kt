package com.example.video_downloader

import android.content.ContentValues
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
    private val CHANNEL = "com.example.video_downloader/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
}
