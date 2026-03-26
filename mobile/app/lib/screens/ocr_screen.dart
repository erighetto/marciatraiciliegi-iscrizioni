import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:marcia_mobile/models/acquisition_record.dart';
import 'package:marcia_mobile/models/flow_payload.dart';
import 'package:marcia_mobile/services/ocr_parser_service.dart';
import 'package:marcia_mobile/services/sync_queue_service.dart';

/// Fasi della schermata OCR: acquisizione foto, revisione campi, errore OCR.
enum _OcrPhase { capture, review, error }

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  static const routeName = '/ocr';

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final _nomeController = TextEditingController();
  final _cognomeController = TextEditingController();
  final _dataNascitaController = TextEditingController();
  bool _ocrModified = false;
  String _operatorId = '';

  _OcrPhase _phase = _OcrPhase.capture;
  bool _isLoading = false;
  bool _isManualEntry = false;
  String _errorMessage = '';

  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _nomeController.dispose();
    _cognomeController.dispose();
    _dataNascitaController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as FlowPayload?;
    if (args != null && _operatorId.isEmpty) _operatorId = args.operatorId;
  }

  Future<void> _takePhotoAndRecognize() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 97, // massima qualità per OCR su testo scritto a mano
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null || !mounted) {
        setState(() => _isLoading = false);
        return;
      }

      final inputImage = InputImage.fromFilePath(file.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      if (!mounted) return;
      final rawText = recognizedText.text.trim();

      if (rawText.isEmpty) {
        setState(() {
          _phase = _OcrPhase.error;
          _errorMessage = 'Nessun testo riconosciuto. Riprova con una foto più leggibile.';
          _isLoading = false;
        });
        return;
      }

      final parsed = OcrParserService.parse(rawText);
      final originalNome = parsed.nome;
      final originalCognome = parsed.cognome;
      final originalData = parsed.dataNascita;
      _nomeController.text = originalNome;
      _cognomeController.text = originalCognome;
      _dataNascitaController.text = originalData;
      _ocrModified = false;

      // Rileva automaticamente se l'operatore modifica i campi
      void markModified() => setState(() => _ocrModified = true);
      _nomeController.addListener(() {
        if (_nomeController.text != originalNome) markModified();
      });
      _cognomeController.addListener(() {
        if (_cognomeController.text != originalCognome) markModified();
      });
      _dataNascitaController.addListener(() {
        if (_dataNascitaController.text != originalData) markModified();
      });

      setState(() {
        _phase = _OcrPhase.review;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _OcrPhase.error;
          _errorMessage = 'Errore durante l\'OCR: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _retakePhoto() {
    setState(() {
      _phase = _OcrPhase.capture;
      _isManualEntry = false;
      _errorMessage = '';
      _nomeController.clear();
      _cognomeController.clear();
      _dataNascitaController.clear();
      _ocrModified = false;
    });
  }

  void _manualEntry() {
    setState(() {
      _phase = _OcrPhase.review;
      _isManualEntry = true;
      _errorMessage = '';
      _nomeController.clear();
      _cognomeController.clear();
      _dataNascitaController.clear();
      _ocrModified = false;
    });
  }

  void _save() {
    if (_nomeController.text.trim().isEmpty ||
        _cognomeController.text.trim().isEmpty ||
        _dataNascitaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compila nome, cognome e data di nascita.')),
      );
      return;
    }

    final record = AcquisitionRecord(
      type: RecordType.anagrafica,
      operatorId: _operatorId.isEmpty ? 'operatore' : _operatorId,
      payload: {
        'nome': _nomeController.text.trim(),
        'cognome': _cognomeController.text.trim(),
        'dataNascita': _dataNascitaController.text.trim(),
        'ocrModificato': _ocrModified,
        'metodoInserimento': 'ocr',
      },
      timestampIso: DateTime.now().toIso8601String(),
    );
    SyncQueueService.instance.enqueue(record);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leggi Anagrafica')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Analisi OCR in corso...'),
            ],
          ),
        ),
      );
    }

    if (_phase == _OcrPhase.error) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leggi Anagrafica')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_errorMessage),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _retakePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Ritenta foto'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _manualEntry,
                icon: const Icon(Icons.keyboard),
                label: const Text('Inserimento manuale'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annulla'),
              ),
            ],
          ),
        ),
      );
    }

    if (_phase == _OcrPhase.capture) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leggi Anagrafica')),
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
                      Row(
                        children: [
                          Icon(Icons.tips_and_updates,
                              color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text('Consigli per una buona lettura',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('• Tieni il tagliandino orizzontale e ben illuminato'),
                      const Text('• Avvicinati finché il testo riempie il mirino'),
                      const Text('• Tieni ferma la mano prima di scattare'),
                      const Text('• Evita ombre e riflessi sul foglio'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Icon(Icons.document_scanner,
                  size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _takePhotoAndRecognize,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Scatta foto'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _manualEntry,
                icon: const Icon(Icons.keyboard),
                label: const Text('Inserimento manuale'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annulla'),
              ),
            ],
          ),
        ),
      );
    }

    // _OcrPhase.review
    final bool fromOcr = _phase == _OcrPhase.review && !_isManualEntry;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisione anagrafica'),
        actions: [
          if (fromOcr)
            TextButton(
              onPressed: _retakePhoto,
              child: const Text('Ritenta foto'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_ocrModified)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16,
                      color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 6),
                  Text(
                    'Campo modificato — verrà segnato come corretto manualmente',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
          TextField(
            controller: _nomeController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Nome',
              suffixIcon: _nomeController.text.isEmpty
                  ? const Icon(Icons.warning_amber, color: Colors.orange)
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _cognomeController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Cognome',
              suffixIcon: _cognomeController.text.isEmpty
                  ? const Icon(Icons.warning_amber, color: Colors.orange)
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _dataNascitaController,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Data di nascita',
              hintText: 'GG/MM/AAAA',
              suffixIcon: _dataNascitaController.text.isEmpty
                  ? const Icon(Icons.warning_amber, color: Colors.orange)
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: const Text('Conferma e salva'),
          ),
        ],
      ),
    );
  }
}
