package com.bitchat.android.nostr

import android.content.Context
import android.util.Log
import com.google.gson.Gson
import com.google.gson.JsonParser
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * UsernameService: Manages unique username registration and search via Nostr.
 * 
 * Uses Nostr kind:0 (metadata) events to store and query usernames.
 * Provides real-time availability checking and global search.
 */
class UsernameService private constructor(private val context: Context) {
    
    companion object {
        private const val TAG = "UsernameService"
        
        @Volatile
        private var instance: UsernameService? = null
        
        fun getInstance(context: Context): UsernameService {
            return instance ?: synchronized(this) {
                instance ?: UsernameService(context.applicationContext).also { instance = it }
            }
        }
    }
    
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val relayManager get() = NostrRelayManager.getInstance(context)
    private val gson = Gson()
    
    // Cached usernames we've seen
    private val usernameCache = mutableMapOf<String, String>() // username -> pubkey
    
    // Current user's registered username
    private val _myUsername = MutableStateFlow<String?>(null)
    val myUsername: StateFlow<String?> = _myUsername
    
    init {
        // Load saved username
        val prefs = context.getSharedPreferences("bitchat_username", Context.MODE_PRIVATE)
        _myUsername.value = prefs.getString("username", null)
        
        // Ensure relays are connected for username queries
        scope.launch {
            try {
                relayManager.connect()
                Log.d(TAG, "📡 UsernameService: Connected to Nostr relays")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to connect relays: ${e.message}")
            }
        }
    }
    
    /**
     * Check if a username is available
     * Returns: true if available, false if taken
     */
    suspend fun checkAvailability(username: String): UsernameCheckResult {
        val normalized = username.lowercase().trim()
        
        if (!isValidUsername(normalized)) {
            return UsernameCheckResult.Invalid("Username must be 3-20 characters, letters/numbers/underscore only")
        }
        
        // Check local cache first
        val cachedOwner = usernameCache[normalized]
        if (cachedOwner != null) {
            return UsernameCheckResult.Taken(cachedOwner)
        }
        
        // Query Nostr relays for kind:0 profiles
        return withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "🔍 Checking availability: $normalized")
                
                // Query for kind:0 metadata events
                // In a full implementation, we'd subscribe and wait for responses
                // For now, we'll use a simple query pattern
                
                val found = queryUsernameFromRelays(normalized)
                
