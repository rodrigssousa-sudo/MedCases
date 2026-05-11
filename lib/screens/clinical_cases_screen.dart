import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/clinical_case_model.dart';
import '../data/clinical_cases_database.dart';
import '../widgets/common_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cores locais (alinhadas ao design system do app)
// ─────────────────────────────────────────────────────────────────────────────
const _kDark   = Color(0xFF07110d);
const _kGreen  = Color(0xFF075f45);
const _kGold   = Color(0xFFC5A365);
const _kGoldL  = Color(0xFFFFE8A6);

const _kBorder = Color(0xFFE2E6EA);

// ─────────────────────────────────────────────────────────────────────────────
// Mapeamento de categorias → cor + ícone
// ─────────────────────────────────────────────────────────────────────────────
const _kCategories = [
  'Todas',
  'Infectologia / Urologia',
  'Neurologia',
  'Medicina Interna',
  'Endocrinologia',
  'Cardiologia',
  'Cardiologia / Pneumologia',
  'Emergência / Alergologia',
  'Pneumologia / Infectologia',
  'Gastroenterologia',
];

Color _catColor(String cat) {
  switch (cat) {
    case 'Neurologia':              return const Color(0xFF5C2D91);
    case 'Cardiologia':             return const Color(0xFFAA1144);
    case 'Cardiologia / Pneumologia': return const Color(0xFF991133);
    case 'Infectologia / Urologia': return const Color(0xFF1A6E38);
    case 'Medicina Interna':        return const Color(0xFF2255AA);
    case 'Endocrinologia':          return const Color(0xFF885500);
    case 'Emergência / Alergologia': return const Color(0xFFCC4400);
    case 'Pneumologia / Infectologia': return const Color(0xFF1A5E8A);
    case 'Gastroenterologia':       return const Color(0xFF4A7A1E);
    default:                        return _kGreen;
  }
}

