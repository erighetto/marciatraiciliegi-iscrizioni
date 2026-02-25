import 'package:flutter/material.dart';
import 'package:marcia_mobile/screens/barcode_screen.dart';
import 'package:marcia_mobile/screens/ocr_screen.dart';
import 'package:marcia_mobile/screens/settings_screen.dart';
import 'package:marcia_mobile/models/flow_payload.dart';
import 'package:marcia_mobile/services/settings_service.dart';
import 'package:marcia_mobile/services/sync_queue_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOnline = true;
  int _sessionRecords = 0;
  String _operatorId = 'Non configurato';
  String _sheetId = 'Non configurato';
  bool _settingsLoaded = false;

  final _settings = SettingsService.instance;
  final _syncQueue = SyncQueueService.instance;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final operatorId = await _settings.getOperatorId();
    final sheetId = await _settings.getSheetId();
    if (mounted) {
      setState(() {
        _operatorId = operatorId.trim().isEmpty ? 'Non configurato' : operatorId.trim();
        _sheetId = sheetId.trim().isEmpty ? 'Non configurato' : sheetId.trim();
        _settingsLoaded = true;
      });
    }
  }

  Future<void> _openFlow(String routeName, {Object? arguments}) async {
    final result = await Navigator.of(context).pushNamed(routeName, arguments: arguments);
    if (result is bool && result) {
      setState(() => _sessionRecords += 1);
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(
      context,
    ).pushNamed(SettingsScreen.routeName, arguments: SettingsPayload(
      operatorId: _operatorId == 'Non configurato' ? '' : _operatorId,
      sheetId: _sheetId == 'Non configurato' ? '' : _sheetId,
    ));

    if (result is SettingsPayload) {
      await _settings.save(
        operatorId: result.operatorId,
        sheetId: result.sheetId,
      );
      if (mounted) {
        setState(() {
          _operatorId = result.operatorId.trim().isEmpty
              ? 'Non configurato'
              : result.operatorId.trim();
          _sheetId = result.sheetId.trim().isEmpty
              ? 'Non configurato'
              : result.sheetId.trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _syncQueue.pendingCount;
    final statusLabel = _isOnline
        ? (pendingCount == 0
              ? 'Online - tutto sincronizzato'
              : 'Online - $pendingCount record in coda')
        : 'Offline - $pendingCount record in coda';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acquisizione Dati'),
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Impostazioni',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Modalita offline'),
                        const Spacer(),
                        Switch(
                          value: !_isOnline,
                          onChanged: (value) {
                            setState(() {
                              _isOnline = !value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Operatore: $_operatorId'),
                    const SizedBox(height: 4),
                    Text('Foglio Google: $_sheetId'),
                    const SizedBox(height: 4),
                    Text('Record sessione: $_sessionRecords'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => _openFlow(
                BarcodeScreen.routeName,
                arguments: FlowPayload(operatorId: _operatorId == 'Non configurato' ? '' : _operatorId),
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Leggi Tessera'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _openFlow(
                OcrScreen.routeName,
                arguments: FlowPayload(operatorId: _operatorId == 'Non configurato' ? '' : _operatorId),
              ),
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Leggi Anagrafica'),
            ),
            if (!_settingsLoaded)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              const SizedBox(height: 12),
            const Text(
              'Impostazioni salvate in locale. Scanner/OCR reali e sync Sheets da integrare (Fasi 3–5).',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
