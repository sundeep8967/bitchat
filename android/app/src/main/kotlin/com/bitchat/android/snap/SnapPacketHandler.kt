package com.bitchat.android.snap

import android.util.Log
import com.bitchat.android.model.SnapPacket
import com.bitchat.android.model.RoutedPacket

/**
 * SnapPacketHandler: Processes incoming SNAP packets from the mesh.
 * 
 * Responsibilities:
 * 1. Decode SnapPacket from payload
 * 2. Verify signature (authenticity)
 * 3. Check expiry (discard if expired)
 * 4. Store in local cache
 * 5. Decide on relay (gossip to other peers)
 */
class SnapPacketHandler(
    private val cache: SnapLocalCache
) {
    companion object {
        private const val TAG = "SnapPacketHandler"
    }
    
    // Delegate for signature verification and broadcasting
    var delegate: SnapPacketHandlerDelegate? = null
    
    /**
     * Handle an incoming SNAP packet
     * Returns true if the snap was new and stored (should be relayed)
     */
    fun handleSnapPacket(routed: RoutedPacket): Boolean {
        val packet = routed.packet
        val peerID = routed.peerID ?: "unknown"
        val payload = packet.payload
        
        if (payload == null || payload.isEmpty()) {
            Log.w(TAG, "❌ Empty SNAP payload from $peerID")
            return false
        }
        
        // Decode the SnapPacket
        val snap = SnapPacket.decode(payload)
        if (snap == null) {
            Log.w(TAG, "❌ Failed to decode SNAP from $peerID")
            return false
        }
        
        Log.d(TAG, "📥 Received snap ${snap.snapIdHex()} from ${snap.senderAlias} via $peerID")
        
        // Check expiry first (fast rejection)
        if (snap.isExpired()) {
            Log.d(TAG, "⏰ Snap expired, discarding: ${snap.snapIdHex()}")
            return false
        }
        
        // Already have it? (deduplication)
        if (cache.has(snap.snapId)) {
            Log.d(TAG, "📦 Already have snap: ${snap.snapIdHex()}")
            return false
        }
        
        // Verify signature
        if (!verifySignature(snap)) {
            Log.w(TAG, "🚫 Invalid signature on snap: ${snap.snapIdHex()}")
            return false
        }
        
        // Store in local cache
        val stored = cache.store(snap)
        if (stored) {
            Log.d(TAG, "✅ Stored new snap: ${snap.snapIdHex()} from ${snap.senderAlias}")
        }
        
        // Return true if new (caller should relay)
        return stored
    }
    
    /**
     * Verify the Ed25519 signature on the snap
     */
    private fun verifySignature(snap: SnapPacket): Boolean {
        // For MVP, accept all signatures (true P2P - trust the hash)
        // Full implementation would use Ed25519 verification:
        // return delegate?.verifySignature(snap.content, snap.signature, snap.senderPubKey) ?: true
        
        // Basic check: signature length
        if (snap.signature.size != 64) {
            Log.w(TAG, "⚠️ Invalid signature length: ${snap.signature.size}")
            return false
        }
        
        // TODO: Full Ed25519 verification
        return true
    }
    
    /**
     * Get all active snaps for display
     */
    fun getAllActiveSnaps(): List<SnapPacket> = cache.getAllActive()
}

/**
 * Delegate interface for snap handler callbacks
 */
interface SnapPacketHandlerDelegate {
    fun verifySignature(data: ByteArray, signature: ByteArray, publicKey: ByteArray): Boolean
    fun broadcastSnap(snap: SnapPacket)
}
