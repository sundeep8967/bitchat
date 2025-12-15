# BitChat Full Feature Migration - Implementation Plan

## Overview

**Goal:** Migrate ALL features from the reference `bitchat-android` project (164 Kotlin files) to this Flutter app.

**Approach:** Backend-first (native Kotlin), UI later (Flutter).

---

## Reference Project Inventory

| Module | Files | Description |
|--------|-------|-------------|
| `mesh/` | 17 | Core BLE mesh networking |
| `noise/` | 4 | End-to-end encryption (Noise Protocol) |
| `model/` | 8 | Data models |
| `protocol/` | 3 | Binary packet format |
| `crypto/` | 1 | Encryption utilities |
| `sync/` | 4 | Gossip protocol sync |
| `service/` | 5 | Background services |
| `services/` | 6 | App services |
| `identity/` | 1 | User identity management |
| `favorites/` | 1 | Contacts/saved peers |
| `features/` | 5 | Feature flags |
| `geohash/` | 4 | Location encoding |
| `net/` | 4 | Network utilities |
| `core/` | 2 | Core utilities |
| `util/` | 5 | Helper utilities |
| `nostr/` | 24 | Decentralized social protocol |
| `onboarding/` | 12 | Setup flow |
| `ui/` | 54 | UI components (skip for now) |

**Total:** 164 files (excluding 54 UI files = 110 backend files to migrate)

---

## Migration Phases

### Phase 1: Message Persistence ⭐⭐⭐ [NEXT]
**Dependencies:** None
**Effort:** 2-3 hours

#### Files to create:
```
lib/services/message_storage_service.dart
lib/models/stored_message.dart
```

#### Tasks:
- [ ] Add `sqflite` and `path` packages
- [ ] Create SQLite database schema for messages
- [ ] Implement CRUD operations
- [ ] Integrate with `ChatViewModel` to persist messages
- [ ] Load message history on app start

#### Reference:
- `services/MessageHistoryService.kt`

---

### Phase 2: Store-and-Forward Enhancement ⭐⭐⭐
**Dependencies:** Phase 1
**Effort:** 2-3 hours

#### Files to modify:
```
android/.../SimpleMeshService.kt (enhance)
lib/services/pending_messages_service.dart (new)
```

#### Tasks:
- [ ] Persist pending messages to SQLite
- [ ] Survive app restart
- [ ] Add delivery receipts
- [ ] Track message status (pending → sent → delivered)
- [ ] Expose status to Flutter

#### Reference:
- `mesh/StoreForwardManager.kt`

---

### Phase 3: Contacts/Favorites ⭐⭐
**Dependencies:** None
**Effort:** 1-2 hours

#### Files to create:
```
lib/services/contacts_service.dart
lib/models/contact.dart
lib/viewmodels/contacts_viewmodel.dart
```

#### Tasks:
- [ ] Store contacts with SharedPreferences
- [ ] Save peer nickname, last seen, favorite status
- [ ] Implement add/remove/list contacts
- [ ] Sort by last interaction

#### Reference:
- `favorites/FavoritesManager.kt`

---

### Phase 4: Identity Management ⭐⭐⭐
**Dependencies:** None
**Effort:** 2-3 hours

#### Files to create:
```
android/.../identity/IdentityManager.kt
lib/services/identity_service.dart
```

#### Tasks:
- [ ] Generate persistent Curve25519 keypair
- [ ] Store securely (Android Keystore)
- [ ] Derive peer ID from public key fingerprint
- [ ] User nickname management
- [ ] Export/import identity

#### Reference:
- `identity/SecureIdentityStateManager.kt`

---

### Phase 5: Noise Protocol Encryption ⭐⭐⭐
**Dependencies:** Phase 4
**Effort:** 4-6 hours

#### Files to copy:
```
android/.../noise/southernstorm/ (entire directory)
android/.../noise/NoiseSession.kt
android/.../noise/NoiseEncryptionService.kt
android/.../noise/NoiseSessionManager.kt
```

#### Tasks:
- [ ] Copy southernstorm Noise-Java fork
- [ ] Implement NoiseEncryptionService
- [ ] XX handshake pattern (3-way)
- [ ] Encrypt outgoing messages
- [ ] Decrypt incoming messages
- [ ] Session management per peer

#### Reference:
- `noise/NoiseSession.kt` (733 lines)

---

### Phase 6: Binary Protocol ⭐⭐
**Dependencies:** Phase 5
**Effort:** 3-4 hours

#### Files to copy:
```
android/.../protocol/BinaryProtocol.kt
android/.../model/BitchatMessage.kt
```

#### Tasks:
- [ ] Binary message serialization
- [ ] Packet fragmentation
- [ ] Reassembly on receive

#### Reference:
- `protocol/BinaryProtocol.kt`

---

### Phase 7: Advanced Mesh Features ⭐⭐
**Dependencies:** Phase 5, 6
**Effort:** 4-5 hours

#### Tasks:
- [ ] Peer lifecycle management
- [ ] Duplicate message detection
- [ ] Packet relay (multi-hop mesh)
- [ ] TTL management

#### Reference:
- `mesh/PeerManager.kt`
- `mesh/SecurityManager.kt`

---

### Phase 8: File Sharing ⭐
**Dependencies:** Phase 6
**Effort:** 5-6 hours

#### Tasks:
- [ ] File chunking (512 byte MTU)
- [ ] Progress tracking
- [ ] Hash verification
- [ ] Resume interrupted transfers

#### Reference:
- `model/FileSharingManager.kt`

---

### Phase 9: Location Sharing ⭐
**Dependencies:** Phase 6
**Effort:** 3-4 hours

#### Tasks:
- [ ] Geohash encoding/decoding
- [ ] Share location as message type
- [ ] Privacy levels

#### Reference:
- `geohash/Geohash.kt`

---

### Phase 10: Nostr Integration (Optional) ⭐
**Dependencies:** Phase 5
**Effort:** 8-10 hours

#### Tasks:
- [ ] Nostr keypair from identity
- [ ] Connect to relays
- [ ] Publish/subscribe events

---

## Current Progress

| Phase | Status |
|-------|--------|
| Phase 0: Basic Mesh | ✅ Done |
| Phase 1: Message Persistence | 🔲 Next |
| Phase 2-10 | 🔲 Pending |

---

**Ready to start Phase 1?**
