// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY SERVICE — Histórico das últimas N ações do usuário no app
// Persiste localmente via SharedPreferences (sem Firestore).
// Registra: IA (query enviada), Protocolo aberto, Fármaco consultado,
//           Calculadora usada, Interação consultada, Prescrição gerada.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Tipos de atividade ───────────────────────────────────────────────────────
enum ActivityType {
  ia,
  protocolo,
  farmaco,
  calculadora,
  interacao,
  prescricao,
  laboratorio,
  caso,
}

extension ActivityTypeX on ActivityType {
  String get key => name;

  String label(String lang) {
    final isEs = lang == 'es';
    switch (this) {
      case ActivityType.ia:           return isEs ? 'IA Clínica'       : 'IA Clínica';
      case ActivityType.protocolo:    return isEs ? 'Protocolo'        : 'Protocolo';
      case ActivityType.farmaco:      return isEs ? 'Farmacología'     : 'Farmacologia';
      case ActivityType.calculadora:  return isEs ? 'Calculadora'      : 'Calculadora';
      case ActivityType.interacao:    return isEs ? 'Interacción'      : 'Interação';
      case ActivityType.prescricao:   return isEs ? 'Prescripción'     : 'Prescrição';
      case ActivityType.laboratorio:  return isEs ? 'Laboratorio'      : 'Laboratório';
      case ActivityType.caso:         return isEs ? 'Caso Clínico'     : 'Caso Clínico';
    }
  }

  // Ícone por tipo (código de codepoint Material)
  int get iconCodePoint {
    switch (this) {
      case ActivityType.ia:           return 0xe4f8; // psychology_rounded
      case ActivityType.protocolo:    return 0xef52; // fact_check_rounded
      case ActivityType.farmaco:      return 0xf0533; // medication_rounded — fallback abaixo
      case ActivityType.calculadora:  return 0xe2ec; // calculate_rounded
      case ActivityType.interacao:    return 0xe5ac; // swap_horiz_rounded
      case ActivityType.prescricao:   return 0xe8f0; // receipt_long_rounded
      case ActivityType.laboratorio:  return 0xe1b9; // biotech_rounded
      case ActivityType.caso:         return 0xe7ef; // person_rounded
    }
  }

  // Cor da badge por tipo
  int get colorValue {
    switch (this) {
      case ActivityType.ia:           return 0xFF6366F1; // indigo
      case ActivityType.protocolo:    return 0xFF0D7A55; // verde
      case ActivityType.farmaco:      return 0xFF0891B2; // ciano
      case ActivityType.calculadora:  return 0xFFD97706; // âmbar
      case ActivityType.interacao:    return 0xFFDC2626; // vermelho
      case ActivityType.prescricao:   return 0xFF7C3AED; // roxo
      case ActivityType.laboratorio:  return 0xFF059669; // esmeralda
      case ActivityType.caso:         return 0xFF9333EA; // violeta
    }
  }
}

// ── Modelo de item de atividade ──────────────────────────────────────────────
class ActivityItem {
  final ActivityType type;
  final String title;       // nome do protocolo / fármaco / query
  final String subtitle;    // detalhe opcional (ex: CID, classificação, dose)
  final DateTime timestamp;

  const ActivityItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'type':      type.key,
    'title':     title,
    'subtitle':  subtitle,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  factory ActivityItem.fromJson(Map<String, dynamic> j) {
    final typeStr = j['type'] as String? ?? 'ia';
    final type = ActivityType.values.firstWhere(
      (t) => t.key == typeStr,
      orElse: () => ActivityType.ia,
    );
    return ActivityItem(
      type:      type,
      title:     j['title']    as String? ?? '',
      subtitle:  j['subtitle'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(j['timestamp'] as int? ?? 0),
    );
  }

  @override
  String toString() => 'ActivityItem($type, $title)';
}

// ── Service ──────────────────────────────────────────────────────────────────
class ActivityService {
  static const _kMaxItems = 20;    // máximo de itens persistidos
  static const _kPrefsKey = 'med_recent_activity_v1';

  /// Notifier — atualizado sempre que a lista muda.
  /// Widgets escutam este notifier sem precisar do BuildContext do service.
  static final ValueNotifier<List<ActivityItem>> items =
      ValueNotifier<List<ActivityItem>>([]);

  static bool _loaded = false;

  /// Carrega histórico do SharedPreferences. Deve ser chamado no app init.
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_kPrefsKey);
      if (raw == null || raw.isEmpty) return;
      final list  = (jsonDecode(raw) as List)
          .map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
          .toList();
      items.value = list;
    } catch (e) {
      debugPrint('[ActivityService] load error: $e');
    }
  }

  /// Registra uma nova atividade no topo da lista.
  /// Se o mesmo título já existe no topo, atualiza o timestamp (evita duplicatas).
  static Future<void> log({
    required ActivityType type,
    required String title,
    String subtitle = '',
  }) async {
    final trimTitle = title.trim();
    if (trimTitle.isEmpty) return;

    final now      = DateTime.now();
    final existing = List<ActivityItem>.from(items.value);

    // Remove duplicata consecutiva (mesmo tipo + título)
    if (existing.isNotEmpty &&
        existing.first.type == type &&
        existing.first.title == trimTitle) {
      existing.removeAt(0);
    }

    final newItem = ActivityItem(
      type:      type,
      title:     trimTitle,
      subtitle:  subtitle.trim(),
      timestamp: now,
    );

    existing.insert(0, newItem);

    // Limita ao máximo
    final capped = existing.take(_kMaxItems).toList();
    items.value = capped;

    // Persiste
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKey, jsonEncode(capped.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('[ActivityService] save error: $e');
    }
  }

  /// Retorna os N itens mais recentes para exibição no Drawer/Sheet.
  static List<ActivityItem> recent({int count = 5}) {
    return items.value.take(count).toList();
  }

  /// Limpa todo o histórico.
  static Future<void> clear() async {
    items.value = [];
    _loaded = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrefsKey);
    } catch (_) {}
  }
}
