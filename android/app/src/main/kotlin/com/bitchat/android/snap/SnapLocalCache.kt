package com.bitchat.android.snap

import android.content.Context
import android.util.Log
import com.bitchat.android.model.SnapPacket
import kotlinx.coroutines.*
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/**
 * SnapLocalCache: On-device storage for received snaps.
 * 
 * This is the "torrent piece cache" equivalent - snaps are stored locally
 * and can be served to other peers. No central database.
 * 
 * Features:
 * - In-memory cache for fast access
 * - Disk persistence for app restarts  
 * - Auto-eviction of expired snaps
 * - Thread-safe concurrent access
 */
class SnapLocalCache(private val context: Context) {
    
    companion object {
        private const val TAG = "SnapLocalCache"
        private const val CACHE_DIR = "snaps"
        private const val MAX_MEMORY_CACHE = 50  // Keep 50 most recent in memory
        private const val CLEANUP_INTERVAL_MS = 60_000L  // Clean every minute
    }
    
    // In-memory cache: snapId hex -> SnapPacket
    private val memoryCache = ConcurrentHashMap<String, SnapPacket>()
    
    // Listeners for new snaps
    private val listeners = mutableListOf<(SnapPacket) -> Unit>()
    
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val cacheDir: File by lazy {
        File(context.filesDir, CACHE_DIR).also { it.mkdirs() }
    }
    
    init {
        // Start periodic cleanup
        scope.launch {
            while (isActive) {
                delay(CLEANUP_INTERVAL_MS)
                cleanupExpired()
            }
        }
        // Load persisted snaps on init
        scope.launch { loadFromDisk() }
    }
    
    /**
     * Store a snap (from local creation or received from peer)
     */
    fun store(snap: SnapPacket): Boolean {
        if (snap.isExpired()) {
            Log.d(TAG, "⏰ Rejecting expired snap: ${snap.snapIdHex()}")
            return false
        }
        
        val key = snap.snapIdHex()
        
        // Already have it?
        if (memoryCache.containsKey(key)) {
            Log.d(TAG, "📦 Already cached: $key")
            return false
        }
        
        // Store in memory
        memoryCache[key] = snap
        Log.d(TAG, "💾 Cached snap: $key from ${snap.senderAlias}")
        
        // Persist to disk
        scope.launch { saveToDisk(snap) }
        
        // Notify listeners
        listeners.forEach { it(snap) }
        
        // Evict old entries if over limit
        if (memoryCache.size > MAX_MEMORY_CACHE) {
            evictOldest()
        }
        
        return true
    }
    
    /**
     * Check if we have a snap (by hash)
     */
    fun has(snapId: ByteArray): Boolean {
        val key = snapId.joinToString("") { "%02x".format(it) }.take(16) + "..."
        return memoryCache.containsKey(key)
    }
    
    /**
     * Get a snap by ID
     */
    fun get(snapId: ByteArray): SnapPacket? {
        val key = snapId.joinToString("") { "%02x".format(it) }.take(16) + "..."
        return memoryCache[key]
    }
    
    /**
     * Get all non-expired snaps (for UI display)
     */
    fun getAllActive(): List<SnapPacket> {
        return memoryCache.values
            .filter { !it.isExpired() }
            .sortedByDescending { it.timestamp }
    }
    
    /**
     * Get snaps from a specific sender
     */
    fun getFromSender(senderPubKey: ByteArray): List<SnapPacket> {
        return memoryCache.values
            .filter { it.senderPubKey.contentEquals(senderPubKey) && !it.isExpired() }
            .sortedByDescending { it.timestamp }
    }
    
    /**
     * Add listener for new snaps (for UI updates)
     */
    fun addListener(listener: (SnapPacket) -> Unit) {
        listeners.add(listener)
    }
    
    fun removeListener(listener: (SnapPacket) -> Unit) {
        listeners.remove(listener)
    }
    
    // === Private helpers ===
    
    private fun cleanupExpired() {
        val before = memoryCache.size
        val expired = memoryCache.entries.filter { it.value.isExpired() }
        expired.forEach { 
            memoryCache.remove(it.key)
            // Delete from disk too
            File(cacheDir, "${it.key}.snap").delete()
        }
        if (expired.isNotEmpty()) {
            Log.d(TAG, "🧹 Cleaned ${expired.size} expired snaps (${before} -> ${memoryCache.size})")
        }
    }
    
    private fun evictOldest() {
        val sorted = memoryCache.entries.sortedBy { it.value.timestamp }
        val toEvict = sorted.take(sorted.size - MAX_MEMORY_CACHE)
        toEvict.forEach { memoryCache.remove(it.key) }
        Log.d(TAG, "🗑️ Evicted ${toEvict.size} oldest snaps")
    }
    
    private fun saveToDisk(snap: SnapPacket) {
        try {
            val file = File(cacheDir, "${snap.snapIdHex()}.snap")
            file.writeBytes(snap.encode())
            Log.d(TAG, "💿 Persisted to disk: ${snap.snapIdHex()}")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to persist snap: ${e.message}")
        }
    }
    
    private fun loadFromDisk() {
        try {
            val files = cacheDir.listFiles { f -> f.extension == "snap" } ?: return
            var loaded = 0
            for (file in files) {
                try {
                    val data = file.readBytes()
                    val snap = SnapPacket.decode(data)
                    if (snap != null && !snap.isExpired()) {
                        memoryCache[snap.snapIdHex()] = snap
                        loaded++
                    } else {
                        // Delete expired/invalid files
                        file.delete()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to load ${file.name}: ${e.message}")
                    file.delete()
                }
            }
            Log.d(TAG, "📂 Loaded $loaded snaps from disk")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to load from disk: ${e.message}")
        }
    }
    
    fun shutdown() {
        scope.cancel()
    }
}
