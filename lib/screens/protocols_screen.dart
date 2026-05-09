import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/protocol_model.dart';
import '../widgets/common_widgets.dart';

class ProtocolsScreen extends StatefulWidget {
  final String? initialProtocolId;
  final VoidCallback? onConsumed;
  const ProtocolsScreen({super.key, this.initialProtocolId, this.onConsumed});

  @override
  State<ProtocolsScreen> createState() => _ProtocolsScreenState();
}

class _ProtocolsScreenState extends State<ProtocolsScreen> {
  final _searchCtrl = TextEditingController();
  ProtocolModel? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.initialProtocolId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openById(widget.initialProtocolId!));
    }
  }

  @override
  void didUpdateWidget(ProtocolsScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialProtocolId != null &&
        widget.initialProtocolId != old.initialProtocolId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openById(widget.initialProtocolId!));
    }
  }

  void _openById(String id) {
    final p = context.read<AppProvider>();
    try {
      final found = p.protocolsDB.firstWhere((x) => x.id == id);
      if (mounted) {
        setState(() => _selected = found);
        widget.onConsumed?.call();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();

    if (_selected != null) {
      return _ProtocolDetailView(
        protocol: _selected!,
        onBack: () => setState(() => _selected = null),
        p: p,
      );
    }

    final q = _searchCtrl.text.toLowerCase();
    final filtered = p.protocolsDB.where((proto) {
      if (q.isEmpty) return true;
      return p.tDB(proto.title).toLowerCase().contains(q) ||
          p.tDB(proto.severity).toLowerCase().contains(q) ||
          p.tDB(proto.recognize).toLowerCase().contains(q) ||
          proto.getActions(p.lang).any((a) => a.toLowerCase().contains(q));
    }).toList();

    filtered.sort((a, b) {
      final aFav = p.favProtocols.contains(a.id) ? 0 : 1;
      final bFav = p.favProtocols.contains(b.id) ? 0 : 1;
      return aFav.compareTo(bFav);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      child: Column(children: [
        PremiumCard(child: SectionTitle(eyebrow: 'Clinical Flow', title: p.t('protocols'), subtitle: p.t('protocols_subtitle'), light: true)),
        const SizedBox(height: 12),
        StandardCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MedInput(
              controller: _searchCtrl,
              hintText: p.t('search_protocol_hint'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text('${filtered.length} ${p.t("protocols_found")}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF888888))),
          ]),
        ),
        const SizedBox(height: 12),
        ...filtered.map((proto) {
          final isFav = p.favProtocols.contains(proto.id);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: GestureDetector(
              onTap: () => setState(() => _selected = proto),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      if (isFav) const Padding(padding: EdgeInsets.only(right: 4), child: Text('⭐', style: TextStyle(fontSize: 12))),
                      Text(p.tDB(proto.severity), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGold, letterSpacing: 1.4)),
                    ]),
                    const SizedBox(height: 4),
                    Text(p.tDB(proto.title), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kDark), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(p.tDB(proto.recognize), style: const TextStyle(fontSize: 12, color: Color(0xFF777777), fontWeight: FontWeight.w600, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ])),
                  const SizedBox(width: 8),
                  Column(children: [
                    GestureDetector(
                      onTap: () => p.toggleFavProtocol(proto.id),
                      child: Padding(padding: const EdgeInsets.all(4), child: Text(isFav ? '⭐' : '☆', style: const TextStyle(fontSize: 18))),
                    ),
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(20)), child: Text(p.t('open'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight))),
                  ]),
                ]),
              ),
            ),
          );
        }),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DETALHE DO PROTOCOLO — hierarquia visual igual ao card de dose dos fármacos
// ─────────────────────────────────────────────────────────────────────────────
class _ProtocolDetailView extends StatelessWidget {
  final ProtocolModel protocol;
  final VoidCallback onBack;
  final AppProvider p;
  const _ProtocolDetailView({required this.protocol, required this.onBack, required this.p});

