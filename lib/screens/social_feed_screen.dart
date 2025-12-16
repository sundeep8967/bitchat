import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:ui';

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

  // Mock Data for "Black & Pink" UI Demo
  final List<Map<String, dynamic>> _friends = [
    {'name': 'Alice Wonder', 'status': 'New Snap • 2m ago', 'type': 'new_snap', 'color': _instaPink},
    {'name': 'Bob Mesh', 'status': 'Opened • 1h ago', 'type': 'opened', 'color': _instaPurple},
    {'name': 'Charlie', 'status': 'Received • 5m ago', 'type': 'received', 'color': Colors.blueAccent},
    {'name': 'David Local', 'status': 'Tap to chat', 'type': 'chat', 'color': Colors.grey},
    {'name': 'Eve Router', 'status': 'Added you', 'type': 'added', 'color': Colors.yellow},
    {'name': 'Frank Node', 'status': 'Screenshot • 1d ago', 'type': 'screenshot', 'color': _instaOrange},
    {'name': 'Grace Hopper', 'status': 'New Snap • 5m ago', 'type': 'new_snap', 'color': _instaPink},
    {'name': 'Hank', 'status': 'Pending', 'type': 'pending', 'color': Colors.grey},
  ];

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
                      'Friends',
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
                  child: Text(
                    'RECENT UPDATES',
                    style: TextStyle(
                      color: _instaPink.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),

              // The Friends List
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final friend = _friends[index];
                    return _buildFriendRow(friend, index);
                  },
                  childCount: _friends.length,
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // 2. The Insta Gradient Shutter Button (FAB)
          Positioned(
            bottom: 30, left: 0, right: 0,
            child: Center(
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

  Widget _buildFriendRow(Map<String, dynamic> friend, int index) {
    Widget statusIcon;
    Color statusColor = friend['color'];
    bool isFilled = friend['type'] == 'new_snap' || friend['type'] == 'received';
    
    // Override colors for the theme
    if (friend['type'] == 'new_snap') statusColor = _instaPink;
    if (friend['type'] == 'received') statusColor = _instaPurple;

    if (friend['type'] == 'new_snap') {
      statusIcon = _buildFilledSquare(statusColor);
    } else if (friend['type'] == 'opened') {
      statusIcon = _buildHollowSquare(statusColor);
    } else if (friend['type'] == 'received') {
      statusIcon = _buildFilledBubble(statusColor);
    } else if (friend['type'] == 'screenshot') {
      statusIcon = Icon(LucideIcons.scanLine, size: 18, color: statusColor);
    } else {
      statusIcon = Icon(LucideIcons.messageSquare, size: 18, color: statusColor);
    }

    return Dismissible(
      key: Key(friend['name']),
      background: Container(color: _instaPurple, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), child: const Icon(LucideIcons.messageCircle, color: Colors.white)),
      secondaryBackground: Container(color: _instaPink, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(LucideIcons.trash2, color: Colors.white)),
      child: Material(
        color: Colors.black,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[900],
                        border: Border.all(color: _instaPurple.withOpacity(0.5), width: 2),
                        image: DecorationImage(
                          image: NetworkImage('https://i.pravatar.cc/150?u=${friend['name']}'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    if (friend['type'] == 'new_snap')
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 12, height: 12,
                              decoration: const BoxDecoration(
                                color: _instaPink,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(width: 16),
                
                // Name & Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          statusIcon,
                          const SizedBox(width: 8),
                          Text(
                            friend['status'],
                            style: TextStyle(
                              color: isFilled ? _instaPink : Colors.grey[600],
                              fontSize: 13,
                              fontWeight: isFilled ? FontWeight.bold : FontWeight.normal,
                              shadows: isFilled ? [Shadow(color: _instaPink.withOpacity(0.6), blurRadius: 8)] : [],
                            ),
                          ),
                          if (friend['type'] == 'new_snap') ...[
                            const SizedBox(width: 6),
                             Text('🔥', style: TextStyle(fontSize: 12))
                                 .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Quick Camera Action
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey[800]!)
                  ),
                  child: Icon(LucideIcons.camera, color: _instaPink, size: 20),
                ).animate(target: 1).fadeIn(duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    ).animate().slideX(begin: 0.1, end: 0, duration: (300 + (index * 50)).ms, curve: Curves.easeOut);
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
