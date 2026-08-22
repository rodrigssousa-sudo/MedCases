import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/vaccines/vaccine_clinical_catalog_v2026.dart';
import '../providers/app_provider.dart';

// MEDCASES_VACINA_CLINICAL_CATALOG_PREMIUM_V1_C_R1
// MEDCASES_VACCINES_VISUAL_STANDARD_V1_R3
// MEDCASES_VACCINES_FULL_CARD_SURFACE_HIERARCHY_V1_B_R0
// MEDCASES_VACCINES_SQUARE_1PX_GUTTER_3PX_GAP_V1_B_R0_R1
// ES -> Argentina | PT -> Brasil.
// Disclaimer remains canonical in MainShell::_LegalBar and is not duplicated here.

enum _VaccinesView { root, routine, seasonal, pregnancy, special, detail }

class VaccinesScreen extends StatefulWidget {
  const VaccinesScreen({required this.onBack, super.key});
  final VoidCallback onBack;

  @override
  State<VaccinesScreen> createState() => _VaccinesScreenState();
}

class _VaccinesScreenState extends State<VaccinesScreen> {
  _VaccinesView _view = _VaccinesView.root;
  _VaccinesView _detailParent = _VaccinesView.root;
  VaccineClinicalRecord? _selected;

  void _openView(_VaccinesView view) {
    setState(() {
      _view = view;
      _selected = null;
    });
  }

  void _openDetail(VaccineClinicalRecord record, _VaccinesView parent) {
    setState(() {
      _selected = record;
      _detailParent = parent;
      _view = _VaccinesView.detail;
    });
  }

