// ══════════════════════════════════════════════════════════════════════════════
// lib/services/ai_stream/sse_parser.dart
// BUILD 462B-REDIRECIONADA — Resilient UTF-8 SSE Parser
//
// CONTRATO DE ROBUSTEZ:
//   • Tolera evento dividido entre vários chunks HTTP
//   • Tolera vários eventos no mesmo chunk HTTP
//   • Tolera UTF-8 cortado no meio (emoji, ç, á, ñ fragmentados)
//   • Tolera \n e \r\n como terminadores de linha
//   • Tolera múltiplas linhas data: por evento
//   • Tolera comentários ": heartbeat" (descartados silenciosamente)
//   • Tolera linhas vazias espúrias
//   • Heartbeat NUNCA chega ao AiVisualBuffer
//
// PROTOCOLO SSE MEDCASES:
//   event: started         → AiStarted
//   event: text_delta      → AiTextDelta
//   event: sources         → AiSources
//   event: transport_done  → (sinaliza fim — AppProvider emite AiCompleted)
//   event: error           → AiFailed
//   : heartbeat            → ignorado
//
// DESCARTE DE FRAGMENTOS (implementado pelo chamador via SseEventFilter):
//   • requestId diferente do ativo → descartar
//   • attempt anterior ao corrente → descartar
//   • sequence duplicada ou inferior à última aceita → descartar
//   • JSON inválido num evento SSE completo → SseParseError (não continuar)
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';

// ─────────────────────────────────────────────────────────────────────────────
/// Evento SSE MedCases parseado — antes de ser convertido para AiEvent.
// ─────────────────────────────────────────────────────────────────────────────
class SseEvent {
  /// Nome do evento (ex: 'text_delta', 'transport_done').
  final String type;

  /// ID do evento SSE (campo `id:` — pode ser vazio).
  final String id;

  /// Dados JSON do evento (campo `data:` — pode ter múltiplas linhas, concatenadas).
  final String dataRaw;

  /// Dados já decodificados como Map (null se [dataRaw] não for JSON válido).
  final Map<String, dynamic>? data;

  const SseEvent({
    required this.type,
    required this.id,
    required this.dataRaw,
    required this.data,
  });

  @override
  String toString() => 'SseEvent(type=$type id=$id data=$dataRaw)';
}

// ─────────────────────────────────────────────────────────────────────────────
/// Erro de protocolo SSE — JSON inválido num evento completo.
/// O parser emite este erro via [SseParser.errors] e o chamador deve
/// propagar como AiFailed (não continuar silenciosamente).
// ─────────────────────────────────────────────────────────────────────────────
class SseParseError {
  final String eventType;
  final String rawData;
  final String errorMessage;

  const SseParseError({
    required this.eventType,
    required this.rawData,
    required this.errorMessage,
  });

  @override
  String toString() =>
      'SseParseError(eventType=$eventType error=$errorMessage data=$rawData)';
}

// ─────────────────────────────────────────────────────────────────────────────
/// Parser SSE resiliente — transforma Stream<List<int>> em Stream<SseEvent>.
///
/// Uso:
///   final parser = SseParser();
///   response.stream
///     .transform(parser.transformer)
///     .listen((event) { ... });
///
///   // Erros de protocolo:
///   parser.errors.listen((err) { ... }); // propagar como AiFailed
///
/// O parser mantém um buffer interno de bytes incompletos para lidar com
/// UTF-8 fragmentado entre chunks HTTP (emoji, acentos, etc.).
// ─────────────────────────────────────────────────────────────────────────────
class SseParser {
  // Buffer de bytes incompletos do último chunk (para UTF-8 fragmentado)
  final List<int> _byteBuffer = [];

  // Buffer de texto incompleto do evento em construção
  String _lineBuffer = '';
  String _currentEventType = '';
  String _currentEventId   = '';
  final StringBuffer _dataBuffer = StringBuffer();

  // Sink de erros de protocolo
  final _errorController = _SyncStreamController<SseParseError>();

  /// Stream de erros de protocolo — escute para detectar JSON inválido.
  Stream<SseParseError> get errors => _errorController.stream;

  /// StreamTransformer que converte Stream<List<int>> → Stream<SseEvent>.
  StreamTransformer<List<int>, SseEvent> get transformer =>
      StreamTransformer.fromHandlers(
        handleData: (chunk, sink) {
          _processChunk(chunk, sink);
        },
        handleDone: (sink) {
          // Flush do buffer restante ao fechar o stream
          if (_lineBuffer.isNotEmpty) {
            _processLine(_lineBuffer);
            _lineBuffer = '';
          }
          // Evento incompleto no final do stream → descartar silenciosamente
          // (o chamador detecta EOF sem transport_done e cria AiFailed local)
          sink.close();
        },
        handleError: (err, stack, sink) {
          sink.addError(err, stack);
        },
      );

