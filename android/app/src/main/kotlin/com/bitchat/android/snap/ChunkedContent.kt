package com.bitchat.android.snap

import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest

/**
 * ChunkedContent: BitTorrent-style content chunking for P2P reliability.
 * 
 * Splits content into fixed-size pieces, each with its own SHA-256 hash.
 * Enables parallel downloads and independent piece verification.
 * 
 * Structure:
 *   Content → [Piece0][Piece1]...[PieceN]
 *   Each piece → SHA-256 hash
 *   Merkle root → Content ID
 */
class ChunkedContent private constructor(
    val merkleRoot: ByteArray,       // Content ID (root of Merkle tree)
    val pieceSize: Int,              // Size of each piece (bytes)
    val totalSize: Long,             // Total content size
    val pieceHashes: List<ByteArray>, // SHA-256 hash of each piece
    private val pieces: MutableMap<Int, ByteArray> = mutableMapOf() // Actual piece data
) {
    companion object {
        private const val TAG = "ChunkedContent"
        
        // Default piece size: 16KB (good balance for BLE MTU and parallelism)
        const val DEFAULT_PIECE_SIZE = 16 * 1024
        
        /**
         * Create ChunkedContent by splitting raw content into pieces
         */
        fun fromContent(content: ByteArray, pieceSize: Int = DEFAULT_PIECE_SIZE): ChunkedContent {
            Log.d(TAG, "📦 Chunking ${content.size} bytes into ${pieceSize}-byte pieces")
            
            val pieceCount = (content.size + pieceSize - 1) / pieceSize
            val pieceHashes = mutableListOf<ByteArray>()
            val pieces = mutableMapOf<Int, ByteArray>()
            
            for (i in 0 until pieceCount) {
                val start = i * pieceSize
                val end = minOf(start + pieceSize, content.size)
                val piece = content.copyOfRange(start, end)
                
                // Calculate SHA-256 hash of piece
                val hash = sha256(piece)
                pieceHashes.add(hash)
                pieces[i] = piece
            }
            
            // Calculate Merkle root
            val merkleRoot = calculateMerkleRoot(pieceHashes)
            
            Log.d(TAG, "✅ Created ${pieceCount} pieces, merkle root: ${merkleRoot.toHexString().take(16)}...")
            
            return ChunkedContent(
                merkleRoot = merkleRoot,
                pieceSize = pieceSize,
                totalSize = content.size.toLong(),
                pieceHashes = pieceHashes,
                pieces = pieces
            )
        }
        
        /**
         * Create ChunkedContent from metadata (for receivers who need to fetch pieces)
         */
        fun fromMetadata(
            merkleRoot: ByteArray,
            pieceSize: Int,
            totalSize: Long,
            pieceHashes: List<ByteArray>
        ): ChunkedContent {
            Log.d(TAG, "📋 Creating from metadata: ${pieceHashes.size} pieces, ${totalSize} bytes")
            return ChunkedContent(
                merkleRoot = merkleRoot,
                pieceSize = pieceSize,
                totalSize = totalSize,
                pieceHashes = pieceHashes
            )
        }
        
        /**
         * Calculate Merkle root from piece hashes
         */
        private fun calculateMerkleRoot(hashes: List<ByteArray>): ByteArray {
            if (hashes.isEmpty()) return sha256(ByteArray(0))
            if (hashes.size == 1) return hashes[0]
            
            // Build Merkle tree bottom-up
            var level = hashes.toMutableList()
            while (level.size > 1) {
                val nextLevel = mutableListOf<ByteArray>()
                for (i in level.indices step 2) {
                    val left = level[i]
                    val right = if (i + 1 < level.size) level[i + 1] else left
                    nextLevel.add(sha256(left + right))
                }
                level = nextLevel
            }
            return level[0]
        }
        
        private fun sha256(data: ByteArray): ByteArray {
            return MessageDigest.getInstance("SHA-256").digest(data)
        }
        
        private fun ByteArray.toHexString(): String = joinToString("") { "%02x".format(it) }
        
        /**
         * Decode metadata from transmission
         */
        fun decodeMetadata(data: ByteArray): ChunkedContent? {
            try {
                val buffer = ByteBuffer.wrap(data).order(ByteOrder.BIG_ENDIAN)
                
                val pieceSize = buffer.int
                val totalSize = buffer.long
                val pieceCount = buffer.int
                
                val merkleRoot = ByteArray(32)
                buffer.get(merkleRoot)
                
                val pieceHashes = mutableListOf<ByteArray>()
                repeat(pieceCount) {
                    val hash = ByteArray(32)
                    buffer.get(hash)
                    pieceHashes.add(hash)
                }
                
                return fromMetadata(merkleRoot, pieceSize, totalSize, pieceHashes)
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to decode metadata: ${e.message}")
                return null
            }
        }
    }
    
    val pieceCount: Int get() = pieceHashes.size
    
    /**
     * Get a piece by index (for sending to peers)
     */
    fun getPiece(index: Int): ByteArray? {
        return pieces[index]
    }
    
    /**
     * Add a received piece (with verification)
     * Returns true if piece is valid and was added
     */
    fun addPiece(index: Int, data: ByteArray): Boolean {
        if (index < 0 || index >= pieceCount) {
            Log.w(TAG, "❌ Invalid piece index: $index (max: ${pieceCount - 1})")
            return false
        }
        
        // Verify piece hash
        val expectedHash = pieceHashes[index]
        val actualHash = sha256(data)
        
        if (!expectedHash.contentEquals(actualHash)) {
            Log.w(TAG, "❌ Piece $index hash mismatch!")
            return false
        }
        
        pieces[index] = data
        Log.d(TAG, "✅ Added piece $index (${data.size} bytes), have ${pieces.size}/${pieceCount}")
        return true
    }
    
    /**
     * Check if we have a specific piece
     */
    fun hasPiece(index: Int): Boolean = pieces.containsKey(index)
    
    /**
     * Get list of pieces we're missing
     */
    fun getMissingPieces(): List<Int> {
        return (0 until pieceCount).filter { !pieces.containsKey(it) }
    }
    
    /**
     * Check if we have all pieces
     */
    fun isComplete(): Boolean = pieces.size == pieceCount
    
    /**
     * Get completion percentage
     */
    fun getProgress(): Float = if (pieceCount == 0) 1f else pieces.size.toFloat() / pieceCount
    
    /**
     * Reassemble complete content from pieces
     * Returns null if not all pieces are available
     */
    fun reassemble(): ByteArray? {
        if (!isComplete()) {
            Log.w(TAG, "⚠️ Cannot reassemble: missing ${getMissingPieces().size} pieces")
            return null
        }
        
        val buffer = ByteBuffer.allocate(totalSize.toInt())
        for (i in 0 until pieceCount) {
            buffer.put(pieces[i]!!)
        }
        
        val content = buffer.array()
        Log.d(TAG, "✅ Reassembled ${content.size} bytes from ${pieceCount} pieces")
        return content
    }
    
    /**
     * Get bitfield representing which pieces we have
     * Each bit represents one piece (1 = have, 0 = missing)
     */
    fun getBitfield(): ByteArray {
        val bytes = (pieceCount + 7) / 8
        val bitfield = ByteArray(bytes)
        for (i in 0 until pieceCount) {
            if (pieces.containsKey(i)) {
                bitfield[i / 8] = (bitfield[i / 8].toInt() or (1 shl (7 - (i % 8)))).toByte()
            }
        }
        return bitfield
    }
    
    /**
     * Parse bitfield to get list of piece indices a peer has
     */
    fun parseBitfield(bitfield: ByteArray): List<Int> {
        val have = mutableListOf<Int>()
        for (i in 0 until pieceCount) {
            val byteIndex = i / 8
            val bitIndex = 7 - (i % 8)
            if (byteIndex < bitfield.size && (bitfield[byteIndex].toInt() and (1 shl bitIndex)) != 0) {
                have.add(i)
            }
        }
        return have
    }
    
    /**
     * Encode metadata for transmission
     */
    fun encodeMetadata(): ByteArray {
        // Format: [pieceSize:4][totalSize:8][pieceCount:4][merkleRoot:32][hash0:32][hash1:32]...
        val size = 4 + 8 + 4 + 32 + (pieceCount * 32)
        val buffer = ByteBuffer.allocate(size).order(ByteOrder.BIG_ENDIAN)
        
        buffer.putInt(pieceSize)
        buffer.putLong(totalSize)
        buffer.putInt(pieceCount)
        buffer.put(merkleRoot)
        pieceHashes.forEach { buffer.put(it) }
        
        return buffer.array()
    }
    
    // Static helper for sha256 (used by addPiece)
    private fun sha256(data: ByteArray): ByteArray {
        return java.security.MessageDigest.getInstance("SHA-256").digest(data)
    }
}

