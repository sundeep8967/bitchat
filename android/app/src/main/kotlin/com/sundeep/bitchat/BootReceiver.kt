package com.sundeep.bitchat

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

import com.bitchat.android.service.MeshForegroundService
import com.bitchat.android.service.MeshServicePreferences

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            try { MeshServicePreferences.init(context.applicationContext) } catch (_: Exception) { }

            if (MeshServicePreferences.isAutoStartEnabled(true)) {
                MeshForegroundService.start(context.applicationContext)
            }
        }
    }
}