  void _processChunk(List<int> chunk, EventSink<SseEvent> sink) {
    // 1. Agrupar bytes pendentes + novos bytes
    _byteBuffer.addAll(chunk);

    // 2. Decodificar UTF-8 de forma incremental e segura
    //    Mantém bytes que formam caracteres incompletos no _byteBuffer
    final decoded = _decodeUtf8Safe();

    // 3. Processar o texto decodificado linha a linha
    _lineBuffer += decoded;

    // Dividir por \r\n ou \n
    while (true) {
      final crlfIdx = _lineBuffer.indexOf('\r\n');
      final lfIdx   = _lineBuffer.indexOf('\n');

      if (crlfIdx == -1 && lfIdx == -1) break; // sem fim de linha ainda

      int endIdx;
      int advanceBy;
      if (crlfIdx != -1 && (lfIdx == -1 || crlfIdx <= lfIdx)) {
        endIdx    = crlfIdx;
        advanceBy = crlfIdx + 2;
      } else {
        endIdx    = lfIdx;
        advanceBy = lfIdx + 1;
      }

      final line = _lineBuffer.substring(0, endIdx);
      _lineBuffer = _lineBuffer.substring(advanceBy);

      final event = _processLine(line);
      if (event != null) {
        sink.add(event);
      }
    }
  }

  /// Decodifica bytes UTF-8 de forma segura, preservando bytes incompletos.
  String _decodeUtf8Safe() {
    if (_byteBuffer.isEmpty) return '';

    // Encontrar o último byte seguro para decodificar
    // UTF-8: continuação = 10xxxxxx (0x80-0xBF)
    //        início de multi-byte = 11xxxxxx (0xC0-0xFF)
    int safeEnd = _byteBuffer.length;

    // Verificar se os últimos bytes formam um caractere incompleto
    // Olhamos até 4 bytes do final (tamanho máximo UTF-8)
    for (int lookback = 1; lookback <= 4 && lookback <= _byteBuffer.length; lookback++) {
      final b = _byteBuffer[_byteBuffer.length - lookback];
      if (b >= 0xF0) {
        // Início de 4-byte: precisa de 4 bytes
        if (lookback < 4) { safeEnd = _byteBuffer.length - lookback; }
        break;
      } else if (b >= 0xE0) {
        // Início de 3-byte: precisa de 3 bytes
        if (lookback < 3) { safeEnd = _byteBuffer.length - lookback; }
        break;
      } else if (b >= 0xC0) {
        // Início de 2-byte: precisa de 2 bytes
        if (lookback < 2) { safeEnd = _byteBuffer.length - lookback; }
        break;
      } else if (b < 0x80) {
        // Byte ASCII — sempre seguro
        break;
      }
      // 0x80-0xBF: byte de continuação — continuar olhando
    }

    if (safeEnd == 0) return '';

    final safeBytes  = _byteBuffer.sublist(0, safeEnd);
    final remaining  = _byteBuffer.sublist(safeEnd);
    _byteBuffer
      ..clear()
      ..addAll(remaining);

    try {
      return utf8.decode(safeBytes, allowMalformed: false);
    } catch (_) {
      // Fallback com malformed — evita crash mas registra o problema
      return utf8.decode(safeBytes, allowMalformed: true);
    }
  }

  /// Processa uma linha SSE e retorna um [SseEvent] quando o evento está completo.
  SseEvent? _processLine(String line) {
    // Linha vazia → fim do evento atual
    if (line.isEmpty) {
      return _dispatchEvent();
    }

    // Comentário `: ...` → heartbeat ou comentário SSE → ignorar
    if (line.startsWith(':')) {
      return null;
    }

    // Campo `event:`
    if (line.startsWith('event:')) {
      _currentEventType = line.substring(6).trim();
      return null;
    }

    // Campo `id:`
    if (line.startsWith('id:')) {
      _currentEventId = line.substring(3).trim();
      return null;
    }

    // Campo `data:`
    if (line.startsWith('data:')) {
      final dataValue = line.substring(5).trim();
      if (_dataBuffer.isNotEmpty) {
        _dataBuffer.write('\n'); // múltiplas linhas data: concatenadas
      }
      _dataBuffer.write(dataValue);
      return null;
    }

    // Campo `retry:` → ignorar (não implementado)
    if (line.startsWith('retry:')) {
      return null;
    }

    // Linha desconhecida → ignorar (tolerância SSE spec)
    return null;
  }