  void _handleBack() {
    if (_view == _VaccinesView.root) {
      widget.onBack();
      return;
    }
    if (_view == _VaccinesView.detail) {
      setState(() {
        _selected = null;
        _view = _detailParent;
      });
      return;
    }
    setState(() {
      _selected = null;
      _view = _VaccinesView.root;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.select<AppProvider, bool>((p) => p.darkMode);
    final lang = context.select<AppProvider, String>((p) => p.lang);
    final isEs = lang == 'es';
    final catalog = vaccineCatalogForLanguage(lang);
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
    final double topPad =
        View.of(context).padding.top / View.of(context).devicePixelRatio;
    final statusGlassColor = dark
        ? const Color(0xFF252930).withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.70);

    // MEDCASES_VACINA_STATUS_GLASS_CONTINUITY_V1_B_R2
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
      child: ColoredBox(
        color: bg,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                _VaccinesTopBar(dark: dark, isEs: isEs, onBack: _handleBack),
                Expanded(child: _body(catalog, dark, isEs)),
              ],
            ),
            Positioned(
              top: -topPad,
              left: 0,
              right: 0,
              height: topPad,
              child: ClipRect(
                child: ColoredBox(
                  color: bg,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: ColoredBox(color: statusGlassColor),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(VaccineCatalog catalog, bool dark, bool isEs) {
    switch (_view) {
      case _VaccinesView.root:
        return _root(catalog, dark, isEs);
      case _VaccinesView.routine:
        return _routine(catalog, dark, isEs);
      case _VaccinesView.seasonal:
        return _recordList(
          catalog,
          dark,
          isEs,
          isEs
              ? 'Vacunas estacionales y recurrentes'
              : 'Vacinas sazonais e recorrentes',
          isEs
              ? 'Indicaciones revisadas por temporada o periodicidad.'
              : 'Indicações revistas por temporada ou periodicidade.',
          catalog.seasonalIds,
          _VaccinesView.seasonal,
        );
      case _VaccinesView.pregnancy:
        return _recordList(
          catalog,
          dark,
          isEs,
          isEs ? 'Embarazo' : 'Gestação',
          isEs
              ? 'Indicaciones específicas durante cada embarazo.'
              : 'Indicações específicas durante cada gestação.',
          catalog.pregnancyIds,
          _VaccinesView.pregnancy,
        );
      case _VaccinesView.special:
        return _recordList(
          catalog,
          dark,
          isEs,
          isEs
              ? 'Riesgo, zona, exposición o indicación especial'
              : 'Risco, área, exposição ou indicação especial',
          isEs
              ? 'No equivale a indicación universal: revisar elegibilidad.'
              : 'Não equivale a indicação universal: revisar elegibilidade.',
          catalog.specialIds,
          _VaccinesView.special,
        );
      case _VaccinesView.detail:
        final record = _selected;
        return record == null
            ? const SizedBox.shrink()
            : _VaccineDetail(
                record: record,
                catalog: catalog,
                dark: dark,
                isEs: isEs,
              );
    }
  }

  Widget _root(VaccineCatalog catalog, bool dark, bool isEs) {
    final rows = <_RootCategory>[
      _RootCategory(
        title: isEs
            ? 'Calendario rutinario por edad'
            : 'Calendário de rotina por idade',
        subtitle: isEs
            ? 'Esquema nacional organizado cronológicamente'
            : 'Esquema nacional organizado cronologicamente',
        icon: Icons.calendar_month_outlined,
        onTap: () => _openView(_VaccinesView.routine),
      ),
      _RootCategory(
        title: isEs
            ? 'Vacunas estacionales y recurrentes'
            : 'Vacinas sazonais e recorrentes',
        subtitle: isEs
            ? 'Influenza, COVID-19 y estrategias periódicas'
            : 'Influenza, COVID-19 e estratégias periódicas',
        icon: Icons.autorenew_rounded,
        onTap: () => _openView(_VaccinesView.seasonal),
      ),
      _RootCategory(
        title: isEs ? 'Embarazo' : 'Gestação',
        subtitle: isEs
            ? 'Vacunación durante cada embarazo'
            : 'Vacinação durante cada gestação',
        icon: Icons.pregnant_woman_outlined,
        onTap: () => _openView(_VaccinesView.pregnancy),
      ),
      _RootCategory(
        title: isEs
            ? 'Riesgo, zona, exposición o indicación especial'
            : 'Risco, área, exposição ou indicação especial',
        subtitle: isEs
            ? 'Viaje, exposición, grupos de riesgo y estrategias focalizadas'
            : 'Viagem, exposição, grupos de risco e estratégias focalizadas',
        icon: Icons.health_and_safety_outlined,
        onTap: () => _openView(_VaccinesView.special),
      ),
    ];

    return ListView(
      key: ValueKey('vaccines-root-${catalog.jurisdiction.name}'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 150),
      children: [
        _JurisdictionHeader(catalog: catalog, dark: dark, isEs: isEs),
        const SizedBox(height: 8),
        for (var i = 0; i < rows.length; i++)
          _ClinicalNavigationRow(
            dark: dark,
            title: rows[i].title,
            subtitle: rows[i].subtitle,
            icon: rows[i].icon,
            onTap: rows[i].onTap,
          ),
        const SizedBox(height: 3),
        _AssessmentNotice(dark: dark, isEs: isEs),
      ],
    );
  }

  Widget _routine(VaccineCatalog catalog, bool dark, bool isEs) {
    return ListView(
      key: ValueKey('vaccines-routine-${catalog.jurisdiction.name}'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 150),
      children: [
        _PageHeading(
          dark: dark,
          title: isEs
              ? 'Calendario rutinario por edad'
              : 'Calendário de rotina por idade',
          subtitle:
              '${catalog.countryLabel} • ${catalog.programLabel} ${catalog.versionLabel}',
        ),
        for (final group in catalog.routineGroups)
          _AgeGroupBlock(
            group: group,
            catalog: catalog,
            dark: dark,
            onOpen: (record) => _openDetail(record, _VaccinesView.routine),
          ),
      ],
    );
  }

  Widget _recordList(
    VaccineCatalog catalog,
    bool dark,
    bool isEs,
    String title,
    String subtitle,
    List<String> ids,
    _VaccinesView parent,
  ) {
    final records =
        ids.map(catalog.recordById).whereType<VaccineClinicalRecord>().toList();
    return ListView(
      key: ValueKey('vaccines-${parent.name}-${catalog.jurisdiction.name}'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 150),
      children: [
        _PageHeading(dark: dark, title: title, subtitle: subtitle),
        for (var i = 0; i < records.length; i++)
          _VaccineListRow(
            record: records[i],
            dark: dark,
            onTap: () => _openDetail(records[i], parent),
          ),
      ],
    );
  }
}

class _RootCategory {
  const _RootCategory(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _VaccinesTopBar extends StatelessWidget {
  const _VaccinesTopBar(
      {required this.dark, required this.isEs, required this.onBack});
  final bool dark, isEs;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final glassColor = dark
        ? const Color(0xFF252930).withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.70);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    final text = dark ? Colors.white : const Color(0xFF05070A);

    // MEDCASES_VACINA_HOME_TOPBAR_V1_B_R1
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: glassColor,
            border: Border(
              bottom: BorderSide(color: border, width: 0.7),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  isEs ? 'VACUNA' : 'VACINA',
                  style: TextStyle(
                    color: text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Tooltip(
                    message: isEs ? 'Volver' : 'Voltar',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onBack,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: text,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JurisdictionHeader extends StatelessWidget {
  const _JurisdictionHeader(
      {required this.catalog, required this.dark, required this.isEs});
  final VaccineCatalog catalog;
  final bool dark, isEs;

  @override
  Widget build(BuildContext context) {
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF05070A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final accent = dark ? const Color(0xFF00C781) : const Color(0xFF059669);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            catalog.countryLabel.toUpperCase(),
            style: TextStyle(
              color: primary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Container(
                  width: 12,
                  height: 2,
                  color: accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${catalog.programLabel.toUpperCase()} ${catalog.versionLabel}',
                  style: TextStyle(
                    color: primary,
                    fontSize: 14.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    height: 1.28,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${isEs ? 'Actualización clínica' : 'Atualização clínica'}: ${catalog.lastVerifiedAt}',
            style: TextStyle(
              color: secondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentNotice extends StatelessWidget {
  const _AssessmentNotice({required this.dark, required this.isEs});
  final bool dark, isEs;

  @override
  Widget build(BuildContext context) {
    final accent = dark ? const Color(0xFFF4B942) : const Color(0xFF9A6700);
    final text = dark ? const Color(0xFFD7DEE8) : const Color(0xFF475569);
    return Container(
      margin: const EdgeInsets.fromLTRB(1, 0, 1, 0),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? 0.08 : 0.07),
        border: Border.all(
          color: accent.withValues(alpha: dark ? 0.34 : 0.24),
          width: 0.8,
        ),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 42,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEs
                  ? 'Referencia clínica. La indicación individual depende de edad, antecedentes, embarazo, inmunosupresión, exposición, territorio y estado vigente del programa.'
                  : 'Referência clínica. A indicação individual depende de idade, histórico, gestação, imunossupressão, exposição, território e status vigente do programa.',
              style: TextStyle(
                color: text,
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading(
      {required this.dark, required this.title, required this.subtitle});
  final bool dark;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) {
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF05070A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                color: primary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.22)),
        const SizedBox(height: 5),
        Text(subtitle,
            style: TextStyle(color: secondary, fontSize: 11.5, height: 1.4)),
      ]),
    );
  }
}

class _ClinicalNavigationRow extends StatelessWidget {
  const _ClinicalNavigationRow(
      {required this.dark,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap});
  final bool dark;
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF05070A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final accent = dark ? const Color(0xFF00C781) : const Color(0xFF059669);
    final surface = _vaccineCardSurface(dark);
    final border = _vaccineCardBorder(dark);

    return Container(
      margin: const EdgeInsets.fromLTRB(1, 0, 1, 3),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border, width: 0.8),
        borderRadius: BorderRadius.zero,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.zero,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: dark ? 0.11 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 19, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: primary,
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: secondary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: secondary.withValues(alpha: 0.78),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgeGroupBlock extends StatelessWidget {
  const _AgeGroupBlock(
      {required this.group,
      required this.catalog,
      required this.dark,
      required this.onOpen});
  final VaccineAgeGroup group;
  final VaccineCatalog catalog;
  final bool dark;
  final ValueChanged<VaccineClinicalRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF05070A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final accent = dark ? const Color(0xFF00C781) : const Color(0xFF059669);
    final divider = _vaccineCardBorder(dark);

    return Container(
      margin: const EdgeInsets.fromLTRB(1, 0, 1, 3),
      decoration: BoxDecoration(
        color: _vaccineCardSurface(dark),
        border: Border.all(color: divider, width: 0.8),
        borderRadius: BorderRadius.zero,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
            decoration: BoxDecoration(
              color: _vaccineCardHeaderSurface(dark),
              border: Border(
                bottom: BorderSide(color: divider, width: 0.7),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group.label,
                    style: TextStyle(
                      color: primary,
                      fontSize: 13.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < group.entries.length; i++) ...[
            Builder(builder: (_) {
              final entry = group.entries[i];
              final record = catalog.recordById(entry.vaccineId);
              return record == null
                  ? const SizedBox.shrink()
                  : _DoseRow(
                      dark: dark,
                      record: record,
                      schedule: entry.schedule,
                      onTap: () => onOpen(record),
                    );
            }),
            if (i < group.entries.length - 1)
              Divider(
                height: 1,
                thickness: 0.6,
                indent: 14,
                endIndent: 14,
                color: divider,
              ),
          ],
          if (group.note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 11),
              child: Text(
                group.note!,
                style: TextStyle(
                  color: secondary,
                  fontSize: 10.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow(
      {required this.dark,
      required this.record,
      required this.schedule,
      required this.onTap});
  final bool dark;
  final VaccineClinicalRecord record;
  final String schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: TextStyle(
                        color: primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      schedule,
                      style: TextStyle(
                        color: secondary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: secondary.withValues(alpha: 0.70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaccineListRow extends StatelessWidget {
  const _VaccineListRow(
      {required this.record, required this.dark, required this.onTap});
  final VaccineClinicalRecord record;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final semantic = _statusColor(record.status, dark);

    return Container(
      margin: const EdgeInsets.fromLTRB(1, 0, 1, 3),
      decoration: BoxDecoration(
        color: _vaccineCardSurface(dark),
        border: Border.all(color: _vaccineCardBorder(dark), width: 0.8),
        borderRadius: BorderRadius.zero,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.zero,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: semantic.withValues(alpha: dark ? 0.11 : 0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _statusIcon(record.status),
                    size: 18,
                    color: semantic,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        style: TextStyle(
                          color: primary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.statusLabel,
                        style: TextStyle(
                          color: semantic,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: secondary.withValues(alpha: 0.75),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VaccineDetail extends StatelessWidget {
  const _VaccineDetail(
      {required this.record,
      required this.catalog,
      required this.dark,
      required this.isEs});
  final VaccineClinicalRecord record;
  final VaccineCatalog catalog;
  final bool dark, isEs;

  @override
  Widget build(BuildContext context) {
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF05070A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final semantic = _statusColor(record.status, dark);

    return ListView(
      key: ValueKey('vaccine-detail-${record.id}'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(1, 18, 1, 150),
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _vaccineCardSurface(dark),
            border: Border.all(color: _vaccineCardBorder(dark), width: 0.8),
            borderRadius: BorderRadius.zero,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.title,
                style: TextStyle(
                  color: primary,
                  fontSize: 19,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (record.aliases.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  record.aliases.join(' • '),
                  style: TextStyle(color: secondary, fontSize: 11),
                ),
              ],
              const SizedBox(height: 10),
              _StatusLabel(
                label: record.statusLabel,
                color: semantic,
                dark: dark,
              ),
              if (record.requiresClinicalAssessment ||
                  record.requiresLiveStatusCheck) ...[
                const SizedBox(height: 12),
                _ClinicalGate(
                  dark: dark,
                  isEs: isEs,
                  liveStatus: record.requiresLiveStatusCheck,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 3),
        _DetailSection(
          dark: dark,
          title: 'ESQUEMA',
          icon: Icons.calendar_today_outlined,
          body: record.schedule,
          accent: semantic,
        ),
        _DetailSection(
          dark: dark,
          title: isEs ? 'QUÉ PREVIENE' : 'O QUE PREVINE',
          icon: Icons.shield_outlined,
          body: record.prevents,
        ),
        _DetailSection(
          dark: dark,
          title: 'TIPO',
          icon: Icons.biotech_outlined,
          body:
              '${record.platform} • ${record.liveVaccine ? (isEs ? 'Vacuna viva' : 'Vacina viva') : (isEs ? 'No viva' : 'Não viva')}',
        ),
        _DetailSection(
          dark: dark,
          title: isEs ? 'ADMINISTRACIÓN' : 'ADMINISTRAÇÃO',
          icon: Icons.vaccines_outlined,
          body: record.administration,
        ),
        _BulletSection(
          dark: dark,
          title: isEs ? 'PUNTOS CLAVE' : 'PONTOS-CHAVE',
          icon: Icons.check_circle_outline_rounded,
          items: record.keyPoints,
        ),
        _BulletSection(
          dark: dark,
          title: isEs
              ? 'CONTRAINDICACIONES / PRECAUCIONES'
              : 'CONTRAINDICAÇÕES / PRECAUÇÕES',
          icon: Icons.warning_amber_rounded,
          items: record.contraindications,
          accent: dark ? const Color(0xFFF4B942) : const Color(0xFF9A6700),
        ),
        _BulletSection(
          dark: dark,
          title: isEs ? 'REACCIONES MÁS COMUNES' : 'REAÇÕES MAIS COMUNS',
          icon: Icons.info_outline_rounded,
          items: record.commonEffects,
        ),
        _BulletSection(
          dark: dark,
          title: isEs ? 'SEÑALES DE ALARMA' : 'SINAIS DE ALERTA',
          icon: Icons.emergency_outlined,
          items: record.alertSigns,
          accent: dark ? const Color(0xFFFF7070) : const Color(0xFFDC2626),
        ),
        _ReferenceSection(
          dark: dark,
          isEs: isEs,
          record: record,
          catalog: catalog,
        ),
      ],
    );
  }
}

class _ClinicalGate extends StatelessWidget {
  const _ClinicalGate(
      {required this.dark, required this.isEs, required this.liveStatus});
  final bool dark, isEs, liveStatus;

  @override
  Widget build(BuildContext context) {
    final color = liveStatus
        ? (dark ? const Color(0xFFFF7070) : const Color(0xFFDC2626))
        : (dark ? const Color(0xFFF4B942) : const Color(0xFF9A6700));
    final text = dark ? const Color(0xFFD7DEE8) : const Color(0xFF475569);
    final message = liveStatus
        ? (isEs
            ? 'Estado dinámico: verificar la recomendación oficial vigente antes de indicar.'
            : 'Status dinâmico: verificar a recomendação oficial vigente antes de indicar.')
        : (isEs
            ? 'Requiere evaluación clínica individual antes de considerar una indicación.'
            : 'Requer avaliação clínica individual antes de considerar uma indicação.');
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 2.5)),
        color: color.withValues(alpha: dark ? 0.06 : 0.08),
      ),
      child: Text(message,
          style: TextStyle(
              color: text,
              fontSize: 11.2,
              height: 1.4,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel(
      {required this.label, required this.color, required this.dark});
  final String label;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.55), width: 0.7),
          color: color.withValues(alpha: dark ? 0.07 : 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                color: color,
                fontSize: 9.2,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.35)),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection(
      {required this.dark,
      required this.title,
      required this.icon,
      required this.body,
      this.accent});
  final bool dark;
  final String title, body;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final secondary = dark ? const Color(0xFFB3BDC9) : const Color(0xFF475569);
    final iconColor =
        accent ?? (dark ? const Color(0xFF00C781) : const Color(0xFF059669));

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _vaccineCardSurface(dark),
        border: Border.all(color: _vaccineCardBorder(dark), width: 0.8),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  color: primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(color: secondary, fontSize: 12, height: 1.48),
          ),
        ],
      ),
    );
  }
}

class _BulletSection extends StatelessWidget {
  const _BulletSection(
      {required this.dark,
      required this.title,
      required this.icon,
      required this.items,
      this.accent});
  final bool dark;
  final String title;
  final IconData icon;
  final List<String> items;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final secondary = dark ? const Color(0xFFB3BDC9) : const Color(0xFF475569);
    final iconColor =
        accent ?? (dark ? const Color(0xFF00C781) : const Color(0xFF059669));

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _vaccineCardSurface(dark),
        border: Border.all(color: _vaccineCardBorder(dark), width: 0.8),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: secondary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReferenceSection extends StatelessWidget {
  const _ReferenceSection(
      {required this.dark,
      required this.isEs,
      required this.record,
      required this.catalog});
  final bool dark, isEs;
  final VaccineClinicalRecord record;
  final VaccineCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _vaccineCardSurface(dark),
        border: Border.all(color: _vaccineCardBorder(dark), width: 0.8),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEs ? 'REFERENCIA' : 'REFERÊNCIA',
            style: TextStyle(
              color: primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            record.reference,
            style: TextStyle(
              color: secondary,
              fontSize: 11.2,
              height: 1.42,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (record.safetyReference != null) ...[
            const SizedBox(height: 6),
            Text(
              '${isEs ? 'Seguridad' : 'Segurança'}: ${record.safetyReference}',
              style: TextStyle(color: secondary, fontSize: 11, height: 1.4),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Verificado: ${record.lastVerifiedAt} • ${catalog.countryLabel}',
            style: TextStyle(
              color: secondary.withValues(alpha: 0.80),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Color _vaccineCardSurface(bool dark) =>
    dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);

Color _vaccineCardHeaderSurface(bool dark) =>
    dark ? const Color(0xFF2A2F37) : const Color(0xFFF7F9FA);

Color _vaccineCardBorder(bool dark) =>
    dark ? const Color(0xFF374151) : const Color(0xFFDCE3E8);

Color _statusColor(VaccineProgramStatus status, bool dark) {
  switch (status) {
    case VaccineProgramStatus.routineAge:
    case VaccineProgramStatus.seasonal:
    case VaccineProgramStatus.pregnancy:
      return dark ? const Color(0xFF00C781) : const Color(0xFF059669);
    case VaccineProgramStatus.riskGroup:
    case VaccineProgramStatus.focalizedStrategy:
    case VaccineProgramStatus.travelExposure:
    case VaccineProgramStatus.postExposure:
    case VaccineProgramStatus.nonUniversal:
      return dark ? const Color(0xFFF4B942) : const Color(0xFF9A6700);
    case VaccineProgramStatus.temporaryHold:
      return dark ? const Color(0xFFFF7070) : const Color(0xFFDC2626);
  }
}

IconData _statusIcon(VaccineProgramStatus status) {
  switch (status) {
    case VaccineProgramStatus.routineAge:
      return Icons.event_available_outlined;
    case VaccineProgramStatus.seasonal:
      return Icons.autorenew_rounded;
    case VaccineProgramStatus.pregnancy:
      return Icons.pregnant_woman_outlined;
    case VaccineProgramStatus.riskGroup:
      return Icons.health_and_safety_outlined;
    case VaccineProgramStatus.focalizedStrategy:
      return Icons.location_on_outlined;
    case VaccineProgramStatus.travelExposure:
      return Icons.flight_takeoff_outlined;
    case VaccineProgramStatus.postExposure:
      return Icons.emergency_outlined;
    case VaccineProgramStatus.nonUniversal:
      return Icons.rule_outlined;
    case VaccineProgramStatus.temporaryHold:
      return Icons.pause_circle_outline_rounded;
  }
}
