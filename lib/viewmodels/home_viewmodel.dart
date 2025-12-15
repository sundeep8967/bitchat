import 'dart:math';
import 'package:flutter/material.dart';
import 'base_viewmodel.dart';
import '../services/mesh_service.dart';

class HomeViewModel extends BaseViewModel {
  final MeshService _meshService = MeshService();
  
  // Rich peer data with RSSI
  List<MeshPeer> _peers = [];
  List<MeshPeer> get peers => _peers;
  
  // Legacy support - positions for map visualization
  List<Offset> _peerPositions = [];
  List<Offset> get mockPeers => _peerPositions;
  
  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  HomeViewModel() {
    _initService();
  }
  
  void _initService() {
    // Start the mesh service when Home is loaded
    _meshService.startMesh();
    
    // Listen for peer updates with rich data
    _meshService.peerListStream.listen((peerList) {
      _updatePeers(peerList);
    });
    
    // Initial fetch
    _meshService.getPeers().then((peerList) {
       _updatePeers(peerList);
    });
  }

  void setIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }
  
  void startMesh() {
    _meshService.startMesh();
  }
  
  void stopMesh() {
    _meshService.stopMesh();
  }

  void _updatePeers(List<MeshPeer> peerList) {
    _peers = peerList;
    
    // Generate positions for map visualization
    _peerPositions = peerList.map((peer) {
      final int hash = peer.id.hashCode;
      final Random rng = Random(hash);
      
      double angle = rng.nextDouble() * 2 * pi;
      double distance = 50 + rng.nextDouble() * 100;
      return Offset(cos(angle) * distance, sin(angle) * distance);
    }).toList();
    
    notifyListeners();
  }
  
  /// Send message to a specific peer
  Future<bool> sendMessage(String recipientId, String content) {
    return _meshService.sendMessage(recipientId, content);
  }
  
  /// Get my peer ID
  Future<String?> getMyPeerId() {
    return _meshService.getMyPeerID();
  }
}


