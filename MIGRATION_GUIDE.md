# BitChat Reference Project Migration Guide

This document explains how to port features from the reference `bitchat-android` project to this Flutter app.

## Reference Project Structure

```
reference/bitchat-android/app/src/main/java/com/bitchat/android/
├── mesh/              # Core BLE mesh networking (17 files)
├── noise/             # End-to-end encryption (Noise Protocol)
├── model/             # Data models
├── protocol/          # Binary packet format
├── crypto/            # Encryption utilities
├── sync/              # Gossip protocol sync
├── nostr/             # Decentralized social (OPTIONAL)
├── favorites/         # Contacts system (OPTIONAL)
├── features/          # Feature flags (OPTIONAL)
└── services/          # App services
```

---

## Feature Priority Matrix

| Feature | Priority | Complexity | Status |
|---------|----------|------------|--------|
| BLE Scanning + RSSI | ⭐⭐⭐ Critical | Medium | ✅ Done |
| Message Send/Receive | ⭐⭐⭐ Critical | Medium | ✅ Done |
| Background Service | ⭐⭐⭐ Critical | Low | ✅ Done |
| Message Persistence | ⭐⭐ High | Low | 🔲 TODO |
| Store-and-Forward | ⭐⭐ High | Medium | 🔲 TODO |
| Noise Encryption | ⭐⭐ High | High | 🔲 TODO |
| Contacts/Favorites | ⭐ Medium | Low | 🔲 TODO |
| File Sharing | ⭐ Medium | High | 🔲 TODO |
| Nostr Integration | ⚪ Optional | Very High | 🔲 Skip |

---

## Step-by-Step Migration

### 1. Message Persistence (NEXT PRIORITY)

**What it does:** Saves messages locally so they survive app restarts.

**Reference files:**
- `services/MessageHistoryService.kt`

**Flutter implementation:**
```dart
// Add to pubspec.yaml:
// sqflite: ^2.3.0
// path: ^1.8.3

// Create lib/services/message_storage_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class MessageStorageService {
  static Database? _database;
  
  Future<Database> get database async {
    _database ??= await _initDB();
    return _database!;
  }
  
  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'bitchat.db');
    return openDatabase(path, version: 1, onCreate: (db, version) {
      return db.execute('''
        CREATE TABLE messages(
          id TEXT PRIMARY KEY,
          senderId TEXT,
          recipientId TEXT,
          content TEXT,
          timestamp INTEGER,
          isDelivered INTEGER DEFAULT 0
        )
      ''');
    });
  }
  
  Future<void> saveMessage(MeshMessage message) async {
    final db = await database;
    await db.insert('messages', {
      'id': message.id,
      'senderId': message.senderId,
      'recipientId': message.recipientId,
      'content': message.content,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
    });
  }
  
  Future<List<MeshMessage>> getMessages(String peerId) async {
    final db = await database;
    final maps = await db.query('messages',
      where: 'senderId = ? OR recipientId = ?',
      whereArgs: [peerId, peerId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => MeshMessage.fromDb(m)).toList();
  }
}
```

---

### 2. Store-and-Forward

**What it does:** Queues messages when recipient is offline, delivers when they come in range.

**Reference files:**
- `mesh/StoreForwardManager.kt`

**Already implemented in SimpleMeshService:**
```kotlin
// In SimpleMeshService.kt
private val pendingMessages = mutableListOf<Triple<String, String, Long>>()

private fun deliverPendingMessages(peerId: String, device: BluetoothDevice) {
    val toDeliver = pendingMessages.filter { it.first == peerId }
    toDeliver.forEach { (_, content, _) ->
        if (sendMessageToDevice(device, content)) {
            pendingMessages.removeIf { it.first == peerId && it.second == content }
        }
    }
}
```

**To enhance:** Add persistence so pending messages survive app restart.

---

### 3. Noise Protocol Encryption

**What it does:** End-to-end encryption using Noise_XX_25519_ChaChaPoly_SHA256.

**Reference files:**
- `noise/NoiseSession.kt` (733 lines)
- `noise/NoiseEncryptionService.kt`
- `noise/southernstorm/` (local Noise-Java fork)

**Porting steps:**
1. Copy `noise/southernstorm/` directory (pure Java, no dependencies)
2. Create simplified `NoiseEncryptionService`

---

### 4. Contacts/Favorites

**What it does:** Save frequently contacted peers.

**Reference files:**
- `favorites/FavoritesManager.kt`

**Flutter implementation:**
```dart
// lib/services/contacts_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class ContactsService {
  static const _key = 'saved_contacts';
  
  Future<List<String>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }
  
  Future<void> addContact(String peerId) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = await getContacts();
    if (!contacts.contains(peerId)) {
      contacts.add(peerId);
      await prefs.setStringList(_key, contacts);
    }
  }
}
```

---

## What NOT to Port

| Component | Reason to Skip |
|-----------|----------------|
| `nostr/` (24 files) | Separate protocol, not core to mesh |
| `ui/debug/` | Development tools only |
| `geohash/` | Location features, optional |

---

## Testing on Physical Devices

⚠️ **Emulators cannot test BLE mesh!** You need:
- 2+ Android phones with BLE
- Bluetooth enabled on both
- Location permission granted

---

## Next Steps (Recommended Order)

1. ✅ **Done:** BLE scanning, RSSI, messaging
2. 🔲 **Add message persistence** (SQLite)
3. 🔲 **Add contacts** (SharedPreferences)
4. 🔲 **Add Noise encryption** (copy southernstorm/)
5. 🔲 **Add file sharing** (if needed)
