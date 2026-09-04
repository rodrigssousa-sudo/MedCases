// MEDCASES_PRODUCTIVE_SECOND_BRAND_B1_V2_R1_LAB
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/laboratory/lab_reference_catalog.dart';
import '../models/lab_reference_model.dart';
import '../providers/app_provider.dart';

abstract final class LaboratorySessionBridge {
  static final ValueNotifier<int> resetSerial = ValueNotifier<int>(0);

  static void reset() {
    resetSerial.value = resetSerial.value + 1;
  }
}

class LaboratoryMainShellWorkspace extends StatelessWidget {
  const LaboratoryMainShellWorkspace({
    required this.onBack,
    super.key,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    return ValueListenableBuilder<int>(
      valueListenable: LaboratorySessionBridge.resetSerial,
      builder: (context, serial, child) {
        return KeyedSubtree(
          key: ValueKey<int>(serial),
          child: LaboratoryScreen(
            dark: p.darkMode,
            isEs: p.lang == 'es',
            embeddedInMainShell: true,
            onBack: onBack,
          ),
        );
      },
    );
  }
}

class LaboratoryScreen extends StatefulWidget {
  const LaboratoryScreen({
    required this.dark,
    required this.isEs,
    this.embeddedInMainShell = false,
    this.onBack,
    super.key,
  });

  final bool dark;
  final bool isEs;
  final bool embeddedInMainShell;
  final VoidCallback? onBack;

  @override
  State<LaboratoryScreen> createState() => _LaboratoryScreenState();
}

class _LaboratoryScreenState extends State<LaboratoryScreen> {
  bool _filtersExpanded = false;
  String _age = 'all';
  String _sex = 'all';
  String _pregnancy = 'all';
  String _method = 'all';
  LabReferenceCategory? _selectedCategory;

  Color get _background =>
      widget.dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
  Color get _surface =>
      widget.dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
  Color get _divider =>
      widget.dark ? const Color(0xFF374151) : const Color(0xFFD8E0E7);
  Color get _primary =>
      widget.dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
  Color get _secondary =>
      widget.dark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  static const Color _accent = Color(0xFF0D6B57);

  bool get _hasFilter =>
      _age != 'all' || _sex != 'all' || _pregnancy != 'all' || _method != 'all';

  void _clearFilters() {
    setState(() {
      _age = 'all';
      _sex = 'all';
      _pregnancy = 'all';
      _method = 'all';
    });
  }

  String _ageLabel(String value) {
    switch (value) {
      case 'newborn':
        return widget.isEs ? '0–28 días' : '0–28 dias';
      case 'infant':
        return widget.isEs ? '1–23 meses' : '1–23 meses';
      case 'child_2_5':
        return widget.isEs ? '2–5 años' : '2–5 anos';
      case 'child_6_10':
        return widget.isEs ? '6–10 años' : '6–10 anos';
      case 'adolescent':
        return widget.isEs ? '11–17 años' : '11–17 anos';
      case 'adult':
        return 'Adulto';
      default:
        return widget.isEs ? 'Edad' : 'Idade';
    }
  }

  String _sexLabel(String value) {
    switch (value) {
      case 'male':
        return widget.isEs ? 'Masculino' : 'Masculino';
      case 'female':
        return widget.isEs ? 'Femenino' : 'Feminino';
      default:
        return 'Sexo';
    }
  }

  String _pregnancyLabel(String value) {
    switch (value) {
      case 'pregnant':
        return widget.isEs ? 'Embarazo' : 'Gestação';
      case 'not_pregnant':
        return widget.isEs ? 'No embarazo' : 'Não gestante';
      default:
        return widget.isEs ? 'Embarazo' : 'Gestação';
    }
  }

  String _methodLabel(String value) {
    switch (value) {
      case 'specific':
        return widget.isEs ? 'Específico' : 'Específico';
      case 'representative':
        return widget.isEs ? 'Representativo' : 'Representativo';
      default:
        return widget.isEs ? 'Método' : 'Método';
    }
  }

