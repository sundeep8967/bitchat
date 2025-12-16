package com.bitchat.android.model

import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest

/**
 * SnapPacket: P2P ephemeral content packet for decentralized social feed.
 * 
 * Like a torrent, content is identified by its hash (snapId) and propagates
 * peer-to-peer through the mesh network. No central server involved.
 * 
 * TLVs:
 *  - 0x01: snapId (32 bytes, SHA-256 hash)
 *  - 0x02: senderPubKey (32 bytes)
 *  - 0x03: senderAlias (UTF-8, max 64 bytes)
 *  - 0x04: contentType (UTF-8, e.g. "image/jpeg")
 *  - 0x05: content (bytes, the actual snap data)
 *  - 0x06: timestamp (8 bytes, Unix millis)
 *  - 0x07: expiresAt (8 bytes, Unix millis)
 *  - 0x08: signature (64 bytes, Ed25519)
 */
data class SnapPacket(
    val snapId: ByteArray,        // SHA-256 of (content + senderPubKey + timestamp)
    val senderPubKey: ByteArray,  // 32-byte public key
    val senderAlias: String,      // Display name
    val contentType: String,      // MIME type
    val content: ByteArray,       // Raw content
    val timestamp: Long,          // Creation time
    val expiresAt: Long,          // Expiry time (TTL)
    val signature: ByteArray      // Ed25519 signature
) {
    companion object {
        private const val TAG = "SnapPacket"
        
        // TLV Types
        private const val TLV_SNAP_ID: Byte = 0x01
        private const val TLV_SENDER_PUBKEY: Byte = 0x02
        private const val TLV_SENDER_ALIAS: Byte = 0x03
        private const val TLV_CONTENT_TYPE: Byte = 0x04
        private const val TLV_CONTENT: Byte = 0x05
        private const val TLV_TIMESTAMP: Byte = 0x06
        private const val TLV_EXPIRES_AT: Byte = 0x07
        private const val TLV_SIGNATURE: Byte = 0x08
        
        // Default TTL: 24 hours
        const val DEFAULT_TTL_MS = 24 * 60 * 60 * 1000L
        
        /**
         * Create a new SnapPacket with auto-generated snapId
         */
        fun create(
            senderPubKey: ByteArray,
            senderAlias: String,
            contentType: String,
            content: ByteArray,
            signature: ByteArray,
            ttlMs: Long = DEFAULT_TTL_MS
        ): SnapPacket {
            val timestamp = System.currentTimeMillis()
            val expiresAt = timestamp + ttlMs
            
            // Generate snapId: SHA-256(content + senderPubKey + timestamp)
            val digest = MessageDigest.getInstance("SHA-256")
            digest.update(content)
            digest.update(senderPubKey)
            digest.update(ByteBuffer.allocate(8).order(ByteOrder.BIG_ENDIAN).putLong(timestamp).array())
            val snapId = digest.digest()
            
            return SnapPacket(
                snapId = snapId,
                senderPubKey = senderPubKey,
                senderAlias = senderAlias,
                contentType = contentType,
                content = content,
                timestamp = timestamp,
                expiresAt = expiresAt,
                signature = signature
            )
        }
        
        /**
         * Decode a SnapPacket from binary TLV data
         */
        fun decode(data: ByteArray): SnapPacket? {
            Log.d(TAG, "🔄 Decoding ${data.size} bytes")
            try {
                var offset = 0
                var snapId: ByteArray? = null
                var senderPubKey: ByteArray? = null
                var senderAlias: String? = null
                var contentType: String? = null
                var content: ByteArray? = null
                var timestamp: Long? = null
                var expiresAt: Long? = null
                var signature: ByteArray? = null
                
                while (offset + 3 <= data.size) {
                    val tlvType = data[offset]
                    offset += 1
                    
                    // Content uses 4-byte length, others use 2-byte
                    val len: Int
                    if (tlvType == TLV_CONTENT) {
                        if (offset + 4 > data.size) return null
                        len = ByteBuffer.wrap(data, offset, 4).order(ByteOrder.BIG_ENDIAN).int
                        offset += 4
                    } else {
                        if (offset + 2 > data.size) return null
                        len = ByteBuffer.wrap(data, offset, 2).order(ByteOrder.BIG_ENDIAN).short.toInt() and 0xFFFF
                        offset += 2
                    }
                    
                    if (len < 0 || offset + len > data.size) return null
                    val value = data.copyOfRange(offset, offset + len)
                    offset += len
                    
                    when (tlvType) {
                        TLV_SNAP_ID -> snapId = value
                        TLV_SENDER_PUBKEY -> senderPubKey = value
                        TLV_SENDER_ALIAS -> senderAlias = String(value, Charsets.UTF_8)
                        TLV_CONTENT_TYPE -> contentType = String(value, Charsets.UTF_8)
                        TLV_CONTENT -> content = value
                        TLV_TIMESTAMP -> timestamp = ByteBuffer.wrap(value).order(ByteOrder.BIG_ENDIAN).long
                        TLV_EXPIRES_AT -> expiresAt = ByteBuffer.wrap(value).order(ByteOrder.BIG_ENDIAN).long
                        TLV_SIGNATURE -> signature = value
                    }
                }
                
                // Validate required fields
                if (snapId == null || senderPubKey == null || content == null || 
                    timestamp == null || expiresAt == null || signature == null) {
                    Log.e(TAG, "❌ Missing required fields in SnapPacket")
                    return null
                }
                
                val result = SnapPacket(
                    snapId = snapId,
                    senderPubKey = senderPubKey,
                    senderAlias = senderAlias ?: "Anonymous",
                    contentType = contentType ?: "application/octet-stream",
                    content = content,
                    timestamp = timestamp,
                    expiresAt = expiresAt,
                    signature = signature
                )
                
                Log.d(TAG, "✅ Decoded snap: ${result.snapIdHex()} from ${result.senderAlias}")
                return result
            } catch (e: Exception) {
                Log.e(TAG, "❌ Decoding failed: ${e.message}", e)
                return null
            }
        }
    }
    
    /**
     * Encode to binary TLV format
     */
    fun encode(): ByteArray {
        val aliasBytes = senderAlias.toByteArray(Charsets.UTF_8).take(64).toByteArray()
        val contentTypeBytes = contentType.toByteArray(Charsets.UTF_8)
        
        // Calculate total size
        val size = (1 + 2 + 32) +  // snapId
                   (1 + 2 + 32) +  // senderPubKey
                   (1 + 2 + aliasBytes.size) +
                   (1 + 2 + contentTypeBytes.size) +
                   (1 + 4 + content.size) +  // content uses 4-byte length
                   (1 + 2 + 8) +  // timestamp
                   (1 + 2 + 8) +  // expiresAt
                   (1 + 2 + 64)   // signature
        
        val buffer = ByteBuffer.allocate(size).order(ByteOrder.BIG_ENDIAN)
        
        // SNAP_ID
        buffer.put(TLV_SNAP_ID)
        buffer.putShort(32)
        buffer.put(snapId)
        
        // SENDER_PUBKEY
        buffer.put(TLV_SENDER_PUBKEY)
        buffer.putShort(32)
        buffer.put(senderPubKey)
        
        // SENDER_ALIAS
        buffer.put(TLV_SENDER_ALIAS)
        buffer.putShort(aliasBytes.size.toShort())
        buffer.put(aliasBytes)
        
        // CONTENT_TYPE
        buffer.put(TLV_CONTENT_TYPE)
        buffer.putShort(contentTypeBytes.size.toShort())
        buffer.put(contentTypeBytes)
        
        // CONTENT (4-byte length for large data)
        buffer.put(TLV_CONTENT)
        buffer.putInt(content.size)
        buffer.put(content)
        
        // TIMESTAMP
        buffer.put(TLV_TIMESTAMP)
        buffer.putShort(8)
        buffer.putLong(timestamp)
        
        // EXPIRES_AT
        buffer.put(TLV_EXPIRES_AT)
        buffer.putShort(8)
        buffer.putLong(expiresAt)
        
        // SIGNATURE
        buffer.put(TLV_SIGNATURE)
        buffer.putShort(64)
        buffer.put(signature)
        
        Log.d(TAG, "✅ Encoded snap: ${snapIdHex()}, ${buffer.position()} bytes")
        return buffer.array()
    }
    
    /**
     * Check if the snap has expired
     */
    fun isExpired(): Boolean = System.currentTimeMillis() > expiresAt
    
    /**
     * Get snap ID as hex string (for display/logging)
     */
    fun snapIdHex(): String = snapId.joinToString("") { "%02x".format(it) }.take(16) + "..."
    
    /**
     * Get sender pubkey as hex string
     */
    fun senderPubKeyHex(): String = senderPubKey.joinToString("") { "%02x".format(it) }
    
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is SnapPacket) return false
        return snapId.contentEquals(other.snapId)
    }
    
    override fun hashCode(): Int = snapId.contentHashCode()
}
