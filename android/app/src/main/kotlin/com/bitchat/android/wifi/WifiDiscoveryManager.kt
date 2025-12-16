package com.bitchat.android.wifi

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.util.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.net.ServerSocket

/**
 * WiFi Discovery Manager using Android's Network Service Discovery (NSD) API.
 * Enables peer-to-peer discovery over local WiFi networks without internet.
 */
class WifiDiscoveryManager(private val context: Context) {
    
    companion object {
        private const val TAG = "WifiDiscoveryManager"
        private const val SERVICE_TYPE = "_bitchat._tcp."
        private const val SERVICE_NAME_PREFIX = "BitChat_"
    }
    
    // NSD Manager
    private val nsdManager: NsdManager by lazy {
        context.getSystemService(Context.NSD_SERVICE) as NsdManager
    }
    
    // State
    private var serverSocket: ServerSocket? = null
    private var localPort: Int = 0
    private var isRegistered = false
    private var isDiscovering = false
    
    // Discovered peers: Map of service name to resolved NsdServiceInfo
    private val _discoveredPeers = MutableStateFlow<Map<String, NsdServiceInfo>>(emptyMap())
    val discoveredPeers: StateFlow<Map<String, NsdServiceInfo>> = _discoveredPeers
    
    // My peer ID (set externally)
    var myPeerID: String = ""
    
    // Delegate for callbacks
    var delegate: WifiDiscoveryDelegate? = null
    
    // Coroutines
    private val discoveryScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // Registration Listener
    private val registrationListener = object : NsdManager.RegistrationListener {
        override fun onServiceRegistered(serviceInfo: NsdServiceInfo) {
            Log.i(TAG, "✅ Service registered: ${serviceInfo.serviceName} on port $localPort")
            isRegistered = true
        }
        
        override fun onRegistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
            Log.e(TAG, "❌ Registration failed: errorCode=$errorCode")
            isRegistered = false
        }
        
        override fun onServiceUnregistered(serviceInfo: NsdServiceInfo) {
            Log.i(TAG, "Service unregistered: ${serviceInfo.serviceName}")
            isRegistered = false
        }
        
