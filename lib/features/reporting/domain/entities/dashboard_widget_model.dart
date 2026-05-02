
class DashboardWidgetModel {
  String id;
  String type; // 'stat_card', 'action_btn', 'hero', 'clock_header', 'spacer', 'section_title'
  double widthFactor; // 0.2 to 1.0 (Percentage of container width)
  Map<String, dynamic> data;

  DashboardWidgetModel({
    required this.id,
    required this.type,
    this.widthFactor = 0.25, // Default 1/4 width
    required this.data,
  });

  // Serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'widthFactor': widthFactor,
      'data': data,
    };
  }

  factory DashboardWidgetModel.fromMap(Map<String, dynamic> map) {
    return DashboardWidgetModel(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: map['type'] ?? 'stat_card',
      widthFactor: (map['widthFactor'] as num?)?.toDouble() ?? 0.25,
      data: Map<String, dynamic>.from(map['data'] ?? {}),
    );
  }

  // CopyWith
  DashboardWidgetModel copyWith({
    String? id,
    String? type,
    double? widthFactor,
    Map<String, dynamic>? data,
  }) {
    return DashboardWidgetModel(
      id: id ?? this.id,
      type: type ?? this.type,
      widthFactor: widthFactor ?? this.widthFactor,
      data: data ?? this.data,
    );
  }
}
