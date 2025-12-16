package com.sundeep.bitchat

import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.bitchat.android.mesh.BluetoothMeshService
import com.bitchat.android.mesh.BluetoothMeshDelegate
import com.bitchat.android.model.BitchatMessage
import com.bitchat.android.service.MeshForegroundService

class MainActivity: FlutterActivity(), BluetoothMeshDelegate {
    private val CHANNEL = "com.sundeep.bitchat/mesh"
    private val EVENT_CHANNEL = "com.sundeep.bitchat/events"
    
    private var eventSink: EventChannel.EventSink? = null
    private var meshService: BluetoothMeshService? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize real mesh service
        meshService = BluetoothMeshService(this)
        meshService?.delegate = this

        // Method Channel for Commands
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startMesh" -> {
                    if (meshService == null || meshService?.isReusable() != true) {
                        meshService = BluetoothMeshService(this)
                        meshService?.delegate = this
                    }
                    meshService?.startServices()
                    MeshForegroundService.start(this)
                    result.success(true)
                }
                "stopMesh" -> {
                    meshService?.stopServices()
                    MeshForegroundService.stop(this)
                    result.success(true)
                }
                "getPeers" -> {
                    val peers = meshService?.getPeers()?.associate { peer ->
                        peer.id to mapOf(
                            "name" to peer.nickname,
                            "rssi" to (meshService?.getPeerRSSI(peer.id) ?: 0),
                            "distance" to "Unknown", // TODO: Calculate from RSSI
                            "signalStrength" to "Unknown" 
                        )
                    } ?: emptyMap()
                    result.success(peers)
                }
                "sendMessage" -> {
                    val recipientId = call.argument<String>("recipientId")
                    val content = call.argument<String>("content")
                    if (recipientId != null && content != null) {
                        try {
                            if (recipientId == "broadcast" || recipientId.isEmpty()) {
                                meshService?.sendMessage(content)
                            } else {
                                // TODO: Use sendPrivateMessage when exposed or implemented
                                // For now, simple fallback to broadcast if private not available cleanly
                                // or try to find if public key is known.
                                // NOTE: Reference implementation uses MessageRouter for this logic.
                                // We will just broadcast for now to ensure delivery in this migration step
                                // until MessageRouter is fully ported/integrated.
                                meshService?.sendMessage(content) 
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SEND_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "recipientId and content required", null)
                    }
                }
                "getMyPeerID" -> {
                    result.success(meshService?.myPeerID ?: "unknown")
                }
                "requestBatteryOptimizationExemption" -> {
                    requestBatteryExemption()
                    result.success(true)
                }
                "isBatteryOptimizationExempt" -> {
                    result.success(isBatteryOptimized())
                }
                "setNickname" -> {
                    val name = call.argument<String>("nickname")
                    if (name != null) {
                        saveNickname(name)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "nickname required", null)
                    }
                }
                // P2P Snap Methods
                "broadcastSnap" -> {
                    val contentBase64 = call.argument<String>("content")
                    val contentType = call.argument<String>("contentType") ?: "image/jpeg"
                    val ttlMs = call.argument<Long>("ttlMs") ?: (24 * 60 * 60 * 1000L)
                    
                    if (contentBase64 != null) {
                        try {
                            val content = android.util.Base64.decode(contentBase64, android.util.Base64.NO_WRAP)
                            meshService?.broadcastSnap(content, contentType, ttlMs)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SNAP_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGS", "content required", null)
                    }
                }
                "getActiveSnaps" -> {
                    val snaps = meshService?.getActiveSnaps() ?: emptyList()
                    result.success(snaps)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Event Channel for Updates
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }
    
    override fun onDestroy() {
        meshService?.stopServices()
        super.onDestroy()
    }
    
    // BluetoothMeshDelegate Implementation
    override fun didReceiveMessage(message: BitchatMessage) {
        val data = mapOf(
            "senderId" to (message.senderPeerID ?: "unknown"),
            "content" to message.content,
            "timestamp" to message.timestamp.time
        )
        runOnUiThread {
            eventSink?.success(mapOf("type" to "message", "data" to data))
        }
    }

    override fun didUpdatePeerList(peers: List<String>) {
        val allPeers = meshService?.getPeers() ?: emptyList()
        val peerList = allPeers.map { peer ->
            mapOf(
                "id" to peer.id,
                "name" to peer.nickname,
                "rssi" to (meshService?.getPeerRSSI(peer.id) ?: 0),
                "distance" to "Unknown",
                "signalStrength" to "Unknown"
            )
        }
        runOnUiThread {
            eventSink?.success(mapOf("type" to "peerList", "data" to peerList))
        }
    }

    override fun getNickname(): String? {
        val prefs = getSharedPreferences("bitchat_prefs", MODE_PRIVATE)
        return prefs.getString("nickname", "Me")
    }

    private fun saveNickname(name: String) {
        val prefs = getSharedPreferences("bitchat_prefs", MODE_PRIVATE)
        prefs.edit().putString("nickname", name).apply()
    }
    override fun isFavorite(peerID: String): Boolean = false
    override fun decryptChannelMessage(encryptedContent: ByteArray, channel: String): String? = null
    override fun didReceiveChannelLeave(channel: String, fromPeer: String) {}
    override fun didReceiveDeliveryAck(messageID: String, recipientPeerID: String) {}
    override fun didReceiveReadReceipt(messageID: String, recipientPeerID: String) {}

    private fun requestBatteryExemption() {
        val packageName = packageName
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
            val intent = Intent().apply {
                action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        }
    }
    
    private fun isBatteryOptimized(): Boolean {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }
}

