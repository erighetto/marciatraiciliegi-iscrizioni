import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:marcia_mobile/models/acquisition_record.dart';
import 'package:marcia_mobile/services/auth_service.dart';
import 'package:marcia_mobile/services/settings_service.dart';

class SheetsService {
  SheetsService._();
  static final SheetsService instance = SheetsService._();

  Future<SheetsApi?> _api() async {
    final client = await AuthService.instance.getAuthClient();
    if (client == null) {
      debugPrint('[SheetsService] _api: client nullo (non autenticato?)');
      return null;
    }
    return SheetsApi(client);
  }

  /// Aggiunge una riga al foglio Tessere (range BC).
  Future<bool> appendTessera(AcquisitionRecord record) async {
    final api = await _api();
    if (api == null) return false;
    final sheetId = await SettingsService.instance.getSheetId();
    final range = SettingsService.instance.sheetRangeBC;
    debugPrint('[SheetsService] appendTessera → sheetId=$sheetId range=$range');
    final row = [
      record.timestampIso,
      record.operatorId,
      record.payload['codiceBarcode']?.toString() ?? '',
      record.payload['tipoTessera']?.toString() ?? '',
      record.payload['metodoInserimento']?.toString() ?? '',
    ];
    try {
      await api.spreadsheets.values.append(
        ValueRange(values: [row]),
        sheetId,
        range,
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
      );
      debugPrint('[SheetsService] appendTessera: OK');
      return true;
    } catch (e) {
      debugPrint('[SheetsService] appendTessera error: $e');
      return false;
    }
  }

  /// Aggiunge una riga al foglio Anagrafiche (range OCR).
  Future<bool> appendAnagrafica(AcquisitionRecord record) async {
    final api = await _api();
    if (api == null) return false;
    final sheetId = await SettingsService.instance.getSheetId();
    final range = SettingsService.instance.sheetRangeOCR;
    debugPrint('[SheetsService] appendAnagrafica → sheetId=$sheetId range=$range');
    final row = [
      record.timestampIso,
      record.operatorId,
      record.payload['nome']?.toString() ?? '',
      record.payload['cognome']?.toString() ?? '',
      record.payload['dataNascita']?.toString() ?? '',
      record.payload['ocrModificato']?.toString() ?? 'false',
      record.payload['metodoInserimento']?.toString() ?? '',
    ];
    try {
      await api.spreadsheets.values.append(
        ValueRange(values: [row]),
        sheetId,
        range,
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
      );
      debugPrint('[SheetsService] appendAnagrafica: OK');
      return true;
    } catch (e) {
      debugPrint('[SheetsService] appendAnagrafica error: $e');
      return false;
    }
  }

  /// Tenta di inviare tutti i record in coda; rimuove quelli inviati con successo.
  Future<int> flushQueue(List<AcquisitionRecord> queue) async {
    int sent = 0;
    for (int i = queue.length - 1; i >= 0; i--) {
      final record = queue[i];
      final ok = record.type == RecordType.tessera
          ? await appendTessera(record)
          : await appendAnagrafica(record);
      if (ok) {
        queue.removeAt(i);
        sent++;
      }
    }
    return sent;
  }
}