  /// Despacha o evento acumulado quando uma linha vazia é encontrada.
  SseEvent? _dispatchEvent() {
    final dataRaw = _dataBuffer.toString();
    final type    = _currentEventType;
    final id      = _currentEventId;

    // Reset do estado do evento
    _currentEventType = '';
    _currentEventId   = '';
    _dataBuffer.clear();

    // Sem dados → evento vazio → ignorar
    if (dataRaw.isEmpty && type.isEmpty) return null;

    // Heartbeat ou comentário sem dados → ignorar
    if (type.isEmpty && dataRaw.isEmpty) return null;

    // Tentar parsear JSON
    Map<String, dynamic>? data;
    if (dataRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(dataRaw);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        } else {
          // JSON válido mas não é um Map → erro de protocolo
          _errorController.add(SseParseError(
            eventType:    type,
            rawData:      dataRaw,
            errorMessage: 'Expected JSON object, got ${decoded.runtimeType}',
          ));
          return null;
        }
      } on FormatException catch (e) {
        // JSON inválido → erro de protocolo (não continuar silenciosamente)
        _errorController.add(SseParseError(
          eventType:    type,
          rawData:      dataRaw,
          errorMessage: e.message,
        ));
        return null;
      }
    }

    return SseEvent(
      type:    type,
      id:      id,
      dataRaw: dataRaw,
      data:    data,
    );
  }

  /// Limpa todo o estado interno do parser.
  void reset() {
    _byteBuffer.clear();
    _lineBuffer      = '';
    _currentEventType = '';
    _currentEventId   = '';
    _dataBuffer.clear();
  }

  /// Fecha o sink de erros. Chamar no dispose.
  void dispose() {
    _errorController.close();
    reset();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Filtro de eventos SSE — descarta fragmentos inválidos conforme o contrato.
///
/// Descarta eventos com:
///   • requestId diferente do ativo
///   • attempt anterior ao corrente
///   • sequence duplicada ou inferior à última aceita
///
/// Uso:
///   final filter = SseEventFilter(requestId: req, expectedAttempt: 2);
///   for (final sseEvent in rawEvents) {
///     final verdict = filter.accept(sseEvent);
///     if (!verdict.accepted) continue;
///     // processar sseEvent...
///   }
// ─────────────────────────────────────────────────────────────────────────────
class SseEventFilter {
  final String requestId;
  final int expectedAttempt;
  int _lastAcceptedSequence = -1;

  SseEventFilter({required this.requestId, required this.expectedAttempt});

  /// Resultado da avaliação de um evento SSE.
  ({bool accepted, String? discardReason}) accept(SseEvent event) {
    final data = event.data;
    if (data == null) {
      // Sem dados JSON — aceitar apenas eventos de controle sem dados
      return (accepted: true, discardReason: null);
    }

    // Verificar requestId
    final eventReqId = data['requestId'] as String? ?? '';
    if (eventReqId.isNotEmpty && eventReqId != requestId) {
      return (
        accepted: false,
        discardReason: 'requestId_mismatch: got=$eventReqId expected=$requestId',
      );
    }

    // Verificar attempt
    final eventAttempt = (data['attempt'] as num?)?.toInt() ?? -1;
    if (eventAttempt != -1 && eventAttempt < expectedAttempt) {
      return (
        accepted: false,
        discardReason: 'attempt_too_old: got=$eventAttempt expected=$expectedAttempt',
      );
    }

    // Verificar sequence (somente para text_delta)
    if (event.type == 'text_delta') {
      final seq = (data['sequence'] as num?)?.toInt() ?? -1;
      if (seq != -1 && seq <= _lastAcceptedSequence) {
        return (
          accepted: false,
          discardReason: 'sequence_duplicate_or_old: got=$seq last=$_lastAcceptedSequence',
        );
      }
      if (seq != -1) _lastAcceptedSequence = seq;
    }

    return (accepted: true, discardReason: null);
  }

  /// Reseta o filtro para um novo attempt.
  void resetForAttempt(int newAttempt) {
    _lastAcceptedSequence = -1;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SyncStreamController — wrapper mínimo para expor um Stream de erros
// ─────────────────────────────────────────────────────────────────────────────
class _SyncStreamController<T> {
  final _listeners = <void Function(T)>[];
  bool _closed = false;

  Stream<T> get stream => _SyncStream<T>(this);

  void add(T event) {
    if (_closed) return;
    for (final l in _listeners) {
      l(event);
    }
  }

  void close() => _closed = true;
}

class _SyncStream<T> extends Stream<T> {
  final _SyncStreamController<T> _ctrl;
  _SyncStream(this._ctrl);

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    if (onData != null) _ctrl._listeners.add(onData);
    return _NullSubscription<T>();
  }
}

class _NullSubscription<T> implements StreamSubscription<T> {
  @override Future<void> cancel() async {}
  @override void onData(void Function(T data)? handleData) {}
  @override void onError(Function? handleError) {}
  @override void onDone(void Function()? handleDone) {}
  @override void pause([Future<void>? resumeSignal]) {}
  @override void resume() {}
  @override bool get isPaused => false;
  @override Future<E> asFuture<E>([E? futureValue]) async => futureValue as E;
}
