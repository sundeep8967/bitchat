import 'dart:convert';

enum FriendStatus {
  added,    // Just added, no interaction
  newSnap,  // Received a snap (Red Square)
  opened,   // Viewed snap (Hollow Square)
  newChat,  // Received chat (Blue Bubble)
  sent      // Sent snap/chat (Arrow)
}

class Friend {
  final String username;
  final String displayName;
  final String? pubkey;
  final DateTime addedAt;
  final FriendStatus status;
  final DateTime? lastInteraction;

  Friend({
    required this.username,
    this.displayName = '',
    this.pubkey,
    required this.addedAt,
    this.status = FriendStatus.added,
    this.lastInteraction,
  });

  // Factory to create from basic search result
  factory Friend.fromMap(Map<String, String> map) {
    return Friend(
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? '',
      pubkey: map['pubkey'],
      addedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'displayName': displayName,
      'pubkey': pubkey,
      'addedAt': addedAt.toIso8601String(),
      'status': status.index,
      'lastInteraction': lastInteraction?.toIso8601String(),
    };
  }

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? '',
      pubkey: json['pubkey'],
      addedAt: DateTime.parse(json['addedAt']),
      status: FriendStatus.values[json['status'] ?? 0],
      lastInteraction: json['lastInteraction'] != null 
          ? DateTime.parse(json['lastInteraction']) 
          : null,
    );
  }

  Friend copyWith({
    String? displayName,
    FriendStatus? status,
    DateTime? lastInteraction,
  }) {
    return Friend(
      username: username,
      displayName: displayName ?? this.displayName,
      pubkey: pubkey,
      addedAt: addedAt,
      status: status ?? this.status,
      lastInteraction: lastInteraction ?? this.lastInteraction,
    );
  }
}
