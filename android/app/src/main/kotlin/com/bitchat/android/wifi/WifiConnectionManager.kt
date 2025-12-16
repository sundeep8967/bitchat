package com.bitchat.android.wifi

import android.util.Log
import com.bitchat.android.protocol.BitchatPacket
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.DataInputStream
import java.io.DataOutputStream
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap

/**
 * WiFi Connection Manager for TCP socket communication with discovered peers.
 * Handles sending/receiving BitchatPackets over WiFi connections.
 */
class WifiConnectionManager {
    
    companion object {
        private const val TAG = "WifiConnectionManager"
        private const val CONNECTION_TIMEOUT_MS = 5000
        private const val READ_TIMEOUT_MS = 30000
    }
    
    // Active connections: peerID -> WifiPeerConnection
    private val connections = ConcurrentHashMap<String, WifiPeerConnection>()
    
    // Connected peer count
    private val _connectedPeerCount = MutableStateFlow(0)
    val connectedPeerCount: StateFlow<Int> = _connectedPeerCount
    
    // Delegate for packet callbacks
    var delegate: WifiConnectionDelegate? = null
    
    // Coroutines
    private val connectionScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    /**
     * Data class representing a WiFi peer connection.
     */
    private data class WifiPeerConnection(
        val peerID: String,
        val socket: Socket,
        val outputStream: DataOutputStream,
        val inputStream: DataInputStream,
        var readerJob: Job? = null
    )
    
    /**
     * Connect to a discovered WiFi peer.
     */
    fun connectToPeer(peerID: String, ipAddress: String, port: Int) {
        if (connections.containsKey(peerID)) {
            Log.d(TAG, "Already connected to $peerID")
            return
        }
        
        connectionScope.launch {
            try {
                Log.d(TAG, "Connecting to $peerID at $ipAddress:$port...")
                
                val socket = Socket()
                socket.connect(java.net.InetSocketAddress(ipAddress, port), CONNECTION_TIMEOUT_MS)
                socket.soTimeout = READ_TIMEOUT_MS
                
                val outputStream = DataOutputStream(socket.getOutputStream())
                val inputStream = DataInputStream(socket.getInputStream())
                
                val connection = WifiPeerConnection(
                    peerID = peerID,
                    socket = socket,
                    outputStream = outputStream,
                    inputStream = inputStream
                )
                
                connections[peerID] = connection
                updatePeerCount()
                
                Log.i(TAG, "✅ Connected to WiFi peer: $peerID")
                
                // Start reading from this connection
                connection.readerJob = startReaderLoop(connection)
                
                delegate?.onWifiPeerConnected(peerID)
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to connect to $peerID: ${e.message}")
                delegate?.onWifiConnectionFailed(peerID, e.message ?: "Unknown error")
            }
        }
    }
    
    /**
     * Accept an incoming connection from a peer.
     */
    fun acceptConnection(socket: Socket, peerID: String? = null) {
        connectionScope.launch {
            try {
                val clientAddress = socket.inetAddress.hostAddress ?: "unknown"
                Log.d(TAG, "Accepting connection from $clientAddress")
                
                socket.soTimeout = READ_TIMEOUT_MS
                
                val outputStream = DataOutputStream(socket.getOutputStream())
                val inputStream = DataInputStream(socket.getInputStream())
                
                // Use address as temporary peerID if not provided
                val effectivePeerID = peerID ?: "wifi_$clientAddress"
                
                val connection = WifiPeerConnection(
                    peerID = effectivePeerID,
                    socket = socket,
                    outputStream = outputStream,
                    inputStream = inputStream
                )
                
                connections[effectivePeerID] = connection
                updatePeerCount()
                
                Log.i(TAG, "✅ Accepted WiFi connection: $effectivePeerID")
                
                // Start reading
                connection.readerJob = startReaderLoop(connection)
                
                delegate?.onWifiPeerConnected(effectivePeerID)
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to accept connection: ${e.message}")
                socket.close()
            }
        }
    }
    
