enum RecordType { tessera, anagrafica }

class AcquisitionRecord {
  AcquisitionRecord({
    required this.type,
    required this.operatorId,
    required this.payload,
    required this.timestampIso,
  });

  final RecordType type;
  final String operatorId;
  final Map<String, dynamic> payload;
  final String timestampIso;
}
