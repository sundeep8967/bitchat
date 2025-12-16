import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:ui';
import '../services/snap_service.dart';

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  // Insta Brand Colors
  static const Color _instaPink = Color(0xFFE1306C);
  static const Color _instaPurple = Color(0xFFC13584);
  static const Color _instaOrange = Color(0xFFF56040);

  // P2P Snaps from cache
  List<Snap> _snaps = [];
  StreamSubscription<Snap>? _snapSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSnaps();
    _subscribeToSnaps();
  }

  @override
  void dispose() {
    _snapSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSnaps() async {
    try {
      final snaps = await SnapService.instance.getActiveSnaps();
      if (mounted) {
        setState(() {
          _snaps = snaps;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Failed to load snaps: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToSnaps() {
    _snapSubscription = SnapService.instance.snapStream.listen((snap) {
      if (mounted) {
        setState(() {
          // Add to front of list (newest first)
          _snaps.insert(0, snap);
        });
      }
    });
  }

  Future<void> _onCameraTap() async {
    HapticFeedback.mediumImpact();
    
    try {
      final ImagePicker picker = ImagePicker();
      
      // Show bottom sheet to choose camera or gallery
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: const Color(0xFF1C1C1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _instaPink.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.camera, color: _instaPink),
                ),
                title: const Text('Take Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('Use camera to capture a snap', style: TextStyle(color: Colors.grey[600])),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _instaPurple.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.image, color: _instaPurple),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('Select an existing photo', style: TextStyle(color: Colors.grey[600])),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
      
      if (source == null) return;
      
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70, // Compress for mesh transfer
        maxWidth: 1080,
        maxHeight: 1080,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        
        // Show sending indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  const Text('📤 Broadcasting snap to mesh...'),
                ],
              ),
              backgroundColor: _instaPink,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        // Broadcast to mesh
        final success = await SnapService.instance.broadcastSnap(content: bytes);
        
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? '✅ Snap sent to mesh!' : '❌ Failed to send snap'),
              backgroundColor: success ? Colors.green : Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        
        // Reload snaps to show our own snap
        _loadSnaps();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Main Content: Friends List
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverAppBar(
                backgroundColor: Colors.black,
                expandedHeight: 120.0,
                floating: false,
                pinned: true,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                  title: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [_instaPurple, _instaPink, _instaOrange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      'Snaps',
                      style: TextStyle(
                        color: Colors.white, // Masked by shader
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  background: Container(color: Colors.black),
                ),
                actions: [
                  _buildHeaderAction(LucideIcons.userPlus),
                  const SizedBox(width: 8),
                  _buildHeaderAction(LucideIcons.moreHorizontal),
                  const SizedBox(width: 20),
                ],
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E), // Dark Gray
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _instaPink.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Icon(LucideIcons.search, color: _instaPink, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Search Friends',
                          style: TextStyle(
                            color: _instaPink.withOpacity(0.7),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _snaps.isEmpty ? 'NO SNAPS YET' : 'RECENT SNAPS',
                        style: TextStyle(
                          color: _instaPink.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (_snaps.isNotEmpty)
                        Text(
                          '${_snaps.length} active',
                          style: TextStyle(
                            color: _instaPink.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Empty State or Snaps List
              if (_isLoading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: _instaPink),
                    ),
                  ),
                )
              else if (_snaps.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1C1C1E),
                            border: Border.all(color: _instaPink.withOpacity(0.3)),
                          ),
                          child: Icon(LucideIcons.camera, color: _instaPink, size: 36),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No snaps yet',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the camera button to send\nyour first P2P snap!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final snap = _snaps[index];
                      return _buildSnapRow(snap, index);
                    },
                    childCount: _snaps.length,
                  ),
                ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // 2. The Insta Gradient Shutter Button (FAB)
          Positioned(
            bottom: 30, left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _onCameraTap,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [_instaPurple, _instaPink, _instaOrange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: _instaPink.withOpacity(0.4), blurRadius: 25, spreadRadius: 2),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 72, height: 72,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black, // Inner cutout
                      ),
                      child: Center(
                        child: Container(
                           width: 58, height: 58,
                           decoration: BoxDecoration(
                             shape: BoxShape.circle,
                             border: Border.all(color: Colors.white, width: 2)
                           ),
                           child: const Icon(LucideIcons.camera, color: Colors.white, size: 26),
                        ),
                      ),
                    ),
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                 .scale(begin: const Offset(1,1), end: const Offset(1.05, 1.05), duration: 1.5.seconds, curve: Curves.easeInOut),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        shape: BoxShape.circle,
        border: Border.all(color: _instaPink.withOpacity(0.3)),
      ),
      child: Icon(icon, color: _instaPink, size: 20),
    );
  }

  Widget _buildSnapRow(Snap snap, int index) {
    return Material(
      color: Colors.black,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          // TODO: Open snap viewer
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Avatar with snap preview
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[900],
                  border: Border.all(color: _instaPurple.withOpacity(0.5), width: 2),
                  image: snap.contentType.startsWith('image/')
                      ? DecorationImage(
                          image: MemoryImage(snap.content),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: snap.contentType.startsWith('image/')
                    ? null
                    : Icon(LucideIcons.camera, color: _instaPink),
              ),
              
              const SizedBox(width: 16),
              
              // Snap info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snap.senderAlias,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildFilledSquare(_instaPink),
                        const SizedBox(width: 8),
                        Text(
                          'Expires in ${snap.timeRemainingString}',
                          style: TextStyle(
                            color: _instaPink,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: _instaPink.withOpacity(0.6), blurRadius: 8)],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('🔥', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Timestamp
              Text(
                _formatTime(snap.timestamp),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ).animate().slideX(begin: 0.1, end: 0, duration: (300 + (index * 50)).ms, curve: Curves.easeOut);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  // Custom Status Icons
  Widget _buildFilledSquare(Color color) {
    return Container(
      width: 14, height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 4)],
      ),
    );
  }

  Widget _buildHollowSquare(Color color) {
    return Container(
      width: 14, height: 14,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildFilledBubble(Color color) {
    return Container(
      width: 14, height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle, 
        boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 4)],
      ),
    );
  }
}
