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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final p = context.read<AppProvider>();
        try {
          final found = p.protocolsDB.firstWhere((x) => x.id == widget.initialProtocolId);
          if (mounted) {
            setState(() => _selected = found);
            widget.onConsumed?.call();
          }
        } catch (_) {}
      });
    }
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
      return _ProtocolDetailView(protocol: _selected!, onBack: () => setState(() => _selected = null), p: p);
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
        PremiumCard(child: SectionTitle(eyebrow: 'Clinical Flow', title: p.t('protocols'), subtitle: 'Pesquise e abra o protocolo completo só quando precisar.', light: true)),
        const SizedBox(height: 12),
        StandardCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MedInput(
              controller: _searchCtrl,
              hintText: 'Pesquisar protocolo: IAM, TEP, choque, hipercalemia...',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text('${filtered.length} protocolo(s) encontrado(s)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF888888))),
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
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: kBorder), color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
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
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(20)), child: const Text('abrir', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight))),
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

class _ProtocolDetailView extends StatelessWidget {
  final ProtocolModel protocol;
  final VoidCallback onBack;
  final AppProvider p;
  const _ProtocolDetailView({required this.protocol, required this.onBack, required this.p});

  @override
  Widget build(BuildContext context) {
    final actions = protocol.getActions(p.lang);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), color: Colors.white),
            child: const Row(children: [
              Icon(Icons.arrow_back_ios, size: 14, color: kDark),
              SizedBox(width: 4),
              Text('Voltar para protocolos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: kDark)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        StandardCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.tDB(protocol.severity), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGold, letterSpacing: 1.4)),
                const SizedBox(height: 4),
                Text(p.tDB(protocol.title), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kDark, height: 1.2)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: kDark, borderRadius: BorderRadius.circular(20)), child: const Text('SOS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kGoldLight))),
            ]),
            const SizedBox(height: 16),
            InfoBlock(label: p.t('recognize'), text: p.tDB(protocol.recognize)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFFECFDF5), border: Border.all(color: const Color(0xFFBBF7D0))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.t('actions'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF065F46), letterSpacing: 1.4)),
                const SizedBox(height: 8),
                ...actions.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $a', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF064E3B), height: 1.4)),
                )),
              ]),
            ),
            const SizedBox(height: 10),
            InfoBlock(label: p.t('avoid'), text: p.tDB(protocol.avoid)),
          ]),
        ),
      ]),
    );
  }
}
