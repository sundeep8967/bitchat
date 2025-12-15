import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/room.dart';

class RoomService {
  static const String _roomsKey = 'bitchat_rooms';
  static const String _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No confusing chars
  
  final Random _random = Random();
  List<Room> _rooms = [];

  List<Room> get rooms => _rooms;

  /// Generate a unique 4-character room code
  String _generateCode() {
    return List.generate(4, (_) => _codeChars[_random.nextInt(_codeChars.length)]).join();
  }

  /// Load rooms from local storage
  Future<void> loadRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final roomsJson = prefs.getString(_roomsKey);
    if (roomsJson != null) {
      final List<dynamic> decoded = jsonDecode(roomsJson);
      _rooms = decoded.map((e) => Room.fromJson(e)).toList();
    }
  }

  /// Save rooms to local storage
  Future<void> _saveRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final roomsJson = jsonEncode(_rooms.map((r) => r.toJson()).toList());
    await prefs.setString(_roomsKey, roomsJson);
  }

  /// Create a new room with generated code
  Future<Room> createRoom(String name) async {
    final room = Room(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      code: _generateCode(),
      createdAt: DateTime.now(),
      members: [],
      isCreator: true,
    );
    _rooms.add(room);
    await _saveRooms();
    return room;
  }

  /// Join a room by code
  Future<Room?> joinRoom(String code) async {
    // In a real mesh network, this would broadcast a join request
    // For now, we create a local reference to the room
    final normalizedCode = code.toUpperCase().trim();
    
    // Check if already joined
    final existing = _rooms.where((r) => r.code == normalizedCode).firstOrNull;
    if (existing != null) {
      return existing;
    }
    
    // Create a local room reference (in real app, we'd get room info from mesh)
    final room = Room(
      id: 'joined_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Room $normalizedCode', // Will be updated when we receive room info
      code: normalizedCode,
      createdAt: DateTime.now(),
      members: [],
      isCreator: false,
    );
    _rooms.add(room);
    await _saveRooms();
    return room;
  }

  /// Leave/delete a room
  Future<void> leaveRoom(String roomId) async {
    _rooms.removeWhere((r) => r.id == roomId);
    await _saveRooms();
  }

  /// Get room by ID
  Room? getRoom(String roomId) {
    return _rooms.where((r) => r.id == roomId).firstOrNull;
  }

  /// Get room by code
  Room? getRoomByCode(String code) {
    return _rooms.where((r) => r.code == code.toUpperCase()).firstOrNull;
  }
}
