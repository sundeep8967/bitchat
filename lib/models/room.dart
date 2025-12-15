import 'dart:convert';

class Room {
  final String id;
  final String name;
  final String code;
  final DateTime createdAt;
  final List<String> members;
  final bool isCreator;

  Room({
    required this.id,
    required this.name,
    required this.code,
    required this.createdAt,
    this.members = const [],
    this.isCreator = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'createdAt': createdAt.toIso8601String(),
    'members': members,
    'isCreator': isCreator,
  };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id: json['id'],
    name: json['name'],
    code: json['code'],
    createdAt: DateTime.parse(json['createdAt']),
    members: List<String>.from(json['members'] ?? []),
    isCreator: json['isCreator'] ?? false,
  );

  Room copyWith({
    String? id,
    String? name,
    String? code,
    DateTime? createdAt,
    List<String>? members,
    bool? isCreator,
  }) => Room(
    id: id ?? this.id,
    name: name ?? this.name,
    code: code ?? this.code,
    createdAt: createdAt ?? this.createdAt,
    members: members ?? this.members,
    isCreator: isCreator ?? this.isCreator,
  );
}
