import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PRESCRIPCIONES SCREEN
// Tela de modelos de prescrição — estrutura pronta para receber os modelos reais.
// Cada modelo tem botão "Copiar" idêntico ao padrão dos protocolos e casos.
// ─────────────────────────────────────────────────────────────────────────────

class PrescripcionesScreen extends StatefulWidget {
  const PrescripcionesScreen({super.key});
  @override
  State<PrescripcionesScreen> createState() => _PrescripcionesScreenState();
}

class _PrescripcionesScreenState extends State<PrescripcionesScreen> {
  String _search = '';
  String? _selectedCategory;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final dark = p.darkMode;
    final es = p.lang == 'es';
    final bg = dark ? const Color(0xFF0A1510) : const Color(0xFFF7F8FA);

    // ── Filtrar modelos ────────────────────────────────────────────────────
    final allModels = _prescriptionModels(es);
    final filtered = allModels.where((m) {
      final matchSearch = _search.isEmpty ||
          m.title.toLowerCase().contains(_search.toLowerCase()) ||
          m.category.toLowerCase().contains(_search.toLowerCase());
      final matchCat = _selectedCategory == null || m.category == _selectedCategory;
      return matchSearch && matchCat;
    }).toList();

    // Categorias únicas
    final categories = allModels.map((m) => m.category).toSet().toList()..sort();

