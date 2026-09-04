import '../contracts/plantao_persistence_record.dart';

enum PlantaoPersistenceWriteDisposition { accepted, rejected, unavailable }

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

abstract interface class PlantaoPersistencePort {
  Future<PlantaoPersistenceWriteReceipt> write(PlantaoPersistenceRecord record);
}
