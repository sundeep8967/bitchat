package com.bitchat.android.snap

import android.util.Log
import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentHashMap

/**
 * TorrentDownloader: Coordinates BitTorrent-style parallel piece downloads.
 * 
 * Manages active downloads, handles piece requests/responses, and
 * reassembles complete content when all pieces are received.
 */
class TorrentDownloader(
    private val scope: CoroutineScope,
    private val sendPieceRequest: suspend (contentId: ByteArray, pieceIndex: Int, toPeerID: String) -> Unit,
    private val onDownloadComplete: (contentId: String, content: ByteArray) -> Unit
) {
    companion object {
        private const val TAG = "TorrentDownloader"
        private const val REQUEST_INTERVAL_MS = 500L  // Request new pieces every 500ms
    }
    
    // Active downloads: contentId hex -> DownloadState
    private val activeDownloads = ConcurrentHashMap<String, DownloadState>()
    
    /**
     * State for an active download
     */
    data class DownloadState(
        val chunkedContent: ChunkedContent,
        val pieceManager: PieceManager,
        var downloadJob: Job? = null
    )
    
    /**
     * Start downloading content from peers
     */
    fun startDownload(chunkedContent: ChunkedContent) {
        val contentId = chunkedContent.merkleRoot.toHexString()
        
        if (activeDownloads.containsKey(contentId)) {
            Log.d(TAG, "⏭️ Download already active: ${contentId.take(16)}...")
            return
        }
        
        Log.d(TAG, "🚀 Starting download: ${contentId.take(16)}... (${chunkedContent.pieceCount} pieces)")
        
        val pieceManager = PieceManager(contentId, chunkedContent.pieceCount)
        val state = DownloadState(chunkedContent, pieceManager)
        activeDownloads[contentId] = state
        
        // Start download loop
        state.downloadJob = scope.launch {
            runDownloadLoop(contentId, state)
        }
    }
    
    /**
     * Handle received bitfield from peer
     */
    fun handlePeerBitfield(contentId: ByteArray, peerID: String, bitfield: ByteArray) {
        val contentIdHex = contentId.toHexString()
        val state = activeDownloads[contentIdHex] ?: return
        
        state.pieceManager.updatePeerBitfield(peerID, bitfield)
    }
    
    /**
     * Handle received piece from peer
     */
    fun handlePieceResponse(contentId: ByteArray, pieceIndex: Int, pieceData: ByteArray, fromPeerID: String) {
        val contentIdHex = contentId.toHexString()
        val state = activeDownloads[contentIdHex] ?: return
        
        // Add piece (with verification)
        val added = state.chunkedContent.addPiece(pieceIndex, pieceData)
        if (added) {
            state.pieceManager.markLocalPiece(pieceIndex)
            
            val progress = state.chunkedContent.getProgress()
            Log.d(TAG, "📦 Piece $pieceIndex received (${(progress * 100).toInt()}% complete)")
            
            // Check if download is complete
            if (state.chunkedContent.isComplete()) {
                completeDownload(contentIdHex, state)
            }
        } else {
            // Piece verification failed
            state.pieceManager.markRequestFailed(pieceIndex, fromPeerID)
        }
    }
    
    /**
     * Handle peer having a piece (from HAVE message)
     */
    fun handlePeerHasPiece(contentId: ByteArray, peerID: String, pieceIndex: Int) {
        val contentIdHex = contentId.toHexString()
        val state = activeDownloads[contentIdHex] ?: return
        state.pieceManager.markPeerHasPiece(peerID, pieceIndex)
    }
    
    /**
     * Remove peer from all downloads (when peer disconnects)
     */
    fun removePeer(peerID: String) {
        activeDownloads.values.forEach { state ->
            state.pieceManager.removePeer(peerID)
        }
    }
    
    /**
     * Check if we're downloading a specific content
     */
    fun isDownloading(contentId: ByteArray): Boolean {
        return activeDownloads.containsKey(contentId.toHexString())
    }
    
    /**
     * Get download progress (0.0 - 1.0)
     */
    fun getProgress(contentId: ByteArray): Float {
        val state = activeDownloads[contentId.toHexString()] ?: return 0f
        return state.chunkedContent.getProgress()
    }
    
    /**
     * Cancel a download
     */
    fun cancelDownload(contentId: ByteArray) {
        val contentIdHex = contentId.toHexString()
        val state = activeDownloads.remove(contentIdHex) ?: return
        state.downloadJob?.cancel()
        Log.d(TAG, "❌ Download cancelled: ${contentIdHex.take(16)}...")
    }
    
    private suspend fun runDownloadLoop(contentId: String, state: DownloadState) {
        while (!state.chunkedContent.isComplete() && activeDownloads.containsKey(contentId)) {
            // Select next pieces to request
            val requests = state.pieceManager.selectNextPieces()
            
            // Send requests
            for ((pieceIndex, peerID) in requests) {
                try {
                    sendPieceRequest(state.chunkedContent.merkleRoot, pieceIndex, peerID)
                } catch (e: Exception) {
                    Log.w(TAG, "⚠️ Failed to request piece $pieceIndex from $peerID: ${e.message}")
                    state.pieceManager.markRequestFailed(pieceIndex, peerID)
                }
            }
            
            delay(REQUEST_INTERVAL_MS)
        }
    }
    
    private fun completeDownload(contentId: String, state: DownloadState) {
        state.downloadJob?.cancel()
        activeDownloads.remove(contentId)
        
        val content = state.chunkedContent.reassemble()
        if (content != null) {
            Log.d(TAG, "✅ Download complete: ${contentId.take(16)}... (${content.size} bytes)")
            onDownloadComplete(contentId, content)
        } else {
            Log.e(TAG, "❌ Failed to reassemble content: ${contentId.take(16)}...")
        }
    }
    
    private fun ByteArray.toHexString(): String = joinToString("") { "%02x".format(it) }
}
