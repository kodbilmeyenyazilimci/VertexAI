package com.vertex.ai

import android.annotation.SuppressLint
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Environment
import android.os.StatFs
import android.util.Log  // Log için import
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val storageChannel = "com.vertex.ai/storage"
    private val llamaChannel = "com.vertex.ai/llama"
    private val memoryChannel = "com.vertex.ai/memory"  // Yeni kanal

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // RAM kanalı
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            memoryChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceMemory" -> {
                    val memoryInfo = getDeviceMemory()
                    result.success(memoryInfo)
                }
                else -> result.notImplemented()
            }
        }

        // Depolama kanalı
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            storageChannel
        ).setMethodCallHandler { call, result ->
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

        // Llama kanalı
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            llamaChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        val llamaServiceIntent = Intent(this, LlamaService::class.java)
                        llamaServiceIntent.putExtra("action", "loadModel")
                        llamaServiceIntent.putExtra("modelPath", path)

                        // Start the service
                        startService(llamaServiceIntent)

                        // Initialize the MethodChannel in the service
                        val llamaService = LlamaService()
                        llamaService.setMethodChannel(
                            MethodChannel(
                                flutterEngine.dartExecutor.binaryMessenger,
                                llamaChannel
                            )
                        )

                        result.success("Model loading started at path: $path")
                    } else {
                        result.error("ERROR", "Invalid model path", null)
                    }
                }

                "sendMessage" -> {
                    val message = call.argument<String>("message")
                    if (message != null) {
                        val llamaServiceIntent = Intent(this, LlamaService::class.java)
                        llamaServiceIntent.putExtra("action", "sendMessage")
                        llamaServiceIntent.putExtra("message", message)

                        // Start the service
                        startService(llamaServiceIntent)

                        // Initialize the MethodChannel in the service
                        val llamaService = LlamaService()
                        llamaService.setMethodChannel(
                            MethodChannel(
                                flutterEngine.dartExecutor.binaryMessenger,
                                llamaChannel
                            )
                        )

                        result.success("Message sending started: $message")
                    } else {
                        result.error("ERROR", "Invalid message", null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    // Mevcut olan RAM miktarını döner (GB cinsinden)
    private fun getDeviceMemory(): Long {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        return memoryInfo.totalMem / (1024 * 1024) // GB cinsine dönüştür
    }

    private fun getFreeStorage(): Long {
        val stat = StatFs(Environment.getExternalStorageDirectory().path)
        return stat.blockSizeLong * stat.availableBlocksLong / (1024 * 1024)
    }

    private fun getTotalStorage(): Long {
        val stat = StatFs(Environment.getExternalStorageDirectory().path)
        return stat.blockSizeLong * stat.blockCountLong / (1024 * 1024) // MB olarak dönüyor
    }
}
