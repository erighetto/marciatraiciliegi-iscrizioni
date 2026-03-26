import 'package:marcia_mobile/models/acquisition_record.dart';

/// Coda condivisa per record in attesa di sync (Sheets o SQLite in seguito).
class SyncQueueService {
  SyncQueueService._();
  static final SyncQueueService instance = SyncQueueService._();

  final List<AcquisitionRecord> _queue = <AcquisitionRecord>[];

  int get pendingCount => _queue.length;

  void enqueue(AcquisitionRecord record) {
    _queue.add(record);
  }

  List<AcquisitionRecord> snapshot() {
    return List<AcquisitionRecord>.unmodifiable(_queue);
  }

  /// Espone la lista interna per il flush diretto da SheetsService.
  List<AcquisitionRecord> get mutableQueue => _queue;

  void removeAt(int index) {
    if (index >= 0 && index < _queue.length) _queue.removeAt(index);
  }

  void clear() {
    _queue.clear();
  }
}