    /**
     * Send a packet to a specific WiFi peer.
     */
    fun sendPacket(peerID: String, packet: BitchatPacket): Boolean {
        val connection = connections[peerID] ?: run {
            Log.w(TAG, "No connection to $peerID")
            return false
        }
        
        return try {
            val data = packet.toBinaryData() ?: run {
                Log.e(TAG, "Failed to serialize packet")
                return false
            }
            
            synchronized(connection.outputStream) {
                // Write length prefix (4 bytes) + data
                connection.outputStream.writeInt(data.size)
                connection.outputStream.write(data)
                connection.outputStream.flush()
            }
            
            Log.d(TAG, "📤 Sent packet to $peerID (${data.size} bytes)")
            true
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send packet to $peerID: ${e.message}")
            disconnectPeer(peerID)
            false
        }
    }
    
    /**
     * Broadcast a packet to all connected WiFi peers.
     */
    fun broadcastPacket(packet: BitchatPacket) {
        val peerIDs = connections.keys.toList()
        
        if (peerIDs.isEmpty()) {
            Log.d(TAG, "No WiFi peers to broadcast to")
            return
        }
        
        Log.d(TAG, "📡 Broadcasting packet to ${peerIDs.size} WiFi peers")
        
        peerIDs.forEach { peerID ->
            sendPacket(peerID, packet)
        }
    }
    
    /**
     * Disconnect from a specific peer.
     */
    fun disconnectPeer(peerID: String) {
        val connection = connections.remove(peerID) ?: return
        
        try {
            connection.readerJob?.cancel()
            connection.socket.close()
            Log.i(TAG, "Disconnected from WiFi peer: $peerID")
            
            updatePeerCount()
            delegate?.onWifiPeerDisconnected(peerID)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error disconnecting from $peerID: ${e.message}")
        }
    }
    
    /**
     * Disconnect all peers and cleanup.
     */
    fun disconnectAll() {
        Log.i(TAG, "Disconnecting all WiFi peers...")
        
        connections.keys.toList().forEach { peerID ->
            disconnectPeer(peerID)
        }
        
        connectionScope.cancel()
    }
    
    /**
     * Start a reader loop for incoming packets from a peer.
     */
    private fun startReaderLoop(connection: WifiPeerConnection): Job {
        return connectionScope.launch {
            Log.d(TAG, "Starting reader loop for ${connection.peerID}")
            
            try {
                while (isActive && connection.socket.isConnected) {
                    // Read length prefix
                    val length = connection.inputStream.readInt()
                    
                    if (length <= 0 || length > 1_000_000) {
                        Log.e(TAG, "Invalid packet length: $length")
                        break
                    }
                    
                    // Read packet data
                    val data = ByteArray(length)
                    connection.inputStream.readFully(data)
                    
                    Log.d(TAG, "📥 Received packet from ${connection.peerID} ($length bytes)")
                    
                    // Deserialize and notify delegate
                    try {
                        val packet = BitchatPacket.fromBinaryData(data)
                        if (packet != null) {
                            delegate?.onWifiPacketReceived(packet, connection.peerID)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to deserialize packet: ${e.message}")
                    }
                }
                
            } catch (e: Exception) {
                if (isActive) {
                    Log.e(TAG, "Reader loop error for ${connection.peerID}: ${e.message}")
                }
            }
            
            // Connection closed
            Log.d(TAG, "Reader loop ended for ${connection.peerID}")
            disconnectPeer(connection.peerID)
        }
    }
    
    /**
     * Update the connected peer count flow.
     */
    private fun updatePeerCount() {
        _connectedPeerCount.value = connections.size
    }
    
    /**
     * Get list of connected peer IDs.
     */
    fun getConnectedPeerIDs(): List<String> = connections.keys.toList()
    
    /**
     * Check if connected to a specific peer.
     */
    fun isConnectedTo(peerID: String): Boolean = connections.containsKey(peerID)
    
    /**
     * Get debug info.
     */
    fun getDebugInfo(): String {
        return buildString {
            appendLine("=== WiFi Connection Manager ===")
            appendLine("Connected Peers: ${connections.size}")
            connections.forEach { (peerID, conn) ->
                appendLine("  - $peerID: ${conn.socket.inetAddress?.hostAddress}:${conn.socket.port}")
            }
        }
    }
}

/**
 * Delegate interface for WiFi connection callbacks.
 */
interface WifiConnectionDelegate {
    fun onWifiPeerConnected(peerID: String)
    fun onWifiPeerDisconnected(peerID: String)
    fun onWifiConnectionFailed(peerID: String, reason: String)
    fun onWifiPacketReceived(packet: BitchatPacket, peerID: String)
}
