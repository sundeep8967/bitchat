package com.bitchat.android.snap

import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * PiecePackets: Encoding/decoding for piece transfer messages.
 */

/**
 * PIECE_REQUEST: Request a specific piece from a peer
 * Format: [contentId:32][pieceIndex:4]
 */
data class PieceRequestPacket(
    val contentId: ByteArray,  // Merkle root (32 bytes)
    val pieceIndex: Int
) {
    fun encode(): ByteArray {
        val buffer = ByteBuffer.allocate(36).order(ByteOrder.BIG_ENDIAN)
        buffer.put(contentId)
        buffer.putInt(pieceIndex)
        return buffer.array()
    }
    
    companion object {
        fun decode(data: ByteArray): PieceRequestPacket? {
            if (data.size < 36) return null
            val buffer = ByteBuffer.wrap(data).order(ByteOrder.BIG_ENDIAN)
            val contentId = ByteArray(32)
            buffer.get(contentId)
            val pieceIndex = buffer.int
            return PieceRequestPacket(contentId, pieceIndex)
        }
    }
    
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is PieceRequestPacket) return false
        return contentId.contentEquals(other.contentId) && pieceIndex == other.pieceIndex
    }
    
    override fun hashCode(): Int = contentId.contentHashCode() + pieceIndex
}

/**
 * PIECE_RESPONSE: Response with piece data
 * Format: [contentId:32][pieceIndex:4][pieceSize:4][pieceData:N]
 */
data class PieceResponsePacket(
    val contentId: ByteArray,  // Merkle root (32 bytes)
    val pieceIndex: Int,
    val pieceData: ByteArray
) {
    fun encode(): ByteArray {
        val buffer = ByteBuffer.allocate(40 + pieceData.size).order(ByteOrder.BIG_ENDIAN)
        buffer.put(contentId)
        buffer.putInt(pieceIndex)
        buffer.putInt(pieceData.size)
        buffer.put(pieceData)
        return buffer.array()
    }
    
    companion object {
        fun decode(data: ByteArray): PieceResponsePacket? {
            if (data.size < 40) return null
            val buffer = ByteBuffer.wrap(data).order(ByteOrder.BIG_ENDIAN)
            val contentId = ByteArray(32)
            buffer.get(contentId)
            val pieceIndex = buffer.int
            val pieceSize = buffer.int
            if (data.size < 40 + pieceSize) return null
            val pieceData = ByteArray(pieceSize)
            buffer.get(pieceData)
            return PieceResponsePacket(contentId, pieceIndex, pieceData)
        }
    }
    
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is PieceResponsePacket) return false
        return contentId.contentEquals(other.contentId) && pieceIndex == other.pieceIndex
    }
    
    override fun hashCode(): Int = contentId.contentHashCode() + pieceIndex
}

/**
 * PIECE_HAVE: Announce which pieces we have (bitfield)
 * Format: [contentId:32][pieceCount:4][bitfieldSize:4][bitfield:N]
 */
data class PieceHavePacket(
    val contentId: ByteArray,  // Merkle root (32 bytes)
    val pieceCount: Int,
    val bitfield: ByteArray
) {
    fun encode(): ByteArray {
        val buffer = ByteBuffer.allocate(40 + bitfield.size).order(ByteOrder.BIG_ENDIAN)
        buffer.put(contentId)
        buffer.putInt(pieceCount)
        buffer.putInt(bitfield.size)
        buffer.put(bitfield)
        return buffer.array()
    }
    
    companion object {
        fun decode(data: ByteArray): PieceHavePacket? {
            if (data.size < 40) return null
            val buffer = ByteBuffer.wrap(data).order(ByteOrder.BIG_ENDIAN)
            val contentId = ByteArray(32)
            buffer.get(contentId)
            val pieceCount = buffer.int
            val bitfieldSize = buffer.int
            if (data.size < 40 + bitfieldSize) return null
            val bitfield = ByteArray(bitfieldSize)
            buffer.get(bitfield)
            return PieceHavePacket(contentId, pieceCount, bitfield)
        }
    }
    
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is PieceHavePacket) return false
        return contentId.contentEquals(other.contentId)
    }
    
    override fun hashCode(): Int = contentId.contentHashCode()
}
