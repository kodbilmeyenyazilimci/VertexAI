package com.vertex.ai

import android.content.Intent
import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val storageChannel = "com.vertex.ai/storage"
    private val llamaChannel = "com.vertex.ai/llama"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Depolama kanalı
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getFreeStorage" -> {
                    val freeStorage = getFreeStorage()
                    result.success(freeStorage)
                }
                "getTotalStorage" -> {
                    val totalStorage = getTotalStorage()
                    result.success(totalStorage)
                }
                else -> result.notImplemented()
            }
        }

        // Llama ile ilgili işlemler için kanal
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, llamaChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        // LlamaService'i başlat
                        val llamaServiceIntent = Intent(this, LlamaService::class.java)
                        llamaServiceIntent.putExtra("action", "loadModel")
                        llamaServiceIntent.putExtra("modelPath", path)
                        startService(llamaServiceIntent)
                        result.success("Model loading started: $path")
                    } else {
                        result.error("ERROR", "Invalid model path", null)
                    }
                }
                "sendMessage" -> {
                    val message = call.argument<String>("message")
                    if (message != null) {
                        // LlamaService'i başlat
                        val llamaServiceIntent = Intent(this, LlamaService::class.java)
                        llamaServiceIntent.putExtra("action", "sendMessage")
                        llamaServiceIntent.putExtra("message", message)
                        startService(llamaServiceIntent)
                        result.success("Message sending started: $message")
                    } else {
                        result.error("ERROR", "Invalid message", null)
                    }
                }
                // Diğer methodlar burada tanımlanabilir
                else -> result.notImplemented()
            }
        }
    }

    private fun getFreeStorage(): Long {
        val stat = StatFs(Environment.getExternalStorageDirectory().path)
        return stat.blockSizeLong * stat.availableBlocksLong / (1024 * 1024) // MB olarak dönüyor
    }

    private fun getTotalStorage(): Long {
        val stat = StatFs(Environment.getExternalStorageDirectory().path)
        return stat.blockSizeLong * stat.blockCountLong / (1024 * 1024) // MB olarak dönüyor
    }
}