        override fun onUnregistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
            Log.e(TAG, "Unregistration failed: errorCode=$errorCode")
        }
    }
    
    // Discovery Listener
    private val discoveryListener = object : NsdManager.DiscoveryListener {
        override fun onDiscoveryStarted(serviceType: String) {
            Log.i(TAG, "🔍 Discovery started for $serviceType")
            isDiscovering = true
        }
        
        override fun onDiscoveryStopped(serviceType: String) {
            Log.i(TAG, "Discovery stopped for $serviceType")
            isDiscovering = false
        }
        
        override fun onServiceFound(serviceInfo: NsdServiceInfo) {
            Log.d(TAG, "📡 Service found: ${serviceInfo.serviceName}")
            
            // Skip our own service
            val myServiceName = SERVICE_NAME_PREFIX + myPeerID
            if (serviceInfo.serviceName == myServiceName) {
                Log.d(TAG, "Ignoring own service")
                return
            }
            
            // Resolve the service to get IP and port
            resolveService(serviceInfo)
        }
        
        override fun onServiceLost(serviceInfo: NsdServiceInfo) {
            Log.d(TAG, "📴 Service lost: ${serviceInfo.serviceName}")
            
            // Remove from discovered peers
            val currentPeers = _discoveredPeers.value.toMutableMap()
            currentPeers.remove(serviceInfo.serviceName)
            _discoveredPeers.value = currentPeers
            
            delegate?.onWifiPeerLost(serviceInfo.serviceName)
        }
        
        override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
            Log.e(TAG, "❌ Discovery start failed: errorCode=$errorCode")
            isDiscovering = false
        }
        
        override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
            Log.e(TAG, "Discovery stop failed: errorCode=$errorCode")
        }
    }
    
    /**
     * Start the WiFi discovery service.
     * 1. Opens a server socket for incoming connections
     * 2. Registers our service via NSD
     * 3. Starts discovering other peers
     */
    fun start(): Boolean {
        Log.i(TAG, "Starting WiFi Discovery Manager...")
        
        try {
            // 1. Create server socket on any available port
            serverSocket = ServerSocket(0).also {
                localPort = it.localPort
                Log.d(TAG, "Server socket opened on port $localPort")
            }
            
            // 2. Register our service
            registerService()
            
            // 3. Start discovering other services
            startDiscovery()
            
            // 4. Start accepting incoming connections
            startAcceptingConnections()
            
            return true
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start WiFi discovery: ${e.message}")
            return false
        }
    }
    
    /**
     * Stop the WiFi discovery service.
     */
    fun stop() {
        Log.i(TAG, "Stopping WiFi Discovery Manager...")
        
        try {
            // Stop discovery
            if (isDiscovering) {
                nsdManager.stopServiceDiscovery(discoveryListener)
            }
            
            // Unregister service
            if (isRegistered) {
                nsdManager.unregisterService(registrationListener)
            }
            
            // Close server socket
            serverSocket?.close()
            serverSocket = null
            
            // Clear discovered peers
            _discoveredPeers.value = emptyMap()
            
            // Cancel coroutines
            discoveryScope.cancel()
            
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping WiFi discovery: ${e.message}")
        }
    }
    
    /**
     * Register our service for others to discover.
     */
    private fun registerService() {
        val serviceInfo = NsdServiceInfo().apply {
            serviceName = SERVICE_NAME_PREFIX + myPeerID
            serviceType = SERVICE_TYPE
            port = localPort
        }
        
        Log.d(TAG, "Registering service: ${serviceInfo.serviceName} on port ${serviceInfo.port}")
        nsdManager.registerService(serviceInfo, NsdManager.PROTOCOL_DNS_SD, registrationListener)
    }
    
    /**
     * Start discovering other BitChat services on the network.
     */
    private fun startDiscovery() {
        Log.d(TAG, "Starting service discovery for $SERVICE_TYPE")
        nsdManager.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
    }
    
    /**
     * Resolve a discovered service to get its IP address and port.
     */
    private fun resolveService(serviceInfo: NsdServiceInfo) {
        val resolveListener = object : NsdManager.ResolveListener {
            override fun onResolveFailed(si: NsdServiceInfo, errorCode: Int) {
                Log.e(TAG, "Resolve failed for ${si.serviceName}: errorCode=$errorCode")
            }
            
            override fun onServiceResolved(si: NsdServiceInfo) {
                val host = si.host
                val port = si.port
                Log.i(TAG, "✅ Resolved ${si.serviceName}: ${host?.hostAddress}:$port")
                
                // Add to discovered peers
                val currentPeers = _discoveredPeers.value.toMutableMap()
                currentPeers[si.serviceName] = si
                _discoveredPeers.value = currentPeers
                
                // Extract peer ID from service name
                val peerID = si.serviceName.removePrefix(SERVICE_NAME_PREFIX)
                
                // Notify delegate
                delegate?.onWifiPeerDiscovered(peerID, host?.hostAddress ?: "", port)
            }
        }
        
        nsdManager.resolveService(serviceInfo, resolveListener)
    }
    
    /**
     * Accept incoming TCP connections from other peers.
     */
    private fun startAcceptingConnections() {
        discoveryScope.launch {
            Log.d(TAG, "Starting to accept connections on port $localPort")
            
            while (isActive && serverSocket != null && !serverSocket!!.isClosed) {
                try {
                    val clientSocket = serverSocket?.accept() ?: break
                    val clientAddress = clientSocket.inetAddress.hostAddress
                    Log.i(TAG, "📥 Accepted connection from $clientAddress")
                    
                    // Notify delegate of new connection
                    delegate?.onWifiConnectionAccepted(clientSocket)
                    
                } catch (e: Exception) {
                    if (isActive) {
                        Log.e(TAG, "Error accepting connection: ${e.message}")
                    }
                }
            }
        }
    }
    
    /**
     * Get the local port we're listening on.
     */
    fun getLocalPort(): Int = localPort
    
    /**
     * Check if discovery is active.
     */
    fun isActive(): Boolean = isRegistered && isDiscovering
    
    /**
     * Get debug info.
     */
    fun getDebugInfo(): String {
        return buildString {
            appendLine("=== WiFi Discovery Manager ===")
            appendLine("Registered: $isRegistered")
            appendLine("Discovering: $isDiscovering")
            appendLine("Local Port: $localPort")
            appendLine("My Service: ${SERVICE_NAME_PREFIX}$myPeerID")
            appendLine("Discovered Peers: ${_discoveredPeers.value.size}")
            _discoveredPeers.value.forEach { (name, info) ->
                appendLine("  - $name: ${info.host?.hostAddress}:${info.port}")
            }
        }
    }
}

/**
 * Delegate interface for WiFi discovery callbacks.
 */
interface WifiDiscoveryDelegate {
    fun onWifiPeerDiscovered(peerID: String, ipAddress: String, port: Int)
    fun onWifiPeerLost(serviceName: String)
    fun onWifiConnectionAccepted(socket: java.net.Socket)
}
