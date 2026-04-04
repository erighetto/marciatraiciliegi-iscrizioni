/// Risultato del parsing OCR per anagrafica (nome, cognome, data di nascita).
class OcrAnagraficaResult {
  const OcrAnagraficaResult({
    this.nome = '',
    this.cognome = '',
    this.dataNascita = '',
  });

  final String nome;
  final String cognome;
  final String dataNascita;

  bool get hasAny => nome.isNotEmpty || cognome.isNotEmpty || dataNascita.isNotEmpty;
}

/// Parsing euristico del testo OCR per estrarre nome, cognome e data di nascita.
///
/// Flusso:
///   1. Pre-processing: corregge errori OCR comuni (| → /, n6/ → 16/, ecc.)
///   2. Strategia keyword: cerca "cognome", "nome", "nascita" nel testo e
///      estrae il valore immediatamente dopo (solo prima riga — evita cattura
///      di righe successive quando alcune keyword mancano).
///   3. Fallback line: se nome/cognome non trovati via keyword, usa le righe
///      del testo (riga 1 = nome, riga 2 = cognome).
///   4. Fallback word: se il testo è su una riga sola (tutto unito), rimuove
///      la data e divide per spazio (primo token = nome, resto = cognome).
class OcrParserService {
  static final _datePattern = RegExp(
    r'\b(\d{1,2})[/\-\.](\d{1,2})[/\-\.](\d{2,4})\b',
  );

  // "cognome" DEVE precedere "nome" nell'alternazione: evita che "nome"
  // faccia match all'interno di "cog-nome".
  static final _keywordPattern = RegExp(
    r'(cognome|nome|data\s+di\s+nascita|nascita|nato\s+il|nata\s+il)',
    caseSensitive: false,
  );

  static OcrAnagraficaResult parse(String rawText) {
    if (rawText.trim().isEmpty) return const OcrAnagraficaResult();

    final text = _preprocess(rawText);

    String nome = '';
    String cognome = '';
    String dataNascita = '';

    // ── STRATEGIA 1: keyword-based ────────────────────────────────────────
    final kwMatches = _keywordPattern.allMatches(text).toList();

    for (int i = 0; i < kwMatches.length; i++) {
      final kw = kwMatches[i]
          .group(0)!
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final chunkStart = kwMatches[i].end;
      final chunkEnd =
          (i + 1 < kwMatches.length) ? kwMatches[i + 1].start : text.length;
      final chunk = text.substring(chunkStart, chunkEnd);

      // Prende solo la prima riga non-vuota del chunk:
      // se una keyword non è stata riconosciuta dall'OCR il chunk
      // arriverebbe fino alla fine del testo — fermandosi alla prima riga
      // evitiamo di catturare righe extra.
      final value = _firstLineValue(chunk);

      if (kw == 'cognome') {
        if (cognome.isEmpty && value.isNotEmpty) cognome = value;
      } else if (kw == 'nome') {
        if (nome.isEmpty && value.isNotEmpty) nome = value;
      } else {
        // data di nascita / nascita / nato il / nata il
        final dateMatch =
            _datePattern.firstMatch(value.isEmpty ? chunk : value);
        if (dateMatch != null && dataNascita.isEmpty) {
          dataNascita = _normalizeDate(dateMatch);
        }
      }
    }

    // ── Fallback data: cerca ovunque nel testo ────────────────────────────
    if (dataNascita.isEmpty) {
      final dateMatch = _datePattern.firstMatch(text);
      if (dateMatch != null) dataNascita = _normalizeDate(dateMatch);
    }

    // ── STRATEGIA 2: fallback quando nome/cognome non trovati ─────────────
    if (nome.isEmpty && cognome.isEmpty) {
      // Rimuovi date e keyword dal testo, poi analizza le righe rimaste
      final stripped = text
          .replaceAll(_datePattern, '')
          .replaceAll(_keywordPattern, '')
          .replaceAll(RegExp(r'[:\.\s]{2,}'), ' ')
          .trim();

      final lines = stripped
          .split(RegExp(r'[\n\r]+'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && l.length > 1)
          .toList();

      if (lines.length >= 2) {
        // Riga 1 = nome, riga 2 = cognome (struttura attesa del modulo)
        nome = lines[0];
        cognome = lines[1];
      } else if (lines.length == 1) {
        // Tutto su una riga: primo token = nome, resto = cognome
        final words = lines[0].split(RegExp(r'\s+'));
        if (words.length >= 2) {
          nome = words.first;
          cognome = words.sublist(1).join(' ');
        } else {
          nome = lines[0];
        }
      }
    }

    return OcrAnagraficaResult(
      nome: nome,
      cognome: cognome,
      dataNascita: dataNascita,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Pre-elabora il testo OCR correggendo errori comuni:
  ///   | → /    (pipe scambiato per slash)
  ///   n6/      → 16/   (1 scambiato per n prima di cifra in data)
  ///   l6/      → 16/   (1 scambiato per l prima di cifra in data)
  static String _preprocess(String text) {
    return text
        .replaceAll('|', '/')
        .replaceAllMapped(
          RegExp(r'\b[nl](\d)([/\-\.])'),
          (m) => '1${m.group(1)!}${m.group(2)!}',
        );
  }

  /// Estrae il valore dopo la keyword: rimuove ":" e puntini iniziali,
  /// poi restituisce solo la prima riga non-vuota.
  static String _firstLineValue(String chunk) {
    final cleaned = chunk
        .replaceFirst(RegExp(r'^[\s:\.]+'), '')
        .replaceAll(RegExp(r'\.{2,}'), '')
        .trim();

    for (final line in cleaned.split(RegExp(r'[\n\r]+'))) {
      final l = line.trim();
      if (l.isNotEmpty) return l;
    }
    return cleaned;
  }

  /// Normalizza la data al formato GG/MM/AAAA.
  /// Anno a 2 cifre: >30 → 1900s, ≤30 → 2000s (es. 72 → 1972, 05 → 2005).
  static String _normalizeDate(RegExpMatch match) {
    final day = match.group(1)!.padLeft(2, '0');
    final month = match.group(2)!.padLeft(2, '0');
    var year = match.group(3)!;
    if (year.length == 2) {
      final y = int.parse(year);
      year = y > 30 ? '19$year' : '20$year';
    }
    return '$day/$month/$year';
  }
}