IconData _catIcon(String cat) {
  switch (cat) {
    case 'Neurologia':              return Icons.psychology_rounded;
    case 'Cardiologia':             return Icons.favorite_rounded;
    case 'Cardiologia / Pneumologia': return Icons.monitor_heart_rounded;
    case 'Infectologia / Urologia': return Icons.biotech_rounded;
    case 'Medicina Interna':        return Icons.local_hospital_rounded;
    case 'Endocrinologia':          return Icons.science_rounded;
    case 'Emergência / Alergologia': return Icons.warning_amber_rounded;
    case 'Pneumologia / Infectologia': return Icons.air_rounded;
    case 'Gastroenterologia':       return Icons.medical_services_rounded;
    default:                        return Icons.cases_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TELA PRINCIPAL — ClinicalCasesScreen
// ─────────────────────────────────────────────────────────────────────────────
class ClinicalCasesScreen extends StatefulWidget {
  const ClinicalCasesScreen({super.key});

  @override
  State<ClinicalCasesScreen> createState() => _ClinicalCasesScreenState();
}

class _ClinicalCasesScreenState extends State<ClinicalCasesScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedCat = 'Todas';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ClinicalCaseModel> get _filtered {
    final q = _searchCtrl.text.toLowerCase().trim();
    return kClinicalCasesDB.where((c) {
      final matchCat = _selectedCat == 'Todas' || c.category == _selectedCat;
      if (!matchCat) return false;
      if (q.isEmpty) return true;
      return c.title.toLowerCase().contains(q) ||
          c.category.toLowerCase().contains(q) ||
          c.history.toLowerCase().contains(q) ||
          c.diagnosis.toLowerCase().contains(q);
    }).toList();
  }

  void _openDetail(ClinicalCaseModel c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClinicalCaseDetailSheet(caseModel: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p      = context.watch<AppProvider>();
    final dark   = p.darkMode;
    final cases  = _filtered;

    return Column(children: [
      // ── Header premium ──────────────────────────────────────────────────────
      PremiumCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: SafeArea(
          bottom: false,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: SectionTitle(
                eyebrow: 'Clinical Cases',
                title: 'Casos Clínicos',
                subtitle: '${kClinicalCasesDB.length} casos comentados com IA integrada',
                light: true,
              ),
            ),
            // badge de contagem
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: _kGold.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${kClinicalCasesDB.length}',
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: _kGoldL),
              ),
            ),
          ]),
        ),
      ),

      // ── Busca + filtros ─────────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Campo de busca
          _SearchField(
            controller: _searchCtrl,
            dark: dark,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          // Chips de categoria
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _kCategories[i];
                final active = _selectedCat == cat;
                return _CategoryChip(
                  label: cat == 'Todas' ? 'Todas' : cat.split(' /').first,
                  active: active,
                  color: cat == 'Todas' ? _kGreen : _catColor(cat),
                  dark: dark,
                  onTap: () => setState(() => _selectedCat = cat),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // contador de resultados
          Text(
            '${cases.length} caso${cases.length != 1 ? "s" : ""} encontrado${cases.length != 1 ? "s" : ""}',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: dark ? Colors.white38 : Colors.grey[500]),
          ),
        ]),
      ),

      const SizedBox(height: 8),

      // ── Lista de casos ──────────────────────────────────────────────────────
      Expanded(
        child: cases.isEmpty
            ? _EmptyState(dark: dark)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: cases.length,
                itemBuilder: (_, i) => _ClinicalCaseCard(
                  c: cases[i],
                  dark: dark,
                  isLast: i == cases.length - 1,
                  onTap: () => _openDetail(cases[i]),
                ),
              ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Campo de busca
// ─────────────────────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool dark;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.dark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: dark ? const Color(0xFF1C2A22) : Colors.white,
        border: Border.all(
          color: dark ? const Color(0xFF2A4030) : _kBorder,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: dark ? Colors.white : _kDark,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar por título, categoria, sintoma...',
          hintStyle: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500,
            color: dark ? Colors.white38 : Colors.grey[400],
          ),
          prefixIcon: Icon(
            Icons.search_rounded, size: 20,
            color: dark ? Colors.white38 : Colors.grey[400],
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, size: 18,
                    color: dark ? Colors.white38 : Colors.grey[400]),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip de categoria
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final bool dark;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.active,
    required this.color,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active
              ? color
              : dark ? const Color(0xFF1C2A22) : Colors.white,
          border: Border.all(
            color: active
                ? color
                : dark ? const Color(0xFF2A4030) : _kBorder,
            width: active ? 0 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active
                ? Colors.white
                : dark ? Colors.white54 : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card de caso clínico
// ─────────────────────────────────────────────────────────────────────────────
class _ClinicalCaseCard extends StatelessWidget {
  final ClinicalCaseModel c;
  final bool dark;
  final bool isLast;
  final VoidCallback onTap;

  const _ClinicalCaseCard({
    required this.c,
    required this.dark,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = _catColor(c.category);
    final catIcon  = _catIcon(c.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: dark ? const Color(0xFF151E18) : Colors.white,
          border: Border.all(
            color: dark ? const Color(0xFF1E2E22) : _kBorder,
          ),
          boxShadow: dark ? null : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Ícone de categoria
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: catColor.withValues(alpha: 0.12),
              border: Border.all(color: catColor.withValues(alpha: 0.25)),
            ),
            child: Icon(catIcon, size: 20, color: catColor),
          ),
          const SizedBox(width: 12),

          // Título + info do paciente
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                c.title,
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, height: 1.3,
                  color: dark ? Colors.white : _kDark,
                ),
              ),
              const SizedBox(height: 4),
              // Dados do paciente
              if (c.patientAge.isNotEmpty || c.patientSex.isNotEmpty) ...[
                Row(children: [
                  if (c.patientAge.isNotEmpty) ...[
                    Icon(Icons.person_rounded, size: 12,
                      color: dark ? Colors.white38 : Colors.grey[400]),
                    const SizedBox(width: 3),
                    Text('${c.patientAge} anos', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: dark ? Colors.white54 : Colors.grey[600],
                    )),
                    const SizedBox(width: 8),
                  ],
                  if (c.patientSex.isNotEmpty) ...[
                    Icon(
                      c.patientSex == 'Feminino'
                          ? Icons.female_rounded
                          : Icons.male_rounded,
                      size: 12,
                      color: dark ? Colors.white38 : Colors.grey[400],
                    ),
                    const SizedBox(width: 3),
                    Text(c.patientSex, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: dark ? Colors.white54 : Colors.grey[600],
                    )),
                  ],
                ]),
                const SizedBox(height: 6),
              ],
              // Badge de categoria
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: catColor.withValues(alpha: 0.1),
                ),
                child: Text(
                  c.category,
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: catColor, letterSpacing: 0.3,
                  ),
                ),
              ),
            ]),
          ),

          // Seta + indicador de IA
          Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: dark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: _kGreen.withValues(alpha: 0.12),
                border: Border.all(color: _kGreen.withValues(alpha: 0.25)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.auto_awesome_rounded, size: 9, color: _kGreen),
                SizedBox(width: 3),
                Text('IA', style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w900, color: _kGreen)),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado vazio
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool dark;
  const _EmptyState({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: dark ? Colors.white12 : Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhum caso encontrado',
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: dark ? Colors.white38 : Colors.grey[500]),
          ),
          const SizedBox(height: 4),
          Text(
            'Tente outro termo ou categoria.',
            style: TextStyle(
              fontSize: 12,
              color: dark ? Colors.white24 : Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET — detalhe completo do caso + botão IA
// ─────────────────────────────────────────────────────────────────────────────
class _ClinicalCaseDetailSheet extends StatefulWidget {
  final ClinicalCaseModel caseModel;
  const _ClinicalCaseDetailSheet({required this.caseModel});

  @override
  State<_ClinicalCaseDetailSheet> createState() => _ClinicalCaseDetailSheetState();
}

class _ClinicalCaseDetailSheetState extends State<_ClinicalCaseDetailSheet> {
  bool _aiLoading  = false;
  String? _aiAnswer;
  bool _aiError    = false;
  bool _showAiPanel = false;

  // Monta o prompt clínico com todo o contexto do caso
  String _buildPrompt() {
    final c = widget.caseModel;
    final sb = StringBuffer();
    sb.writeln('=== CASO CLÍNICO: ${c.title} ===');
    sb.writeln();
    if (c.patientAge.isNotEmpty)
      sb.writeln('• Paciente: ${c.patientSex}, ${c.patientAge} anos'
          '${c.patientWeight.isNotEmpty ? ", ${c.patientWeight} kg" : ""}');
    sb.writeln();
    if (c.history.isNotEmpty) {
      sb.writeln('--- HISTÓRIA CLÍNICA ---');
      sb.writeln(c.history.trim());
      sb.writeln();
    }
    if (c.diagnosis.isNotEmpty) {
      sb.writeln('--- DIAGNÓSTICO ---');
      sb.writeln(c.diagnosis.trim());
      sb.writeln();
    }
    if (c.plan.isNotEmpty) {
      sb.writeln('--- PLANO TERAPÊUTICO ---');
      sb.writeln(c.plan.trim());
      sb.writeln();
    }
    if (c.notes.isNotEmpty) {
      sb.writeln('--- NOTAS / PERLAS CLÍNICAS ---');
      sb.writeln(c.notes.trim());
      sb.writeln();
    }
    sb.writeln('Analise este caso clinicamente. Comente os pontos-chave do diagnóstico, '
        'o raciocínio por trás do plano terapêutico e destaque perlas educacionais '
        'relevantes para médicos em formação.');
    return sb.toString();
  }

  Future<void> _consultIA() async {
    final p = context.read<AppProvider>();
    setState(() {
      _aiLoading  = true;
      _aiAnswer   = null;
      _aiError    = false;
      _showAiPanel = true;
    });

    final prompt = _buildPrompt();
    final answer = await p.buildAIAnswer(prompt);

    if (!mounted) return;
    setState(() {
      _aiLoading = false;
      _aiAnswer  = answer;
      _aiError   = answer.startsWith('❌') && answer.contains('API');
    });
  }

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final c    = widget.caseModel;
    final catColor = _catColor(c.category);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF0E1612) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: dark ? Colors.white24 : Colors.grey[300],
                ),
              ),
            ),

            // ── Cabeçalho do caso ──────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kDark, const Color(0xFF123326), _kGreen],
                ),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  child: Icon(_catIcon(c.category), size: 22, color: _kGoldL),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.title, style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900,
                      color: Colors.white, height: 1.3,
                    )),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (c.patientAge.isNotEmpty) ...[
                        const Icon(Icons.person_rounded, size: 11, color: _kGoldL),
                        const SizedBox(width: 3),
                        Text('${c.patientSex}, ${c.patientAge} anos'
                            '${c.patientWeight.isNotEmpty ? " · ${c.patientWeight} kg" : ""}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.75))),
                      ],
                    ]),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: catColor.withValues(alpha: 0.25),
                        border: Border.all(color: catColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(c.category, style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: catColor == const Color(0xFF1A6E38) ? _kGoldL : Colors.white70,
                        letterSpacing: 0.3,
                      )),
                    ),
                  ]),
                ),
              ]),
            ),

            // ── Botão "Consultar IA" ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _AiConsultButton(
                loading: _aiLoading,
                hasAnswer: _aiAnswer != null,
                onTap: _aiLoading ? null : _consultIA,
              ),
            ),

            // ── Conteúdo scrollável ────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [

                  // Painel IA (aparece após chamar a IA)
                  if (_showAiPanel) ...[
                    _AiAnswerPanel(
                      loading: _aiLoading,
                      answer: _aiAnswer,
                      isError: _aiError,
                      dark: dark,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── História Clínica ─────────────────────────────────────
                  if (c.history.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.history_edu_rounded,
                      label: 'História Clínica',
                      color: const Color(0xFF2255AA),
                      dark: dark,
                    ),
                    const SizedBox(height: 8),
                    _SectionContent(text: c.history.trim(), dark: dark),
                    const SizedBox(height: 16),
                  ],

                  // ── Diagnóstico ──────────────────────────────────────────
                  if (c.diagnosis.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.rule_rounded,
                      label: 'Diagnóstico',
                      color: catColor,
                      dark: dark,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: catColor.withValues(alpha: 0.08),
                        border: Border.all(color: catColor.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        c.diagnosis.trim(),
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          height: 1.5,
                          color: dark ? Colors.white.withValues(alpha: 0.87) : _kDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Plano Terapêutico ────────────────────────────────────
                  if (c.plan.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.playlist_add_check_rounded,
                      label: 'Plano Terapêutico',
                      color: _kGreen,
                      dark: dark,
                    ),
                    const SizedBox(height: 8),
                    _PlanContent(plan: c.plan.trim(), dark: dark),
                    const SizedBox(height: 16),
                  ],

                  // ── Notas / Perlas clínicas ──────────────────────────────
                  if (c.notes.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.tips_and_updates_rounded,
                      label: 'Perla Clínica',
                      color: const Color(0xFFC5A365),
                      dark: dark,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFFFFBF0),
                        border: Border.all(color: const Color(0xFFE8D8A0)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.lightbulb_rounded,
                          size: 16, color: Color(0xFFC5A365)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.notes.trim(),
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              height: 1.5,
                              color: dark ? const Color(0xFF8B6914) : const Color(0xFF7A5500),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Fármacos mencionados ─────────────────────────────────
                  if (c.drugIds.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.medication_rounded,
                      label: 'Fármacos do Caso',
                      color: const Color(0xFF5C2D91),
                      dark: dark,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: c.drugIds.map((id) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFF5C2D91).withValues(alpha: 0.1),
                          border: Border.all(
                            color: const Color(0xFF5C2D91).withValues(alpha: 0.2)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.medication_rounded,
                            size: 12, color: Color(0xFF5C2D91)),
                          const SizedBox(width: 4),
                          Text(
                            id.replaceAll('_', ' '),
                            style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Color(0xFF5C2D91)),
                          ),
                        ]),
                      )).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botão de Consultar IA
