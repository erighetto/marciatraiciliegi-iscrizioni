import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:marcia_mobile/models/acquisition_record.dart';
import 'package:marcia_mobile/models/flow_payload.dart';
import 'package:marcia_mobile/services/sync_queue_service.dart';

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
  String _operatorId = '';

  /// Codice letto dallo scanner (null = ancora in scansione o in manuale).
  String? _detectedCode;
  /// true = l'operatore ha scelto inserimento manuale.
  bool _manualMode = false;
  /// Metodo usato per questo record: 'barcode' se letto da camera, 'manual' altrimenti.
  String _metodoInserimento = 'barcode';

  late MobileScannerController _scannerController;
  bool _torchOn = false;
  CameraFacing _facing = CameraFacing.back;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  void _initScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: _facing,
      torchEnabled: _torchOn,
      formats: const [
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.codabar,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.itf,
        BarcodeFormat.qrCode,
      ],
    );
  }

  Future<void> _toggleTorch() async {
    await _scannerController.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  Future<void> _switchCamera() async {
    await _scannerController.dispose();
    setState(() {
      _facing = _facing == CameraFacing.back ? CameraFacing.front : CameraFacing.back;
      _detectedCode = null;
      _initScanner();
    });
  }

  @override
  void dispose() {
    _manualCodeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as FlowPayload?;
    if (args != null && _operatorId.isEmpty) _operatorId = args.operatorId;
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_detectedCode != null || _manualMode) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty) return;

    _scannerController.stop();
    HapticFeedback.mediumImpact();
    if (mounted) {
      setState(() {
        _detectedCode = code;
        _metodoInserimento = 'barcode';
      });
    }
  }

  void _switchToManual() {
    _scannerController.stop();
    setState(() {
      _manualMode = true;
      _detectedCode = null;
      _metodoInserimento = 'manual';
    });
  }

  void _backToScanner() {
    setState(() {
      _manualMode = false;
      _detectedCode = null;
      _manualCodeController.clear();
      _selectedType = null;
    });
    _scannerController.start();
  }

  void _confirm() {
    final String code = _manualMode
        ? (_manualCodeController.text as String).trim()
        : (_detectedCode ?? '').trim();
    if (code.isEmpty || _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci codice tessera e seleziona FIASP o UMV.'),
        ),
      );
      return;
    }

    final typeLabel = _selectedType == TesseraType.fiasp ? 'FIASP' : 'UMV';
    final record = AcquisitionRecord(
      type: RecordType.tessera,
      operatorId: _operatorId.isEmpty ? 'operatore' : _operatorId,
      payload: {
        'codiceBarcode': code,
        'tipoTessera': typeLabel,
        'metodoInserimento': _metodoInserimento,
      },
      timestampIso: DateTime.now().toIso8601String(),
    );
    SyncQueueService.instance.enqueue(record);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final inReview = _detectedCode != null || _manualMode;
    final String code = _detectedCode ?? (_manualCodeController.text as String);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leggi Tessera'),
        actions: [
          if (!inReview) ...[
            IconButton(
              onPressed: _toggleTorch,
              icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
              tooltip: 'Torcia',
            ),
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(Icons.flip_camera_android),
              tooltip: 'Cambia camera',
            ),
          ],
          if (inReview)
            TextButton(
              onPressed: _manualMode ? _backToScanner : _switchToManual,
              child: Text(_manualMode ? 'Scansiona' : 'Inserimento manuale'),
            ),
        ],
      ),
      body: inReview
          ? _buildReviewContent(code)
          : _buildScannerContent(),
    );
  }

  Widget _buildScannerContent() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _onBarcodeDetected,
                ),
              ),
              // Mirino: rettangolo orizzontale per barcode lineari
              IgnorePointer(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _BarcodeScanOverlayPainter(),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Centra il barcode nel rettangolo',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Tieni la tessera ferma e ben illuminata',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _switchToManual,
                icon: const Icon(Icons.keyboard),
                label: const Text('Inserimento manuale'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewContent(String code) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_detectedCode != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Codice letto', style: Theme.of(context).textTheme.labelMedium),
                        Text(code, style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_manualMode) ...[
          TextField(
            controller: _manualCodeController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Codice barcode',
              hintText: 'Es. 802345678901',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 14),
        SegmentedButton<TesseraType>(
          emptySelectionAllowed: true,
          selected: _selectedType == null ? <TesseraType>{} : {_selectedType!},
          segments: const [
            ButtonSegment<TesseraType>(value: TesseraType.fiasp, label: Text('FIASP')),
            ButtonSegment<TesseraType>(value: TesseraType.umv, label: Text('UMV')),
          ],
          onSelectionChanged: (selection) {
            setState(() {
              _selectedType = selection.isEmpty ? null : selection.first;
            });
          },
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _confirm,
          child: const Text('Conferma e salva'),
        ),
      ],
    );
  }
}

/// Disegna un rettangolo orizzontale semi-trasparente come guida per i barcode lineari.
class _BarcodeScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double rectW = size.width * 0.85;
    final double rectH = size.height * 0.18;
    final Rect scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: rectW,
      height: rectH,
    );

    // Oscura tutto tranne il rettangolo di scansione
    final Paint dimPaint = Paint()..color = Colors.black54;
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(8))),
      ),
      dimPaint,
    );

    // Bordo verde del mirino
    final Paint borderPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(8)),
      borderPaint,
    );

    // Linea rossa centrale orizzontale
    final Paint linePaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(scanRect.left + 8, scanRect.center.dy),
      Offset(scanRect.right - 8, scanRect.center.dy),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
