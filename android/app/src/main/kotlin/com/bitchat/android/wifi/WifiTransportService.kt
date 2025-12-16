package com.bitchat.android.wifi

import android.content.Context
import android.util.Log
import com.bitchat.android.protocol.BitchatPacket
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.StateFlow
import java.net.Socket

/**
 * Unified WiFi Transport Service that coordinates discovery and connection management.
 * This is the main entry point for WiFi-based peer communication.
 */
class WifiTransportService(private val context: Context) : WifiDiscoveryDelegate, WifiConnectionDelegate {
    
    companion object {
        private const val TAG = "WifiTransportService"
    }
    
    // Component managers
    private val discoveryManager = WifiDiscoveryManager(context)
    private val connectionManager = WifiConnectionManager()
    
    // State
    private var isActive = false
    
    // Delegate for packet callbacks (to BluetoothMeshService)
    var delegate: WifiTransportDelegate? = null
    
    // My peer ID
    var myPeerID: String
        get() = discoveryManager.myPeerID
        set(value) { discoveryManager.myPeerID = value }
    
    // Exposed state flows
    val connectedPeerCount: StateFlow<Int> = connectionManager.connectedPeerCount
    
    init {
        discoveryManager.delegate = this
        connectionManager.delegate = this
    }
    
    /**
     * Start the WiFi transport (discovery + connection handling).
     */
    fun start(): Boolean {
        if (isActive) {
            Log.d(TAG, "WiFi transport already active")
            return true
        }
        
        Log.i(TAG, "🌐 Starting WiFi Transport Service...")
        
        val success = discoveryManager.start()
        isActive = success
        
        if (success) {
            Log.i(TAG, "✅ WiFi Transport Service started on port ${discoveryManager.getLocalPort()}")
        } else {
            Log.e(TAG, "❌ Failed to start WiFi Transport Service")
        }
        
        return success
    }
    
    /**
     * Stop the WiFi transport.
     */
    fun stop() {
        if (!isActive) return
        
        Log.i(TAG, "Stopping WiFi Transport Service...")
        
        isActive = false
        connectionManager.disconnectAll()
        discoveryManager.stop()
        
        Log.i(TAG, "WiFi Transport Service stopped")
    }
    
    /**
     * Send a packet to all connected WiFi peers.
     */
    fun broadcastPacket(packet: BitchatPacket) {
        if (!isActive) return
        connectionManager.broadcastPacket(packet)
    }
    
    /**
     * Send a packet to a specific WiFi peer.
     */
    fun sendPacket(peerID: String, packet: BitchatPacket): Boolean {
        if (!isActive) return false
        return connectionManager.sendPacket(peerID, packet)
    }
    
    /**
     * Get list of connected WiFi peer IDs.
     */
    fun getConnectedPeerIDs(): List<String> = connectionManager.getConnectedPeerIDs()
    
    /**
     * Check if active.
     */
    fun isActive(): Boolean = isActive && discoveryManager.isActive()
    
    // MARK: - WifiDiscoveryDelegate
    
    override fun onWifiPeerDiscovered(peerID: String, ipAddress: String, port: Int) {
        Log.i(TAG, "🔍 Discovered WiFi peer: $peerID at $ipAddress:$port")
        
        // Auto-connect to discovered peers
        if (!connectionManager.isConnectedTo(peerID)) {
            connectionManager.connectToPeer(peerID, ipAddress, port)
        }
    }
    
    override fun onWifiPeerLost(serviceName: String) {
        Log.d(TAG, "WiFi peer lost: $serviceName")
        // Connection will be cleaned up by timeout or explicit disconnect
    }
    
    override fun onWifiConnectionAccepted(socket: Socket) {
        Log.d(TAG, "Accepting incoming WiFi connection")
        connectionManager.acceptConnection(socket)
    }
    
    // MARK: - WifiConnectionDelegate
    
    override fun onWifiPeerConnected(peerID: String) {
        Log.i(TAG, "✅ WiFi peer connected: $peerID")
        delegate?.onWifiPeerConnected(peerID)
    }
    
    override fun onWifiPeerDisconnected(peerID: String) {
        Log.d(TAG, "WiFi peer disconnected: $peerID")
        delegate?.onWifiPeerDisconnected(peerID)
    }
    
    override fun onWifiConnectionFailed(peerID: String, reason: String) {
        Log.w(TAG, "WiFi connection failed to $peerID: $reason")
    }
    
    override fun onWifiPacketReceived(packet: BitchatPacket, peerID: String) {
        Log.d(TAG, "📥 Received packet from WiFi peer $peerID")
        delegate?.onWifiPacketReceived(packet, peerID)
    }
    
    /**
     * Get debug info.
     */
    fun getDebugInfo(): String {
        return buildString {
            appendLine("=== WiFi Transport Service ===")
            appendLine("Active: $isActive")
            appendLine()
            append(discoveryManager.getDebugInfo())
            appendLine()
            append(connectionManager.getDebugInfo())
        }
    }
}

/**
 * Delegate interface for WiFi transport callbacks to BluetoothMeshService.
 */
interface WifiTransportDelegate {
    fun onWifiPeerConnected(peerID: String)
    fun onWifiPeerDisconnected(peerID: String)
    fun onWifiPacketReceived(packet: BitchatPacket, peerID: String)
}
