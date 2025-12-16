import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/room_viewmodel.dart';
import '../models/room.dart';
import 'chat_screen.dart';
import 'room_chat_screen.dart';
import 'social_feed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final MapController _mapController;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  int _selectedTab = 0; // 0=Nearby, 1=Rooms (Within Map Tab)
  int _currentNavIndex = 0; // 0=Map/Chat, 1=Social
  
  // Bengaluru Center (user's location)
  final _center = const LatLng(12.9716, 77.5946); 

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentNavIndex == 1 ? Colors.black : Colors.white,
      body: _currentNavIndex == 0 
          ? _buildMapInterface(context) 
          : const SocialFeedScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!, width: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: (index) => setState(() => _currentNavIndex = index),
          backgroundColor: Colors.transparent, 
          elevation: 0,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey[400],
          showSelectedLabels: false,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(LucideIcons.map), label: 'Map'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.messageCircle), label: 'Social'),
          ],
        ),
      ),
    );
  }

  Widget _buildMapInterface(BuildContext context) {
    return Consumer2<HomeViewModel, RoomViewModel>(
      builder: (context, homeModel, roomModel, child) {
        final peerLocations = List.generate(homeModel.mockPeers.length, (index) {
           final offset = (index + 1) * 0.003; 
           return LatLng(
             _center.latitude + (offset * (index % 2 == 0 ? 1 : -1)), 
             _center.longitude + (offset * (index % 2 == 0 ? -1 : 1))
           );
        });

        return Stack(
          children: [
            // 1. Interactive Map Layer
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 14,
                minZoom: 3,
                maxZoom: 18,
              ),
              children: [
                 TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.bitchat.app',
                ),
                
                PolylineLayer(
                  polylines: peerLocations.map<Polyline>((peerLoc) {
                    return Polyline(
                      points: [_center, peerLoc],
                      color: const Color(0xFF2E75FF).withOpacity(0.4),
                      strokeWidth: 2.0,
                    );
                  }).toList(),
                ),
                
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _center,
                      width: 80,
                      height: 80,
                      child: _buildAvatar(name: 'You', imageUrl: 'https://i.pravatar.cc/150?u=you', isMe: true),
                    ),
                    ...List.generate(peerLocations.length, (index) {
                       return Marker(
                         point: peerLocations[index],
                         width: 60,
                         height: 60,
                         child: GestureDetector(
                           onTap: () => Navigator.push(context, MaterialPageRoute(
                             builder: (_) => ChatScreen(peerName: 'mesh_user_$index', peerId: 'peer_$index'),
                           )),
                           child: _buildAvatar(name: 'Peer ${index+1}', imageUrl: 'https://i.pravatar.cc/150?u=$index', isMe: false),
                         ),
                       );
                    }),
                  ],
                ),
              ],
            ),
            
            // Fade overlay at top
            Positioned(
              top: 0, left: 0, right: 0, height: 120,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withOpacity(0.95), Colors.white.withOpacity(0.0)],
                  ),
                ),
              ),
            ),

            // 2. Floating Header Card
            Positioned(
              top: 60, left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(LucideIcons.mapPin, color: Colors.blue, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bengaluru Mesh', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1F36))),
                        Text('${homeModel.mockPeers.length} nodes • ${roomModel.rooms.length} rooms', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(icon: const Icon(LucideIcons.crosshair, color: Colors.grey, size: 20), onPressed: () => _mapController.move(_center, 15)),
                  ],
                ),
              ).animate().slideY(begin: -1, end: 0, duration: 600.ms, curve: Curves.easeOutBack),
            ),
            
            // Map Attribution
            Positioned(bottom: 4, right: 4, child: Text('© OpenStreetMap, © CartoDB', style: TextStyle(fontSize: 9, color: Colors.grey[600]))),

            // 3. Draggable Bottom Sheet
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.35,
              minChildSize: 0.15,
              maxChildSize: 0.85,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                      ),
                      
                      // Tabs
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            _buildTab('Nearby', LucideIcons.radio, 0),
                            const SizedBox(width: 12),
                            _buildTab('Rooms', LucideIcons.lock, 1),
                            const Spacer(),
                            // Quick actions
                            if (_selectedTab == 1) ...[
                              _buildIconButton(LucideIcons.plus, 'Create', () => _showCreateRoomDialog(roomModel)),
                              const SizedBox(width: 8),
                              _buildIconButton(LucideIcons.key, 'Join', () => _showJoinRoomDialog(roomModel)),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Content
                      Expanded(
                        child: _selectedTab == 0
                          ? _buildNearbyList(homeModel, peerLocations, scrollController)
                          : _buildRoomsList(roomModel, scrollController),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTab(String label, IconData icon, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E75FF) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: Colors.grey[700]),
        ),
      ),
    );
  }

  Widget _buildNearbyList(HomeViewModel model, List<LatLng> peerLocations, ScrollController controller) {
    if (model.mockPeers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.radio, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No peers nearby', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => model.startMesh(),
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Scan'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E75FF)),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: model.mockPeers.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage('https://i.pravatar.cc/100?u=$index'),
            backgroundColor: Colors.grey[200],
          ),
          title: Text('mesh_user_$index', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('~50m away • Strong signal', style: TextStyle(fontSize: 12)),
          trailing: const Icon(LucideIcons.messageCircle, color: Color(0xFF2E75FF)),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChatScreen(peerName: 'mesh_user_$index', peerId: 'peer_$index'),
          )),
        );
      },
    );
  }

  Widget _buildRoomsList(RoomViewModel model, ScrollController controller) {
    if (model.rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.lock, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No rooms yet', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 4),
            Text('Create or join a room with a code', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
      );
    }
    
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: model.rooms.length,
      itemBuilder: (context, index) {
        final room = model.rooms[index];
        return ListTile(
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2E75FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.users, color: Color(0xFF2E75FF)),
          ),
          title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                child: Text(room.code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
              const SizedBox(width: 8),
              Text(room.isCreator ? 'Owner' : 'Member', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
          trailing: const Icon(LucideIcons.chevronRight, color: Colors.grey),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoomChatScreen(room: room))),
        );
      },
    );
  }

  void _showCreateRoomDialog(RoomViewModel model) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Create Room', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Room name',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isNotEmpty) {
                  final room = await model.createRoom(controller.text.trim());
                  if (mounted) {
                    Navigator.pop(context);
                    // Show code in snackbar
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(LucideIcons.check, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('Room created! Code: ${room.code}'),
                          ],
                        ),
                        action: SnackBarAction(label: 'Copy', textColor: Colors.white, onPressed: () {
                          Clipboard.setData(ClipboardData(text: room.code));
                        }),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF2E75FF),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E75FF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Create', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinRoomDialog(RoomViewModel model) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Join Room', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Enter 4-letter code',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().length >= 4) {
                  final room = await model.joinRoom(controller.text.trim());
                  if (mounted && room != null) {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RoomChatScreen(room: room)));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E75FF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Join', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar({required String name, required String imageUrl, required bool isMe}) {
    final size = isMe ? 70.0 : 50.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (isMe)
          Container(width: size + 30, height: size + 30, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2E75FF).withOpacity(0.15)))
            .animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 2.seconds).fadeOut(duration: 2.seconds),
        Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle, color: Colors.white,
            border: Border.all(color: Colors.white, width: isMe ? 3 : 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: ClipOval(
            child: Image.network(imageUrl, fit: BoxFit.cover, 
              errorBuilder: (_,__,___) => Container(color: isMe ? const Color(0xFF2E75FF) : Colors.grey[200], child: Icon(LucideIcons.user, color: isMe ? Colors.white : Colors.grey))),
          ),
        ),
      ],
    ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack);
  }
}

