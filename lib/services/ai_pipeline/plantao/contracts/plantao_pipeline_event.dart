import 'plantao_result.dart';

abstract class PlantaoPipelineEvent {
  const PlantaoPipelineEvent({
    required this.requestId,
    required this.sequence,
    required this.occurredAt,
  });

  final String requestId;
  final int sequence;
  final DateTime occurredAt;

  String get type;

  Map<String, Object?> toJson();
}

class PlantaoPipelineStarted extends PlantaoPipelineEvent {
  const PlantaoPipelineStarted({
    required super.requestId,
    required super.sequence,
    required super.occurredAt,
  });

  @override
  String get type => 'started';

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': type,
      'requestId': requestId,
      'sequence': sequence,
      'occurredAt': occurredAt.toIso8601String(),
    };
  }
}

class PlantaoPipelineChunk extends PlantaoPipelineEvent {
  const PlantaoPipelineChunk({
    required super.requestId,
    required super.sequence,
    required super.occurredAt,
    required this.text,
  });

  final String text;

  @override
  String get type => 'chunk';

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': type,
      'requestId': requestId,
      'sequence': sequence,
      'occurredAt': occurredAt.toIso8601String(),
      'text': text,
    };
  }
}

class PlantaoPipelineCompleted extends PlantaoPipelineEvent {
  const PlantaoPipelineCompleted({
    required super.requestId,
    required super.sequence,
    required super.occurredAt,
    required this.result,
  });

  final PlantaoResult result;

  @override
  String get type => 'completed';

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': type,
      'requestId': requestId,
      'sequence': sequence,
      'occurredAt': occurredAt.toIso8601String(),
      'result': result.toJson(),
    };
  }
}

class PlantaoPipelineUnavailable extends PlantaoPipelineEvent {
  const PlantaoPipelineUnavailable({
    required super.requestId,
    required super.sequence,
    required super.occurredAt,
    required this.reasonCode,
    required this.message,
  });

  final String reasonCode;
  final String message;

  @override
  String get type => 'unavailable';

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': type,
      'requestId': requestId,
      'sequence': sequence,
      'occurredAt': occurredAt.toIso8601String(),
      'reasonCode': reasonCode,
      'message': message,
    };
  }
}

class PlantaoPipelineFailed extends PlantaoPipelineEvent {
  const PlantaoPipelineFailed({
    required super.requestId,
    required super.sequence,
    required super.occurredAt,
    required this.errorCode,
    required this.message,
  });

  final String errorCode;
  final String message;

  @override
  String get type => 'failed';

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'type': type,
      'requestId': requestId,
      'sequence': sequence,
      'occurredAt': occurredAt.toIso8601String(),
      'errorCode': errorCode,
      'message': message,
    };
  }
}