    return Column(children: [
      // ── Barra de busca ───────────────────────────────────────────────────
      Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        child: Column(children: [
          // Campo de busca
          Container(
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: dark ? const Color(0xFF0E1A14) : Colors.white,
              border: Border.all(
                color: dark ? const Color(0xFF1A2E20) : const Color(0xFFE2E6EA),
              ),
            ),
            child: Row(children: [
              const SizedBox(width: 12),
              Icon(Icons.search_rounded, size: 18,
                color: dark ? Colors.white38 : const Color(0xFFAAAAAA)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: TextStyle(
                    fontSize: 13,
                    color: dark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                  decoration: InputDecoration(
                    hintText: es ? 'Buscar prescripción...' : 'Buscar prescrição...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: dark ? Colors.white30 : const Color(0xFFBBBBBB),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_search.isNotEmpty)
                GestureDetector(
                  onTap: () { _searchCtrl.clear(); setState(() => _search = ''); },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.close_rounded, size: 16,
                      color: dark ? Colors.white38 : const Color(0xFFAAAAAA)),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          // Chips de categoria
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _CategoryChip(
                label: es ? 'Todas' : 'Todas',
                active: _selectedCategory == null,
                dark: dark,
                onTap: () => setState(() => _selectedCategory = null),
              ),
              const SizedBox(width: 6),
              ...categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _CategoryChip(
                  label: cat,
                  active: _selectedCategory == cat,
                  dark: dark,
                  onTap: () => setState(() =>
                    _selectedCategory = _selectedCategory == cat ? null : cat),
                ),
              )),
            ]),
          ),
        ]),
      ),

      // ── Lista de modelos ─────────────────────────────────────────────────
      Expanded(
        child: filtered.isEmpty
            ? _EmptyState(dark: dark, es: es)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  // Inserir cabeçalhos de categoria
                  final model = filtered[i];
                  final showHeader = i == 0 ||
                      filtered[i - 1].category != model.category;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _CategoryHeader(label: model.category, dark: dark),
                        const SizedBox(height: 6),
                      ],
                      _PrescriptionCard(
                        model: model,
                        dark: dark,
                        es: es,
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS DE PRESCRIÇÃO — Placeholder estruturado
// Aguardando os modelos reais enviados pelo usuário.
// Cada PrescriptionModel representa um modelo completo de prescrição.
// ─────────────────────────────────────────────────────────────────────────────

class _PrescriptionModel {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final String content; // Texto completo da prescrição (para copiar)
  final IconData icon;

  const _PrescriptionModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.content,
    required this.icon,
  });
}

List<_PrescriptionModel> _prescriptionModels(bool es) => [
  // ── Cardiovascular ───────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'hta_basica',
    title: es ? 'Hipertensión arterial — inicial' : 'Hipertensão arterial — inicial',
    subtitle: es ? 'Monoterapia de primera línea' : 'Monoterapia de primeira linha',
    category: es ? 'Cardiovascular' : 'Cardiovascular',
    icon: Icons.favorite_rounded,
    content: es
        ? '── PRESCRIPCIÓN: Hipertensión Arterial ──\n\n'
          '1. Losartán 50 mg — 1 cp/día, vía oral, con o sin alimentos.\n'
          '2. Hidroclorotiazida 12,5 mg — 1 cp/día, vía oral, por la mañana.\n\n'
          'Controles: PA cada 2 semanas hasta meta (<140/90 mmHg).\n'
          'Laboratorio en 4 semanas: creatinina, K+, Na+.\n\n'
          '⚕ Modelo educacional — adaptar al paciente.'
        : '── PRESCRIÇÃO: Hipertensão Arterial ──\n\n'
          '1. Losartana 50 mg — 1 cp/dia, VO, com ou sem alimentos.\n'
          '2. Hidroclorotiazida 12,5 mg — 1 cp/dia, VO, pela manhã.\n\n'
          'Controles: PA a cada 2 semanas até meta (<140/90 mmHg).\n'
          'Laboratório em 4 semanas: creatinina, K+, Na+.\n\n'
          '⚕ Modelo educacional — adaptar ao paciente.',
  ),
  _PrescriptionModel(
    id: 'hta_2drogas',
    title: es ? 'Hipertensión — combinación 2 fármacos' : 'Hipertensão — combinação 2 fármacos',
    subtitle: es ? 'Cuando monoterapia insuficiente' : 'Quando monoterapia insuficiente',
    category: es ? 'Cardiovascular' : 'Cardiovascular',
    icon: Icons.favorite_rounded,
    content: es
        ? '── PRESCRIPCIÓN: HTA – 2 Fármacos ──\n\n'
          '1. Amlodipino 5 mg — 1 cp/día, vía oral.\n'
          '2. Losartán 50 mg — 1 cp/día, vía oral.\n\n'
          'Meta: PA <140/90 mmHg (general) / <130/80 (DM, ERC).\n'
          'Revisar en 4 semanas: ajustar dosis según respuesta.\n\n'
          '⚕ Modelo educacional — adaptar al paciente.'
        : '── PRESCRIÇÃO: HTA – 2 Fármacos ──\n\n'
          '1. Anlodipino 5 mg — 1 cp/dia, VO.\n'
          '2. Losartana 50 mg — 1 cp/dia, VO.\n\n'
          'Meta: PA <140/90 mmHg (geral) / <130/80 (DM, DRC).\n'
          'Rever em 4 semanas: ajustar dose conforme resposta.\n\n'
          '⚕ Modelo educacional — adaptar ao paciente.',
  ),
  _PrescriptionModel(
    id: 'ic_ambulatorial',
    title: es ? 'Insuficiencia cardíaca — ambulatorio' : 'Insuficiência cardíaca — ambulatório',
    subtitle: es ? 'IC-FEr estable, FEVI <40%' : 'ICFEr estável, FEVE <40%',
    category: es ? 'Cardiovascular' : 'Cardiovascular',
    icon: Icons.favorite_rounded,
    content: es
        ? '── PRESCRIPCIÓN: IC – Ambulatorio ──\n\n'
          '1. Carvedilol 3,125 mg — 1 cp/12h, vía oral, con comidas.\n'
          '   (titular: doblar dosis cada 2 semanas hasta 25 mg/12h)\n'
          '2. Enalapril 2,5 mg — 1 cp/12h, vía oral.\n'
          '   (titular: doblar dosis cada 2 semanas hasta 10 mg/12h)\n'
          '3. Espironolactona 25 mg — 1 cp/día, vía oral.\n'
          '4. Furosemida 40 mg — 1 cp/día, VO (si congestión).\n\n'
          'Control: peso diario; si +2 kg en 3 días → consultar.\n'
          'Laboratorio: creatinina + K+ en 7-14 días.\n\n'
          '⚕ Modelo educacional — adaptar al paciente.'
        : '── PRESCRIÇÃO: IC – Ambulatório ──\n\n'
          '1. Carvedilol 3,125 mg — 1 cp/12h, VO, com alimentos.\n'
          '   (titular: dobrar dose a cada 2 semanas até 25 mg/12h)\n'
          '2. Enalapril 2,5 mg — 1 cp/12h, VO.\n'
          '   (titular: dobrar dose a cada 2 semanas até 10 mg/12h)\n'
          '3. Espironolactona 25 mg — 1 cp/dia, VO.\n'
          '4. Furosemida 40 mg — 1 cp/dia, VO (se congestão).\n\n'
          'Controle: peso diário; se +2 kg em 3 dias → consultar.\n'
          'Laboratório: creatinina + K+ em 7-14 dias.\n\n'
          '⚕ Modelo educacional — adaptar ao paciente.',
  ),

