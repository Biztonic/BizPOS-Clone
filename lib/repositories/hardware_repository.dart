import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hardware_master.dart';
import '../services/firestore_helper.dart';

/// Repository for hardware master catalog management.
/// Isolates data access and cloud mutations from admin screens.
class HardwareRepository {
  final FirebaseFirestore? _firestore;

  HardwareRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get _db => _firestore ?? getFirestore();

  Future<List<HardwareMaster>> getHardwareMasters() async {
    final snap = await _db.collection('hardware_master').get();
    return snap.docs
        .map((d) => HardwareMaster.fromMap(d.data(), d.id))
        .toList();
  }

  Future<void> addHardware(HardwareMaster hardware) async {
    await _db.collection('hardware_master').add(hardware.toMap());
  }

  Future<void> updateHardware(HardwareMaster hardware) async {
    await _db
        .collection('hardware_master')
        .doc(hardware.id)
        .update(hardware.toMap());
  }

  Future<void> setHardwareActive(String id, bool isActive) async {
    await _db
        .collection('hardware_master')
        .doc(id)
        .update({'isActive': isActive});
  }
}
