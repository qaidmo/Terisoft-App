package com.example.untitled4

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.terasoft/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendPdfToWhatsApp") {
                val path = call.argument<String>("path")
                val phone = call.argument<String>("phone")
                val packageName = call.argument<String>("packageName") ?: "com.whatsapp"
                val caption = call.argument<String>("caption")
                
                if (path != null && phone != null) {
                    try {
                        val file = File(path)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "The PDF file does not exist at the provided path.", null)
                            return@setMethodCallHandler
                        }
                        
                        val uri: Uri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file
                        )
                        
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "application/pdf"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            putExtra("jid", "$phone@s.whatsapp.net")
                            setPackage(packageName)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            if (caption != null) {
                                putExtra(Intent.EXTRA_TEXT, caption)
                            }
                        }
                        
                        // To ensure it opens even if inside another task
                        // intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) 
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_FAILED", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Path or phone number is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}