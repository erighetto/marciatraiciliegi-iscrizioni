import 'package:flutter/material.dart';

enum TesseraType { fiasp, umv }

class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({super.key});

  static const routeName = '/barcode';

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  final _manualCodeController = TextEditingController();
  TesseraType? _selectedType;

  @override
  void dispose() {
    _manualCodeController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_manualCodeController.text.trim().isEmpty || _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci codice tessera e seleziona FIASP o UMV.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leggi Tessera')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Fase 3 in corso: scanner barcode reale da integrare. Per ora usiamo inserimento manuale.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _manualCodeController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Codice barcode',
              hintText: 'Es. 802345678901',
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<TesseraType>(
            emptySelectionAllowed: true,
            selected: _selectedType == null ? <TesseraType>{} : {_selectedType!},
            segments: const [
              ButtonSegment<TesseraType>(
                value: TesseraType.fiasp,
                label: Text('FIASP'),
              ),
              ButtonSegment<TesseraType>(
                value: TesseraType.umv,
                label: Text('UMV'),
              ),
            ],
            onSelectionChanged: (selection) {
              setState(() {
                _selectedType = selection.isEmpty ? null : selection.first;
              });
            },
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _confirm,
            child: const Text('Conferma e salva'),
          ),
        ],
      ),
    );
  }
}
