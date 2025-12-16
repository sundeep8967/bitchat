import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/friend.dart';

class FriendService {
  static final FriendService instance = FriendService._();
  FriendService._();

  List<Friend> _friends = [];
  List<Map<String, String>> _pendingRequests = []; // NEW: Pending friend requests
  bool _initialized = false;

  List<Friend> get friends => List.unmodifiable(_friends);
  List<Map<String, String>> get pendingRequests => List.unmodifiable(_pendingRequests);

  Future<void> init() async {
    if (_initialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Load Friends
    final String? friendsJson = prefs.getString('friends_list');
    if (friendsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(friendsJson);
        _friends = decoded.map((item) => Friend.fromJson(item)).toList();
        _sortFriends();
      } catch (e) {
        print('❌ Failed to load friends: $e');
      }
    }
    
    // Load Pending Requests
    final String? requestsJson = prefs.getString('pending_requests');
    if (requestsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(requestsJson);
        _pendingRequests = decoded.map((item) => Map<String, String>.from(item)).toList();
      } catch (e) {
        print('❌ Failed to load pending requests: $e');
      }
    }
    
    _initialized = true;
  }

  // ========== FRIEND REQUESTS ==========
  
  Future<void> addPendingRequest(Map<String, String> user) async {
    await init();
    // Don't add if already a friend or already pending
    if (isFriend(user['username'] ?? '')) return;
    if (_pendingRequests.any((r) => r['username'] == user['username'])) return;
    
    _pendingRequests.add(user);
    await _saveRequests();
  }
  
  Future<void> acceptRequest(String username) async {
    await init();
    final request = _pendingRequests.firstWhere(
      (r) => r['username'] == username,
      orElse: () => {},
    );
    
    if (request.isNotEmpty) {
      await addFriend(request);
      _pendingRequests.removeWhere((r) => r['username'] == username);
      await _saveRequests();
    }
  }
  
  Future<void> declineRequest(String username) async {
    await init();
    _pendingRequests.removeWhere((r) => r['username'] == username);
    await _saveRequests();
  }
  
  Future<void> _saveRequests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_requests', jsonEncode(_pendingRequests));
  }

  // ========== FRIENDS ==========

  Future<void> addFriend(Map<String, String> userMap) async {
    await init();
    
    // Check if already added
    if (_friends.any((f) => f.username == userMap['username'])) {
      return;
    }

    final newFriend = Friend.fromMap(userMap);
    _friends.add(newFriend);
    _sortFriends();
    await _saveFriends();
  }

  Future<void> removeFriend(String username) async {
    await init();
    _friends.removeWhere((f) => f.username == username);
    await _saveFriends();
  }
  
  Future<void> updateFriendStatus(String username, FriendStatus status) async {
    await init();
    final index = _friends.indexWhere((f) => f.username == username);
    if (index != -1) {
      _friends[index] = _friends[index].copyWith(
        status: status,
        lastInteraction: DateTime.now(),
      );
      _sortFriends();
      await _saveFriends();
    }
  }

  bool isFriend(String username) {
    return _friends.any((f) => f.username == username);
  }

  void _sortFriends() {
    _friends.sort((a, b) {
      final aTime = a.lastInteraction ?? a.addedAt;
      final bTime = b.lastInteraction ?? b.addedAt;
      return bTime.compareTo(aTime); // Descending (newest first)
    });
  }

  Future<void> _saveFriends() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_friends.map((f) => f.toJson()).toList());
    await prefs.setString('friends_list', encoded);
  }
}
