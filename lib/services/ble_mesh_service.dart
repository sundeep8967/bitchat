import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Represents a discovered peer with signal strength
class MeshPeer {
  final String id;
  final String name;
  final int rssi;
  final DateTime lastSeen;
  final String? distance; // Approximate distance string

  MeshPeer({
    required this.id,
    required this.name,
    required this.rssi,
    required this.lastSeen,
    this.distance,
  });

  /// Calculate approximate distance from RSSI
  static String calculateDistance(int rssi) {
    if (rssi >= -50) return "Very Close (~1m)";
    if (rssi >= -65) return "Close (~2-5m)";
    if (rssi >= -75) return "Nearby (~5-10m)";
    if (rssi >= -85) return "Far (~10-20m)";
    return "Very Far (>20m)";
  }

  /// Signal strength as percentage (0-100)
  int get signalStrength {
    // RSSI typically ranges from -100 (weak) to -30 (strong)
    const minRssi = -100;
    const maxRssi = -30;
    final clamped = rssi.clamp(minRssi, maxRssi);
    return ((clamped - minRssi) / (maxRssi - minRssi) * 100).round();
  }

  MeshPeer copyWith({int? rssi, DateTime? lastSeen}) {
    final newRssi = rssi ?? this.rssi;
    return MeshPeer(
      id: id,
      name: name,
      rssi: newRssi,
      lastSeen: lastSeen ?? this.lastSeen,
      distance: calculateDistance(newRssi),
    );
  }
}

/// Message to be sent/received via BLE mesh
class MeshMessage {
  final String id;
  final String senderId;
  final String recipientId; // Can be a specific peer or "broadcast"
  final String content;
  final DateTime timestamp;
  final bool isDelivered;

  MeshMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.timestamp,
    this.isDelivered = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'recipientId': recipientId,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory MeshMessage.fromJson(Map<String, dynamic> json) => MeshMessage(
    id: json['id'],
    senderId: json['senderId'],
    recipientId: json['recipientId'],
    content: json['content'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

/// BitChat BLE Mesh Service
/// Provides real Bluetooth scanning, RSSI tracking, and message exchange
class BleMeshService {
  static final BleMeshService _instance = BleMeshService._internal();
  factory BleMeshService() => _instance;
  BleMeshService._internal();

  // BitChat service UUID (same as reference iOS/Android)
  static const String serviceUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String txCharUuid = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String rxCharUuid = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

  // State
  bool _isScanning = false;
  bool _isAdvertising = false;
  final Map<String, MeshPeer> _peers = {};
  final List<MeshMessage> _pendingMessages = []; // Store-and-forward queue
  String _myPeerId = "";

  // Stream controllers
  final _peerController = StreamController<List<MeshPeer>>.broadcast();
  final _messageController = StreamController<MeshMessage>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  // Public streams
  Stream<List<MeshPeer>> get peerStream => _peerController.stream;
  Stream<MeshMessage> get messageStream => _messageController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  // Getters
  List<MeshPeer> get peers => _peers.values.toList();
  String get myPeerId => _myPeerId;
  bool get isScanning => _isScanning;

  /// Initialize the mesh service
  Future<void> initialize() async {
    // Generate unique peer ID based on device
    _myPeerId = "peer_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}";
    
    // Check Bluetooth support
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported on this device");
      return;
    }

    // Listen for Bluetooth state changes
    FlutterBluePlus.adapterState.listen((state) {
      _connectionStateController.add(state == BluetoothAdapterState.on);
    });
  }

  /// Start scanning for nearby BitChat peers
  Future<void> startScanning() async {
    if (_isScanning) return;

    try {
      // Ensure Bluetooth is on
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
      }

      _isScanning = true;
      _connectionStateController.add(true);

      // Listen for scan results
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          _handleScanResult(result);
        }
        _peerController.add(peers);
      });