  Future<String?> _pick(
    String title,
    List<MapEntry<String, String>> options,
  ) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final safeBottom = MediaQuery.paddingOf(sheetContext).bottom;
        return Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 10 + safeBottom),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(top: BorderSide(color: _divider, width: 0.7)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 5),
                  child: Text(
                    title,
                    style: TextStyle(
                      color: _primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              ...options.map(
                (option) => InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.of(sheetContext).pop(option.key),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 42),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      option.value,
                      style: TextStyle(
                        color: _primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAge() async {
    final value = await _pick(
      widget.isEs ? 'Filtrar por edad' : 'Filtrar por idade',
      <MapEntry<String, String>>[
        MapEntry('all', widget.isEs ? 'Todas las edades' : 'Todas as idades'),
        MapEntry('newborn', widget.isEs ? '0–28 días' : '0–28 dias'),
        const MapEntry('infant', '1–23 meses'),
        MapEntry('child_2_5', widget.isEs ? '2–5 años' : '2–5 anos'),
        MapEntry('child_6_10', widget.isEs ? '6–10 años' : '6–10 anos'),
        MapEntry('adolescent', widget.isEs ? '11–17 años' : '11–17 anos'),
        const MapEntry('adult', 'Adulto'),
      ],
    );
    if (!mounted || value == null) return;
    setState(() => _age = value);
  }

  Future<void> _pickSex() async {
    final value = await _pick(
      widget.isEs ? 'Filtrar por sexo' : 'Filtrar por sexo',
      <MapEntry<String, String>>[
        MapEntry('all', widget.isEs ? 'Todos' : 'Todos'),
        const MapEntry('male', 'Masculino'),
        MapEntry('female', widget.isEs ? 'Femenino' : 'Feminino'),
      ],
    );
    if (!mounted || value == null) return;
    setState(() => _sex = value);
  }

  Future<void> _pickPregnancy() async {
    final value = await _pick(
      widget.isEs ? 'Filtrar por embarazo' : 'Filtrar por gestação',
      <MapEntry<String, String>>[
        MapEntry('all', widget.isEs ? 'Todos' : 'Todos'),
        MapEntry(
          'not_pregnant',
          widget.isEs ? 'No embarazo' : 'Não gestante',
        ),
        MapEntry('pregnant', widget.isEs ? 'Embarazo' : 'Gestação'),
      ],
    );
    if (!mounted || value == null) return;
    setState(() => _pregnancy = value);
  }

  Future<void> _pickMethod() async {
    final value = await _pick(
      widget.isEs ? 'Filtrar por método' : 'Filtrar por método',
      <MapEntry<String, String>>[
        MapEntry('all', widget.isEs ? 'Todos' : 'Todos'),
        const MapEntry('representative', 'Representativo'),
        const MapEntry('specific', 'Específico'),
      ],
    );
    if (!mounted || value == null) return;
    setState(() => _method = value);
  }

  List<LabReferenceCategory> get _categories {
    return LabReferenceCatalog.categories.where((category) {
      final records = LabReferenceCatalog.recordsForCategory(category.id)
          .where(
            (record) =>
                _LabPresentationFilter.methodMatches(record, _method) &&
                _LabPresentationFilter.recordMatches(
                  record,
                  age: _age,
                  sex: _sex,
                  pregnancy: _pregnancy,
                  isEs: widget.isEs,
                ),
          )
          .toList(growable: false);

      return records.isNotEmpty;
    }).toList(growable: false);
  }

  void _openCategory(LabReferenceCategory category) {
    FocusScope.of(context).unfocus();
    setState(() => _selectedCategory = category);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedCategory;
    if (selected != null) {
      return LaboratoryCategoryScreen(
        category: selected,
        dark: widget.dark,
        isEs: widget.isEs,
        age: _age,
        sex: _sex,
        pregnancy: _pregnancy,
        method: _method,
        query: '',
        embeddedInMainShell: widget.embeddedInMainShell,
        onBack: () => setState(() => _selectedCategory = null),
      );
    }

    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bottomClearance = widget.embeddedInMainShell
        ? (keyboardOpen ? 16.0 + safeBottom : 114.0 + safeBottom)
        : 28.0 + safeBottom;
    final categories = _categories;

    return Scaffold(
      backgroundColor: _background,
      // LABORATORIO_R8_NO_DOUBLE_KEYBOARD_RESIZE
      resizeToAvoidBottomInset: !widget.embeddedInMainShell,
      body: Column(
        children: [
          _LaboratoryRootTopbar(
            dark: widget.dark,
            title: 'LABORATORIO',
            textColor: _primary,
            divider: _divider,
            backTooltip: widget.isEs ? 'Volver' : 'Voltar',
            onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(4, 8, 4, bottomClearance),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(
                          () => _filtersExpanded = !_filtersExpanded,
                        ),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _hasFilter
                                  ? _accent.withOpacity(0.55)
                                  : _divider,
                              width: _hasFilter ? 0.8 : 0.55,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 16,
                                color: _hasFilter ? _accent : _secondary,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  'FILTRO',
                                  style: TextStyle(
                                    color:
                                        _hasFilter ? _accent : _secondary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.9,
                                  ),
                                ),
                              ),
                              AnimatedRotation(
                                turns: _filtersExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 160),
                                curve: Curves.easeOutCubic,
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color:
                                      _hasFilter ? _accent : _secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_hasFilter) ...[
                      const SizedBox(width: 5),
                      InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: _clearFilters,
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: _accent.withOpacity(0.38),
                              width: 0.65,
                            ),
                          ),
                          child: Text(
                            widget.isEs ? 'Limpiar' : 'Limpar',
                            style: const TextStyle(
                              color: _accent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _filtersExpanded
                      ? Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _FilterButton(
                                    label: _ageLabel(_age),
                                    active: _age != 'all',
                                    surface: _surface,
                                    divider: _divider,
                                    secondary: _secondary,
                                    accent: _accent,
                                    onTap: _pickAge,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: _FilterButton(
                                    label: _sexLabel(_sex),
                                    active: _sex != 'all',
                                    surface: _surface,
                                    divider: _divider,
                                    secondary: _secondary,
                                    accent: _accent,
                                    onTap: _pickSex,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Expanded(
                                  child: _FilterButton(
                                    label: _pregnancyLabel(_pregnancy),
                                    active: _pregnancy != 'all',
                                    surface: _surface,
                                    divider: _divider,
                                    secondary: _secondary,
                                    accent: _accent,
                                    onTap: _pickPregnancy,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: _FilterButton(
                                    label: _methodLabel(_method),
                                    active: _method != 'all',
                                    surface: _surface,
                                    divider: _divider,
                                    secondary: _secondary,
                                    accent: _accent,
                                    onTap: _pickMethod,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    widget.isEs ? 'CATEGORÍAS' : 'CATEGORIAS',
                    style: TextStyle(
                      color: _secondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (categories.isEmpty)
                  _EmptyCard(
                    text: widget.isEs
                        ? 'No hay resultados para este filtro.'
                        : 'Não há resultados para este filtro.',
                    surface: _surface,
                    divider: _divider,
                    secondary: _secondary,
                  )
                else
                  ...categories.map((category) {
                    final records = LabReferenceCatalog.recordsForCategory(
                      category.id,
                    )
                        .where(
                          (record) =>
                              _LabPresentationFilter.methodMatches(
                                  record, _method) &&
                              _LabPresentationFilter.recordMatches(
                                record,
                                age: _age,
                                sex: _sex,
                                pregnancy: _pregnancy,
                                isEs: widget.isEs,
                              ),
                        )
                        .toList(growable: false);
                    return _CategoryRow(
                      label: category.label(widget.isEs),
                      count: records.length,
                      primary: _primary,
                      secondary: _secondary,
                      surface: _surface,
                      divider: _divider,
                      accent: _accent,
                      onTap: () => _openCategory(category),
                    );
                  }),
                const SizedBox(height: 6),
                _InfoNote(
                  text: widget.isEs
                      ? 'El intervalo informado por el laboratorio ejecutor prevalece cuando difiere. No existe un “valor normal universal”.'
                      : 'O intervalo informado pelo laboratório executor prevalece quando houver diferença. Não existe um “valor normal universal”.',
                  color: _secondary,
                ),
                const SizedBox(height: 4),
                _InfoNote(
                  text: widget.isEs
                      ? 'Base clínica: agosto de 2026 · analitos organizados por fuente y contexto.'
                      : 'Base clínica: agosto de 2026 · analitos organizados por fonte e contexto.',
                  color: _secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LaboratoryCategoryScreen extends StatelessWidget {
  const LaboratoryCategoryScreen({
    required this.category,
    required this.dark,
    required this.isEs,
    required this.age,
    required this.sex,
    required this.pregnancy,
    required this.method,
    required this.query,
    required this.embeddedInMainShell,
    required this.onBack,
    super.key,
  });

  final LabReferenceCategory category;
  final bool dark;
  final bool isEs;
  final String age;
  final String sex;
  final String pregnancy;
  final String method;
  final String query;
  final bool embeddedInMainShell;
  final VoidCallback onBack;

  Color get _background =>
      dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
  Color get _surface =>
      dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
  Color get _divider =>
      dark ? const Color(0xFF374151) : const Color(0xFFD8E0E7);
  Color get _primary =>
      dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
  Color get _secondary =>
      dark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  static const Color _accent = Color(0xFF0D6B57);

  String _fold(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n');
  }

  @override
  Widget build(BuildContext context) {
    final q = _fold(query.trim());
    final categoryMatches =
        q.isNotEmpty && _fold(category.label(isEs)).contains(q);
    final records = LabReferenceCatalog.recordsForCategory(category.id)
        .where(
          (record) =>
              _LabPresentationFilter.methodMatches(record, method) &&
              (q.isEmpty ||
                  categoryMatches ||
                  _fold(record.name(isEs)).contains(q)) &&
              _LabPresentationFilter.recordMatches(
                record,
                age: age,
                sex: sex,
                pregnancy: pregnancy,
                isEs: isEs,
              ),
        )
        .toList(growable: false);

    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bottomClearance = embeddedInMainShell
        ? (keyboardOpen ? 16.0 + safeBottom : 114.0 + safeBottom)
        : 28.0 + safeBottom;

    return Scaffold(
      backgroundColor: _background,
      // LABORATORIO_R8_CATEGORY_NO_DOUBLE_KEYBOARD_RESIZE
      resizeToAvoidBottomInset: !embeddedInMainShell,
      body: Column(
        children: [
          _LaboratoryRootTopbar(
            dark: dark,
            title: category.label(isEs),
            textColor: _primary,
            divider: _divider,
            backTooltip: isEs ? 'Volver' : 'Voltar',
            onBack: onBack,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(4, 6, 4, bottomClearance),
              children: [
                if (age != 'all' ||
                    sex != 'all' ||
                    pregnancy != 'all' ||
                    method != 'all') ...[
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      if (age != 'all')
                        _ActiveFilterChip(
                          text: _filterDisplay(age, isEs),
                          color: _secondary,
                          divider: _divider,
                          surface: _surface,
                        ),
                      if (sex != 'all')
                        _ActiveFilterChip(
                          text: _filterDisplay(sex, isEs),
                          color: _secondary,
                          divider: _divider,
                          surface: _surface,
                        ),
                      if (pregnancy != 'all')
                        _ActiveFilterChip(
                          text: _filterDisplay(pregnancy, isEs),
                          color: _secondary,
                          divider: _divider,
                          surface: _surface,
                        ),
                      if (method != 'all')
                        _ActiveFilterChip(
                          text: _filterDisplay(method, isEs),
                          color: _secondary,
                          divider: _divider,
                          surface: _surface,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (records.isEmpty)
                  _EmptyCard(
                    text: isEs
                        ? 'No hay una franja explícita compatible con este filtro.'
                        : 'Não há uma faixa explícita compatível com este filtro.',
                    surface: _surface,
                    divider: _divider,
                    secondary: _secondary,
                  )
                else
                  ...records.map(
                    (record) => _AnalyteBlock(
                      record: record,
                      isEs: isEs,
                      age: age,
                      sex: sex,
                      pregnancy: pregnancy,
                      method: method,
                      primary: _primary,
                      secondary: _secondary,
                      surface: _surface,
                      divider: _divider,
                      accent: _accent,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _filterDisplay(String value, bool isEs) {
    switch (value) {
      case 'newborn':
        return isEs ? '0–28 días' : '0–28 dias';
      case 'infant':
        return '1–23 meses';
      case 'child_2_5':
        return isEs ? '2–5 años' : '2–5 anos';
      case 'child_6_10':
        return isEs ? '6–10 años' : '6–10 anos';
      case 'adolescent':
        return isEs ? '11–17 años' : '11–17 anos';
      case 'adult':
        return 'Adulto';
      case 'male':
        return 'Masculino';
      case 'female':
        return isEs ? 'Femenino' : 'Feminino';
      case 'pregnant':
        return isEs ? 'Embarazo' : 'Gestação';
      case 'not_pregnant':
        return isEs ? 'No embarazo' : 'Não gestante';
      case 'specific':
        return 'Específico';
      case 'representative':
        return 'Representativo';
      default:
        return value;
    }
  }
}

class _AgeSpan {
  const _AgeSpan(this.lowMonths, this.highMonths);

  final double lowMonths;
  final double highMonths;

  bool overlaps(_AgeSpan other) {
    return lowMonths < other.highMonths && other.lowMonths < highMonths;
  }
}

abstract final class _LabPresentationFilter {
  static bool methodMatches(LabReferenceRecord record, String method) {
    if (method == 'specific') return record.methodSpecific;
    if (method == 'representative') return !record.methodSpecific;
    return true;
  }

  static List<LabValueLine> lines(
    List<LabValueLine> source, {
    required String age,
    required String sex,
    required String pregnancy,
    required bool isEs,
  }) {
    return source
        .where(
          (line) => _lineMatches(
            line.label(isEs),
            age: age,
            sex: sex,
            pregnancy: pregnancy,
          ),
        )
        .toList(growable: false);
  }

  static bool recordMatches(
    LabReferenceRecord record, {
    required String age,
    required String sex,
    required String pregnancy,
    required bool isEs,
  }) {
    if (age == 'all' && sex == 'all' && pregnancy == 'all') return true;

    final groups = <List<LabValueLine>>[
      lines(
        record.referenceIntervals,
        age: age,
        sex: sex,
        pregnancy: pregnancy,
        isEs: isEs,
      ),
      lines(
        record.clinicalDecisionLimits,
        age: age,
        sex: sex,
        pregnancy: pregnancy,
        isEs: isEs,
      ),
      lines(
        record.criticalValues,
        age: age,
        sex: sex,
        pregnancy: pregnancy,
        isEs: isEs,
      ),
    ];

    final hasContextualLine = groups.any((group) => group.isNotEmpty);
    if (pregnancy == 'pregnant') return hasContextualLine;

    final hadAnyNumericContext = record.referenceIntervals.isNotEmpty ||
        record.clinicalDecisionLimits.isNotEmpty ||
        record.criticalValues.isNotEmpty;

    if (hadAnyNumericContext) return hasContextualLine;
    return record.qualitativeValues.isNotEmpty ||
        record.notes(isEs).isNotEmpty ||
        record.sourceTitle.isNotEmpty;
  }

  static bool _lineMatches(
    String label, {
    required String age,
    required String sex,
    required String pregnancy,
  }) {
    return _sexMatches(label, sex) &&
        _pregnancyMatches(label, pregnancy) &&
        _ageMatches(label, age);
  }

  static String _fold(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n')
        .replaceAll('–', '-')
        .replaceAll('—', '-');
  }

  static bool _sexMatches(String label, String sex) {
    if (sex == 'all') return true;
    final l = _fold(label).trim();

    final explicitMale = RegExp(r'^m(?:\s|(?=\d|[><=]))').hasMatch(l) ||
        l.contains('masculin') ||
        l.contains(' male');
    final explicitFemale = RegExp(r'^f(?:\s|(?=\d|[><=]))').hasMatch(l) ||
        l.contains('feminin') ||
        l.contains('femenin') ||
        l.contains(' female');

    if (sex == 'male') return !explicitFemale;
    if (sex == 'female') return !explicitMale;
    return true;
  }

  static bool _pregnancyMatches(String label, String pregnancy) {
    if (pregnancy == 'all') return true;
    final l = _fold(label);
    final specific = l.contains('gest') ||
        l.contains('embaraz') ||
        l.contains('pregnan') ||
        l.contains('trimestre') ||
        l.contains('trimester');
    if (pregnancy == 'pregnant') return specific;
    if (pregnancy == 'not_pregnant') return !specific;
    return true;
  }

  static bool _ageMatches(String label, String age) {
    if (age == 'all') return true;
    final parsed = _ageSpan(label);
    if (parsed == null) return true;
    return parsed.overlaps(_bucket(age));
  }

  static _AgeSpan _bucket(String age) {
    switch (age) {
      case 'newborn':
        return const _AgeSpan(0, 1);
      case 'infant':
        return const _AgeSpan(1, 24);
      case 'child_2_5':
        return const _AgeSpan(24, 72);
      case 'child_6_10':
        return const _AgeSpan(72, 132);
      case 'adolescent':
        return const _AgeSpan(132, 216);
      case 'adult':
        return const _AgeSpan(216, double.infinity);
      default:
        return const _AgeSpan(0, double.infinity);
    }
  }

  static _AgeSpan? _ageSpan(String label) {
    var l = _fold(label).trim();
    l = l.replaceFirst(RegExp(r'^[mf]\s+'), '');

    if (l.contains('adult')) {
      return const _AgeSpan(216, double.infinity);
    }

    final less = RegExp(
      r'(?:<|<=|≤)\s*(\d+(?:[.,]\d+)?)\s*(d|dia|dias|sem|semana|semanas|m|mes|meses|a|ano|anos)',
    ).firstMatch(l);
    if (less != null) {
      final high = _toMonths(less.group(1)!, less.group(2)!);
      return _AgeSpan(0, high);
    }

    final threshold = RegExp(
      r'(>=|≥|>)\s*(\d+(?:[.,]\d+)?)\s*(d|dia|dias|sem|semana|semanas|m|mes|meses|a|ano|anos)',
    ).firstMatch(l);
    if (threshold != null) {
      var low = _toMonths(threshold.group(2)!, threshold.group(3)!);
      if (threshold.group(1) == '>' &&
          <String>{'a', 'ano', 'anos'}.contains(threshold.group(3))) {
        low += 12;
      }
      return _AgeSpan(low, double.infinity);
    }

    final sameUnit = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*-\s*(\d+(?:[.,]\d+)?)\s*(d|dia|dias|sem|semana|semanas|m|mes|meses|a|ano|anos)',
    ).firstMatch(l);
    if (sameUnit != null) {
      final low = _toMonths(sameUnit.group(1)!, sameUnit.group(3)!);
      final highBase = _toMonths(sameUnit.group(2)!, sameUnit.group(3)!);
      return _AgeSpan(low, _inclusiveHigh(highBase, sameUnit.group(3)!));
    }

    final components = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(d|dia|dias|sem|semana|semanas|m|mes|meses|a|ano|anos)',
    ).allMatches(l).toList();
    if (components.length >= 2 && l.contains('-')) {
      final first = components[0];
      final second = components[1];
      final low = _toMonths(first.group(1)!, first.group(2)!);
      final highBase = _toMonths(second.group(1)!, second.group(2)!);
      return _AgeSpan(low, _inclusiveHigh(highBase, second.group(2)!));
    }

    if (components.length == 1) {
      final only = components.single;
      final point = _toMonths(only.group(1)!, only.group(2)!);
      return _AgeSpan(point, _inclusiveHigh(point, only.group(2)!));
    }

    return null;
  }

  static double _inclusiveHigh(double value, String unit) {
    if (<String>{'d', 'dia', 'dias'}.contains(unit)) return value + 1 / 30;
    if (<String>{'sem', 'semana', 'semanas'}.contains(unit)) {
      return value + 7 / 30;
    }
    if (<String>{'m', 'mes', 'meses'}.contains(unit)) return value + 1;
    return value + 12;
  }

  static double _toMonths(String raw, String unit) {
    final n = double.parse(raw.replaceAll(',', '.'));
    if (<String>{'d', 'dia', 'dias'}.contains(unit)) return n / 30;
    if (<String>{'sem', 'semana', 'semanas'}.contains(unit)) return n * 7 / 30;
    if (<String>{'m', 'mes', 'meses'}.contains(unit)) return n;
    return n * 12;
  }
}

class _AnalyteBlock extends StatefulWidget {
  const _AnalyteBlock({
    required this.record,
    required this.isEs,
    required this.age,
    required this.sex,
    required this.pregnancy,
    required this.method,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.divider,
    required this.accent,
  });

  final LabReferenceRecord record;
  final bool isEs;
  final String age;
  final String sex;
  final String pregnancy;
  final String method;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color divider;
  final Color accent;

  @override
  State<_AnalyteBlock> createState() => _AnalyteBlockState();
}

class _AnalyteBlockState extends State<_AnalyteBlock> {
  bool _expanded = false;

  List<LabValueLine> _visible(List<LabValueLine> source) {
    return _LabPresentationFilter.lines(
      source,
      age: widget.age,
      sex: widget.sex,
      pregnancy: widget.pregnancy,
      isEs: widget.isEs,
    );
  }

  bool get _filtersActive =>
      widget.age != 'all' ||
      widget.sex != 'all' ||
      widget.pregnancy != 'all' ||
      widget.method != 'all';

  LabValueLine? _adultMale(List<LabValueLine> lines) {
    for (final line in lines) {
      final label = line.label(widget.isEs).toLowerCase();
      if (label.contains('m adulto') ||
          label.contains('adulto m') ||
          label.contains('masculino adulto')) {
        return line;
      }
    }
    for (final line in lines) {
      if (line.label(widget.isEs).toLowerCase().contains('adult')) {
        return line;
      }
    }
    return null;
  }

  _AnalytePreview _preview() {
    final refs = _visible(widget.record.referenceIntervals);
    final decisions = _visible(widget.record.clinicalDecisionLimits);
    final critical = _visible(widget.record.criticalValues);

    if (!_filtersActive) {
      final defaultLine = _adultMale(widget.record.referenceIntervals) ??
          (widget.record.referenceIntervals.isNotEmpty
              ? widget.record.referenceIntervals.first
              : null);
      if (defaultLine != null) {
        return _AnalytePreview(
          value: defaultLine.value,
          detail: defaultLine.label(widget.isEs),
          explicit: true,
        );
      }
    }

    for (final group in <List<LabValueLine>>[refs, decisions, critical]) {
      if (group.isNotEmpty) {
        return _AnalytePreview(
          value: group.first.value,
          detail: group.first.label(widget.isEs),
          explicit: true,
        );
      }
    }

    if (widget.pregnancy != 'pregnant' &&
        widget.record.qualitativeValues.isNotEmpty) {
      return _AnalytePreview(
        value: widget.record.qualitativeValues.first,
        detail: widget.isEs ? 'Cualitativo' : 'Qualitativo',
        explicit: true,
      );
    }

    return _AnalytePreview(
      value: widget.isEs ? 'Sin rango explícito' : 'Sem faixa explícita',
      detail: widget.isEs ? 'Filtro aplicado' : 'Filtro aplicado',
      explicit: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview();
    final refs = _visible(widget.record.referenceIntervals);
    final decisions = _visible(widget.record.clinicalDecisionLimits);
    final critical = _visible(widget.record.criticalValues);
    final qualitative = widget.pregnancy == 'pregnant'
        ? const <String>[]
        : widget.record.qualitativeValues;
    final hasAny = refs.isNotEmpty ||
        decisions.isNotEmpty ||
        critical.isNotEmpty ||
        qualitative.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: widget.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _expanded
              ? widget.accent.withOpacity(0.42)
              : widget.divider,
          width: _expanded ? 0.8 : 0.55,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Row(
                children: [
                  Container(
                    width: 2.5,
                    height: 30,
                    decoration: BoxDecoration(
                      color: widget.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.record.name(widget.isEs),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.primary,
                            fontSize: 13.8,
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                          ),
                        ),
                        if (widget.record.unit.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.record.unit,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.secondary,
                              fontSize: 9.6,
                              fontWeight: FontWeight.w600,
                              height: 1.05,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 122),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          preview.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: widget.primary,
                            fontSize: 14.8,
                            fontWeight: FontWeight.w800,
                            height: 1.02,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          preview.detail.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: preview.explicit
                                ? widget.accent
                                : widget.secondary,
                            fontSize: 8.8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.25,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: widget.secondary,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Container(height: 0.55, color: widget.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (refs.isNotEmpty)
                    _ClinicalTableSection(
                      title: widget.isEs
                          ? 'INTERVALO DE REFERENCIA'
                          : 'INTERVALO DE REFERÊNCIA',
                      lines: refs,
                      isEs: widget.isEs,
                      primary: widget.primary,
                      secondary: widget.secondary,
                      divider: widget.divider,
                    ),
                  if (refs.isNotEmpty && decisions.isNotEmpty)
                    const SizedBox(height: 8),
                  if (decisions.isNotEmpty)
                    _ClinicalTableSection(
                      title: widget.isEs
                          ? 'LÍMITE DE DECISIÓN CLÍNICA'
                          : 'LIMITE DE DECISÃO CLÍNICA',
                      lines: decisions,
                      isEs: widget.isEs,
                      primary: widget.primary,
                      secondary: widget.secondary,
                      divider: widget.divider,
                    ),
                  if ((refs.isNotEmpty || decisions.isNotEmpty) &&
                      critical.isNotEmpty)
                    const SizedBox(height: 8),
                  if (critical.isNotEmpty)
                    _ClinicalTableSection(
                      title: widget.isEs ? 'VALOR CRÍTICO' : 'VALOR CRÍTICO',
                      lines: critical,
                      isEs: widget.isEs,
                      primary: widget.primary,
                      secondary: widget.secondary,
                      divider: widget.divider,
                    ),
                  if ((refs.isNotEmpty || decisions.isNotEmpty ||
                          critical.isNotEmpty) &&
                      qualitative.isNotEmpty)
                    const SizedBox(height: 8),
                  if (qualitative.isNotEmpty)
                    _CompactTextSection(
                      title: widget.isEs
                          ? 'RESULTADO ESPERADO'
                          : 'RESULTADO ESPERADO',
                      values: qualitative,
                      primary: widget.primary,
                      secondary: widget.secondary,
                      divider: widget.divider,
                    ),
                  if (!hasAny)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        widget.isEs
                            ? 'No existe una franja explícita compatible con el filtro seleccionado.'
                            : 'Não existe uma faixa explícita compatível com o filtro selecionado.',
                        style: TextStyle(
                          color: widget.secondary,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ),
                  if (hasAny) const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
                    decoration: BoxDecoration(
                      color: widget.secondary.withOpacity(0.045),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.divider,
                        width: 0.45,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.record.notes(widget.isEs).isNotEmpty)
                          _CompactMetaRow(
                            label: 'OBS.',
                            text: widget.record.notes(widget.isEs),
                            color: widget.secondary,
                          ),
                        if (widget.record.notes(widget.isEs).isNotEmpty)
                          const SizedBox(height: 3),
                        _CompactMetaRow(
                          label: 'REF.',
                          text: widget.record.sourceTitle,
                          color: widget.secondary,
                          italic: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnalytePreview {
  const _AnalytePreview({
    required this.value,
    required this.detail,
    required this.explicit,
  });

  final String value;
  final String detail;
  final bool explicit;
}

class _ClinicalTableSection extends StatelessWidget {
  const _ClinicalTableSection({
    required this.title,
    required this.lines,
    required this.isEs,
    required this.primary,
    required this.secondary,
    required this.divider,
  });

  final String title;
  final List<LabValueLine> lines;
  final bool isEs;
  final Color primary;
  final Color secondary;
  final Color divider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Label(text: title, color: secondary),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(1.45),
                1: FlexColumnWidth(0.85),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: divider.withOpacity(0.14),
                    border: Border(
                      bottom: BorderSide(color: divider, width: 0.7),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                      child: _TableCellText(
                        text: isEs
                            ? 'FRANJA / CONTEXTO'
                            : 'FAIXA / CONTEXTO',
                        color: secondary,
                        bold: true,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
                      child: _TableCellText(
                        text: 'VALOR',
                        color: secondary,
                        bold: true,
                        alignRight: true,
                      ),
                    ),
                  ],
                ),
                ...lines.map(
                  (line) => TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: divider, width: 0.4),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 11, 8, 11),
                        child: _TableCellText(
                          text: line.label(isEs),
                          color: secondary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 11, 10, 11),
                        child: _TableCellText(
                          text: line.value,
                          color: primary,
                          bold: true,
                          alignRight: true,
                        ),
                      ),
                    ],
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

class _TableCellText extends StatelessWidget {
  const _TableCellText({
    required this.text,
    required this.color,
    this.bold = false,
    this.alignRight = false,
  });

  final String text;
  final Color color;
  final bool bold;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          height: 1.18,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _CompactTextSection extends StatelessWidget {
  const _CompactTextSection({
    required this.title,
    required this.values,
    required this.primary,
    required this.secondary,
    required this.divider,
  });

  final String title;
  final List<String> values;
  final Color primary;
  final Color secondary;
  final Color divider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Label(text: title, color: secondary),
          const SizedBox(height: 5),
          ...values.map(
            (value) => Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: divider, width: 0.4),
                ),
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: primary,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMetaRow extends StatelessWidget {
  const _CompactMetaRow({
    required this.label,
    required this.text,
    required this.color,
    this.italic = false,
  });

  final String label;
  final String text;
  final Color color;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 10.2,
                height: 1.28,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LaboratoryRootTopbar extends StatelessWidget {
  const _LaboratoryRootTopbar({
    required this.dark,
    required this.title,
    required this.textColor,
    required this.divider,
    required this.backTooltip,
    required this.onBack,
  });

  final bool dark;
  final String title;
  final Color textColor;
  final Color divider;
  final String backTooltip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    // LABORATORIO_R8_HOME_TOPBAR_SAFE_AREA_OWNER
    final topPad =
        View.of(context).padding.top / View.of(context).devicePixelRatio;
    final glassColor = dark
        ? const Color(0xFF252930).withOpacity(0.70)
        : Colors.white.withOpacity(0.70);

    return SizedBox(
      height: topPad + 48,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: glassColor,
                    border: Border(
                      bottom: BorderSide(color: divider, width: 0.7),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: topPad,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 52),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 6,
                  child: Tooltip(
                    message: backTooltip,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onBack,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                            color: textColor,
                          ),
                        ),
                      ),
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

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.active,
    required this.surface,
    required this.divider,
    required this.secondary,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color surface;
  final Color divider;
  final Color secondary;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(
            color: active ? accent.withOpacity(0.55) : divider,
            width: active ? 0.8 : 0.55,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? accent : secondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: active ? accent : secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.count,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.divider,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color divider;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: divider, width: 0.55),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              Container(width: 4, height: 54, color: accent),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: TextStyle(
                  color: secondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 7),
              Icon(
                Icons.chevron_right_rounded,
                color: secondary,
                size: 20,
              ),
              const SizedBox(width: 7),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({
    required this.text,
    required this.color,
    required this.divider,
    required this.surface,
  });

  final String text;
  final Color color;
  final Color divider;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 27),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: divider, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.text,
    required this.surface,
    required this.divider,
    required this.secondary,
  });

  final String text;
  final Color surface;
  final Color divider;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: divider, width: 0.55),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: secondary,
          fontSize: 11.5,
          height: 1.3,
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Text(
        text,
        style: TextStyle(
          color: color.withOpacity(0.74),
          fontSize: 9.8,
          height: 1.24,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 9.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.65,
      ),
    );
  }
}
