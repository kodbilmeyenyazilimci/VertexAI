package com.vertex.ai

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class LlamaService : Service() {

    companion object {
        lateinit var resultChannel: MethodChannel
        var isChannelInitialized = false

        // JNI tarafından çağrılacak olan statik fonksiyon
        @JvmStatic
        fun sendTokenToFlutter(token: String) {
            if (isChannelInitialized) {
                // Ana thread'de çalıştır
                val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
                mainHandler.post {
                    resultChannel.invokeMethod("onMessageResponse", token)
                }
            } else {
                Log.e("LlamaService", "MethodChannel başlatılmamış.")
            }
        }
    }

    private lateinit var viewModel: MainViewModel
    private val serviceScope = CoroutineScope(Dispatchers.Main + Job())

    override fun onCreate() {
        super.onCreate()
        viewModel = MainViewModel()
        Log.d("LlamaService", "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.let {
            val action = it.getStringExtra("action")
            when (action) {
                "loadModel" -> {
                    val path = it.getStringExtra("modelPath")
                    path?.let { loadModel(it) }
                }
                "sendMessage" -> {
                    val message = it.getStringExtra("message")
                    message?.let { sendMessage(it) }
                }
                else -> {}
            }
        }
        return START_STICKY
    }

    fun loadModel(path: String) {
        serviceScope.launch {
            viewModel.load(path)

            if (isChannelInitialized) {
                resultChannel.invokeMethod("onModelLoaded", "Model başarıyla yüklendi: $path")
            } else {
                Log.e("LlamaService", "MethodChannel başlatılmamış.")
            }
        }
    }

    fun sendMessage(message: String) {
        serviceScope.launch {
            viewModel.updateMessage(message)
            viewModel.send { token ->
                if (isChannelInitialized) {
                    // Token gönderimi de ana thread'de yapılmalı
                    val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
                    mainHandler.post {
                        resultChannel.invokeMethod("onMessageResponse", token)
                    }
                } else {
                    Log.e("LlamaService", "MethodChannel başlatılmamış.")
                }
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
    }

    fun setMethodChannel(channel: MethodChannel) {
        resultChannel = channel
        isChannelInitialized = true
        Log.d("LlamaService", "MethodChannel initialized")
    }
}
