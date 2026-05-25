import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';
import '../services/drug_interaction_service.dart';
import '../data/drugs_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────
void openDrugInteractionsScreen(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => const DrugInteractionsScreen(),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 280),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DRUG INTERACTIONS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class DrugInteractionsScreen extends StatefulWidget {
  const DrugInteractionsScreen({super.key});

  @override
  State<DrugInteractionsScreen> createState() => _DrugInteractionsScreenState();
}

class _DrugInteractionsScreenState extends State<DrugInteractionsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<String> _selectedDrugs = [];
  List<String> _searchSuggestions = [];
  List<DrugInteraction> _interactions = [];
  bool _hasSearched = false;
  bool _showSuggestions = false;

  // Todos os nomes conhecidos pelo serviço
  late final List<String> _allDrugNames;

  @override
  void initState() {
    super.initState();
    _allDrugNames = DrugInteractionService.getAllDrugNames();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    final filtered = _allDrugNames
        .where((n) => n.contains(q))
        .take(8)
        .toList();
    setState(() {
      _searchSuggestions = filtered;
      _showSuggestions = filtered.isNotEmpty;
    });
  }

  void _addDrug(String name) {
    // Capitalizar primeira letra
    final display = name.isNotEmpty
        ? '${name[0].toUpperCase()}${name.substring(1)}'
        : name;
    if (_selectedDrugs.any((d) => d.toLowerCase() == name.toLowerCase())) {
      _searchCtrl.clear();
      setState(() { _showSuggestions = false; });
      return;
    }
    setState(() {
      _selectedDrugs.add(display);
      _searchCtrl.clear();
      _showSuggestions = false;
      _hasSearched = false;
      _interactions = [];
    });
    _searchFocus.unfocus();
  }

  void _removeDrug(String name) {
    setState(() {
      _selectedDrugs.remove(name);
      _hasSearched = false;
      _interactions = [];
    });
  }

  void _checkInteractions() {
    if (_selectedDrugs.length < 2) return;
    _searchFocus.unfocus();
    final results = DrugInteractionService.checkSelectedOnly(_selectedDrugs);
    setState(() {
      _interactions = results;
      _hasSearched = true;
    });
  }

  void _reset() {
    setState(() {
      _selectedDrugs = [];
      _interactions = [];
      _hasSearched = false;
      _searchCtrl.clear();
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';
    final c    = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _Header(dark: dark, isEs: isEs, c: c),

            // ── Conteúdo principal ──────────────────────────────────────────
            Expanded(
              child: GestureDetector(
                onTap: () {
                  _searchFocus.unfocus();
                  setState(() { _showSuggestions = false; });
                },
                behavior: HitTestBehavior.opaque,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Campo de busca ────────────────────────────────────
                      _SearchField(
                        ctrl: _searchCtrl,
                        focusNode: _searchFocus,
                        dark: dark,
                        isEs: isEs,
                        c: c,
                      ),

                      // ── Sugestões autocomplete ────────────────────────────
                      if (_showSuggestions)
                        _SuggestionsDropdown(
                          suggestions: _searchSuggestions,
                          dark: dark,
                          c: c,
                          onSelect: _addDrug,
                        ),

                      const SizedBox(height: 14),

                      // ── Chips dos fármacos selecionados ───────────────────
                      if (_selectedDrugs.isNotEmpty) ...[
                        _SelectedDrugsChips(
                          drugs: _selectedDrugs,
                          dark: dark,
                          isEs: isEs,
                          c: c,
                          onRemove: _removeDrug,
                        ),
                        const SizedBox(height: 18),
                      ],

                      // ── Botão Avaliar ─────────────────────────────────────
                      if (_selectedDrugs.length >= 2 && !_hasSearched) ...[
                        _AvaliarButton(
                          isEs: isEs,
                          dark: dark,
                          onTap: _checkInteractions,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Estado vazio — nenhum fármaco selecionado ─────────
                      if (_selectedDrugs.isEmpty && !_hasSearched)
                        _EmptyState(dark: dark, isEs: isEs, c: c),

                      // ── Instrução — só 1 fármaco ──────────────────────────
                      if (_selectedDrugs.length == 1 && !_hasSearched)
                        _OneMoreDrugHint(dark: dark, isEs: isEs, c: c),

                      // ── Resultados ────────────────────────────────────────
                      if (_hasSearched) ...[
                        _ResultsHeader(
                          count: _interactions.length,
                          dark: dark,
                          isEs: isEs,
                          c: c,
                          drugsCount: _selectedDrugs.length,
                          onNewAnalysis: _reset,
                        ),
                        const SizedBox(height: 16),

                        if (_interactions.isEmpty)
                          _NoInteractionsFound(
                            dark: dark,
                            isEs: isEs,
                            c: c,
                            drugs: _selectedDrugs,
                          )
                        else
                          ..._interactions.map(
                            (ix) => _InteractionCard(
                              interaction: ix,
                              dark: dark,
                              isEs: isEs,
                              c: c,
                            ),
                          ),

                        const SizedBox(height: 28),
                        _NewAnalysisButton(
                          isEs: isEs,
                          dark: dark,
                          onTap: _reset,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final AppColors c;

  const _Header({required this.dark, required this.isEs, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 18, 10),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          bottom: BorderSide(color: c.border.withValues(alpha: 0.5), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Botão voltar
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.textPrimary, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 20,
            padding: const EdgeInsets.all(8),
          ),

          // Ícone + título
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Color(0xFF1A0A2E), Color(0xFF3D1F6B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.compare_arrows_rounded,
              color: Color(0xFFD8B4FE),
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs ? 'Interacciones' : 'Interações',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  isEs ? 'Verificación medicamentosa' : 'Verificação medicamentosa',
                  style: TextStyle(
                    fontSize: 11,
                    color: c.textHint,
                  ),
                ),
              ],
            ),
          ),

          // Badge "337 fármacos"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF3D1F6B).withValues(alpha: dark ? 0.4 : 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF9F7AEA).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              isEs ? '$uniqueDrugsCount fármacos' : '$uniqueDrugsCount fármacos',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFFA78BFA),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMPO DE BUSCA
// ─────────────────────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final bool dark;
  final bool isEs;
  final AppColors c;

  const _SearchField({
    required this.ctrl,
    required this.focusNode,
    required this.dark,
    required this.isEs,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF1A1A2E).withValues(alpha: 0.6)
            : const Color(0xFFF3F0FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF9F7AEA).withValues(alpha: dark ? 0.25 : 0.2),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.search_rounded,
            color: const Color(0xFFA78BFA),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctrl,
              focusNode: focusNode,
              style: TextStyle(
                fontSize: 15,
                color: c.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: isEs
                    ? 'Buscar medicamento...'
                    : 'Buscar medicamento...',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: c.textHint,
                  fontWeight: FontWeight.w400,
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: () => ctrl.clear(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.close_rounded,
                  color: c.textHint,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DROPDOWN DE SUGESTÕES
// ─────────────────────────────────────────────────────────────────────────────
class _SuggestionsDropdown extends StatelessWidget {
  final List<String> suggestions;
  final bool dark;
  final AppColors c;
  final ValueChanged<String> onSelect;

  const _SuggestionsDropdown({
    required this.suggestions,
    required this.dark,
    required this.c,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1C1C2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF9F7AEA).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.4 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: suggestions.asMap().entries.map((entry) {
          final i    = entry.key;
          final name = entry.value;
          final display = name.isNotEmpty
              ? '${name[0].toUpperCase()}${name.substring(1)}'
              : name;
          return GestureDetector(
            onTap: () => onSelect(name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: i < suggestions.length - 1
                    ? Border(
                        bottom: BorderSide(
                          color: c.border.withValues(alpha: 0.3),
                          width: 0.7,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.medication_rounded,
                    size: 16,
                    color: const Color(0xFFA78BFA),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      display,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 16,
                    color: const Color(0xFFA78BFA).withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHIPS DE FÁRMACOS SELECIONADOS
// ─────────────────────────────────────────────────────────────────────────────
class _SelectedDrugsChips extends StatelessWidget {
  final List<String> drugs;
  final bool dark;
  final bool isEs;
  final AppColors c;
  final ValueChanged<String> onRemove;

  const _SelectedDrugsChips({
    required this.drugs,
    required this.dark,
    required this.isEs,
    required this.c,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEs ? 'Seleccionados (${drugs.length})' : 'Selecionados (${drugs.length})',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: c.textHint,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: drugs.map((drug) => _DrugChip(
            name: drug,
            dark: dark,
            c: c,
            onRemove: () => onRemove(drug),
          )).toList(),
        ),
      ],
    );
  }
}

class _DrugChip extends StatelessWidget {
  final String name;
  final bool dark;
  final AppColors c;
  final VoidCallback onRemove;

  const _DrugChip({
    required this.name,
    required this.dark,
    required this.c,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF2A1A4E)
            : const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF9F7AEA).withValues(alpha: dark ? 0.35 : 0.3),
          width: 1.1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: dark ? const Color(0xFFD8B4FE) : const Color(0xFF6D28D9),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF9F7AEA).withValues(alpha: 0.25),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 12,
                color: dark ? const Color(0xFFD8B4FE) : const Color(0xFF7C3AED),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTÃO AVALIAR
// ─────────────────────────────────────────────────────────────────────────────
class _AvaliarButton extends StatelessWidget {
  final bool isEs;
  final bool dark;
  final VoidCallback onTap;

  const _AvaliarButton({
    required this.isEs,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF3D1F6B), Color(0xFF6B3FA8), Color(0xFF9F7AEA)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B3FA8).withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.compare_arrows_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              isEs ? 'Evaluar interacciones' : 'Avaliar Interações',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADO VAZIO — NENHUM FÁRMACO SELECIONADO
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final AppColors c;

  const _EmptyState({required this.dark, required this.isEs, required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3D1F6B).withValues(alpha: dark ? 0.4 : 0.12),
                    const Color(0xFF6B3FA8).withValues(alpha: dark ? 0.2 : 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: const Color(0xFF9F7AEA).withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.medication_liquid_rounded,
                size: 38,
                color: Color(0xFFA78BFA),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isEs ? 'Busca de Interacciones' : 'Verificador de Interações',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isEs
                  ? 'Busque y seleccione 2 o más\nmedicamentos para verificar\ninteracciones clínicas'
                  : 'Busque e selecione 2 ou mais\nmedicamentos para verificar\ninterações clínicas',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: c.textHint,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // Dicas rápidas
            _HintRow(
              icon: Icons.search_rounded,
              text: isEs
                  ? 'Escriba el nombre genérico o comercial'
                  : 'Digite o nome genérico ou comercial',
              c: c,
            ),
            const SizedBox(height: 10),
            _HintRow(
              icon: Icons.add_circle_outline_rounded,
              text: isEs
                  ? 'Seleccione de la lista'
                  : 'Selecione da lista',
              c: c,
            ),
            const SizedBox(height: 10),
            _HintRow(
              icon: Icons.compare_arrows_rounded,
              text: isEs
                  ? 'Pulse "Evaluar" para verificar'
                  : 'Toque "Avaliar" para verificar',
              c: c,
            ),
          ],
        ),
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final AppColors c;

  const _HintRow({required this.icon, required this.text, required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFFA78BFA)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: c.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DICA — PRECISA DE MAIS UM FÁRMACO
// ─────────────────────────────────────────────────────────────────────────────
class _OneMoreDrugHint extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final AppColors c;

  const _OneMoreDrugHint({
    required this.dark,
    required this.isEs,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3D1F6B).withValues(alpha: dark ? 0.3 : 0.1),
              ),
              child: const Icon(
                Icons.add_circle_rounded,
                size: 32,
                color: Color(0xFFA78BFA),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isEs
                  ? 'Agregue al menos un\nmedicamento más'
                  : 'Adicione pelo menos mais\num medicamento',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isEs
                  ? 'Se necesitan 2+ para verificar interacciones'
                  : 'São necessários 2+ para verificar interações',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: c.textHint),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CABEÇALHO DOS RESULTADOS
// ─────────────────────────────────────────────────────────────────────────────
class _ResultsHeader extends StatelessWidget {
  final int count;
  final bool dark;
  final bool isEs;
  final AppColors c;
  final int drugsCount;
  final VoidCallback onNewAnalysis;

  const _ResultsHeader({
    required this.count,
    required this.dark,
    required this.isEs,
    required this.c,
    required this.drugsCount,
    required this.onNewAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    final hasInteractions = count > 0;
    final badgeColor = hasInteractions
        ? (count >= 3
            ? const Color(0xFFDC2626)
            : const Color(0xFFD97706))
        : const Color(0xFF16A34A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Linha de resultado
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: dark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: badgeColor.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasInteractions
                        ? Icons.warning_rounded
                        : Icons.check_circle_rounded,
                    size: 16,
                    color: badgeColor,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    hasInteractions
                        ? '$count ${isEs ? (count == 1 ? 'interacción' : 'interacciones') : (count == 1 ? 'interação' : 'interações')} ${isEs ? 'encontrada${count == 1 ? '' : 's'}' : 'encontrada${count == 1 ? '' : 's'}'}'
                        : isEs ? 'Sin interacciones' : 'Sem interações',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Sub-texto
        Text(
          isEs
              ? 'Analizados $drugsCount medicamentos'
              : 'Analisados $drugsCount medicamentos',
          style: TextStyle(
            fontSize: 12,
            color: c.textHint,
          ),
        ),

        if (hasInteractions) ...[
          const SizedBox(height: 12),
          // Legenda de severidade
          _SeverityLegend(dark: dark, c: c),
        ],
      ],
    );
  }
}

class _SeverityLegend extends StatelessWidget {
  final bool dark;
  final AppColors c;

  const _SeverityLegend({required this.dark, required this.c});

  @override
  Widget build(BuildContext context) {
    final isEs = context.read<AppProvider>().lang == 'es';
    final items = [
      (const Color(0xFF7C2D12), const Color(0xFFDC2626), 'CONTRAINDICADA'),
      (const Color(0xFF7C3003), const Color(0xFFEA580C), 'GRAVE'),
      (const Color(0xFF713F12), const Color(0xFFD97706), 'MODERADA'),
      (const Color(0xFF1A4731), const Color(0xFF16A34A), 'LEVE'),
      (const Color(0xFF1E3A5F), const Color(0xFF2563EB), isEs ? 'MONITOREAR' : 'MONITORAR'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.$2,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              item.$3,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: c.textHint,
                letterSpacing: 0.3,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NENHUMA INTERAÇÃO ENCONTRADA
// ─────────────────────────────────────────────────────────────────────────────
class _NoInteractionsFound extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final AppColors c;
  final List<String> drugs;

  const _NoInteractionsFound({
    required this.dark,
    required this.isEs,
    required this.c,
    required this.drugs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF14532D).withValues(alpha: dark ? 0.3 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF16A34A).withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF4ADE80),
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            isEs ? 'Sin interacciones detectadas' : 'Nenhuma interação detectada',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4ADE80),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isEs
                ? 'No se encontraron interacciones conocidas\nentre los medicamentos seleccionados.'
                : 'Não foram encontradas interações conhecidas\nentre os medicamentos selecionados.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: c.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF14532D).withValues(alpha: dark ? 0.3 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isEs
                  ? 'Ausencia de alerta no garantiza seguridad absoluta.\nSiempre consultar referencia actualizada.'
                  : 'Ausência de alerta não garante segurança absoluta.\nSempre consulte referência atualizada.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: c.textHint,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE INTERAÇÃO
// ─────────────────────────────────────────────────────────────────────────────
class _InteractionCard extends StatefulWidget {
  final DrugInteraction interaction;
  final bool dark;
  final bool isEs;
  final AppColors c;

  const _InteractionCard({
    required this.interaction,
    required this.dark,
    required this.isEs,
    required this.c,
  });

  @override
  State<_InteractionCard> createState() => _InteractionCardState();
}

class _InteractionCardState extends State<_InteractionCard> {
  bool _expanded = false;

  Color get _severityColor {
    switch (widget.interaction.severity) {
      case InteractionSeverity.contraindicated: return const Color(0xFFDC2626);
      case InteractionSeverity.major:           return const Color(0xFFEA580C);
      case InteractionSeverity.moderate:        return const Color(0xFFD97706);
      case InteractionSeverity.minor:           return const Color(0xFF16A34A);
      case InteractionSeverity.monitorOnly:     return const Color(0xFF2563EB);
    }
  }

  Color get _severityBg {
    switch (widget.interaction.severity) {
      case InteractionSeverity.contraindicated: return const Color(0xFF7C2D12);
      case InteractionSeverity.major:           return const Color(0xFF7C3003);
      case InteractionSeverity.moderate:        return const Color(0xFF713F12);
      case InteractionSeverity.minor:           return const Color(0xFF14532D);
      case InteractionSeverity.monitorOnly:     return const Color(0xFF1E3A5F);
    }
  }

  IconData get _severityIcon {
    switch (widget.interaction.severity) {
      case InteractionSeverity.contraindicated: return Icons.cancel_rounded;
      case InteractionSeverity.major:           return Icons.warning_rounded;
      case InteractionSeverity.moderate:        return Icons.error_outline_rounded;
      case InteractionSeverity.minor:           return Icons.info_outline_rounded;
      case InteractionSeverity.monitorOnly:     return Icons.visibility_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ix   = widget.interaction;
    final dark = widget.dark;
    final c    = widget.c;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF141420) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _severityColor.withValues(alpha: dark ? 0.3 : 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _severityColor.withValues(alpha: dark ? 0.12 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Cabeçalho do card ────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  // Ícone de severidade
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _severityBg.withValues(alpha: dark ? 0.5 : 0.15),
                      border: Border.all(
                        color: _severityColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(_severityIcon, color: _severityColor, size: 22),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Par de fármacos
                        Text(
                          '${ix.drug1} + ${ix.drug2}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Badge severidade
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _severityBg.withValues(alpha: dark ? 0.35 : 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ix.severityLabelL10n(isEs: widget.isEs),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _severityColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Seta expand/collapse
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: c.textHint,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Alerta clínico rápido (sempre visível) ───────────────────────
          if (!_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _severityColor.withValues(alpha: dark ? 0.12 : 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _severityColor.withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: _severityColor, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ix.clinicalAlertL10n(isEs: widget.isEs),
                        style: TextStyle(
                          fontSize: 12,
                          color: _severityColor,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Conteúdo expandido ───────────────────────────────────────────
          if (_expanded) ...[
            Divider(
              color: c.border.withValues(alpha: 0.4),
              height: 1,
              thickness: 0.7,
            ),
            _ExpandedContent(
              ix: ix,
              dark: dark,
              c: c,
              severityColor: _severityColor,
              isEs: widget.isEs,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTEÚDO EXPANDIDO DO CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ExpandedContent extends StatelessWidget {
  final DrugInteraction ix;
  final bool dark;
  final AppColors c;
  final Color severityColor;
  final bool isEs;

  const _ExpandedContent({
    required this.ix,
    required this.dark,
    required this.c,
    required this.severityColor,
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Alerta clínico destacado ─────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: dark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: severityColor.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bolt_rounded, color: severityColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ix.clinicalAlert,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: severityColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Efeito clínico ───────────────────────────────────────────────
          _InfoSection(
            title: isEs ? 'EFECTO CLÍNICO' : 'EFEITO CLÍNICO',
            icon: Icons.monitor_heart_rounded,
            iconColor: const Color(0xFFF87171),
            content: ix.effectL10n(isEs: isEs),
            dark: dark,
            c: c,
          ),

          const SizedBox(height: 14),

          // ── Fisiopatologia / Mecanismo ───────────────────────────────────
          _InfoSection(
            title: isEs ? 'FISIOPATOLOGÍA DE LA INTERACCIÓN' : 'FISIOPATOLOGIA DA INTERAÇÃO',
            icon: Icons.biotech_rounded,
            iconColor: const Color(0xFF60A5FA),
            content: ix.mechanismL10n(isEs: isEs),
            dark: dark,
            c: c,
          ),

          const SizedBox(height: 14),

          // ── Manejo Clínico ───────────────────────────────────────────────
          _InfoSection(
            title: isEs ? 'MANEJO CLÍNICO' : 'CONDUTA CLÍNICA',
            icon: Icons.medical_services_rounded,
            iconColor: const Color(0xFF34D399),
            content: ix.managementL10n(isEs: isEs),
            dark: dark,
            c: c,
          ),

          const SizedBox(height: 14),

          // ── Risco + Evidência em linha ────────────────────────────────────
          Row(
            children: [
              // Tipos de risco
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEs ? 'RIESGOS' : 'RISCOS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: c.textHint,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: ix.riskTypes.map((rt) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF87171)
                                .withValues(alpha: dark ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            DrugInteraction.riskTypeLabel(rt, isEs: isEs),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF87171),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Nível de evidência
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isEs ? 'EVIDENCIA' : 'EVIDÊNCIA',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: c.textHint,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24)
                          .withValues(alpha: dark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      ix.evidenceLabel(isEs: isEs),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFBBF24),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Referências ───────────────────────────────────────────────────
          if (ix.references.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              isEs ? 'FUENTES' : 'FONTES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: c.textHint,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ix.references.join(' · '),
              style: TextStyle(
                fontSize: 11,
                color: c.textHint,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEÇÃO DE INFORMAÇÃO (reutilizável)
// ─────────────────────────────────────────────────────────────────────────────
class _InfoSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String content;
  final bool dark;
  final AppColors c;

  const _InfoSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.content,
    required this.dark,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: c.textHint,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: dark
                ? const Color(0xFF1C1C2E)
                : const Color(0xFFF8F8FC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: c.border.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTÃO NOVA ANÁLISE
// ─────────────────────────────────────────────────────────────────────────────
class _NewAnalysisButton extends StatelessWidget {
  final bool isEs;
  final bool dark;
  final VoidCallback onTap;

  const _NewAnalysisButton({
    required this.isEs,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF9F7AEA).withValues(alpha: dark ? 0.5 : 0.4),
            width: 1.5,
          ),
          color: const Color(0xFF3D1F6B).withValues(alpha: dark ? 0.2 : 0.06),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.refresh_rounded,
              color: Color(0xFFA78BFA),
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              isEs ? 'Nuevo análisis' : 'Nova análise',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFFA78BFA),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
