class TableModel {
  final String id;
  final String storeId;
  final String floorId;
  final String name;
  final List<TableSeat> seats;
  final String shape; // 'square', 'circle', 'rectangular'
  final TablePosition position;
  final double rotation;
  final String status; // 'Available', 'Occupied', 'Reserved'
  final String? orderId;
  final String billingMode; // 'per-seat', 'per-table'
  final DateTime? bookedTime; // Added for advanced reservation
  final int? bookedSeats; // Added to track specific seat booking counts

  TableModel({
    required this.id,
    required this.storeId,
    required this.floorId,
    required this.name,
    required this.seats,
    required this.shape,
    required this.position,
    required this.rotation,
    required this.status,
    this.orderId,
    required this.billingMode,
    this.bookedTime,
    this.bookedSeats,
  });

  factory TableModel.fromMap(Map<String, dynamic> data, String id) {
    return TableModel(
      id: id,
      storeId: data['storeId'] ?? '',
      floorId: data['floorId'] ?? '',
      name: data['name'] ?? '',
      seats: (data['seats'] is int)
          ? List.generate(data['seats'] as int, (i) => TableSeat(number: i + 1))
          : (data['seats'] as List<dynamic>?)
              ?.map((s) => TableSeat.fromMap(s))
              .toList() ??
          [],
      shape: data['shape'] ?? 'square',
      position: TablePosition.fromMap(data['position'] ?? {}),
      rotation: (data['rotation'] ?? 0).toDouble(),
      status: data['status'] ?? 'Available',
      orderId: data['orderId'],
      billingMode: data['billingMode'] ?? 'per-table',
      bookedTime: data['bookedTime'] != null ? DateTime.tryParse(data['bookedTime']) : null,
      bookedSeats: data['bookedSeats'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'floorId': floorId,
      'name': name,
      'seats': seats.map((s) => s.toMap()).toList(),
      'shape': shape,
      'position': position.toMap(),
      'rotation': rotation,
      'status': status,
      'orderId': orderId,
      'billingMode': billingMode,
      'bookedTime': bookedTime?.toIso8601String(),
      'bookedSeats': bookedSeats,
    };
  }

  TableModel copyWith({
    String? id,
    String? storeId,
    String? floorId,
    String? name,
    List<TableSeat>? seats,
    String? shape,
    TablePosition? position,
    double? rotation,
    String? status,
    String? orderId,
    String? billingMode,
    DateTime? bookedTime,
    int? bookedSeats,
  }) {
    return TableModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      floorId: floorId ?? this.floorId,
      name: name ?? this.name,
      seats: seats ?? this.seats,
      shape: shape ?? this.shape,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      status: status ?? this.status,
      orderId: orderId ?? this.orderId,
      billingMode: billingMode ?? this.billingMode,
      bookedTime: bookedTime ?? this.bookedTime,
      bookedSeats: bookedSeats ?? this.bookedSeats,
    );
  }

  // --- Computed Properties (Business Logic) ---
  bool get isAvailable => status == 'Available';
  bool get isOccupied => status == 'Occupied';
  bool get isBooked => status == 'Booked';

  /// Returns true if there is a booking within the next 30 minutes
  bool get isImpendingReservation {
    if (bookedTime == null) return false;
    final now = DateTime.now();
    final diff = bookedTime!.difference(now);
    return diff.inMinutes > 0 && diff.inMinutes <= 30;
  }

  double get occupancyPercentage {
    if (seats.isEmpty) return isOccupied ? 1.0 : 0.0;
    final occupiedCount = seats.where((s) => s.isOccupied).length;
    return occupiedCount / seats.length;
  }

  String get displayStatus {
    if (isImpendingReservation) return 'Arriving Soon';
    return status;
  }
}

class TableSeat {
  final int number;
  final String? orderId;

  TableSeat({required this.number, this.orderId});

  bool get isOccupied => orderId != null;

  factory TableSeat.fromMap(Map<String, dynamic> data) {
    return TableSeat(
      number: data['number'] ?? 0,
      orderId: data['orderId'],
    );
  }

  Map<String, dynamic> toMap() => {
    'number': number,
    'orderId': orderId,
  };
}

class TablePosition {
  final double x;
  final double y;

  TablePosition({required this.x, required this.y});

  factory TablePosition.fromMap(Map<String, dynamic> data) {
    return TablePosition(
      x: (data['x'] ?? 0).toDouble(),
      y: (data['y'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {'x': x, 'y': y};
}
