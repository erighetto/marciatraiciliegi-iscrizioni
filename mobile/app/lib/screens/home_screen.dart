import 'package:flutter/material.dart';
import 'package:marcia_mobile/screens/barcode_screen.dart';
import 'package:marcia_mobile/screens/ocr_screen.dart';
import 'package:marcia_mobile/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOnline = true;
  int _pendingSyncCount = 0;
  int _sessionRecords = 0;
  String _operatorId = 'Non configurato';
  String _sheetId = 'Non configurato';

  Future<void> _openFlow(String routeName) async {
    final result = await Navigator.of(context).pushNamed(routeName);
    if (result is bool && result) {
      setState(() {
        _sessionRecords += 1;
        if (!_isOnline) {
          _pendingSyncCount += 1;
        }
      });
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

  @override
  Widget build(BuildContext context) {
    final statusLabel = _isOnline
        ? (_pendingSyncCount == 0
              ? 'Online - tutto sincronizzato'
              : 'Online - $_pendingSyncCount record in coda')
        : 'Offline - $_pendingSyncCount record in coda';

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
              onPressed: () => _openFlow(BarcodeScreen.routeName),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Leggi Tessera'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _openFlow(OcrScreen.routeName),
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Leggi Anagrafica'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Bootstrap completato: home, navigazione e primi due flussi sono pronti per integrare scanner/OCR reali.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