  @override
  Widget build(BuildContext context) {
    final actions  = protocol.getActions(p.lang);
    final isFav    = p.favProtocols.contains(protocol.id);
    final avoidTxt = p.tDB(protocol.avoid);
    final drugs    = protocol.drugs;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Voltar ──────────────────────────────────────────────────────────
        GestureDetector(
          onTap: onBack,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
              color: Colors.white,
            ),
            child: Row(children: [
              const Icon(Icons.arrow_back_ios, size: 14, color: kDark),
              const SizedBox(width: 4),
              Text(p.t('back_protocols'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kDark)),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // ── Header premium ───────────────────────────────────────────────────
        PremiumCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.tDB(protocol.severity),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                  color: Color(0xBFFFE8A6), letterSpacing: 1.4)),
              const SizedBox(height: 4),
              Text(p.tDB(protocol.title),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -0.5, height: 1.2)),
            ])),
            GestureDetector(
              onTap: () => p.toggleFavProtocol(protocol.id),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Icon(
                  isFav ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 22,
                  color: isFav ? const Color(0xFFFFE8A6) : Colors.white54,
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Reconhecer ───────────────────────────────────────────────────────
        _RecognizeCard(text: p.tDB(protocol.recognize), p: p),
        const SizedBox(height: 10),

        // ── Conduta imediata — hierarquia visual ─────────────────────────────
        _ActionsCard(actions: actions, p: p),
        const SizedBox(height: 10),

        // ── Evitar ──────────────────────────────────────────────────────────
        if (avoidTxt.isNotEmpty) ...[
          _AvoidCard(text: avoidTxt, p: p),
          const SizedBox(height: 10),
        ],

        // ── Fármacos relacionados ────────────────────────────────────────────
        if (drugs.isNotEmpty) ...[
          _DrugsChipsCard(drugs: drugs, p: p),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD: RECONHECER
// ─────────────────────────────────────────────────────────────────────────────
class _RecognizeCard extends StatelessWidget {
  final String text;
  final AppProvider p;
  const _RecognizeCard({required this.text, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFFFFBF0),
        border: Border.all(color: const Color(0xFFE8D8A0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFC5A365).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(p.t('recognize').toUpperCase(),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                color: Color(0xFF8B6914), letterSpacing: 1.8)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(text,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600,
            color: Color(0xFF3D2E00), height: 1.55)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD: CONDUTA — com badge numerado + linha conectora + labels semânticos
// ─────────────────────────────────────────────────────────────────────────────
class _ActionsCard extends StatelessWidget {
  final List<String> actions;
  final AppProvider p;
  const _ActionsCard({required this.actions, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kDark, Color(0xFF0D2218), Color(0xFF0A3020)],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8A6).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(p.t('actions').toUpperCase(),
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                  color: Color(0xFFFFE8A6), letterSpacing: 2.0)),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // Passos com hierarquia visual
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(actions.length, (i) {
              return _ActionStepRow(
                index: i,
                text: actions[i],
                isLast: i == actions.length - 1,
                p: p,
              );
            }),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LINHA DE PASSO — badge + linha conectora + classificação semântica
// ─────────────────────────────────────────────────────────────────────────────
class _ActionStepRow extends StatelessWidget {
  final int index;
  final String text;
  final bool isLast;
  final AppProvider p;

  const _ActionStepRow({
    required this.index,
    required this.text,
    required this.isLast,
    required this.p,
  });

  // ── Classificação semântica do passo ──────────────────────────────────────
  _StepType _classify(String t) {
    final lower = t.toLowerCase();

    // Urgência / Reperfusão / Cirurgia emergencial
    if (lower.contains('urgente') || lower.contains('emergência') ||
        lower.contains('cirurgia') || lower.contains('reperfusão') ||
        lower.contains('reperfusión') || lower.contains('icp') ||
        lower.contains('fibrinólise') || lower.contains('fibrinolisis') ||
        lower.contains('rcp') || lower.contains('desfibril') ||
        lower.contains('cardiovers') || lower.contains('intubação') ||
        lower.contains('intubación') || lower.contains('cricotireot') ||
        lower.contains('toracostomia') || lower.contains('pericardiocentese')) {
      return _StepType.urgent;
    }

    // Evitar / Contraindicação inline
    if (lower.contains('evitar') || lower.contains('não usar') ||
        lower.contains('no usar') || lower.contains('contraindicado') ||
        lower.contains('contraindicad') || lower.contains('cuidado com') ||
        lower.contains('cautela')) {
      return _StepType.avoid;
    }

    // Monitorização / Reavaliação
    if (lower.contains('monitor') || lower.contains('reavaliar') ||
        lower.contains('reevaluar') || lower.contains('controlar') ||
        lower.contains('acompanhar') || lower.contains('verificar') ||
        lower.contains('checar') || lower.contains('ecg') ||
        lower.contains('spo2') || lower.contains('pa ') ||
        lower.contains('diurese') || lower.contains('lactato')) {
      return _StepType.monitor;
    }

    // Acesso / Via / Preparação
    if (lower.contains('acesso venoso') || lower.contains('acesso iv') ||
        lower.contains('acesso vv') || lower.contains('via aérea') ||
        lower.contains('vía aérea') || lower.contains('posicionar') ||
        lower.contains('exames') || lower.contains('gasometria') ||
        lower.contains('hemograma') || lower.contains('colher') ||
        lower.contains('solicitar') || lower.contains('chamar') ||
        lower.contains('notificar') || lower.contains('acionar')) {
      return _StepType.prepare;
    }

    // Primeiro passo — destaque máximo
    if (index == 0) return _StepType.primary;

    return _StepType.secondary;
  }

  @override
  Widget build(BuildContext context) {
    final type = _classify(text);
    final cfg  = _config(type);

    // Divide o texto em parte principal e sub-detalhe (entre parênteses)
    final parenMatch = RegExp(r'^(.*?)\s*\(([^)]+)\)\s*(.*)$').firstMatch(text);
    final hasParen   = parenMatch != null;
    final mainText   = hasParen
        ? '${parenMatch.group(1)!.trim()}${parenMatch.group(3)!.trim()}'.trim()
        : text;
    final subText    = hasParen ? parenMatch.group(2)! : null;

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Coluna esquerda: badge + linha conectora ─────────────────────────
        SizedBox(
          width: 28,
          child: Column(children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: cfg.badgeBg,
                shape: BoxShape.circle,
                border: Border.all(color: cfg.badgeBorder, width: 1.5),
              ),
              child: Center(
                child: cfg.badgeIcon != null
                    ? Icon(cfg.badgeIcon, size: 12, color: cfg.badgeFg)
                    : Text('${index + 1}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                          color: cfg.badgeFg)),
              ),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 1.5,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            if (isLast) const SizedBox(height: 14),
          ]),
        ),

        const SizedBox(width: 10),

        // ── Coluna direita: label + texto + sub ──────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Label semântico (ex: URGENTE, EVITAR, MONITORAR)
              if (cfg.label != null) ...[
                Text(cfg.label!,
                  style: TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w900,
                    color: cfg.labelColor, letterSpacing: 1.6)),
                const SizedBox(height: 2),
              ],

              // Texto principal
              Text(mainText,
                style: TextStyle(
                  fontSize: cfg.fontSize,
                  fontWeight: cfg.fontWeight,
                  color: cfg.textColor,
                  height: 1.4,
                  letterSpacing: -0.1)),

              // Sub-detalhe entre parênteses — menor, mais suave
              if (subText != null) ...[
                const SizedBox(height: 3),
                Text('($subText)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.35,
                    fontStyle: FontStyle.italic)),
              ],

              const SizedBox(height: 10),
            ]),
          ),
        ),
      ]),
    );
  }

  _StepCfg _config(_StepType t) {
    switch (t) {
      case _StepType.primary:
        return _StepCfg(
          label: null,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          textColor: Colors.white,
          badgeBg: const Color(0xFFFFE8A6).withValues(alpha: 0.25),
          badgeBorder: const Color(0xFFFFE8A6).withValues(alpha: 0.7),
          badgeFg: const Color(0xFFFFE8A6),
        );
      case _StepType.urgent:
        return _StepCfg(
          label: p.lang == 'es' ? 'URGENTE' : 'URGENTE',
          labelColor: const Color(0xFFFF8080),
          fontSize: 14,
          fontWeight: FontWeight.w800,
          textColor: const Color(0xFFFFCCCC),
          badgeBg: const Color(0xFFFF6B6B).withValues(alpha: 0.20),
          badgeBorder: const Color(0xFFFF6B6B).withValues(alpha: 0.55),
          badgeFg: const Color(0xFFFF9090),
          badgeIcon: Icons.priority_high_rounded,
        );
      case _StepType.avoid:
        return _StepCfg(
          label: p.lang == 'es' ? 'PRECAUCIÓN' : 'ATENÇÃO',
          labelColor: const Color(0xFFFFB347),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          textColor: const Color(0xFFFFD59A),
          badgeBg: const Color(0xFFFFB347).withValues(alpha: 0.15),
          badgeBorder: const Color(0xFFFFB347).withValues(alpha: 0.45),
          badgeFg: const Color(0xFFFFB347),
          badgeIcon: Icons.warning_amber_rounded,
        );
      case _StepType.monitor:
        return _StepCfg(
          label: p.lang == 'es' ? 'MONITORIZAR' : 'MONITORAR',
          labelColor: const Color(0xFF90CDD9),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          textColor: Colors.white.withValues(alpha: 0.88),
          badgeBg: const Color(0xFF90CDD9).withValues(alpha: 0.15),
          badgeBorder: const Color(0xFF90CDD9).withValues(alpha: 0.45),
          badgeFg: const Color(0xFF90CDD9),
          badgeIcon: Icons.monitor_heart_outlined,
        );
      case _StepType.prepare:
        return _StepCfg(
          label: p.lang == 'es' ? 'PREPARAR' : 'PREPARAR',
          labelColor: const Color(0xFFB0C4FF),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          textColor: Colors.white.withValues(alpha: 0.85),
          badgeBg: const Color(0xFFB0C4FF).withValues(alpha: 0.12),
          badgeBorder: const Color(0xFFB0C4FF).withValues(alpha: 0.35),
          badgeFg: const Color(0xFFB0C4FF),
          badgeIcon: Icons.playlist_add_check_rounded,
        );
      case _StepType.secondary:
        return _StepCfg(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          textColor: Colors.white.withValues(alpha: 0.82),
          badgeBg: Colors.white.withValues(alpha: 0.08),
          badgeBorder: Colors.white.withValues(alpha: 0.20),
          badgeFg: Colors.white.withValues(alpha: 0.55),
        );
    }
  }
}

