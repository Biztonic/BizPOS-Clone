import 'package:cloud_firestore/cloud_firestore.dart';

class HardwareMaster {
  final String id;
  final String name;
  final String description;
  final double basePrice;
  final double downPayment;
  final double emiAmount;
  final String emiType; // 'weekly', 'monthly'
  final int totalEmiCount;
  final double buybackDepreciationPerDay;
  final int gracePeriodDays;
  final String serialPrefix;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  HardwareMaster({
    required this.id,
    required this.name,
    this.description = '',
    required this.basePrice,
    required this.downPayment,
    required this.emiAmount,
    this.emiType = 'monthly',
    required this.totalEmiCount,
    required this.buybackDepreciationPerDay,
    this.gracePeriodDays = 2,
    required this.serialPrefix,
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HardwareMaster.fromMap(Map<String, dynamic> data, String id) {
    return HardwareMaster(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      basePrice: (data['basePrice'] ?? 0).toDouble(),
      downPayment: (data['downPayment'] ?? 0).toDouble(),
      emiAmount: (data['emiAmount'] ?? 0).toDouble(),
      emiType: data['emiType'] ?? 'monthly',
      totalEmiCount: data['totalEmiCount'] ?? 0,
      buybackDepreciationPerDay: (data['buybackDepreciationPerDay'] ?? 0).toDouble(),
      gracePeriodDays: data['gracePeriodDays'] ?? 2,
      serialPrefix: data['serialPrefix'] ?? '',
      imageUrl: data['imageUrl'],
      isActive: data['isActive'] ?? true,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'basePrice': basePrice,
      'downPayment': downPayment,
      'emiAmount': emiAmount,
      'emiType': emiType,
      'totalEmiCount': totalEmiCount,
      'buybackDepreciationPerDay': buybackDepreciationPerDay,
      'gracePeriodDays': gracePeriodDays,
      'serialPrefix': serialPrefix,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    try {
      return (value as dynamic).toDate();
    } catch (_) {
      return DateTime.now();
    }
  }

  HardwareMaster copyWith({
    String? id,
    String? name,
    String? description,
    double? basePrice,
    double? downPayment,
    double? emiAmount,
    String? emiType,
    int? totalEmiCount,
    double? buybackDepreciationPerDay,
    int? gracePeriodDays,
    String? serialPrefix,
    String? imageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HardwareMaster(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      basePrice: basePrice ?? this.basePrice,
      downPayment: downPayment ?? this.downPayment,
      emiAmount: emiAmount ?? this.emiAmount,
      emiType: emiType ?? this.emiType,
      totalEmiCount: totalEmiCount ?? this.totalEmiCount,
      buybackDepreciationPerDay: buybackDepreciationPerDay ?? this.buybackDepreciationPerDay,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      serialPrefix: serialPrefix ?? this.serialPrefix,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
