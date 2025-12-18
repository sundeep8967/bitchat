package com.bitchat.android.nostr

import android.content.Context
import android.util.Log
import com.google.gson.Gson
import com.google.gson.JsonParser
import com.google.gson.JsonObject
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
        private const val BITCHAT_DIRECTORY_TAG = "bitchat-user-v1" // Tag for reliable discovery
        
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
                    "nip05" to "${normalized}@bitchat.org"
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
                
                // Publish to BitChat directory (Standard Relays via Tag)
                publishDirectoryEntry(identity, normalized)
                
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
     * Get all BitChat users using Tag-based Directory (#t = bitchat-user-v1)
     * This works on standard relays (Damus, Offchain, etc.) without search support
     */
    suspend fun getAllBitChatUsers(): List<UserSearchResult> {
        return withContext(Dispatchers.IO) {
            try {
                Log.d(TAG, "🔍 Fetching directory users (Tag: $BITCHAT_DIRECTORY_TAG)...")
                
                // Ensure connected
                if (!relayManager.isConnected.value) {
                    relayManager.connect()
                    delay(1500)
                }
                
                val results = mutableListOf<UserSearchResult>()
                
                // Query for Kind 1 events with our directory tag
                // This is supported by ALL public relays
                val filter = NostrFilter(
                    kinds = listOf(NostrKind.TEXT_NOTE),
                    tagFilters = mapOf("t" to listOf(BITCHAT_DIRECTORY_TAG)),
                    limit = 500
                )
                
                val latch = java.util.concurrent.CountDownLatch(1)
                val eoseCount = java.util.concurrent.atomic.AtomicInteger(0)
                val expectedRelays = 5 // Wait for best effort
                
                val subscriptionId = "directory-fetch-${System.currentTimeMillis()}"
                
                relayManager.subscribe(
                    filter = filter,
                    id = subscriptionId,
                    handler = { event ->
                        try {
                            // Directory entries contain JSON with username
                            // Content: {"username": "emu7", "joined": 123456789}
                            if (event.content.startsWith("{")) {
                                val data = JsonParser.parseString(event.content).asJsonObject
                                val username = data.get("username")?.asString
                                
                                if (username != null) {
                                    synchronized(results) {
                                        if (results.none { it.pubkey == event.pubkey }) {
                                            // Unique user found
                                            Log.d(TAG, "📥 Directory User: $username")
                                            results.add(UserSearchResult(username, event.pubkey))
                                            usernameCache[username.lowercase()] = event.pubkey
                                        }
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            // Ignore invalid entries
                        }
                    },
                    onEose = { _ ->
                        if (eoseCount.incrementAndGet() >= 2) { // 2 relays is enough for "fast" load
                           latch.countDown()
                        }
                    }
                )
                
                // Wait up to 5 seconds
                latch.await(5, java.util.concurrent.TimeUnit.SECONDS)
                relayManager.unsubscribe(subscriptionId)
                
                Log.d(TAG, "✅ Found ${results.size} users in directory")
                results.sortedBy { it.username }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to fetch directory: ${e.message}")
                emptyList()
            }
        }
    }
    
    /**
     * Publish a directory entry so others can find this user via tags
     */
    private suspend fun publishDirectoryEntry(identity: com.bitchat.android.nostr.NostrIdentity, username: String) {
        try {
            val content = JsonObject().apply {
                addProperty("username", username)
                addProperty("joined", System.currentTimeMillis())
                addProperty("client", "BitChat")
            }.toString()
            
            val event = NostrEvent.createTextNote(
                content = content,
                publicKeyHex = identity.publicKeyHex,
                privateKeyHex = identity.privateKeyHex,
                tags = listOf(listOf("t", BITCHAT_DIRECTORY_TAG))
            )
            
            relayManager.sendEvent(event)
            Log.d(TAG, "📢 Published directory entry for $username")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to publish directory entry: ${e.message}")
        }
    }
    
    /**
     * STRESS TEST: Publish 10 users and fetch them back
     */
    suspend fun runDirectoryStressTest(): String {
        return withContext(Dispatchers.IO) {
            val report = StringBuilder()
            report.append("🧪 Starting Directory Stress Test...\n")
            
            val testUsers = (1..10).map { "bot_test_${System.currentTimeMillis() % 1000}_$it" }
            var publishedCount = 0
            
            report.append("📤 Publishing ${testUsers.size} users...\n")
            
            // 1. Publish 10 users
            testUsers.forEach { username ->
                try {
                    // Generate a temp identity
                    val seed = "test_bot_$username"
                    val identity = NostrIdentityBridge.deriveIdentity(seed, context)
                    
                    publishDirectoryEntry(identity, username)
                    publishedCount++
                    delay(200) // Spread out slightly
                } catch (e: Exception) {
                    report.append("❌ Failed to publish $username: ${e.message}\n")
                }
            }
            report.append("✅ Published $publishedCount users. Waiting 3s for propagation...\n")
            
            delay(3000)
            
            // 2. Fetch
            report.append("🔍 Fetching directory...\n")
            val users = getAllBitChatUsers()
            
            // 3. Verify
            val foundCount = users.count { it.username.startsWith("bot_test_") }
            report.append("📥 Found $foundCount / $publishedCount test users.\n")
            
            if (foundCount == publishedCount) {
                report.append("🎉 SUCCESS: All users found via standard relays!")
            } else {
                report.append("⚠️ PARTIAL: Missing ${publishedCount - foundCount} users.")
            }
            
            report.toString()
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
                val filter = NostrFilter(
                    kinds = listOf(NostrKind.METADATA),
                    limit = 500  // Reasonable limit per relay
                )
                
                var foundPubkey: String? = null
                val latch = java.util.concurrent.CountDownLatch(1)
                val eoseCount = java.util.concurrent.atomic.AtomicInteger(0)
                val expectedRelays = 5  // We have 5 default relays (including relay.nostr.band)
                
                val subscriptionId = "username-query-$username"
                
                relayManager.subscribe(
                    filter = filter, 
                    id = subscriptionId, 
                    handler = { event ->
                        try {
                            // Parse the content as JSON metadata
                            val metadata = JsonParser.parseString(event.content).asJsonObject
                            val name = metadata.get("name")?.asString?.lowercase()
                            
                            // Also check nip05 for BitChat users
                            val nip05 = metadata.get("nip05")?.asString?.lowercase()
                            val isBitChatUser = nip05?.endsWith("@bitchat.org") == true
                            
                            if (name == username.lowercase()) {
                                Log.d(TAG, "✅ Found username '$username' with pubkey: ${event.pubkey.take(16)}...")
                                foundPubkey = event.pubkey
                                usernameCache[username.lowercase()] = event.pubkey
                                latch.countDown()  // Found it! Stop waiting
                            }
                        } catch (e: Exception) {
                            // Ignore parsing errors
                        }
                    },
                    onEose = { relayUrl ->
                        val count = eoseCount.incrementAndGet()
                        Log.d(TAG, "📥 EOSE from $relayUrl ($count/$expectedRelays)")
                        
                        // When all relays have sent EOSE, we've seen everything
                        if (count >= expectedRelays) {
                            Log.d(TAG, "✅ All relays sent EOSE for username query '$username'")
                            latch.countDown()
                        }
                    }
                )
                
                // Wait until either: match found OR all relays sent EOSE
                // Also add a safety timeout of 30 seconds in case relays don't respond
                latch.await(30, java.util.concurrent.TimeUnit.SECONDS)
                relayManager.unsubscribe(subscriptionId)
                
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

                Log.d(TAG, "🔍 Searching with NIP-50 for: $query")
                
                val results = mutableListOf<UserSearchResult>()
                
                // Use NIP-50 full-text search filter
                // relay.nostr.band supports this - it's a dedicated search relay
                val filter = NostrFilter(
                    kinds = listOf(NostrKind.METADATA),
                    search = query,  // NIP-50 search parameter!
                    limit = 50
                )
                
                val latch = java.util.concurrent.CountDownLatch(1)
                val eoseReceived = java.util.concurrent.atomic.AtomicBoolean(false)
                val subscriptionId = "nip50-search-$query"
                
                // Use relay.nostr.band which supports NIP-50 search
                val searchRelayUrl = "wss://relay.nostr.band"
                
                // Ensure search relay is connected
                relayManager.ensureConnectionsFor(setOf(searchRelayUrl))
                delay(1000)  // Give time to connect
                
                relayManager.subscribe(
                    filter = filter,
                    id = subscriptionId,
                    handler = { event ->
                        try {
                            val metadata = JsonParser.parseString(event.content).asJsonObject
                            val name = metadata.get("name")?.asString
                            
                            // Only show BitChat users (with @bitchat.org nip05)
                            val nip05 = metadata.get("nip05")?.asString?.lowercase()
                            val isBitChatUser = nip05?.endsWith("@bitchat.org") == true
                            
                            if (name != null && isBitChatUser) {
                                synchronized(results) {
                                    if (results.none { it.pubkey == event.pubkey }) {
                                        Log.d(TAG, "📥 NIP-50 found BitChat user: $name")
                                        results.add(UserSearchResult(name, event.pubkey))
                                        usernameCache[name.lowercase()] = event.pubkey
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error parsing search result: ${e.message}")
                        }
                    },
                    targetRelayUrls = listOf(searchRelayUrl),
                    onEose = { relayUrl ->
                        Log.d(TAG, "📥 NIP-50 Search EOSE from $relayUrl")
                        if (eoseReceived.compareAndSet(false, true)) {
                            latch.countDown()
                        }
                    }
                )
                
                // Wait for EOSE from search relay (max 10 seconds)
                latch.await(10, java.util.concurrent.TimeUnit.SECONDS)
                relayManager.unsubscribe(subscriptionId)
                
                Log.d(TAG, "🔍 NIP-50 search found ${results.size} users matching '$query'")
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
