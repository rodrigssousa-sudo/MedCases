import '../contracts/plantao_persistence_record.dart';

enum PlantaoPersistenceWriteDisposition {
  accepted,
  rejected,
  unavailable,
}

class PlantaoPersistenceWriteReceipt {
  const PlantaoPersistenceWriteReceipt({
    required this.recordId,
    required this.disposition,
    required this.reason,
  });

  final String recordId;
  final PlantaoPersistenceWriteDisposition disposition;
  final String reason;
}

abstract final class PlantaoPersistencePlan {
  static const bool productiveConnectionEnabled = false;
  static const bool firestoreConnected = false;
  static const bool productiveHistoryConnected = false;
  static const String shadowNamespace = 'plantao_shadow_unconnected';
}

abstract interface class PlantaoPersistencePort {
  Future<PlantaoPersistenceWriteReceipt> write(
    PlantaoPersistenceRecord record,
  );
}