  // ── Respiratório ─────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'asma_leve',
    title: es ? 'Asma leve-moderada — mantenimiento' : 'Asma leve-moderada — manutenção',
    subtitle: es ? 'Corticoide inhalado + SABA de rescate' : 'Corticoide inalatório + SABA resgate',
    category: es ? 'Respiratorio' : 'Respiratório',
    icon: Icons.air_rounded,
    content: es
        ? '── PRESCRIPCIÓN: Asma Leve-Moderada ──\n\n'
          '1. Budesonida 200 mcg (inhalador) — 2 puff/12h, inhalado.\n'
          '   Técnica: agitar, exhalar, inhalar lentamente, apnea 10s.\n'
          '2. Salbutamol 100 mcg (inhalador) — 2 puff en rescate.\n'
          '   Uso: si síntomas agudos. Máx: 8 puff/día.\n\n'
          'Revisión en 4 semanas. Diario de síntomas.\n\n'
          '⚕ Modelo educacional — adaptar al paciente.'
        : '── PRESCRIÇÃO: Asma Leve-Moderada ──\n\n'
          '1. Budesonida 200 mcg (inalador) — 2 puff/12h, inalado.\n'
          '   Técnica: agitar, expirar, inalar lentamente, apneia 10s.\n'
          '2. Salbutamol 100 mcg (inalador) — 2 puff em resgate.\n'
          '   Uso: se sintomas agudos. Máx: 8 puff/dia.\n\n'
          'Revisão em 4 semanas. Diário de sintomas.\n\n'
          '⚕ Modelo educacional — adaptar ao paciente.',
  ),
  _PrescriptionModel(
    id: 'dpoc_estavel',
    title: es ? 'EPOC estable — broncodilatadores' : 'DPOC estável — broncodilatadores',
    subtitle: es ? 'LAMA ± LABA según gravedad' : 'LAMA ± LABA conforme gravidade',
    category: es ? 'Respiratorio' : 'Respiratório',
    icon: Icons.air_rounded,
    content: es
        ? '── PRESCRIPCIÓN: EPOC Estable ──\n\n'
          '1. Tiotropio 18 mcg (HandiHaler) — 1 cápsula/día, inhalado.\n'
          '2. Salbutamol 100 mcg (inhalador) — 2 puff en rescate.\n\n'
          'EPOC moderada-grave: añadir formoterol 12 mcg/12h.\n\n'
          'No fumar. Vacuna neumococo + gripe.\n'
          'Revisión en 3 meses: espirometría + exacerbaciones.\n\n'
          '⚕ Modelo educacional — adaptar al paciente.'
        : '── PRESCRIÇÃO: DPOC Estável ──\n\n'
          '1. Tiotrópio 18 mcg (HandiHaler) — 1 cápsula/dia, inalado.\n'
          '2. Salbutamol 100 mcg (inalador) — 2 puff em resgate.\n\n'
          'DPOC moderado-grave: acrescentar formoterol 12 mcg/12h.\n\n'
          'Não fumar. Vacina pneumococo + influenza.\n'
          'Reavaliação em 3 meses: espirometria + exacerbações.\n\n'
          '⚕ Modelo educacional — adaptar ao paciente.',
  ),

  // ── Endocrinologia ───────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'dm2_inicial',
    title: es ? 'Diabetes tipo 2 — inicio' : 'Diabetes tipo 2 — início',
    subtitle: es ? 'Metformina de primera línea' : 'Metformina de primeira linha',
    category: es ? 'Endocrinología' : 'Endocrinologia',
    icon: Icons.water_drop_rounded,
    content: es
        ? '── PRESCRIPCIÓN: DM2 – Inicio ──\n\n'
          '1. Metformina 500 mg — 1 cp/12h, vía oral, con comidas.\n'
          '   (semana 2-4: aumentar a 850 mg/12h si tolera)\n\n'
          'Meta: HbA1c <7% (general) / <8% (>75 años o comórbidos).\n'
          'Laboratorio en 3 meses: HbA1c, creatinina, perfil lipídico.\n'
          'Suspender si: creatinina >1,4 (F) / >1,5 (M) mg/dL.\n\n'
          '⚕ Modelo educacional — adaptar al paciente.'
        : '── PRESCRIÇÃO: DM2 – Início ──\n\n'
          '1. Metformina 500 mg — 1 cp/12h, VO, com refeições.\n'
          '   (semana 2-4: aumentar para 850 mg/12h se tolerado)\n\n'
          'Meta: HbA1c <7% (geral) / <8% (>75 anos ou comórbidos).\n'
          'Laboratório em 3 meses: HbA1c, creatinina, perfil lipídico.\n'
          'Suspender se: creatinina >1,4 (F) / >1,5 (M) mg/dL.\n\n'
          '⚕ Modelo educacional — adaptar ao paciente.',
  ),
  _PrescriptionModel(
    id: 'hipotireoidismo',
    title: es ? 'Hipotiroidismo — sustitución' : 'Hipotireoidismo — reposição',
    subtitle: es ? 'Levotiroxina: dosis por peso' : 'Levotiroxina: dose por peso',
    category: es ? 'Endocrinología' : 'Endocrinologia',
    icon: Icons.water_drop_rounded,
    content: es
        ? '── PRESCRIPCIÓN: Hipotiroidismo ──\n\n'
          '1. Levotiroxina — dosis: 1,6 mcg/kg/día, VO, en ayunas.\n'
          '   (iniciar con 25-50 mcg/día si >65 años o cardiopatía)\n\n'
          'Tomar 30-60 min antes del desayuno.\n'
          'No tomar junto a hierro, calcio o antiácidos.\n'
          'Laboratorio en 6 semanas: TSH.\n'
          'Meta: TSH 0,5–2,5 mUI/L (adultos jóvenes).\n\n'
          '⚕ Modelo educacional — adaptar al paciente.'
        : '── PRESCRIÇÃO: Hipotireoidismo ──\n\n'
          '1. Levotiroxina — dose: 1,6 mcg/kg/dia, VO, em jejum.\n'
          '   (iniciar com 25-50 mcg/dia se >65 anos ou cardiopatia)\n\n'
          'Tomar 30-60 min antes do café da manhã.\n'
          'Não tomar junto de ferro, cálcio ou antiácido.\n'
          'Laboratório em 6 semanas: TSH.\n'
          'Meta: TSH 0,5–2,5 mUI/L (adultos jovens).\n\n'
          '⚕ Modelo educacional — adaptar ao paciente.',
  ),

  // ── Infectologia ─────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'itu_nao_complicada',
    title: es ? 'ITU no complicada — mujer' : 'ITU não complicada — mulher',
    subtitle: es ? 'Nitrofurantoína o trimetoprim' : 'Nitrofurantoína ou trimetoprim',
    category: es ? 'Infectología' : 'Infectologia',
    icon: Icons.bug_report_rounded,
    content: es
        ? '── PRESCRIPCIÓN: ITU No Complicada ──\n\n'
          'Opción 1:\n'
          '1. Nitrofurantoína 100 mg — 1 cp/6h, VO, con comidas × 5 días.\n\n'
          'Opción 2 (si sensibilidad local conocida):\n'
          '1. Trimetoprim-sulfametoxazol 800/160 mg — 1 cp/12h × 3 días.\n\n'
          'Aumentar ingesta hídrica (>2 L/día).\n'
          'Si persiste sintomatología en 48-72h → urocultivo.\n\n'
          '⚕ Modelo educacional — adaptar al paciente.'
        : '── PRESCRIÇÃO: ITU Não Complicada ──\n\n'
          'Opção 1:\n'
          '1. Nitrofurantoína 100 mg — 1 cp/6h, VO, com refeições × 5 dias.\n\n'
          'Opção 2 (se sensibilidade local conhecida):\n'
          '1. Sulfametoxazol+trimetoprim 800/160 mg — 1 cp/12h × 3 dias.\n\n'
          'Aumentar ingestão hídrica (>2 L/dia).\n'
          'Se sintomas persistirem em 48-72h → urocultura.\n\n'
          '⚕ Modelo educacional — adaptar ao paciente.',
  ),
  _PrescriptionModel(
    id: 'pac_ambulatorial',
    title: es ? 'NAC ambulatoria — adulto sano' : 'PAC ambulatorial — adulto hígido',
    subtitle: es ? 'Amoxicilina ± macrólido' : 'Amoxicilina ± macrolídeo',
    category: es ? 'Infectología' : 'Infectologia',
    icon: Icons.bug_report_rounded,
    content: es
        ? '── PRESCRIPCIÓN: NAC Ambulatoria ──\n\n'
          'Sin comorbilidades:\n'
          '1. Amoxicilina 1 g — 1 cp/8h, vía oral × 5 días.\n\n'
          'Con comorbilidades (DM, EPOC, tabaco) o sospecha atípica:\n'
          '1. Amoxicilina 1 g/8h × 5 días\n'
          '   + Azitromicina 500 mg/día × 3 días\n\n'
          'Reevaluar en 48-72h. Criterios de hospitalización:\n'
          'CURB-65 ≥2, SpO2 <92%, FR >30, PA <90/60.\n\n'
          '⚕ Modelo educacional — adaptar al paciente.'
        : '── PRESCRIÇÃO: PAC Ambulatorial ──\n\n'
          'Sem comorbidades:\n'
          '1. Amoxicilina 1 g — 1 cp/8h, VO × 5 dias.\n\n'
          'Com comorbidades (DM, DPOC, tabagismo) ou suspeita atípica:\n'
          '1. Amoxicilina 1 g/8h × 5 dias\n'
          '   + Azitromicina 500 mg/dia × 3 dias\n\n'
          'Reavaliar em 48-72h. Critérios de internação:\n'
          'CURB-65 ≥2, SpO2 <92%, FR >30, PA <90/60.\n\n'
          '⚕ Modelo educacional — adaptar ao paciente.',
  ),

  // ── Neurologia ───────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'enxaqueca_profilaxia',
    title: es ? 'Migraña — profilaxis' : 'Enxaqueca — profilaxia',
    subtitle: es ? 'Propranolol o amitriptilina' : 'Propranolol ou amitriptilina',
    category: es ? 'Neurología' : 'Neurologia',
    icon: Icons.psychology_rounded,
    content: es
        ? '── PRESCRIPCIÓN: Migraña – Profilaxis ──\n\n'
          'Opción 1 (si hipertensión o taquicardia):\n'
          '1. Propranolol 40 mg — 1 cp/12h, VO. Titular hasta 80-160 mg/día.\n\n'
          'Opción 2 (si insomnio o depresión asociada):\n'
          '1. Amitriptilina 10 mg — 1 cp/noche, VO.\n'
          '   (titular: aumentar 10 mg/semana hasta 25-75 mg/noche)\n\n'
          'Indicar diario de cefalea. Evaluar eficacia en 3 meses.\n\n'
          '⚕ Modelo educacional — adaptar al paciente.'
        : '── PRESCRIÇÃO: Enxaqueca – Profilaxia ──\n\n'
          'Opção 1 (se hipertensão ou taquicardia):\n'
          '1. Propranolol 40 mg — 1 cp/12h, VO. Titular até 80-160 mg/dia.\n\n'
          'Opção 2 (se insônia ou depressão associada):\n'
          '1. Amitriptilina 10 mg — 1 cp/noite, VO.\n'
          '   (titular: aumentar 10 mg/semana até 25-75 mg/noite)\n\n'
          'Orientar diário de cefaleia. Avaliar eficácia em 3 meses.\n\n'
          '⚕ Modelo educacional — adaptar ao paciente.',
  ),
  _PrescriptionModel(
    id: 'insomnia',
    title: es ? 'Insomnio — tratamiento inicial' : 'Insônia — tratamento inicial',
    subtitle: es ? 'Higiene del sueño + farmacoterapia' : 'Higiene do sono + farmacoterapia',
    category: es ? 'Neurología' : 'Neurologia',
    icon: Icons.psychology_rounded,
    content: es
        ? '── PRESCRIPCIÓN: Insomnio ──\n\n'
          '1. Melatonina 2 mg — 1 cp 30 min antes de dormir, VO.\n'
          '   (segura, sin dependencia; primera línea en mayores)\n\n'
          'Si insomnio moderado-severo (corto plazo ≤4 semanas):\n'
          '1. Zolpidem 5 mg — 1 cp en la noche, VO. Máx: 4 semanas.\n'
          '   Evitar en >65 años, EPOC, apnea del sueño.\n\n'
          'Higiene del sueño: horario fijo, sin pantallas 1h antes.\n\n'
          '⚕ Modelo educacional — adaptar al paciente.'
        : '── PRESCRIÇÃO: Insônia ──\n\n'
          '1. Melatonina 2 mg — 1 cp 30 min antes de dormir, VO.\n'
          '   (segura, sem dependência; primeira linha em idosos)\n\n'
          'Se insônia moderada-grave (curto prazo ≤4 semanas):\n'
          '1. Zolpidem 5 mg — 1 cp à noite, VO. Máx: 4 semanas.\n'
          '   Evitar em >65 anos, DPOC, apneia do sono.\n\n'
          'Higiene do sono: horário fixo, sem telas 1h antes.\n\n'
          '⚕ Modelo educacional — adaptar ao paciente.',
  ),

  // ── Gastroenterologia ────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'ulcera_peptica',
    title: es ? 'Úlcera péptica / GERD — cicatrización' : 'Úlcera péptica / DRGE — cicatrização',
    subtitle: es ? 'IBP + erradicación H. pylori si positivo' : 'IBP + erradicação H. pylori se positivo',
    category: es ? 'Gastroenterología' : 'Gastroenterologia',
    icon: Icons.medical_services_rounded,
    content: es
        ? '── PRESCRIPCIÓN: Úlcera Péptica / GERD ──\n\n'
          '1. Omeprazol 20 mg — 1 cp/día, VO, en ayunas × 4-8 semanas.\n'
          '   (úlcera gástrica: 8 semanas / duodenal: 4 semanas)\n\n'
          'Si H. pylori positivo — Triple terapia × 14 días:\n'
          '1. Omeprazol 20 mg/12h\n'
          '2. Amoxicilina 1 g/12h\n'
          '3. Claritromicina 500 mg/12h\n\n'
          'Evitar: AINEs, tabaco, alcohol.\n'
          'Endoscopia de control si úlcera gástrica en 8-12 semanas.\n\n'
          '⚕ Modelo educacional — adaptar al paciente.'
        : '── PRESCRIÇÃO: Úlcera Péptica / DRGE ──\n\n'
          '1. Omeprazol 20 mg — 1 cp/dia, VO, em jejum × 4-8 semanas.\n'
          '   (úlcera gástrica: 8 semanas / duodenal: 4 semanas)\n\n'
          'Se H. pylori positivo — Terapia tripla × 14 dias:\n'
          '1. Omeprazol 20 mg/12h\n'
          '2. Amoxicilina 1 g/12h\n'
          '3. Claritromicina 500 mg/12h\n\n'
          'Evitar: AINEs, tabagismo, álcool.\n'
          'Endoscopia de controle se úlcera gástrica em 8-12 semanas.\n\n'
          '⚕ Modelo educacional — adaptar ao paciente.',
  ),

  // ── Analgesia ────────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'dor_aguda_leve',
    title: es ? 'Dolor agudo leve-moderado' : 'Dor aguda leve-moderada',
    subtitle: es ? 'Escalonado: paracetamol → AINE → opioide fraco' : 'Escalonado: paracetamol → AINE → opioide fraco',
    category: es ? 'Analgesia' : 'Analgesia',
    icon: Icons.healing_rounded,
    content: es
        ? '── PRESCRIPCIÓN: Dolor Agudo ──\n\n'
          'Escalón 1 (leve):\n'
          '1. Paracetamol 1 g — 1 cp/6h, VO, máx 4 g/día.\n\n'
          'Escalón 2 (moderado, si escalón 1 insuficiente):\n'
          '1. Ibuprofeno 400-600 mg — 1 cp/8h, VO, con comidas.\n'
          '   Contraindicado: ERC, úlcera, ICC, anticoagulación.\n\n'
          'Escalón 3 (moderado-severo):\n'
          '1. Tramadol 50 mg — 1 cp/6-8h, VO, máx 400 mg/día.\n\n'
          '⚕ Modelo educacional — adaptar al paciente.'
        : '── PRESCRIÇÃO: Dor Aguda ──\n\n'
          'Degrau 1 (leve):\n'
          '1. Paracetamol 1 g — 1 cp/6h, VO, máx 4 g/dia.\n\n'
          'Degrau 2 (moderada, se degrau 1 insuficiente):\n'
          '1. Ibuprofeno 400-600 mg — 1 cp/8h, VO, com alimentos.\n'
          '   Contraindicado: DRC, úlcera, ICC, anticoagulação.\n\n'
          'Degrau 3 (moderada-intensa):\n'
          '1. Tramadol 50 mg — 1 cp/6-8h, VO, máx 400 mg/dia.\n\n'
          '⚕ Modelo educacional — adaptar ao paciente.',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool dark;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.active,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = dark ? const Color(0xFFFFE8A6) : const Color(0xFF07110d);
    final activeBg = dark
        ? const Color(0xFF1A3528)
        : const Color(0xFF07110d).withValues(alpha: 0.09);
    final inactiveBg = dark ? const Color(0xFF0E1A14) : Colors.white;
    final inactiveBorder = dark ? const Color(0xFF1A2E20) : const Color(0xFFDDD8CC);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active ? activeBg : inactiveBg,
          border: Border.all(
            color: active
                ? (dark ? const Color(0xFF2A4A38) : const Color(0xFF07110d).withValues(alpha: 0.25))
                : inactiveBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            color: active
                ? activeColor
                : (dark ? Colors.white54 : const Color(0xFF888888)),
          ),
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String label;
  final bool dark;
  const _CategoryHeader({required this.label, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
          color: dark ? const Color(0xFFFFE8A6) : const Color(0xFF075f45),
        ),
      ),
    );
  }
}

