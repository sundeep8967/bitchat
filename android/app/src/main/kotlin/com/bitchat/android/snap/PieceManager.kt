package com.bitchat.android.snap

import android.util.Log
import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentHashMap

/**
 * PieceManager: Tracks piece availability across peers for optimal downloading.
 * 
 * Implements BitTorrent-style piece selection:
 * - Tracks which peers have which pieces (bitfields)
 * - Rarest-first selection for network health
 * - Parallel requests to multiple peers
 * - Request deduplication
 */
class PieceManager(
    private val contentId: String,  // Merkle root hex
    private val pieceCount: Int
) {
    companion object {
        private const val TAG = "PieceManager"
        private const val MAX_PENDING_REQUESTS = 5  // Max concurrent requests per content
        private const val REQUEST_TIMEOUT_MS = 10_000L  // 10 seconds
    }
    
    // Piece availability: pieceIndex -> set of peerIDs that have it
    private val pieceAvailability = ConcurrentHashMap<Int, MutableSet<String>>()
    
    // Pending requests: pieceIndex -> (peerID, timestamp)
    private val pendingRequests = ConcurrentHashMap<Int, Pair<String, Long>>()
    
    // Our local pieces
    private val localPieces = mutableSetOf<Int>()
    
    // Listener for piece events
    var listener: PieceManagerListener? = null
    
    init {
        // Initialize availability tracking
        for (i in 0 until pieceCount) {
            pieceAvailability[i] = mutableSetOf()
        }
    }
    
    /**
     * Update piece availability when we receive a peer's bitfield
     */
    fun updatePeerBitfield(peerID: String, bitfield: ByteArray) {
        Log.d(TAG, "📊 Updating bitfield from $peerID")
        
        for (i in 0 until pieceCount) {
            val byteIndex = i / 8
            val bitIndex = 7 - (i % 8)
            if (byteIndex < bitfield.size && (bitfield[byteIndex].toInt() and (1 shl bitIndex)) != 0) {
                pieceAvailability[i]?.add(peerID)
            }
        }
        
        logAvailability()
    }
    
    /**
     * Mark that a peer has a specific piece
     */
    fun markPeerHasPiece(peerID: String, pieceIndex: Int) {
        pieceAvailability[pieceIndex]?.add(peerID)
    }
    
    /**
     * Remove peer from all tracking (when peer disconnects)
     */
    fun removePeer(peerID: String) {
        pieceAvailability.values.forEach { it.remove(peerID) }
        // Cancel pending requests to this peer
        pendingRequests.entries.removeIf { it.value.first == peerID }
    }
    
    /**
     * Mark that we have a piece locally
     */
    fun markLocalPiece(pieceIndex: Int) {
        localPieces.add(pieceIndex)
        // Remove from pending
        pendingRequests.remove(pieceIndex)
    }
    
    /**
     * Get pieces we still need
     */
    fun getMissingPieces(): List<Int> {
        return (0 until pieceCount).filter { !localPieces.contains(it) }
    }
    
    /**
     * Check if download is complete
     */
    fun isComplete(): Boolean = localPieces.size == pieceCount
    
    /**
     * Get completion progress (0.0 - 1.0)
     */
    fun getProgress(): Float = localPieces.size.toFloat() / pieceCount
    
    /**
     * Select next pieces to request using rarest-first strategy
     * Returns list of (pieceIndex, peerID) pairs
     */
    fun selectNextPieces(): List<Pair<Int, String>> {
        val now = System.currentTimeMillis()
        
        // Clean up timed-out requests
        pendingRequests.entries.removeIf { now - it.value.second > REQUEST_TIMEOUT_MS }
        
        // Find pieces we need that aren't pending
        val needed = getMissingPieces().filter { !pendingRequests.containsKey(it) }
        
        if (needed.isEmpty()) {
            return emptyList()
        }
        
        // Sort by rarity (fewer peers = rarer = higher priority)
        val sortedByRarity = needed.sortedBy { pieceAvailability[it]?.size ?: 0 }
        
        val requests = mutableListOf<Pair<Int, String>>()
        val slotsAvailable = MAX_PENDING_REQUESTS - pendingRequests.size
        
        for (pieceIndex in sortedByRarity) {
            if (requests.size >= slotsAvailable) break
            
            val peers = pieceAvailability[pieceIndex] ?: continue
            if (peers.isEmpty()) continue
            
            // Pick a random peer that has this piece
            val peerID = peers.random()
            requests.add(pieceIndex to peerID)
            pendingRequests[pieceIndex] = peerID to now
        }
        
        if (requests.isNotEmpty()) {
            Log.d(TAG, "🎯 Selected ${requests.size} pieces (rarest-first): ${requests.map { it.first }}")
        }
        
        return requests
    }
    
    /**
     * Handle failed request (retry with different peer)
     */
    fun markRequestFailed(pieceIndex: Int, peerID: String) {
        pendingRequests.remove(pieceIndex)
        // Optionally remove peer from availability for this piece
        pieceAvailability[pieceIndex]?.remove(peerID)
    }
    
    /**
     * Get our local bitfield for sharing with peers
     */
    fun getLocalBitfield(): ByteArray {
        val bytes = (pieceCount + 7) / 8
        val bitfield = ByteArray(bytes)
        for (i in localPieces) {
            bitfield[i / 8] = (bitfield[i / 8].toInt() or (1 shl (7 - (i % 8)))).toByte()
        }
        return bitfield
    }
    
    private fun logAvailability() {
        val available = pieceAvailability.count { it.value.isNotEmpty() }
        Log.d(TAG, "📊 Availability: $available/$pieceCount pieces available from peers")
    }
}

/**
 * Listener for piece manager events
 */
interface PieceManagerListener {
    fun onPieceReceived(contentId: String, pieceIndex: Int)
    fun onDownloadComplete(contentId: String)
    fun onDownloadProgress(contentId: String, progress: Float)
}