// ─────────────────────────────────────────────────────────────────────────────
class _AiConsultButton extends StatelessWidget {
  final bool loading;
  final bool hasAnswer;
  final VoidCallback? onTap;

  const _AiConsultButton({
    required this.loading,
    required this.hasAnswer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: loading
                ? [const Color(0xFF1A4030), const Color(0xFF1A4030)]
                : [_kGreen, const Color(0xFF0A4A35)],
          ),
          boxShadow: loading ? null : [
            BoxShadow(
              color: _kGreen.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (loading)
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                color: _kGoldL, strokeWidth: 2),
            )
          else
            const Icon(Icons.auto_awesome_rounded, size: 18, color: _kGoldL),
          const SizedBox(width: 10),
          Text(
            loading
                ? 'Consultando IA...'
                : hasAnswer
                    ? 'Atualizar resposta da IA'
                    : 'Consultar IA sobre este caso',
            style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800,
              color: _kGoldL, letterSpacing: 0.2,
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painel de resposta da IA
// ─────────────────────────────────────────────────────────────────────────────
class _AiAnswerPanel extends StatelessWidget {
  final bool loading;
  final String? answer;
  final bool isError;
  final bool dark;

  const _AiAnswerPanel({
    required this.loading,
    required this.answer,
    required this.isError,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: dark
            ? const Color(0xFF0D1F16)
            : const Color(0xFFF0F9F4),
        border: Border.all(
          color: isError
              ? const Color(0xFFCC2222).withValues(alpha: 0.3)
              : _kGreen.withValues(alpha: 0.25),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header IA
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _kGreen.withValues(alpha: 0.15),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome_rounded, size: 12, color: _kGreen),
              SizedBox(width: 5),
              Text('Análise IA', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900, color: _kGreen)),
            ]),
          ),
          const SizedBox(width: 8),
          if (!loading && answer != null)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: answer!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copiado para a área de transferência'),
                    duration: Duration(seconds: 2),
                    backgroundColor: _kGreen,
                  ),
                );
              },
              child: Icon(Icons.copy_rounded, size: 14,
                color: dark ? Colors.white38 : Colors.grey[400]),
            ),
        ]),
        const SizedBox(height: 10),

        // Conteúdo
        if (loading)
          Row(children: [
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2)),
            const SizedBox(width: 10),
            Text('Analisando o caso clínico...', style: TextStyle(
              fontSize: 13, color: dark ? Colors.white54 : Colors.grey[600],
              fontStyle: FontStyle.italic)),
          ])
        else if (answer != null)
          SelectableText(
            answer!,
            style: TextStyle(
              fontSize: 13, height: 1.6, fontWeight: FontWeight.w500,
              color: isError
                  ? const Color(0xFFCC2222)
                  : dark ? Colors.white.withValues(alpha: 0.87) : const Color(0xFF1A2E22),
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cabeçalho de seção
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool dark;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.12),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(width: 8),
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w900,
          letterSpacing: 1.2, color: color,
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conteúdo de seção (texto formatado)
// ─────────────────────────────────────────────────────────────────────────────
class _SectionContent extends StatelessWidget {
  final String text;
  final bool dark;

  const _SectionContent({required this.text, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: dark ? const Color(0xFF151E18) : const Color(0xFFF8F9F8),
        border: Border.all(
          color: dark ? const Color(0xFF1E2E22) : _kBorder,
        ),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: 13, height: 1.65, fontWeight: FontWeight.w500,
          color: dark ? Colors.white.withValues(alpha: 0.87) : const Color(0xFF2A2A2A),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plano terapêutico formatado (itens numerados)
// ─────────────────────────────────────────────────────────────────────────────
class _PlanContent extends StatelessWidget {
  final String plan;
  final bool dark;

  const _PlanContent({required this.plan, required this.dark});

  @override
  Widget build(BuildContext context) {
    // Cada linha numerada vira um item visual separado
    final lines = plan
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        // Detectar se começa com número (ex: "1.", "2.", etc.)
        final isNumbered = RegExp(r'^\d+\.').hasMatch(line);
        final isAlert    = line.contains('IMEDIATO') ||
            line.contains('URGENTE') || line.contains('INICIAR');

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isAlert
                ? const Color(0xFFCC2222).withValues(alpha: 0.06)
                : dark
                    ? const Color(0xFF151E18)
                    : const Color(0xFFF5FAF6),
            border: Border.all(
              color: isAlert
                  ? const Color(0xFFCC2222).withValues(alpha: 0.2)
                  : dark
                      ? const Color(0xFF1E2E22)
                      : const Color(0xFFD0E8D8),
            ),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (isAlert)
              const Padding(
                padding: EdgeInsets.only(right: 6, top: 1),
                child: Icon(Icons.priority_high_rounded,
                  size: 14, color: Color(0xFFCC2222)),
              )
            else if (isNumbered)
              Container(
                width: 20, height: 20,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kGreen.withValues(alpha: 0.15),
                ),
                child: Center(
                  child: Text(
                    line.substring(0, line.indexOf('.')),
                    style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w900, color: _kGreen),
                  ),
                ),
              )
            else
              const SizedBox(width: 4),
            Expanded(
              child: Text(
                isNumbered
                    ? line.substring(line.indexOf('.') + 1).trim()
                    : line,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isAlert ? FontWeight.w800 : FontWeight.w600,
                  height: 1.5,
                  color: isAlert
                      ? const Color(0xFFCC2222)
                      : dark ? Colors.white.withValues(alpha: 0.87) : const Color(0xFF1A2E22),
                ),
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }
}
