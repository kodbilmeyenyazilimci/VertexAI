package com.vertex.ai

import android.app.Service
import android.content.Intent
import android.os.IBinder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class LlamaService : Service() {

    private lateinit var viewModel: MainViewModel
    private val serviceScope = CoroutineScope(Dispatchers.Main + Job())

    override fun onCreate() {
        super.onCreate()
        viewModel = MainViewModel()  // Initialize your ViewModel
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Optional: Handle start commands here, if needed
        return START_STICKY
    }

    fun loadModel(path: String) {
        serviceScope.launch {
            viewModel.load(path)
        }
    }

    fun sendMessage(message: String) {
        serviceScope.launch {
            viewModel.updateMessage(message)
            viewModel.send()
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        // Return null since this is a started service, not a bound service
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()  // Clean up coroutines when service is destroyed
    }
}
