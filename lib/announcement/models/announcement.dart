import 'package:uuid/uuid.dart';
import 'announcement_priority.dart';
import 'announcement_channel.dart';
import 'announcement_type.dart';

class Announcement {
  final String id;
  final AnnouncementType type;
  final AnnouncementPriority priority;
  final AnnouncementChannel channel;
  final String text;
  final String? soundAsset;
  final String? ttsText;
  final bool interruptible;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  Announcement({
    String? id,
    required this.type,
    required this.priority,
    required this.channel,
    required this.text,
    this.soundAsset,
    this.ttsText,
    this.interruptible = true,
    DateTime? timestamp,
    this.metadata = const {},
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Announcement copyWith({
    String? id,
    AnnouncementType? type,
    AnnouncementPriority? priority,
    AnnouncementChannel? channel,
    String? text,
    String? soundAsset,
    String? ttsText,
    bool? interruptible,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return Announcement(
      id: id ?? this.id,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      channel: channel ?? this.channel,
      text: text ?? this.text,
      soundAsset: soundAsset ?? this.soundAsset,
      ttsText: ttsText ?? this.ttsText,
      interruptible: interruptible ?? this.interruptible,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
}
