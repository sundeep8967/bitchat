import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// SnapService: Flutter interface for P2P social snaps.
/// 
/// Communicates with the Kotlin backend (BluetoothMeshService) to:
/// - Create and broadcast snaps
/// - Receive incoming snaps via EventChannel
/// - Query local cache for active snaps
class SnapService {
  // Use the same channel as the existing mesh service
  static const MethodChannel _channel = MethodChannel('com.sundeep.bitchat/mesh');
  static const EventChannel _eventChannel = EventChannel('com.sundeep.bitchat/events');
  
  static SnapService? _instance;
  static SnapService get instance => _instance ??= SnapService._();
  
  SnapService._();
  
  // Stream of incoming snaps
  Stream<Snap>? _snapStream;
  
  /// Broadcast a new snap to the mesh network
  Future<bool> broadcastSnap({
    required Uint8List content,
    String contentType = 'image/jpeg',
    int ttlMs = 24 * 60 * 60 * 1000, // 24 hours default
  }) async {
    try {
      final result = await _channel.invokeMethod('broadcastSnap', {
        'content': base64Encode(content),
        'contentType': contentType,
        'ttlMs': ttlMs,
      });
      return result == true;
    } catch (e) {
      print('❌ SnapService.broadcastSnap failed: $e');
      return false;
    }
  }
  
  /// Get all active (non-expired) snaps from local cache
  Future<List<Snap>> getActiveSnaps() async {
    try {
      final result = await _channel.invokeMethod('getActiveSnaps');
      if (result is List) {
        return result.map((item) => Snap.fromMap(Map<String, dynamic>.from(item))).toList();
      }
      return [];
    } catch (e) {
      print('❌ SnapService.getActiveSnaps failed: $e');
      return [];
    }
  }
  
  /// Stream of incoming snaps (for real-time UI updates)
  Stream<Snap> get snapStream {
    _snapStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      return Snap.fromMap(Map<String, dynamic>.from(event));
    });
    return _snapStream!;
  }
  
  /// Search for users by username via Nostr
  Future<List<Map<String, String>>> searchUsername(String query) async {
    try {
      final result = await _channel.invokeMethod('searchUsername', {
        'query': query,
      });
      if (result is List) {
        return result.map((item) => Map<String, String>.from(item as Map)).toList();
      }
      return [];
    } catch (e) {
      print('❌ SnapService.searchUsername failed: $e');
      return [];
    }
  }
}

/// Snap model representing a P2P social snap
class Snap {
  final String snapId;
  final String senderPubKey;
  final String senderAlias;
  final String contentType;
  final Uint8List content;
  final DateTime timestamp;
  final DateTime expiresAt;
  
  Snap({
    required this.snapId,
    required this.senderPubKey,
    required this.senderAlias,
    required this.contentType,
    required this.content,
    required this.timestamp,
    required this.expiresAt,
  });
  
  factory Snap.fromMap(Map<String, dynamic> map) {
    return Snap(
      snapId: map['snapId'] as String,
      senderPubKey: map['senderPubKey'] as String,
      senderAlias: map['senderAlias'] as String,
      contentType: map['contentType'] as String,
      content: base64Decode(map['content'] as String),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expiresAt'] as int),
    );
  }
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  /// Sender ID hex (first 16 chars of pubkey)
  String get senderIdHex => senderPubKey.length >= 16 
      ? senderPubKey.substring(0, 16) 
      : senderPubKey;
  
  /// Time remaining until expiry
  Duration get timeRemaining => expiresAt.difference(DateTime.now());
  
  /// Human-readable time remaining (e.g., "23h 45m")
  String get timeRemainingString {
    if (isExpired) return 'Expired';
    final hours = timeRemaining.inHours;
    final minutes = timeRemaining.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