enum _StepType { primary, urgent, avoid, monitor, prepare, secondary }

class _StepCfg {
  final String? label;
  final Color labelColor;
  final double fontSize;
  final FontWeight fontWeight;
  final Color textColor;
  final Color badgeBg;
  final Color badgeBorder;
  final Color badgeFg;
  final IconData? badgeIcon;

  const _StepCfg({
    this.label,
    this.labelColor = Colors.white,
    required this.fontSize,
    required this.fontWeight,
    required this.textColor,
    required this.badgeBg,
    required this.badgeBorder,
    required this.badgeFg,
    this.badgeIcon,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD: EVITAR
// ─────────────────────────────────────────────────────────────────────────────
class _AvoidCard extends StatelessWidget {
  final String text;
  final AppProvider p;
  const _AvoidCard({required this.text, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFFFF5F5),
        border: Border.all(color: const Color(0xFFFFCCCC)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.block_rounded, size: 13, color: Color(0xFFCC2222)),
          const SizedBox(width: 6),
          Text(p.t('avoid').toUpperCase(),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
              letterSpacing: 1.8, color: Color(0xFFCC2222))),
        ]),
        const SizedBox(height: 8),
        Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: Color(0xFF8B0000), height: 1.5)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD: FÁRMACOS RELACIONADOS
// ─────────────────────────────────────────────────────────────────────────────
class _DrugsChipsCard extends StatelessWidget {
  final List<String> drugs;
  final AppProvider p;
  const _DrugsChipsCard({required this.drugs, required this.p});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF5F2EB),
        border: Border.all(color: const Color(0xFFDDD8CC)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.medication_rounded, size: 13, color: kGold),
          const SizedBox(width: 6),
          Text(p.lang == 'es' ? 'FÁRMACOS CLAVE' : 'FÁRMACOS CHAVE',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
              letterSpacing: 1.8, color: kGold)),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: drugs.map((d) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDDD8CC)),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4, offset: const Offset(0, 1))],
            ),
            child: Text(d,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                color: kDark)),
          )).toList(),
        ),
      ]),
    );
  }
}