                if (found != null) {
                    usernameCache[normalized] = found
                    UsernameCheckResult.Taken(found)
                } else {
                    UsernameCheckResult.Available
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to check availability: ${e.message}")
                UsernameCheckResult.Error(e.message ?: "Unknown error")
            }
        }
    }
    
    /**
     * Claim a username by publishing to Nostr
     */
    suspend fun claimUsername(username: String): ClaimResult {
        return claimProfile(username, null, null, null)
    }
    
    /**
     * Claim a full profile with username, display name, bio, and picture
     */
    suspend fun claimProfile(
        username: String,
        displayName: String?,
        bio: String?,
        pictureBase64: String?
    ): ClaimResult {
        val normalized = username.lowercase().trim()
        
        // First check availability
        val availability = checkAvailability(normalized)
        if (availability is UsernameCheckResult.Taken) {
            return ClaimResult.AlreadyTaken
        }
        if (availability is UsernameCheckResult.Invalid) {
            return ClaimResult.InvalidUsername(availability.reason)
        }
        if (availability is UsernameCheckResult.Error) {
            return ClaimResult.Failed(availability.message)
        }
        
        return withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "📝 Claiming profile: $normalized (${displayName ?: "no display name"})")
                
                // Get our Nostr identity
                val identity = NostrIdentityBridge.deriveIdentity("", context)
                
                // Create metadata JSON per NIP-01
                val metadata = mutableMapOf(
                    "name" to normalized,
                    "nip05" to "${normalized}@bitchat.app"
                )
                
                // Add optional fields
                if (!displayName.isNullOrBlank()) {
                    metadata["display_name"] = displayName
                }
                if (!bio.isNullOrBlank()) {
                    metadata["about"] = bio
                }
                if (!pictureBase64.isNullOrBlank()) {
                    // In production, you'd upload to a hosting service
                    // For now, we'll use a data URI (works for small images)
                    metadata["picture"] = "data:image/jpeg;base64,${pictureBase64.take(500)}..."
                }
                
                val metadataJson = gson.toJson(metadata)
                
                // Create and sign kind:0 event
                val event = NostrEvent.createMetadata(
                    metadata = metadataJson,
                    publicKeyHex = identity.publicKeyHex,
                    privateKeyHex = identity.privateKeyHex
                )
                
                // Publish to relays
                relayManager.sendEvent(event)
                
                // Save locally
                _myUsername.value = normalized
                val prefs = context.getSharedPreferences("bitchat_username", Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("username", normalized)
                    .putString("display_name", displayName)
                    .putString("bio", bio)
                    .apply()
                
                // Add to our cache
                usernameCache[normalized] = identity.publicKeyHex
                
                Log.d(TAG, "✅ Profile claimed: $normalized")
                ClaimResult.Success(normalized)
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to claim profile: ${e.message}")
                ClaimResult.Failed(e.message ?: "Unknown error")
            }
        }
    }
    
    /**
     * Search for users by username
     */
    suspend fun searchUsername(query: String): List<UserSearchResult> {
        val normalized = query.lowercase().trim()
        if (normalized.length < 2) return emptyList()
        
        return withContext(Dispatchers.IO) {
            val results = mutableListOf<UserSearchResult>()
            
            // Search local cache first
            usernameCache.forEach { (username, pubkey) ->
                if (username.contains(normalized)) {
                    results.add(UserSearchResult(username, pubkey))
                }
            }
            
            // Query Nostr for more results
            try {
                val remoteResults = searchUsernamesFromRelays(normalized)
                remoteResults.forEach { result ->
                    if (results.none { it.pubkey == result.pubkey }) {
                        results.add(result)
                        usernameCache[result.username] = result.pubkey
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "Remote search failed: ${e.message}")
            }
            
            results.sortedBy { it.username }
        }
    }
    
    /**
     * Get pubkey for a username (for adding as friend)
     */
    suspend fun getPubkeyForUsername(username: String): String? {
        val normalized = username.lowercase().trim()
        
        // Check cache
        usernameCache[normalized]?.let { return it }
        
        // Query Nostr
        return queryUsernameFromRelays(normalized)
    }
    
    private fun isValidUsername(username: String): Boolean {
        if (username.length < 3 || username.length > 20) return false
        return username.matches(Regex("^[a-z0-9_]+$"))
    }
    
    private suspend fun queryUsernameFromRelays(username: String): String? {
        return withContext(Dispatchers.IO) {
            try {
                // Ensure connected
                if (!relayManager.isConnected.value) {
                    Log.d(TAG, "📡 Connecting to relays before query...")
                    relayManager.connect()
                    // Give it a moment to connect
                    delay(1500)
                }

                Log.d(TAG, "🔍 Querying relays for username: $username")
                
                // Create a filter for kind:0 metadata events
                // We'll search across all profiles and filter by name field
                val filter = NostrFilter(
                    kinds = listOf(NostrKind.METADATA),
                    limit = 100
                )
                
                var foundPubkey: String? = null
                val latch = java.util.concurrent.CountDownLatch(1)
                
                relayManager.subscribe(filter, "username-query-$username", handler = { event ->
                    try {
                        // Parse the content as JSON metadata
                        val metadata = JsonParser.parseString(event.content).asJsonObject
                        val name = metadata.get("name")?.asString?.lowercase()
                        
                        if (name == username.lowercase()) {
                            foundPubkey = event.pubkey
                            usernameCache[username.lowercase()] = event.pubkey
                            latch.countDown()
                        }
                    } catch (e: Exception) {
                        // Ignore parsing errors
                    }
                })
                
                // Wait for results with timeout
                latch.await(3, java.util.concurrent.TimeUnit.SECONDS)
                relayManager.unsubscribe("username-query-$username")
                
                foundPubkey
            } catch (e: Exception) {
                Log.e(TAG, "Failed to query username from relays: ${e.message}")
                null
            }
        }
    }
    
    private suspend fun searchUsernamesFromRelays(query: String): List<UserSearchResult> {
        return withContext(Dispatchers.IO) {
            try {
                // Ensure connected
                if (!relayManager.isConnected.value) {
                    Log.d(TAG, "📡 Connecting to relays before search...")
                    relayManager.connect()
                    // Give it a moment to connect
                    delay(1500)
                }
                
                if (!relayManager.isConnected.value) {
                     Log.e(TAG, "⚠️ SEARCH WARNING: Still offline after connection attempt. Search will likely fail or return only local results.")
                }

                Log.d(TAG, "🔍 Searching relays for: $query")
                
                val results = mutableListOf<UserSearchResult>()
                
                // Create a filter for kind:0 metadata events
                val filter = NostrFilter(
                    kinds = listOf(NostrKind.METADATA),
                    limit = 100
                )
                
                val latch = java.util.concurrent.CountDownLatch(1)
                var receivedCount = 0
                
                relayManager.subscribe(filter, "username-search-$query", handler = { event ->
                    try {
                        val metadata = JsonParser.parseString(event.content).asJsonObject
                        val name = metadata.get("name")?.asString
                        
                        if (name != null && name.lowercase().contains(query.lowercase())) {
                            synchronized(results) {
                                if (results.none { it.pubkey == event.pubkey }) {
                                    results.add(UserSearchResult(name, event.pubkey))
                                    usernameCache[name.lowercase()] = event.pubkey
                                }
                            }
                        }
                        
                        receivedCount++
                        if (receivedCount >= 50 || results.size >= 10) {
                            latch.countDown()
                        }
                    } catch (e: Exception) {
                        // Ignore parsing errors
                    }
                })
                
                // Wait with timeout
                latch.await(3, java.util.concurrent.TimeUnit.SECONDS)
                relayManager.unsubscribe("username-search-$query")
                
                Log.d(TAG, "🔍 Found ${results.size} users matching '$query'")
                results.take(10)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to search usernames: ${e.message}")
                emptyList()
            }
        }
    }
}

sealed class UsernameCheckResult {
    object Available : UsernameCheckResult()
    data class Taken(val ownerPubkey: String) : UsernameCheckResult()
    data class Invalid(val reason: String) : UsernameCheckResult()
    data class Error(val message: String) : UsernameCheckResult()
}

sealed class ClaimResult {
    data class Success(val username: String) : ClaimResult()
    object AlreadyTaken : ClaimResult()
    data class InvalidUsername(val reason: String) : ClaimResult()
    data class Failed(val message: String) : ClaimResult()
}

data class UserSearchResult(
    val username: String,
    val pubkey: String
)
