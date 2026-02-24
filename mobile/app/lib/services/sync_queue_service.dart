import 'package:marcia_mobile/models/acquisition_record.dart';

class SyncQueueService {
  final List<AcquisitionRecord> _queue = <AcquisitionRecord>[];

  int get pendingCount => _queue.length;

  void enqueue(AcquisitionRecord record) {
    _queue.add(record);
  }

  List<AcquisitionRecord> snapshot() {
    return List<AcquisitionRecord>.unmodifiable(_queue);
  }
}
