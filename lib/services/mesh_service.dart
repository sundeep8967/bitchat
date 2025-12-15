
import 'dart:async';
import 'package:flutter/services.dart';

/// Represents a discovered mesh peer with signal info
class MeshPeer {
  final String id;
  final String name;
  final int rssi;
  final String distance;
  final int signalStrength;
  final DateTime lastSeen;

  MeshPeer({
    required this.id,
    required this.name,
    required this.rssi,
    required this.distance,
    required this.signalStrength,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  factory MeshPeer.fromMap(Map<String, dynamic> map, String peerId) {
    return MeshPeer(
      id: peerId,
      name: map['name'] ?? 'BitChat User',
      rssi: map['rssi'] ?? -100,
      distance: map['distance'] ?? 'Unknown',
      signalStrength: map['signalStrength'] ?? 0,
    );
  }
}

/// Represents a mesh message
class MeshMessage {
  final String senderId;
  final String content;
  final DateTime timestamp;

  MeshMessage({
    required this.senderId,
    required this.content,
    required this.timestamp,
  });

  factory MeshMessage.fromMap(Map<String, dynamic> map) {
    return MeshMessage(
      senderId: map['senderId'] ?? '',
      content: map['content'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

class MeshService {
  static final MeshService _instance = MeshService._internal();

  factory MeshService() {
    return _instance;
  }

  MeshService._internal();

  static const MethodChannel _channel = MethodChannel('com.sundeep.bitchat/mesh');
  static const EventChannel _eventChannel = EventChannel('com.sundeep.bitchat/events');

  // Rich peer list with RSSI info
  final StreamController<List<MeshPeer>> _peerListController = StreamController<List<MeshPeer>>.broadcast();
  final StreamController<MeshMessage> _messageController = StreamController<MeshMessage>.broadcast();

  Stream<List<MeshPeer>> get peerListStream => _peerListController.stream;
  Stream<MeshMessage> get messageStream => _messageController.stream;

  bool _isListening = false;

  void initialize() {
    if (_isListening) return;
    
    _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final type = event['type'];
        final data = event['data'];
        
        if (type == 'peerList') {
          if (data is List) {
            final peers = data.map((peerData) {
              if (peerData is Map) {
                return MeshPeer(
                  id: peerData['id'] ?? '',
                  name: peerData['name'] ?? 'BitChat User',
                  rssi: peerData['rssi'] ?? -100,
                  distance: peerData['distance'] ?? 'Unknown',
                  signalStrength: peerData['signalStrength'] ?? 0,
                );
              }
              return null;
            }).whereType<MeshPeer>().toList();
            _peerListController.add(peers);
          }
        } else if (type == 'message') {
           if (data is Map) {
             _messageController.add(MeshMessage.fromMap(Map<String, dynamic>.from(data)));
           }
        }
      }
    }, onError: (error) {
      print('Mesh Event Error: $error');
    });
    
    _isListening = true;
  }

  Future<bool> startMesh() async {
    try {
      initialize();
      final bool result = await _channel.invokeMethod('startMesh');
      return result;
    } on PlatformException catch (e) {
      print("Failed to start mesh: '${e.message}'.");
      return false;
    }
  }

  Future<bool> stopMesh() async {
    try {
      final bool result = await _channel.invokeMethod('stopMesh');
      return result;
    } on PlatformException catch (e) {
      print("Failed to stop mesh: '${e.message}'.");
      return false;
    }
  }

  /// Get current peers with rich info
  Future<List<MeshPeer>> getPeers() async {
    try {
      final Map result = await _channel.invokeMethod('getPeers');
      return result.entries.map((entry) {
        final data = entry.value is Map ? Map<String, dynamic>.from(entry.value) : <String, dynamic>{};
        return MeshPeer.fromMap(data, entry.key.toString());
      }).toList();
    } on PlatformException catch (e) {
      print("Failed to get peers: '${e.message}'.");
      return [];
    }
  }

  Future<String?> getMyPeerID() async {
    try {
      final String? result = await _channel.invokeMethod('getMyPeerID');
      return result;
    } on PlatformException catch (e) {
      print("Failed to get my peer ID: '${e.message}'.");
      return null;
    }
  }

  /// Send message to a specific peer
  Future<bool> sendMessage(String recipientId, String content) async {
    try {
      final bool result = await _channel.invokeMethod('sendMessage', {
        'recipientId': recipientId,
        'content': content,
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to send message: '${e.message}'.");
      return false;
    }
  }
  
  /// Request exemption from battery optimization (Android only)
  Future<void> requestBatteryOptimizationExemption() async {
    try {
      await _channel.invokeMethod('requestBatteryOptimizationExemption');
    } on PlatformException catch (e) {
      print("Failed to request battery exemption: '${e.message}'.");
    }
  }

  /// Set user nickname
  Future<void> setNickname(String name) async {
    try {
      await _channel.invokeMethod('setNickname', {'nickname': name});
    } on PlatformException catch (e) {
      print("Failed to set nickname: '${e.message}'.");
    }
  }
  
  /// Check if app is exempt from battery optimization
  Future<bool> isBatteryOptimizationExempt() async {
    try {
      final bool result = await _channel.invokeMethod('isBatteryOptimizationExempt');
      return result;
    } on PlatformException catch (e) {
      print("Failed to check battery optimization: '${e.message}'.");
      return false;
    }
  }
}