class _PrescriptionCard extends StatefulWidget {
  final _PrescriptionModel model;
  final bool dark;
  final bool es;
  const _PrescriptionCard({
    required this.model,
    required this.dark,
    required this.es,
  });

  @override
  State<_PrescriptionCard> createState() => _PrescriptionCardState();
}

class _PrescriptionCardState extends State<_PrescriptionCard> {
  bool _expanded = false;
  bool _copied = false;

  void _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.model.content));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final es = widget.es;
    final cardBg = dark ? const Color(0xFF0E1A14) : Colors.white;
    final borderCol = dark ? const Color(0xFF1A2E20) : const Color(0xFFE8E1D2);
    final textCol = dark ? Colors.white : const Color(0xFF1A1A1A);
    final subCol = dark ? Colors.white54 : const Color(0xFF888888);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: cardBg,
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.18 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Cabeçalho ────────────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(children: [
              // Ícone da categoria
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: dark
                      ? const Color(0xFF1A3528)
                      : const Color(0xFF07110d).withValues(alpha: 0.07),
                ),
                child: Icon(widget.model.icon, size: 18,
                  color: dark ? const Color(0xFFFFE8A6) : const Color(0xFF075f45)),
              ),
              const SizedBox(width: 12),
              // Título e subtítulo
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.model.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textCol,
                    height: 1.3,
                  )),
                const SizedBox(height: 2),
                Text(widget.model.subtitle,
                  style: TextStyle(fontSize: 11, color: subCol, fontWeight: FontWeight.w500)),
              ])),
              const SizedBox(width: 8),
              // Botão copiar + chevron
              Row(mainAxisSize: MainAxisSize.min, children: [
                _CopyBtn(copied: _copied, dark: dark, es: es, onTap: _copy),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more_rounded, size: 20,
                    color: dark ? Colors.white38 : const Color(0xFFAAAAAA)),
                ),
              ]),
            ]),
          ),
        ),

        // ── Conteúdo expandido ───────────────────────────────────────────
        if (_expanded) ...[
          Divider(height: 1, color: borderCol),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Texto da prescrição
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: dark
                      ? const Color(0xFF071510).withValues(alpha: 0.7)
                      : const Color(0xFFF7F5F0),
                  border: Border.all(color: borderCol),
                ),
                child: Text(
                  widget.model.content,
                  style: TextStyle(
                    fontSize: 12,
                    color: dark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF2A2A2A),
                    height: 1.65,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Botão copiar expandido
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _copy,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: _copied
                          ? const Color(0xFF065F46)
                          : (dark
                              ? const Color(0xFF1A3528)
                              : const Color(0xFF07110d).withValues(alpha: 0.08)),
                      border: Border.all(
                        color: _copied
                            ? const Color(0xFF065F46)
                            : (dark ? const Color(0xFF2A4A38) : const Color(0xFF07110d).withValues(alpha: 0.2)),
                      ),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(
                        _copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 15,
                        color: _copied
                            ? Colors.white
                            : (dark ? const Color(0xFFFFE8A6) : const Color(0xFF07110d)),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _copied
                            ? (es ? '¡Copiado!' : 'Copiado!')
                            : (es ? 'Copiar prescripción' : 'Copiar prescrição'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _copied
                              ? Colors.white
                              : (dark ? const Color(0xFFFFE8A6) : const Color(0xFF07110d)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _CopyBtn extends StatelessWidget {
  final bool copied;
  final bool dark;
  final bool es;
  final VoidCallback onTap;
  const _CopyBtn({
    required this.copied,
    required this.dark,
    required this.es,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: copied
              ? const Color(0xFF065F46)
              : (dark
                  ? const Color(0xFF1A3528)
                  : const Color(0xFF07110d).withValues(alpha: 0.07)),
          border: Border.all(
            color: copied
                ? const Color(0xFF065F46)
                : (dark ? const Color(0xFF2A4A38) : const Color(0xFFDDD8CC)),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            copied ? Icons.check_rounded : Icons.copy_rounded,
            size: 13,
            color: copied
                ? Colors.white
                : (dark ? const Color(0xFFFFE8A6) : const Color(0xFF07110d)),
          ),
          const SizedBox(width: 5),
          Text(
            copied ? (es ? '¡Copiado!' : 'Copiado!') : (es ? 'Copiar' : 'Copiar'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: copied
                  ? Colors.white
                  : (dark ? const Color(0xFFFFE8A6) : const Color(0xFF07110d)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool dark;
  final bool es;
  const _EmptyState({required this.dark, required this.es});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.description_outlined, size: 52,
          color: dark ? Colors.white24 : const Color(0xFFCCCCCC)),
        const SizedBox(height: 14),
        Text(
          es ? 'Sin prescripciones encontradas' : 'Nenhuma prescrição encontrada',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: dark ? Colors.white38 : const Color(0xFFAAAAAA),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          es ? 'Intenta con otra búsqueda o categoría'
             : 'Tente outra busca ou categoria',
          style: TextStyle(
            fontSize: 12,
            color: dark ? Colors.white24 : const Color(0xFFBBBBBB),
          ),
        ),
      ]),
    );
  }
}