      // Start scanning (continuous for mesh)
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        androidUsesFineLocation: true,
      );

      // Restart scan when it stops
      FlutterBluePlus.isScanning.listen((scanning) {
        if (!scanning && _isScanning) {
          // Restart scanning after a brief delay
          Future.delayed(const Duration(seconds: 2), () {
            if (_isScanning) {
              FlutterBluePlus.startScan(
                timeout: const Duration(seconds: 30),
              );
            }
          });
        }
      });

      // Periodic cleanup of stale peers
      Timer.periodic(const Duration(seconds: 10), (timer) {
        if (!_isScanning) {
          timer.cancel();
          return;
        }
        _cleanupStalePeers();
      });
    } catch (e) {
      print("Error starting scan: $e");
      _isScanning = false;
    }
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    _isScanning = false;
    await FlutterBluePlus.stopScan();
    _connectionStateController.add(false);
  }

  /// Handle a scan result
  void _handleScanResult(ScanResult result) {
    final device = result.device;
    final rssi = result.rssi;
    
    // Get device name or use platform ID
    String name = device.platformName.isNotEmpty 
        ? device.platformName 
        : "Device ${device.remoteId.str.substring(0, 8)}";

    // Check if this looks like a BitChat device (by service UUID or name)
    // For now, we'll show all discoverable devices as potential mesh peers
    final peerId = device.remoteId.str;

    if (_peers.containsKey(peerId)) {
      // Update existing peer's RSSI
      _peers[peerId] = _peers[peerId]!.copyWith(
        rssi: rssi,
        lastSeen: DateTime.now(),
      );
    } else {
      // New peer discovered
      _peers[peerId] = MeshPeer(
        id: peerId,
        name: name,
        rssi: rssi,
        lastSeen: DateTime.now(),
        distance: MeshPeer.calculateDistance(rssi),
      );
    }

    // Check if we have pending messages for this peer
    _deliverPendingMessages(peerId);
  }

  /// Remove peers not seen recently
  void _cleanupStalePeers() {
    final now = DateTime.now();
    final staleThreshold = const Duration(seconds: 30);
    
    _peers.removeWhere((id, peer) {
      return now.difference(peer.lastSeen) > staleThreshold;
    });
    
    _peerController.add(peers);
  }

  /// Send a message to a peer (or broadcast)
  Future<bool> sendMessage(String recipientId, String content) async {
    final message = MeshMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: _myPeerId,
      recipientId: recipientId,
      content: content,
      timestamp: DateTime.now(),
    );

    // Check if recipient is currently connected
    if (_peers.containsKey(recipientId)) {
      // Try to send immediately
      final success = await _transmitMessage(recipientId, message);
      if (success) return true;
    }

    // If not connected or send failed, queue for later
    _pendingMessages.add(message);
    print("Message queued for delivery when $recipientId is in range");
    return false;
  }

  /// Actually transmit message via BLE
  Future<bool> _transmitMessage(String recipientId, MeshMessage message) async {
    try {
      // Find the device
      final deviceId = DeviceIdentifier(recipientId);
      final device = BluetoothDevice(remoteId: deviceId);
      
      // Connect if not already
      await device.connect(timeout: const Duration(seconds: 5));
      
      // Discover services
      final services = await device.discoverServices();
      
      // Find our service
      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase().contains("6E400001")) {
          // Find TX characteristic
          for (BluetoothCharacteristic char in service.characteristics) {
            if (char.uuid.toString().toUpperCase().contains("6E400002")) {
              // Write message
              final messageBytes = utf8.encode(jsonEncode(message.toJson()));
              await char.write(messageBytes, withoutResponse: false);
              print("Message sent to $recipientId");
              return true;
            }
          }
        }
      }
      
      return false;
    } catch (e) {
      print("Error transmitting message: $e");
      return false;
    }
  }

  /// Deliver any pending messages to a peer that just came in range
  Future<void> _deliverPendingMessages(String peerId) async {
    final toDeliver = _pendingMessages.where((m) => m.recipientId == peerId).toList();
    
    for (final message in toDeliver) {
      final success = await _transmitMessage(peerId, message);
      if (success) {
        _pendingMessages.remove(message);
      }
    }
  }

  /// Dispose resources
  void dispose() {
    stopScanning();
    _peerController.close();
    _messageController.close();
    _connectionStateController.close();
  }
}
