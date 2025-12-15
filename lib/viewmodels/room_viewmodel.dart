import 'package:flutter/foundation.dart';
import '../models/room.dart';
import '../services/room_service.dart';
import 'base_viewmodel.dart';

class RoomViewModel extends BaseViewModel {
  final RoomService _roomService = RoomService();
  
  List<Room> get rooms => _roomService.rooms;

  RoomViewModel() {
    _init();
  }

  Future<void> _init() async {
    setState(ViewState.busy);
    await _roomService.loadRooms();
    setState(ViewState.idle);
  }

  Future<Room> createRoom(String name) async {
    setState(ViewState.busy);
    final room = await _roomService.createRoom(name);
    setState(ViewState.idle);
    return room;
  }

  Future<Room?> joinRoom(String code) async {
    setState(ViewState.busy);
    final room = await _roomService.joinRoom(code);
    setState(ViewState.idle);
    return room;
  }

  Future<void> leaveRoom(String roomId) async {
    await _roomService.leaveRoom(roomId);
    notifyListeners();
  }

  Room? getRoom(String roomId) => _roomService.getRoom(roomId);
}
