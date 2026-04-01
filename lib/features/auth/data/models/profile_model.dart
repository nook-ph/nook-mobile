import 'package:nook/features/auth/domain/entities/profile_entites.dart';

class ProfileModel extends ProfileEntity {
  ProfileModel({
    required super.id,
    required super.fullName,
    required super.username,
    required super.createdAt,
    super.avatarUrl,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'];

    return ProfileModel(
      id: (json['id'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      createdAt: createdAtRaw is String
          ? (DateTime.tryParse(createdAtRaw) ??
                DateTime.fromMillisecondsSinceEpoch(0))
          : DateTime.fromMillisecondsSinceEpoch(0),
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
