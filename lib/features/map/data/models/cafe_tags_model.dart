import 'package:nook/features/map/domain/entities/cafe_tags_entity.dart';

class CafeTagsModel extends CafeTagsEntity {
  const CafeTagsModel({required super.id, required super.name});

  factory CafeTagsModel.fromJson(Map<String, dynamic> json) {
    return CafeTagsModel(
      id: _asString(json['id']),
      name: _asString(json['name']),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  static String _asString(dynamic value) => value?.toString() ?? '';
}
