package com.bitchat.android.service

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.sundeep.bitchat.MainActivity
import com.sundeep.bitchat.R

/**
 * SnapNotificationHelper: Shows notifications for incoming P2P snaps
 */
object SnapNotificationHelper {
    
    private const val TAG = "SnapNotificationHelper"
    private const val CHANNEL_ID = "bitchat_snaps"
    private const val CHANNEL_NAME = "P2P Snaps"
    private const val NOTIFICATION_ID_BASE = 20000
    
    private var notificationManager: NotificationManagerCompat? = null
    private var notificationId = NOTIFICATION_ID_BASE
    
    fun initialize(context: Context) {
        notificationManager = NotificationManagerCompat.from(context)
        createNotificationChannel(context)
    }
    
    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for incoming snaps from friends"
                enableVibration(true)
                enableLights(true)
            }
            
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
            Log.d(TAG, "✅ Created snap notification channel")
        }
    }
    
    /**
     * Show a notification for an incoming snap
     */
    fun showSnapNotification(
        context: Context,
        senderAlias: String,
        senderId: String,
        snapId: String
    ) {
        if (notificationManager == null) {
            initialize(context)
        }
        
        // Check permission (Android 13+)
        if (Build.VERSION.SDK_INT >= 33) {
            if (androidx.core.content.ContextCompat.checkSelfPermission(
                    context, android.Manifest.permission.POST_NOTIFICATIONS
                ) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                Log.w(TAG, "⚠️ No notification permission, skipping snap notification")
                return
            }
        }
        
        // Create tap intent to open app
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("snap_id", snapId)
            putExtra("open_snaps", true)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        )
        
        val displayName = if (senderAlias.isNotBlank()) senderAlias else "Someone"
        val senderShort = if (senderId.length >= 8) senderId.substring(0, 8) else senderId
        
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle("📸 New Snap!")
            .setContentText("$displayName ($senderShort...) sent you a snap")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_SOCIAL)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .build()
        
        try {
            notificationManager?.notify(notificationId++, notification)
            Log.d(TAG, "✅ Showed snap notification from $displayName")
        } catch (e: SecurityException) {
            Log.w(TAG, "⚠️ SecurityException showing notification: ${e.message}")
        }
        
        // Reset ID to prevent overflow
        if (notificationId > NOTIFICATION_ID_BASE + 100) {
            notificationId = NOTIFICATION_ID_BASE
        }
    }
}
