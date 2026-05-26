import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart';

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
    // ── Filtrar modelos ────────────────────────────────────────────────────
    final allModels = prescriptionModels(es);
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

      // ── Busca + filtros ──────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MedInput(
            controller: _searchCtrl,
            hintText: es ? 'Buscar prescripción...' : 'Buscar prescrição...',
            onChanged: (_) => setState(() => _search = _searchCtrl.text),
          ),
          const SizedBox(height: 8),
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
                  label: _categoryLabel(cat, es),
                  active: _selectedCategory == cat,
                  dark: dark,
                  onTap: () => setState(() =>
                    _selectedCategory = _selectedCategory == cat ? null : cat),
                ),
              )),
            ]),
          ),
          const SizedBox(height: 6),
          Text(
            '${filtered.length} ${es ? 'ejemplos educativos' : 'exemplos educacionais'}',
            style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: Color(0xFF888888),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // ── Lista de modelos ─────────────────────────────────────────────────
      Expanded(
        child: filtered.isEmpty
            ? _EmptyState(dark: dark, es: es)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final model = filtered[i];
                  final showHeader = i == 0 ||
                      filtered[i - 1].category != model.category;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _CategoryHeader(label: _categoryLabel(model.category, es), dark: dark),
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

class PrescriptionModel {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final String content; // Texto completo da prescrição (para copiar)
  final IconData icon;

  const PrescriptionModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.content,
    required this.icon,
  });
}

// ignore: library_private_types_in_public_api
typedef _PrescriptionModel = PrescriptionModel;

// ── Tradutor de categoria ES → PT ─────────────────────────────────────────────
// Os dados internos usam ES como idioma-base.
// Esta função traduz o rótulo exibido nos chips e títulos quando isEs=false.
String _categoryLabel(String cat, bool isEs) {
  if (isEs) return cat;
  const Map<String, String> ptMap = {
    'Analgesia':                         'Analgesia',
    'Cardiovascular':                    'Cardiovascular',
    'Cirugía':                           'Cirurgia',
    'Clínica Médica':                    'Clínica Médica',
    'Clínica Médica / Prevención':       'Clínica Médica / Prevenção',
    'Clínica Médica / Reumatología':     'Clínica Médica / Reumatologia',
    'Dermatología':                      'Dermatologia',
    'Dermatología / Infectología':       'Dermatologia / Infectologia',
    'Endocrinología':                    'Endocrinologia',
    'Gastroenterología':                 'Gastroenterologia',
    'Gastroenterología / Clínica':       'Gastroenterologia / Clínica',
    'Genitourinario':                    'Genitourinário',
    'Ginecología':                       'Ginecologia',
    'Hematología':                       'Hematologia',
    'Hidroelectrolítico':                'Hidroeletrolítico',
    'Infectología':                      'Infectologia',
    'Infectología / Ginecología':        'Infectologia / Ginecologia',
    'Infectología / Pediatría':          'Infectologia / Pediatria',
    'Neurología':                        'Neurologia',
    'Neurología / Clínica':              'Neurologia / Clínica',
    'Neurología / ORL':                  'Neurologia / ORL',
    'Obstetricia / Infectología':        'Obstetrícia / Infectologia',
    'Odontología':                       'Odontologia',
    'Odontología / Clínica':             'Odontologia / Clínica',
    'Oftalmología':                      'Oftalmologia',
    'Osteomuscular':                     'Osteomuscular',
    'Otorrinolaringología':              'Otorrinolaringologia',
    'Pediatría':                         'Pediatria',
    'Pediatría / Dermatología':          'Pediatria / Dermatologia',
    'Proctología':                       'Proctologia',
    'Psiquiatría':                       'Psiquiatria',
    'Respiratorio':                      'Respiratório',
    'Reumatología':                      'Reumatologia',
    'Toxicología':                       'Toxicologia',
    'Urgencias':                         'Urgências',
    'Urología':                          'Urologia',
  };
  return ptMap[cat] ?? cat;
}

List<PrescriptionModel> prescriptionModels(bool es) => [

  // ══════════════════════════════════════════════════════════════════════════
  // ANALGESIA
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'cefalea_tensional',
    title: 'Cefalea Tensional',
    subtitle: 'Dolor de cabeza común — analgésicos simples',
    category: 'Analgesia',
    icon: Icons.psychology_rounded,
    content: '''1. Ibuprofeno 400 mg
   1 comprimido cada 6h si hay dolor, VO
   □ Cant: 10 comprimidos

2. Paracetamol 500 mg
   1 comprimido cada 6h si hay dolor, VO
   (Alternativa si contraindicación a AINEs)
   □ Cant: 10 comprimidos

3. Dipirona 500 mg
   1 comprimido cada 6h si hay dolor, VO
   □ Cant: 10 comprimidos

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'dolor_muscular_lombalgia',
    title: 'Dolor Muscular / Lumbalgia',
    subtitle: 'Contractura muscular — escalera analgésica',
    category: 'Analgesia',
    icon: Icons.accessibility_new_rounded,
    content: '''Uso oral — domicilio:
1. Dipirona 1 g
   1 comprimido cada 6h (máx: 4 g/día), VO

2. Ibuprofeno 600 mg
   1 comprimido cada 12h por hasta 5 días, VO

3. Diclofenac 75 mg
   1 comprimido cada 12h por hasta 5 días, VO

4. Ciclobenzaprina [Miosan®] 5 mg
   1 comprimido cada 12h por 5 días, VO
   (Precaución: produce somnolencia)

Guardia — IV:
- Dipirona 1 g/2 mL → diluir en 10 mL AD, EV en bolo lento
- Cetoprofeno 100 mg/2 mL → diluir en 100 mL SF 0,9%, EV en 20 min
- Tramadol 100 mg/2 mL → diluir en 100 mL SF 0,9%, EV en 30 min

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'analgesia_guardia_escalera',
    title: 'Escalera Analgésica en Guardia',
    subtitle: 'OMS — dosis de referencia en urgencias',
    category: 'Analgesia',
    icon: Icons.stairs_rounded,
    content: '''ANALGÉSICOS SIMPLES — EV:
• Dipirona 500 mg/mL (amp 2 mL)
  Diluir en 10 mL AD. Dosis máx: 8.000 mg/día.

• Paracetamol 750 mg VO
  1 comprimido cada 8h (máx 3 g/día)

ANTIINFLAMATORIOS — EV:
• Cetoprofeno 1 mg/mL (bolsa 100 mL)
  Infundir lentamente en 20 min.
  Dosis máx: 300 mg/día.

• Tenoxicam 20 mg (fco/amp)
  Diluir en 20 mL AD. Administrar en 1 min.

• Diclofenac 75 mg/3 mL (amp IM)
  Aplicar solo en glúteo.

OPIOIDES DÉBILES — EV:
• Tramadol 50 mg/mL (amp 1 mL)
  Diluir en 100 mL SF 0,9%. Administrar lento.

OPIOIDES FUERTES — EV:
• Morfina 10 mg/mL (amp 1 mL)
  Diluir en 10 mL SF 0,9%. Administrar lentamente.

• Nalbufina 10 mg/mL (amp 1 mL)
  Diluir en 100 a 250 mL SF 0,9%.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'cuidados_paliativos_dolor',
    title: 'Cuidados Paliativos — Dolor',
    subtitle: 'Manejo del dolor oncológico y terminal',
    category: 'Analgesia',
    icon: Icons.favorite_border_rounded,
    content: '''Dolor moderado a intenso con componente neuropático:
1. Dipirona 500 mg
   2 comprimidos VO cada 4h si hay dolor
2. Amitriptilina 25 mg
   1 comprimido VO a la noche
3. Tramadol 50 mg
   1 comprimido VO si dolor intenso refractario

Dolor intenso refractario:
1. Morfina 10 mg/mL
   Diluir 1 mL en 9 mL SF 0,9% → administrar 4 mL EV
2. Dipirona 500 mg
   2 comprimidos VO cada 6h
3. Tramadol 50 mg
   1 comprimido VO si dolor refractario a dipirona

Dispnea (paliativa):
• Codeína 30 mg VO cada 4–6h (leve)
• Morfina 5 mg VO cada 4h / 2 mg EV cada 4h (moderada-intensa)

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // CARDIOVASCULAR
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'tsv_adenosina',
    title: 'TPSV — Adenosina',
    subtitle: 'Taquicardia Paroxística Supraventricular — cardioversión farmacológica',
    category: 'Cardiovascular',
    icon: Icons.favorite_rounded,
    content: '''1. Adenosina 6 mg/2 mL (amp)
   Administrar 6 mg EV en bolo rápido + flush rápido con 20 mL SF.
   Si no revierte en 1–2 min → repetir con 12 mg.
   Si no revierte → repetir 12 mg (3ra dosis).
   Acceso venoso antecubital o yugular (cuanto más proximal, mejor efecto).

Contraindicaciones absolutas:
- BAV 2° y 3° grado.
- Asma severa / EPOC severo (broncoespasmo grave).
- Síndrome de Wolf-Parkinson-White (WPW) con FA o Flutter.
- Bloqueo sinusal o disfunción sinusal sin marcapasos.

Notas:
- Monitorización ECG continua durante la administración.
- Tener equipo de reanimación disponible (puede provocar asistolia transitoria breve).
- No es útil en FA ni Flutter auricular (los termina o enlentece transitoriamente pero no los revierte).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'tv_amiodarona',
    title: 'TV Monomorfa Estable — Amiodarona',
    subtitle: 'Taquicardia ventricular con pulso — manejo inicial',
    category: 'Cardiovascular',
    icon: Icons.monitor_heart_rounded,
    content: '''⚠️ CLASIFICACIÓN PREVIA OBLIGATORIA:
→ TV con pulso + estable hemodinámicamente: tratamiento farmacológico.
→ TV con pulso + inestable (hipotensión, síncope, EAP, dolor torácico): CARDIOVERSIÓN ELÉCTRICA SINCRONIZADA inmediata.
→ TV sin pulso → protocolo de PCR / FV (desfibrilación).

1. Amiodarona 150 mg/3 mL (amp)
   Dosis de ataque: 150 mg EV en 10 min (diluido en 100 mL SG 5%).
   Mantenimiento: 1 mg/min en infusión continua por 6h;
   luego 0,5 mg/min por 18h.

Preparación infusión continua (BIC):
   Diluir 3 amp (450 mg) en 250 mL SG 5%.
   Velocidad inicial: ~33 mL/h (1 mg/min).

⚠️ Advertencias sobre Amiodarona:
- Vida media extremadamente larga (40–55 días): los efectos persisten semanas.
- Toxicidad pulmonar (neumonitis): vigilar disnea progresiva, rx tórax.
- Toxicidad tiroidea: puede causar hipo o hipertiroidismo.
- Toxicidad hepática: controlar enzimas hepáticas.
- Prolongación del QT: monitorización ECG continua.
- Interacciones: potencia efecto de warfarina, digoxina.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'fa_flutter_aguda',
    title: 'FA / Flutter — Control de Frecuencia Ventricular',
    subtitle: 'Fibrilación auricular aguda — control de respuesta ventricular',
    category: 'Cardiovascular',
    icon: Icons.electric_bolt_rounded,
    content: '''Control de FC:
1. Metoprolol 5 mg (amp)
   Administrar 5 mg EV en 5 min.
   Repetir cada 5–10 min hasta 15 mg (máx 3 dosis).

2. Verapamil 5 mg (amp)
   Administrar EV lento en 2–3 min.
   Puede repetir a los 15–30 min.

3. Amiodarona 150 mg/3 mL
   150 mg EV en 10 min; luego BIC 1 mg/min.

Digoxina (control de FC en FA con IC sistólica asociada):
• Digoxina 0,25 mg VO/EV c/24h (dosis de mantenimiento).
⚠ ALERTAS SOBRE DIGOXINA:
- Margen terapéutico ESTRECHO: nivel terapéutico 0,5–0,9 ng/mL.
- Riesgo ALTO en insuficiencia renal: reduce dosis o evitar (ajustar según ClCr).
- Hipopotasemia AUMENTA toxicidad: controlar K+ siempre antes.
- Signos de intoxicación: náuseas, xantopsia, bloqueos AV, arritmias.
- NO suspender abruptamente si se usa cronicamente.

Alta (anticoagulación):
• Apixabán 5 mg — 1 comprimido cada 12h, VO
• Rivaroxabán 20 mg — 1 comprimido/día con cena, VO

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'bradiarritmia_atropina',
    title: 'Bradicardia Sintomática',
    subtitle: 'Atropina / Adrenalina / Marcapasos transcutáneo',
    category: 'Cardiovascular',
    icon: Icons.heart_broken_rounded,
    content: '''\u26a0\ufe0f BRADICARDIA SINTOMÁTICA: FC <50 lpm + síntomas (hipotensión, síncope, dolor torácico, EAP).

PASO 1: Suspender fármacos bradicardizantes si es posible:
- Betabloqueantes / calcioantagonistas / digoxina / amiodarona.
⚠ BETABLOQUEANTES: NO suspender abruptamente (fenómeno rebote simpático).
  Reducir dosis gradualmente con monitoreo.

PASO 2: Tratamiento farmacológico:
1. Atropina 0,5 mg/mL (amp 1 mL)
   Administrar 0,5–1 mg EV en bolo.
   Repetir cada 3–5 min (máx 3 mg).
   (Ineficaz en bloqueo AV tipo Mobitz II o bloqueo completo).

PASO 3: Si no responde a atropina:
2. Adrenalina (Epinefrina) 1 mg/mL
   Diluir en infusión continua: 0,05–1 mcg/kg/min (titular).
3. Dopamina 50 mg/10 mL
   BIC 5–20 mcg/kg/min (segunda línea, alternativa).

PASO 4: Marcapasos:
- Preparar marcapasos transcutáneo inmediatamente si hay inestabilidad.
- Marcapasos transvenoso transitorio si bradicardia es persistente o refractaria.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'sca_sindrome_coronario',
    title: 'SCA — Síndrome Coronario Agudo',
    subtitle: 'IAM / AI — manejo inicial',
    category: 'Cardiovascular',
    icon: Icons.bloodtype_rounded,
    content: '''1. AAS 100–300 mg
   300 mg dosis de carga VO (masticar).
   Luego 100 mg/día, VO.

2. Ticagrelor 90 mg
   Dosis de carga: 2 comprimidos (180 mg) VO.
   Mantenimiento: 1 comprimido cada 12h, VO.
   (Alternativa: Clopidogrel 300–600 mg carga, luego 75 mg/día)

3. Atorvastatina 80 mg
   1 comprimido/noche, VO.

4. Enoxaparina (según peso)
   1 mg/kg SC cada 12h.

5. Nitroglicerina [Tridil®] 50 mg/10 mL
   Diluir en 240 mL SF 0,9% → BIC 1–2 mL/h.
   Titular por PA.

Trombolisis (si no hay ICP disponible):
• Alteplase (tPA): 15 mg EV bolo + 0,75 mg/kg en 30 min + 0,5 mg/kg en 60 min.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'icad_eap_icc',
    title: 'Insuf. Cardíaca / EAP',
    subtitle: 'ICAD — Edema Agudo de Pulmón',
    category: 'Cardiovascular',
    icon: Icons.air_rounded,
    content: '''1. Furosemida 20 mg/mL (amp)
   Administrar 40–80 mg EV en bolo.

2. Nitroglicerina [Tridil®] 50 mg/10 mL
   Diluir en 240 mL SF 0,9% → BIC 1–2 mL/h.
   Titular PA (sistólica >90 mmHg).

3. Dobutamina 250 mg/20 mL
   Diluir 4 amp (80 mL) en 170 mL SF 0,9%.
   BIC: iniciar 2 mL/h → titular (2,5–20 mcg/kg/min).

Hipotensión refractaria:
• Nitroprusiato [Nipride®] 50 mg/2 mL
  Diluir en 248 mL SG 5% → BIC 5 mL/h.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'crisis_hipertensiva',
    title: 'Crisis Hipertensiva',
    subtitle: 'Urgencia / Emergencia hipertensiva \u2014 algoritmo diferenciado',
    category: 'Cardiovascular',
    icon: Icons.speed_rounded,
    content: '''\u26a0\ufe0f CLASIFICACI\u00d3N OBLIGATORIA ANTES DE TRATAR:
\u2192 URGENCIA: PA alta sin daño de \u00f3rgano blanco \u2192 descenso gradual en 24\u201348h, VO.
\u2192 EMERGENCIA: PA alta CON daño agudo de \u00f3rgano blanco \u2192 descenso controlado EV en UTI/guardia.

URGENCIA HIPERTENSIVA (sin daño orgánico):
1. Captopril 25 mg VO (o SL si no puede tragar)
   Repetir cada 30\u201360 min seg\u00fan respuesta (m\u00e1x 100 mg).
2. Clonidina 0,15 mg VO
   Alternativa especialmente si frecuencia card\u00edaca acelerada.
3. Labetalol 200 mg VO
   \u00datil si hay taquicardia asociada o disinci\u00f3n aortica leve.

EMERGENCIA HIPERTENSIVA (con daño de órgano blanco \u2014 EV):
A. ACV Hemorr\u00e1gico / ENC\u00c9FALO:
   \u2022 Objetivo: PA <180/105 mmHg.
   \u2022 Nicardipina 25 mg/10 mL: BIC 5\u201315 mg/h (titular).
   \u2022 Labetalol 20 mg EV en 2 min \u2192 repetir 40\u201380 mg c/10 min (m\u00e1x 300 mg).

B. EAP / INSUFICIENCIA CARD\u00cdACA:
   \u2022 Nitroglicerina [Tridil\u00ae] 50 mg/10 mL: BIC 5\u201320 mcg/min (titular PA).
   \u2022 Furosemida 40\u201380 mg EV \u2014 SOLO si hay sobrecarga vol\u00e9mica / EAP (NO rutinariamente).
   \u2022 Nitroprusiato [Nipride\u00ae] si falla nitroglicerina.

C. SCA / ANGINA INESTABLE:
   \u2022 Nitroglicerina SL + BIC.
   \u2022 Labetalol EV (si no hay IC descompensada).

D. DISECCIÓN AÓRTICA (reducir FC Y PA):
   \u2022 Esmolol 10 mg/mL: BIC 50\u2013200 mcg/kg/min \u2192 objetivo FC <60 lpm.
   \u2022 Luego: Nitroprusiato o Nicardipina para PA objetivo <120/80.
   \u2022 Morfina 2\u20134 mg EV para analgesia.

E. ECLAMPSIA / PREECLAMPSIA GRAVE:
   \u2022 Labetalol 20 mg EV o Hidralazina 5 mg EV (de elecci\u00f3n en embarazo).
   \u2022 EVITAR: IECAs, ARA II, Nitroprusiato.

\u26a0\ufe0f Furosemida NO se indica de rutina en Crisis Hipertensiva.
   Solo en EAP o cuando haya evidencia de sobrecarga hidros\u00f3dica real.

---
\u2695 Modelo educativo \u2014 adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'tvp_tep_anticoagulacion',
    title: 'TVP / TEP — Anticoagulación',
    subtitle: 'Trombosis venosa — tratamiento inicial',
    category: 'Cardiovascular',
    icon: Icons.water_rounded,
    content: '''Anticoagulación (elegir 1):
1. Enoxaparina (según peso)
   1 mg/kg SC cada 12h (o 1,5 mg/kg/día).

2. Rivaroxabán 15 mg
   2 comprimidos cada 12h con alimentos por 21 días.
   Luego 20 mg/día.

3. Heparina No Fraccionada (HNF)
   Bolo 80 UI/kg EV + BIC 18 UI/kg/h.

Trombolisis (TEP masivo/submasivo grave):
• Alteplase 100 mg EV:
  10 mg bolo EV + 90 mg en 2h en BIC.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'aminas_vasoativas',
    title: 'Vasoactivos — Infusión Continua',
    subtitle: 'Noradrenalina · Dobutamina · Vasopresina — shock',
    category: 'Cardiovascular',
    icon: Icons.science_rounded,
    content: '''VASOPRESOR DE 1° LÍNEA — Shock Séptico / Distributivo:
Noradrenalina 2 mg/mL (amp 4 mL):
   Diluir 4 amp (16 mg) en 234 mL SF 0,9% → concentración 0,064 mg/mL.
   Iniciar: 5 mL/h (0,05 mcg/kg/min).
   Rango: 0,05–2,0 mcg/kg/min. Titular por PAM objetivo ≥65 mmHg.
   ✅ Primera línea en shock séptico (Surviving Sepsis Campaign).

INOTRÓPICO — Disfunción miocárdica / bajo gasto:
Dobutamina 250 mg/20 mL:
   Diluir 4 amp en 170 mL SF 0,9% (concentración 4 mg/mL).
   Iniciar: 2 mL/h. Rango: 2,5–20 mcg/kg/min.
   ⚠ Solo si hay evidencia de hipoperfusión tisular con precarga adecuada.
   ⚠ Puede causar taquiarritmias — monitoreo ECG continuo.

VASOPRESOR 2° LÍNEA — refractario a noradrenalina:
Vasopresina 20 UI/amp:
   Diluir 3 amp en 57 mL SF 0,9% (1 UI/mL).
   BIC: 0,01–0,04 UI/min (efecto ahorrador de catecolaminas).

VASOPRESOR — contexto específico (bajo gasto + bradicardia):
Dopamina 50 mg/10 mL:
   Diluir 5 amp en 200 mL SF 0,9% (10 mg/mL).
   Rango: 5–20 mcg/kg/min.
   ⚠ Mayor incidencia de arritmias que noradrenalina — no es primera línea en sepsis.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // NEUROLOGÍA
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'migrana_jaqueca',
    title: 'Migraña',
    subtitle: 'Manejo agudo y tratamiento profiláctico',
    category: 'Neurología',
    icon: Icons.psychology_rounded,
    content: '''Guardia (ataque agudo):
1. Metoclopramida 10 mg/2 mL
   Diluir en 100 mL SF 0,9%; EV en 15–20 min.
   (Alternativa: Clorpromazina 12,5–25 mg EV diluid.)

2. Cetoprofeno 100 mg/2 mL
   Diluir en 100 mL SF 0,9%; EV en 20 min.

3. Dexametasona 4 mg
   1 amp EV (reducción recurrencia).

Oral (leve-moderada):
• Dipirona 1 g — 1 comprimido cada 6h
• Ibuprofeno 400–600 mg — cada 8–12h por 5 días
• Sumatriptán 50–100 mg — 1 comprimido al inicio del dolor
  (Repetir a las 2h si necesario, máx 2/día)

Profilaxis (si ≥4 episodios/mes):
• Propranolol 40 mg VO, 2 veces/día
• Amitriptilina 25 mg VO, a la noche

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'vertigo_cinarizina',
    title: 'Vértigo Agudo / Síndrome Vestibular',
    subtitle: 'Dimenhidrinato · Cinarizina · Betahistina',
    category: 'Neurología',
    icon: Icons.rotate_right_rounded,
    content: '''1. Dimeninato [Dramin®] 50 mg/mL
   Diluir 1 amp en 100 mL SF 0,9%; EV en 30 min.
   (Alternativa VO: 50–100 mg cada 6–8h)

2. Cinarizina 25 mg
   1 comprimido cada 8h, VO.
   □ Cant: 30 comprimidos

Profilaxis:
• Cinarizina 75 mg — 1 comprimido a la noche

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'avc_isquemico_tpa',
    title: 'ACV Isquémico Agudo — Trombólisis',
    subtitle: 'Alteplasa (tPA) / Tenecteplasa — ventana terapéutica',
    category: 'Neurología',
    icon: Icons.bolt_rounded,
    content: '''Alteplase (tPA) 50 mg/frasco:
   Dosis total: 0,9 mg/kg (máx 90 mg).
   10% en bolo EV (en 1 min).
   90% restante en BIC durante 60 min.

Ejemplo — Paciente 70 kg:
   Dosis total: 63 mg.
   Bolo: 6,3 mg EV en 1 min.
   BIC: 56,7 mg en 60 min.

Ventana: hasta 4,5h del inicio de síntomas.
No administrar si: PA >185/110, plaquetas <100k,
  glucemia <50 o >400, RNI >1,7, uso de ACO.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'paralisis_bell',
    title: 'Parálisis de Bell',
    subtitle: 'Parálisis facial periférica — tratamiento',
    category: 'Neurología',
    icon: Icons.face_rounded,
    content: '''1. Prednisona 20 mg
   Tomar 2 comprimidos (40 mg) VO por la mañana durante 7–10 días.
   □ Cant: 14–20 comprimidos

2. Aciclovir 400 mg
   1 comprimido cada 8h por 7–10 días, VO.
   □ Cant: 21–30 comprimidos

3. Protección ocular:
   Colirio lubricante (hialuronato sódico) — 1 gota cada 4h.
   Parche ocular nocturno si cierre incompleto.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'crisis_convulsiva',
    title: 'Crisis Convulsiva / Status Epiléptico',
    subtitle: 'Diazepam · Midazolam · Fenitoína · Fenobarbital',
    category: 'Neurología',
    icon: Icons.electric_bolt_rounded,
    content: '''1ª Línea (0–5 min):
• Diazepam 10 mg/2 mL
  Diluir en 8 mL AD → administrar 5 mL EV cada 5–10 min.
  (Dosis rectal: 0,5 mg/kg en pediatría)
• Midazolam 5 mg IM/intranasal (si sin acceso venoso)

2ª Línea (si no cede tras 2 dosis BZD):
• Fenitoína 250 mg/5 mL
  15–20 mg/kg EV en BIC: máx 50 mg/min.
  Diluir en SF 0,9% (NO SG — precipita).
• Fenobarbital 100 mg/mL
  20 mg/kg EV en BIC: máx 100 mg/min.

Status Epiléptico Refractario:
• Midazolam en BIC: 0,2 mg/kg bolo → 0,05–0,5 mg/kg/h.
• UCI: propofol o tiopental.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'meningitis_empirica',
    title: 'Meningitis Bacteriana',
    subtitle: 'Antibioticoterapia empírica urgente',
    category: 'Neurología',
    icon: Icons.bug_report_rounded,
    content: '''1. Dexametasona 4 mg/mL
   0,15 mg/kg EV cada 6h por 4 días.
   Administrar ANTES del ATB.

2. Ceftriaxona 1 g
   2 g EV cada 12h.

3. Ampicilina 1 g (si >50 años, inmunosuprimido — Listeria):
   2 g EV cada 4h.

4. Vancomicina 500 mg/frasco (SAMR):
   15–20 mg/kg EV cada 12h.

5. Aciclovir 250 mg/frasco (si sospecha viral):
   10 mg/kg EV cada 8h.

BIZU: NO demorar ATB esperando tomografía/punción lumbar.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'insomnia_leve',
    title: 'Insomnio / Ansiedad Leve',
    subtitle: 'Manejo a corto plazo',
    category: 'Neurología',
    icon: Icons.bedtime_rounded,
    content: '''1. Clonazepam 0,5 mg
   1 comprimido VO a la noche (por tiempo limitado).
   □ Cant: 10 comprimidos

2. Lorazepam 1 mg
   1 comprimido VO a la noche si necesario.
   (Preferir en hepatópatas)

No farmacológico:
• Higiene del sueño + restricción cafeína.
• Psicoterapia cognitivo-conductual (primera línea real).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // RESPIRATORIO
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'asma_leve_moderada',
    title: 'Asma — Crisis Leve/Moderada',
    subtitle: 'Salbutamol · Ipratropio · Corticoides',
    category: 'Respiratorio',
    icon: Icons.air_rounded,
    content: '''1. Salbutamol [Ventolín®] 5 mg/mL
   Micronebulización: 20–40 gotas en 5 mL SF 0,9%.
   Repetir cada 20 min × 3 (1ª hora), luego cada 4–6h.
   (Alternativa MDI: 4–8 puffs cada 20 min)

2. Ipratropio [Atrovent®] 0,25 mg/mL
   Micronebulización: 20–40 gotas en 5 mL SF 0,9%.
   Cada 20 min × 3; luego cada 6–8h.

3. Prednisolona 40 mg
   1 comprimido/día VO por 5–7 días.
   (Equivalente: Prednisona 40 mg/día VO)

Alta (leve):
• Salbutamol MDI 100 mcg — 2–4 puffs cada 6h si necesario.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'asma_grave_uti',
    title: 'Asma — Crisis Grave',
    subtitle: 'Metilprednisolona · Sulfato de Magnesio',
    category: 'Respiratorio',
    icon: Icons.emergency_rounded,
    content: '''(Todo lo del asma leve/moderada +)

4. Metilprednisolona 125 mg
   1 amp EV en bolo.

5. Sulfato de Magnesio 10%
   2 g (20 mL) diluidos en 100 mL SF 0,9%.
   Infundir EV en 20 min.

6. Adrenalina 1 mg/mL (si no responde a broncodilatadores):
   0,3–0,5 mg IM. Repetir cada 20 min.

UCI / IOT si:
• Sat O2 <90% con FiO2 alta
• Agotamiento, alteración del sensorio
• pH <7,25

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'epoc_exacerbacion',
    title: 'EPOC — Exacerbación',
    subtitle: 'Broncodilatadores + Corticoides + ATB',
    category: 'Respiratorio',
    icon: Icons.cloud_rounded,
    content: '''1. Salbutamol 5 mg/mL
   Micronebulización: 20–40 gotas en 5 mL SF 0,9%.
   Cada 4–6h.

2. Ipratropio 0,25 mg/mL
   Micronebulización: 20–40 gotas en 5 mL SF 0,9%.
   Cada 6–8h.

3. Prednisona 40 mg VO por 5 días.
   (O Metilprednisolona 40 mg EV cada 6h)

4. Antibioticoterapia (si esputo purulento/fiebre):
   • Amox + Clavulanato 875/125 mg — 1 comprimido cada 12h × 7 días
   • Levofloxacina 750 mg — 1 comprimido/día × 7 días

Oxígeno: meta Sat 88–92%.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'neumonia_comunitaria',
    title: 'Neumonía Adquirida en Comunidad',
    subtitle: 'Amox/Clav · Azitromicina · Ceftriaxona',
    category: 'Respiratorio',
    icon: Icons.coronavirus_rounded,
    content: '''Ambulatorio — leve (PSI I–II):
1. Amoxicilina + Clavulanato 875/125 mg
   1 comprimido cada 12h por 7 días, VO.
2. Azitromicina 500 mg
   1 comprimido/día por 5 días, VO.
   (Alternativa: Claritromicina 500 mg cada 12h × 7 días)

Internación — moderada:
• Ceftriaxona 1–2 g EV/día + Azitromicina 500 mg EV/día.

Internación — grave / UCI:
• Piperacilina + Tazobactam 4,5 g EV cada 6h
• + Azitromicina 500 mg EV/día

Antiviral (si influenza confirmado):
• Oseltamivir 75 mg — 1 comprimido cada 12h × 5 días.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'tuberculosis_rhze',
    title: 'Tuberculosis — Tratamiento Inicial',
    subtitle: 'Esquema RHZE — 2 meses intensivo',
    category: 'Respiratorio',
    icon: Icons.biotech_rounded,
    content: '''Fase intensiva (2 meses):
RHZE — Rifampicina + Isoniazida + Pirazinamida + Etambutol
(Dosis según peso — comprimidos combinados disponibles)

Fase de mantenimiento (4 meses):
RH — Rifampicina + Isoniazida

Suplemento obligatorio:
• Piridoxina (Vitamina B6) 10–50 mg/día
  (Previene neuropatía periférica por isoniazida)

BIZU:
- Notificación obligatoria.
- Control mensual de función hepática.
- Orientar coloración naranja de orina/sudor por rifampicina.
- Baciloscopía de control al 2° mes.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // ORL — OTORRINOLARINGOLOGÍA
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'otitis_media_aguda',
    title: 'Otitis Media Aguda',
    subtitle: 'Tratamiento antibiótico y analgésico',
    category: 'Otorrinolaringología',
    icon: Icons.hearing_rounded,
    content: '''Analgesia:
1. Dipirona 1 g — 1 comprimido cada 6h, VO
2. Ibuprofeno 400 mg — 1 comprimido cada 8h por 5 días, VO

Antibiótico (si <2 años, bilateral, o grave):
1. Amoxicilina 500 mg — 1 comprimido cada 8h × 7–10 días, VO
   (Dosis pediátrica: 50 mg/kg/día cada 8h)
2. Amoxicilina + Clavulanato 875/125 mg
   1 comprimido cada 12h × 10 días, VO
   (Si falla amoxicilina o recurrente)
3. Ceftriaxona 50 mg/kg IM (si no tolera VO o alergia):
   Dosis única.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'rinosinusitis',
    title: 'Rinosinusitis Aguda',
    subtitle: 'Descongestionante · ATB si bacteriana',
    category: 'Otorrinolaringología',
    icon: Icons.face_retouching_natural_rounded,
    content: '''Viral (≤10 días) — Sintomático:
1. Sertaconazol nasal o Lavado salino nasal.
2. Dipirona 1 g — 1 comprimido cada 6h, VO.
3. Ibuprofeno 400 mg — cada 8h por 5 días, VO.
4. Seudoefedrina (descongestionante) — por max 5 días.

Bacteriana (>10 días o triada):
1. Amoxicilina + Clavulanato 875/125 mg
   1 comprimido cada 12h × 10–14 días, VO.
2. Prednisona 20 mg — 1 comprimido/día por 5–7 días.
3. Budesonida spray nasal — 2 puffs/fosa × 2/día.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'faringoamigdalitis',
    title: 'Faringoamigdalitis Aguda',
    subtitle: 'Penicilina benzatínica — Streptococcus',
    category: 'Otorrinolaringología',
    icon: Icons.sick_rounded,
    content: '''Score Centor ≥3 → Tratar con ATB:

1. Penicilina Benzatínica 1.200.000 UI
   1 amp IM en glúteo, dosis única.
   (Adultos >27 kg: 1.200.000 UI)
   (Menores de 27 kg: 600.000 UI)

Alternativas VO:
• Amoxicilina 500 mg — 1 comprimido cada 8h × 10 días
• Azitromicina 500 mg — 1 comprimido/día × 5 días
  (Si alergia a penicilina)

Analgesia:
• Ibuprofeno 400 mg — cada 8h por 5 días, VO
• Dipirona 1 g — cada 6h si dolor, VO

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'epistaxis',
    title: 'Epistaxis — Sangrado Nasal',
    subtitle: 'Ácido tranexámico · Compresión · Cauterización',
    category: 'Otorrinolaringología',
    icon: Icons.healing_rounded,
    content: '''Manejo inicial:
• Compresión manual del tabique por 10–15 min.
• Posición sentado, cabeza levemente inclinada hacia adelante.

Farmacológico:
1. Ácido tranexámico 250 mg/5 mL
   Diluir 4 frascos (1 g) en 100 mL SF 0,9%.
   Administrar EV en 10 min.
   (Alternativa local: empapar gasa con Ac. Tranexámico y comprimir)

2. Oximetazolina spray nasal
   2 puffs en la fosa afectada.

Si no cede:
• Taponamiento anterior con gasa vaselinada.
• Evaluación por ORL (cauterización, taponamiento posterior).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'otitis_externa',
    title: 'Otitis Externa',
    subtitle: 'Oído de nadador — gotas + analgesia',
    category: 'Otorrinolaringología',
    icon: Icons.hearing_disabled_rounded,
    content: '''1. Ciprofloxacina + Dexametasona gotas óticas
   3–4 gotas en oído afectado cada 12h por 7 días.

2. Dipirona 1 g — 1 comprimido cada 6h si dolor, VO.

3. Ibuprofeno 400 mg — cada 8h por 5 días (si intenso), VO.

Si celulitis periauricular:
• Cefalexina 500 mg — 1 comprimido cada 6h × 7 días, VO.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'laringitis_croup',
    title: 'Laringitis / Croup',
    subtitle: 'Corticoides · Nebulización adrenalina',
    category: 'Otorrinolaringología',
    icon: Icons.record_voice_over_rounded,
    content: '''1. Dexametasona 0,15–0,6 mg/kg VO/IM/EV (dosis única).
   (Alternativa: Budesonida 2 mg nebulizada)

2. Adrenalina 1 mg/mL (croup grave/estridoroso):
   5 mL de adrenalina 1:1000 nebulizada pura.
   Repetir cada 30 min si necesario.
   (Observar 2–4h tras nebulización por efecto rebote)

3. O2 húmedo si Sat <92%.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'amigdalitis_absceso',
    title: 'Absceso Periamigdalino',
    subtitle: 'Drenaje + antibioticoterapia sistémica',
    category: 'Otorrinolaringología',
    icon: Icons.local_hospital_rounded,
    content: '''1. Drenaje quirúrgico por ORL.

2. Penicilina G Cristalina 1.000.000 UI
   2 mill UI EV cada 4h por 7–10 días.

3. Metronidazol 500 mg
   Administrar 500 mg EV cada 8h por 7–10 días.
   (Cubre anaerobios)

4. Dexametasona 4 mg EV — 1 amp (reducción del edema).

5. Dipirona 1 g — 1 amp EV en bolo lento (analgesia).

Alta (VO):
• Amoxicilina + Clavulanato 875/125 mg cada 12h × 7 días.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // GASTROENTEROLOGÍA
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'nauseas_vomitos',
    title: 'Náuseas y Vómitos',
    subtitle: 'Metoclopramida · Ondansetrón · Domperidona',
    category: 'Gastroenterología',
    icon: Icons.sick_rounded,
    content: '''Guardia — EV:
1. Metoclopramida 10 mg/2 mL
   Diluir en 100 mL SF 0,9%; EV en 20 min.
   (Repetir cada 6–8h)

2. Ondansetrón [Vonau®] 4 mg/mL — 1 amp
   Diluir en 100 mL SF 0,9%; EV en 15 min.
   (Cada 8h)

3. Bromoprida 10 mg/2 mL
   Diluir en 20 mL; EV lentamente (cada 8–12h).

Alta — VO:
• Domperidona 10 mg — 1 comprimido antes de c/comida (3 × día)
• Ondansetrón 4–8 mg — 1 comprimido cada 8h
• Metoclopramida 10 mg — 1 comprimido cada 8h (max 5 días)

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'diarrea_aguda',
    title: 'Diarrea Aguda',
    subtitle: 'Hidratación · Probióticos · ATB si indicado',
    category: 'Gastroenterología',
    icon: Icons.water_drop_rounded,
    content: '''1. Sales de Rehidratación Oral (SRO)
   Beber 200–400 mL después de cada deposición.

2. Racecadotrilo 100 mg (anti-secretor):
   1 comprimido cada 8h, VO.
   □ Cant: 15 comprimidos

3. Loperamida 2 mg (si no hay fiebre/sangre):
   2 mg tras c/deposición (máx 16 mg/día), VO.

Antibioticoterapia (si: fiebre, sangre, compromiso general):
• Ciprofloxacina 500 mg — 1 comprimido cada 12h × 3–5 días, VO.
• Metronidazol 400 mg — cada 8h × 7 días (si Giardia o C. diff.)

Hidratación EV (si vómitos o deshidratación grave):
• SF 0,9% 1000 mL + electrolitos EV.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'hda_varicosa',
    title: 'HDA Variceal — Manejo Inicial',
    subtitle: 'Terlipresina · Octreotide · Somatostatina · endoscopía',
    category: 'Gastroenterología',
    icon: Icons.bloodtype_rounded,
    content: '''1. Octreotide 100 mcg/mL — amp 1 mL
   Bolo EV: 100 mcg.
   BIC: 50 mcg/h (diluir 5 amp en 45 mL SF 0,9% → 10 mcg/mL).

2. Terlipresina 2 mg/frasco
   2 mg EV cada 4h (iniciar ANTES de endoscopía).
   Reducir a 1 mg cada 4h tras control del sangrado.

3. Ceftriaxona 1 g EV cada 24h
   (Profilaxis infecciosa por 7 días).

4. Pantoprazol 80 mg EV bolo
   Luego BIC: 8 mg/h × 72h.

Dieta oral cero hasta endoscopía.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'hda_no_varicosa',
    title: 'HDA No Variceal — Manejo Inicial',
    subtitle: 'Úlcera péptica sangrante · IBP · endoscopía',
    category: 'Gastroenterología',
    icon: Icons.emergency_share_rounded,
    content: '''1. Pantoprazol 80 mg EV bolo.
   Luego BIC: Pantoprazol 8 mg/h × 72h.
   (Tras endoscopía con hemostasis: 40 mg EV cada 12h)

2. Clopidogrel / AAS — suspender temporalmente.

3. Ceftriaxona 1 g EV/día (si cirrosis asociada).

4. Vitamina K 10 mg EV (si coagulopatía).

H. Pylori (si presente):
• Amoxicilina 1 g + Claritromicina 500 mg + Omeprazol 40 mg
  (Todo VO cada 12h × 14 días tras hemostasis)

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'encefalopatia_hepatica',
    title: 'Encefalopatía Hepática',
    subtitle: 'Lactulosa · Rifaximina · Manejo de precipitantes',
    category: 'Gastroenterología',
    icon: Icons.psychology_alt_rounded,
    content: '''1. Lactulosa 667 mg/mL (frasco)
   30 mL VO cada 2–4h hasta 2–3 deposiciones/día.
   (Enema: 300 mL en 700 mL agua si no puede tragar)

2. Rifaximina 550 mg
   1 comprimido cada 12h, VO.
   □ Cant: 60 comprimidos

3. Suspender diuréticos/sedantes si precipitaron.

4. Tratar causa precipitante (sangrado, infección, etc.)

5. Hidratación EV según estado hemodinámico.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'pancreatitis_aguda',
    title: 'Pancreatitis Aguda',
    subtitle: 'Hidratación · Analgesia · Ayuno',
    category: 'Gastroenterología',
    icon: Icons.medical_services_rounded,
    content: '''1. Dieta oral cero (hasta mejoría).

2. Hidratación EV vigorosa:
   SF 0,9% o Ringer Lactato 250–500 mL/h en las primeras 12–24h.
   (Meta: 200–250 mL/h de mantenimiento)

3. Analgesia:
   Dipirona 1 g EV en bolo lento cada 6h.
   +
   Tramadol 100 mg — diluir en 100 mL SF 0,9%; EV en 30 min.
   (Morfina 4–6 mg EV si dolor intenso refractario)

4. Antieméticos:
   Ondansetrón 4 mg EV — diluir en 100 mL SF; en 15 min cada 8h.

ATB (solo si infección demostrada):
   Imipenem / Meropenem 1 g EV cada 8h.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'colangitis_colecistitis',
    title: 'Colangitis / Colecistitis',
    subtitle: 'Antibióticos + analgesia + hidratación',
    category: 'Gastroenterología',
    icon: Icons.local_pharmacy_rounded,
    content: '''Leve-Moderada:
1. Ciprofloxacina 400 mg/200 mL
   Administrar 1 bolsa EV cada 12h.
2. Metronidazol 500 mg
   Administrar EV cada 8h.
3. Dipirona 1 g EV — bolo lento cada 6h.

Grave / UCI:
1. Piperacilina + Tazobactam 4,5 g EV cada 6h.
2. Analgesia con Tramadol o Morfina EV.
3. Drenaje biliar urgente (CPRE/percutáneo).

Alta (postoperatorio):
• Amoxicilina + Clavulanato 875/125 mg cada 12h × 7 días, VO.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'erge_reflujo_gastroesofagico',
    title: 'ERGE — Reflujo Gastroesofágico',
    subtitle: 'IBP · Omeprazol · Cambios en el estilo de vida',
    category: 'Gastroenterología',
    icon: Icons.medication_rounded,
    content: '''Tratamiento de ERGE sin esofagitis:
1. Omeprazol 20 mg — 1 comprimido VO en ayunas × 4–8 semanas.
   (Alternativa: Pantoprazol 20 mg o Esomeprazol 20 mg)

Esofagitis moderada-grave (endoscópica):
1. Omeprazol 40 mg — 1 comprimido VO en ayunas × 8 semanas.
   (Alternativa: Pantoprazol 40 mg o Esomeprazol 40 mg)

Mantenimiento (ERGE crónico):
• Omeprazol 20 mg VO diario (dosis mínima efectiva).

Medidas no farmacológicas (fundamentales):
→ Elevar cabecera de la cama 15–20 cm.
→ Evitar comidas copiosas 3h antes de acostarse.
→ Evitar alcohol, café, chocolate, cítricos, picantes, grasas.
→ Suspender tabaco.
→ Reducir peso corporal si hay obesidad.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'ulcera_peptica_hp',
    title: 'Úlcera Péptica — Erradicación H. Pylori',
    subtitle: 'Terapia triple/cuádruple · IBP · Amoxicilina · Claritromicina',
    category: 'Gastroenterología',
    icon: Icons.medication_rounded,
    content: '''Terapia Triple Estándar × 14 días (1° línea):
1. Omeprazol 40 mg — 1 comprimido VO cada 12h.
2. Amoxicilina 1 g — 1 comprimido VO cada 12h.
3. Claritromicina 500 mg — 1 comprimido VO cada 12h.

Segunda línea (si falló Claritromicina o resistencia >15%):
Terapia cuádruple con bismuto × 14 días:
1. Omeprazol 40 mg VO cada 12h.
2. Subcitrato de Bismuto 120 mg VO cada 6h.
3. Metronidazol 500 mg VO cada 8h.
4. Tetraciclina 500 mg VO cada 6h.

Mantenimiento tras erradicación:
• Omeprazol 20–40 mg VO diario × 4–8 semanas adicionales.
• Confirmar erradicación: Test de aliento con urea-C13 (>4 semanas post-ATB).

⚠ Indicación de estudio endoscópico:
→ Úlcera gástrica: siempre confirmar cicatrización + biopsia.
→ Úlcera duodenal: endoscopia post-tratamiento si síntomas persisten.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'ascite_cirrosis',
    title: 'Ascitis — Cirrosis',
    subtitle: 'Diuréticos · Albumina · Paracentesis',
    category: 'Gastroenterología',
    icon: Icons.water_rounded,
    content: '''Leve-Moderada:
1. Espironolactona 100 mg — 1 comprimido/día, VO.
   (Titular hasta 400 mg/día)
2. Furosemida 40 mg — 1 comprimido/día, VO.
   (Si no responde a espironolactona sola)

Restricción de sodio: <2 g/día.

Ascitis a tensión (Paracentesis terapéutica >5 L):
• Albúmina humana 20% (0,2 g/mL):
  6–8 g/L extraído EV durante 30 min.

PBE (Peritonitis Bacteriana Espontánea):
• Ceftriaxona 2 g EV/día × 5 días.
• Albúmina 1,5 g/kg en día 1 + 1 g/kg en día 3.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // ENDÓCRINO
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'cad_ehh',
    title: 'CAD / EHH — Manejo Integral',
    subtitle: 'Fluidos · insulina · potasio · bicarbonato · monitoreo',
    category: 'Endocrinología',
    icon: Icons.science_rounded,
    content: '''Insulina Regular 100 UI/mL:
   Diluir 1 mL en SF 0,9% 100 mL (1 UI/mL).
   Bolo ataque: 0,1–0,15 UI/kg EV.
   Mantenimiento BIC: 0,1 UI/kg/h.
   Ejemplo — 70 kg: 7 UI bolo + BIC 7 UI/h (7 mL/h).

Control: Glucemia capilar cada 1h.
Meta de caída: 50–70 mg/dL/hora.

Hidratación:
   SF 0,9%: 15–20 mL/kg en 1h; luego 100 mL/kg en 48h.
   Si Na >150 → usar SF 0,45%.

Potasio (K⁺):
   K <3,5: reponer 10–30 mEq/L KCl ANTES de insulina.
   K 3,5–5,0: reponer 10–20 mEq/L KCl.
   K >5,0: no reponer (monitorizar).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'hipoglicemia',
    title: 'Hipoglucemia',
    subtitle: 'Glucosa 50% · Glucagón · Tiamina',
    category: 'Endocrinología',
    icon: Icons.monitor_heart_rounded,
    content: '''Con acceso venoso:
1. Glucosa 50% — 4 ampollas EV en bolo.

Sin acceso venoso:
2. Glucagón 1 mg IM.

Si etilismo / desnutrición / hepatópata:
3. Tiamina 100–300 mg EV o IM.
   (Administrar ANTES de la glucosa)

Pediatría:
• Neonatos: 2 mL/kg glucosa 10%
• Lactantes/niños: 2 mL/kg glucosa 25%
• Adolescentes: 1 mL/kg glucosa 50%

Oral leve (si consciente):
• 15–20 g de carbohidratos (jugo, caramelos, etc.)

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'control_glucemico_internacion',
    title: 'Control Glucémico en Internación',
    subtitle: 'Insulina regular BIC — hiperglucemia hospitalaria',
    category: 'Endocrinología',
    icon: Icons.monitor_rounded,
    content: '''Insulina Regular 100 UI/mL:
   Diluir 1 mL en SF 0,9% 100 mL (1 UI/mL).

Inicio BIC:
• Glucemia >180 mg/dL: BIC a 2 mL/h
• Glucemia >220 mg/dL: BIC a 4 mL/h

Ajuste:
• Glucemia <60: apagar bomba + 40 mL SG 50%.
• Glucemia <100: apagar bomba.
• Glucemia >160–180: mantener 1 mL/h.
• Glucemia >189: aumentar 2 mL/h.

Meta: 140–180 mg/dL.

Esquema basal-bolo (al suspender BIC):
• 50% NPH: ⅔ mañana + ⅓ noche.
• 50% Regular: ⅓ en cada comida.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // GENITOURINARIO
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'itu_cistitis',
    title: 'Cistitis Aguda',
    subtitle: 'Nitrofurantoína · Fosfomicina · TMP-SMX',
    category: 'Genitourinario',
    icon: Icons.water_drop_rounded,
    content: '''1. Nitrofurantoína [Macrodantín®] 100 mg
   1 comprimido cada 6h × 7 días, VO.
   □ Cant: 28 comprimidos
   (No usar si ClCr <30 o sospecha pielonefritis)

2. Fosfomicina [Monouril®] 3 g/sobre — dosis única
   Disolver en agua y tomar VO al acostarse (después de orinar).

3. TMP-SMX [Bactrim®] 800/160 mg
   1 comprimido cada 12h × 3–5 días, VO.

4. Amoxicilina + Clavulanato 500/125 mg
   1 comprimido cada 8h × 7–10 días, VO.

Analgesia urinaria:
• Fenazopiridina [Pyridium®] 200 mg — 1 comprimido cada 8h
  (Informa al paciente: orina se vuelve naranja)

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'pielonefritis',
    title: 'Pielonefritis',
    subtitle: 'Tratamiento ambulatorio e internación',
    category: 'Genitourinario',
    icon: Icons.local_hospital_rounded,
    content: '''No complicada (VO):
1. Levofloxacina 750 mg — 1 comprimido/día × 7 días, VO.
2. Ciprofloxacina 500 mg — 1 comprimido cada 12h × 10 días.
3. Amoxicilina + Clavulanato 875/125 mg cada 12h × 10–14 días.

Internación (EV):
1. Levofloxacina 500 mg/100 mL — 1 bolsa EV cada 24h.
2. Ciprofloxacina 400 mg/200 mL — 1 bolsa EV cada 12h.
3. Ceftriaxona 1 g EV cada 24h × 10–14 días.

Con sepsis:
• Pip + Tazobactam 4,5 g EV cada 6h.
• Cefepime 1–2 g EV cada 12h.
• Meropenem 1 g EV cada 8h (BLEE/resistente).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'colica_nefritica',
    title: 'Cólico Nefrítico / Urolitiasis',
    subtitle: 'Analgesia + antiespasmódico + litólisis',
    category: 'Genitourinario',
    icon: Icons.emergency_rounded,
    content: '''Guardia — EV:
1. Cetoprofeno [Profenid®] 100 mg/2 mL — 1 amp
   Diluir en 100 mL SF 0,9%; EV en 20 min.
2. Dipirona 1–2 g EV — 1 a 2 amp en bolo lento.
3. Tramadol 50 mg/mL — 1 amp diluida en 100 mL SF; EV en 1h.
4. Ondansetrón 4 mg — diluir en 100 mL SF; en 20 min.

Alta — VO:
1. Cetoprofeno 100 mg — 1 comprimido cada 12h × 5 días, VO.
2. Dipirona 1 g — 1 comprimido cada 6h, VO.
3. Tamsulosina 0,4 mg — 1 comprimido a la noche × hasta 6 semanas.
   (Expulsivo — mayor eficacia con cálculos <5 mm)

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // GINECOLOGÍA / REPRODUCTOR
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'candidosis_vaginal',
    title: 'Candidiasis Vaginal',
    subtitle: 'Azoles tópicos y orales',
    category: 'Ginecología',
    icon: Icons.spa_rounded,
    content: '''Intravaginal (elegir 1):
1. Clotrimazol 10 mg/g (crema vaginal) — 1 frasco
   1 aplicador lleno intravaginal, al acostarse × 7–14 días.
2. Miconazol 2% (crema vaginal) — 1 frasco
   1 aplicador lleno al acostarse × 7 días.
3. Nistatina 25.000 UI/g (crema) — al acostarse × 14 días.

Oral:
1. Fluconazol 150 mg — 1 comprimido VO, dosis única.
2. Itraconazol 100 mg — 2 comprimidos cada 12h × 1 día.

Recurrente (≥4 episodios/año):
• Fluconazol 150 mg días 1, 4 y 7.
• Mantenimiento: Fluconazol 150 mg VO 1×/semana × 6 meses.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'vaginosis_bacteriana',
    title: 'Vaginosis Bacteriana',
    subtitle: 'Metronidazol · Clindamicina',
    category: 'Ginecología',
    icon: Icons.healing_rounded,
    content: '''Oral:
1. Metronidazol 250 mg
   2 comprimidos (500 mg) cada 12h × 7 días, VO.
   □ Cant: 28 comprimidos

2. Clindamicina 150 mg
   2 comprimidos cada 12h × 7 días, VO.
   □ Cant: 28 comprimidos

Tópico:
• Metronidazol gel vaginal 0,75% — 1 aplicador al acostarse × 7 días.
• Clindamicina crema 2% — 1 aplicador al acostarse × 7 días.

No tratar a la pareja (excepto tricomoniasis).
Evitar alcohol durante el tratamiento (metronidazol).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'sangrado_uterino',
    title: 'Sangrado Uterino Anormal',
    subtitle: 'Estrógenos · Progestágenos · Ac. Tranexámico',
    category: 'Ginecología',
    icon: Icons.bloodtype_rounded,
    content: '''Inestable / Sin vía oral:
• Estrógenos conjugados [Premarin®] 20 mg — 1 amp EV.

Estable con vía oral:
• Estrógenos conjugados 0,625 mg — 1 comprimido cada 6h × 21–25 días.
• Seguido de Medroxiprogesterona 10 mg × 10 días.

Antifibrinolítico:
• Ác. Tranexámico 250 mg — 4 comprimidos (1 g) cada 8h × 5 días.
• (EV: 10 mg/kg cada 8h × hasta 5 días)

Mantenimiento:
• Anticonceptivo oral combinado — 1 comprimido/día × 21 días.
  Pausa 7 días y reiniciar.

Hb <7 g/dL → Concentrado de glóbulos rojos.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'herpes_genital',
    title: 'Herpes Genital',
    subtitle: 'Aciclovir · Valaciclovir — primoinfección',
    category: 'Ginecología',
    icon: Icons.coronavirus_rounded,
    content: '''Primoinfección:
1. Aciclovir 400 mg — 1 comprimido cada 8h × 7–14 días, VO.
2. Valaciclovir 500 mg — 2 comprimidos cada 12h × 7–14 días, VO.
3. Fanciclovir 125 mg — 2 comprimidos cada 8h × 7 días, VO.

Episódico (recurrencia):
• Aciclovir 800 mg cada 8h × 2 días VO.
• Valaciclovir 1 g/día × 5 días, VO.

Profilaxis (≥4–6 episodios/año):
• Aciclovir 400 mg × 2/día (indefinido), VO.
• Valaciclovir 500 mg × 1/día, VO.

Grave/diseminado — EV:
• Aciclovir 5–10 mg/kg EV cada 8h × 5–7 días.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // OSTEOMUSCULAR
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'lumbalgia_torcicolis',
    title: 'Lumbalgia / Tortícolis',
    subtitle: 'AINEs + miorelajantes — manejo agudo',
    category: 'Osteomuscular',
    icon: Icons.accessibility_new_rounded,
    content: '''Guardia — EV:
1. Dipirona 1 g/2 mL — 1 amp EV en bolo lento.
2. Cetoprofeno 100 mg/2 mL — diluir en 100 mL SF 0,9%; EV 20 min.
3. Tramadol 100 mg/2 mL — diluir en 100 mL SF 0,9%; EV 30 min.

Alta — VO:
1. Celecoxib 200 mg — 1 comprimido cada 12h × hasta 5 días.
2. Diclofenac 75 mg — 1 comprimido cada 12h × hasta 5 días.
3. Ibuprofeno 600 mg — 1 comprimido cada 12h × hasta 5 días.
4. Ciclobenzaprina 5 mg — 1 comprimido cada 12h × 5 días.
   (Precaución: somnolencia)

Combinado (Torsilax/Tandrilax):
• Paracetamol 300 mg + Cafeína + Carisoprodol + Diclofenac
  1 comprimido cada 8–12h × máx 7 días.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'gota_crisis',
    title: 'Gota — Crisis Aguda',
    subtitle: 'Colchicina · AINEs · Alopurinol',
    category: 'Osteomuscular',
    icon: Icons.medical_information_rounded,
    content: '''Crisis aguda:
1. Colchicina 0,5 mg
   Día 1: 2 comprimidos (1 mg) dosis única.
   Días 2–7: 1 comprimido cada 12h.

Analgesia guardia:
2. Dipirona 1 g/2 mL EV — bolo.
3. Tramadol 50 mg/mL — diluir en 100 mL SF; EV en 1h.

Anti-inflamatorio VO (elegir 1):
• Celecoxib 200 mg — cada 12h × hasta 5 días.
• Meloxicam 15 mg — 1/día × hasta 5 días.
• Prednisona 20 mg — 1/día × 7–10 días (si CI a AINEs).

Control de hiperuricemia (post-crisis):
• Alopurinol 100 mg — 1 comprimido/día.
  Titular de 50–100 mg cada 4 semanas.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'fractura_expuesta',
    title: 'Fractura Expuesta',
    subtitle: 'Clasificación Gustilo-Anderson + ATB',
    category: 'Osteomuscular',
    icon: Icons.healing_rounded,
    content: '''Tipo I (herida <1 cm puntiforme):
• Cefazolina 2 g EV dosis única.

Tipo II (1–10 cm) y Tipo III (>10 cm):
• Clindamicina 600 mg EV + Gentamicina 240 mg EV.

Trauma en zona rural/campo:
• Agregar: Penicilina 2.000.000 UI cada 4h
  o Metronidazol 500 mg cada 6h.

Si >60 años / choque / mioglobinuria:
• Ceftriaxona 1 g EV cada 12h.

Analgesia:
• Dipirona 1 g EV bolo + Morfina 4 mg EV si dolor intenso.

Profilaxis antitetánica según esquema vacunal.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // DERMATOLOGÍA
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'celulitis_erisipela',
    title: 'Celulitis / Erisipela',
    subtitle: 'Ambulatorio vs internación — antibioticoterapia',
    category: 'Dermatología',
    icon: Icons.medical_services_rounded,
    content: '''Ambulatorio (leve):
1. Cefalexina 500 mg — 1 comprimido cada 6h × 5–7 días, VO.
   □ Cant: 28 comprimidos
2. Cefadroxilo 500 mg — 1 comprimido cada 12h × 5–7 días, VO.
3. Amoxicilina + Clavulanato 875/125 mg cada 12h × 5–7 días.

Internación (EV):
1. Cefazolina 1 g EV cada 8h × 7 días.
2. Oxacilina 2 g EV cada 4h × 7 días.

Pediátrico grave:
• Oxacilina 150–200 mg/kg/día cada 6h.
• Ceftriaxona 50–100 mg/kg cada 12h.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'furunculo_absceso',
    title: 'Forúnculo / Absceso',
    subtitle: 'Drenaje + ATB (solo si indicado)',
    category: 'Dermatología',
    icon: Icons.healing_rounded,
    content: '''Tratamiento principal: DRENAJE quirúrgico.

ATB oral (si >5 cm, sistémico, recurrente):
1. Clindamicina 300 mg — 2 comprimidos cada 6h × 10 días, VO.
2. TMP-SMX 800/160 mg — 1 comprimido cada 12h × 10 días, VO.
3. Doxiciclina 100 mg — 1 comprimido cada 12h × 10 días, VO.

Fasceíte (grave/profunda) — internación:
• Vancomicina 15–20 mg/kg EV cada 12h
  + Pip/Tazo 4,5 g EV cada 6h.
• Desbridamiento quirúrgico urgente.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'herpes_zoster',
    title: 'Herpes Zóster',
    subtitle: 'Antiviral + analgesia + corticoide',
    category: 'Dermatología',
    icon: Icons.coronavirus_rounded,
    content: '''1. Aciclovir 800 mg (4 comprimidos 200 mg)
   4 comp × 5 veces/día × 7 días, VO.
   (Alternativa: Valaciclovir 1 g cada 8h × 7 días)

2. Prednisona 40 mg — tomar a la mañana × 5 días, VO.

3. Tramadol 50 mg — 1 comprimido cada 8h × 5 días, VO.

Neuralgia postherpética:
• Gabapentina 300 mg — titular hasta 1800 mg/día.
• Pregabalina 75 mg — cada 12h.
• Amitriptilina 25 mg — a la noche.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'urticaria',
    title: 'Urticaria Aguda',
    subtitle: 'Antihistamínicos + corticoides',
    category: 'Dermatología',
    icon: Icons.healing_rounded,
    content: '''1. Loratadina 10 mg
   1 comprimido a la noche × 5–7 días, VO.
   □ Cant: 7 comprimidos

2. Hidroxizina 25 mg (alternativa, más sedante):
   1 comprimido a la noche × 5–7 días, VO.

3. Prednisona 20 mg
   1 comprimido a la noche × 5 días, VO.

Guardia — EV/IM:
• Prometazina 50 mg/2 mL — 25 mg IM (repetir a las 2h si necesario).
• Hidrocortisona 50 mg EV diluida en 100 mL SF.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'escabiosis',
    title: 'Sarna / Escabiosis',
    subtitle: 'Ivermectina · Permetrina',
    category: 'Dermatología',
    icon: Icons.pest_control_rounded,
    content: '''1. Ivermectina 6 mg
   Dosis: 6 mg/30 kg peso — dosis única VO.
   Ejemplo: 60 kg → 2 comprimidos; 90 kg → 3 comprimidos.

Pediátrico (según peso):
   15–24 kg: ½ comprimido
   25–35 kg: 1 comprimido
   36–50 kg: 1½ comprimidos
   51–65 kg: 2 comprimidos

2. Permetrina tópica 5%:
   Aplicar en todo el cuerpo (cuello a pies) por 8–12h.
   Lavar. Repetir a los 7 días.
   (Indicada en embarazadas y <15 kg)

Tratar convivientes simultáneamente.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'tinea_corporis',
    title: 'Tinea Corporis',
    subtitle: 'Terbinafina · Miconazol — tópico y sistémico',
    category: 'Dermatología',
    icon: Icons.spa_rounded,
    content: '''Tópico (elegir 1):
1. Miconazol crema 2% — aplicar 2 × día × 2 semanas.
2. Terbinafina crema 1% — aplicar 2 × día × 2 semanas.

Oral (si diseminado):
1. Terbinafina 250 mg — 1/día × 2–6 semanas.
   (Pediátrico: <20 kg → 62,5 mg; 20–40 kg → 125 mg; >40 kg → 250 mg)
2. Itraconazol 200 mg — 1/día × 7 días.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'impetigo',
    title: 'Impétigo',
    subtitle: 'Mupirocina tópica',
    category: 'Dermatología',
    icon: Icons.local_pharmacy_rounded,
    content: '''1. Mupirocina 2% (ungüento o crema)
   Aplicar en las lesiones 3 × día × 5–7 días.

Si lesiones extensas (oral):
• Cefalexina 500 mg — 1 comprimido cada 6h × 7 días.
• Amoxicilina + Clavulanato 875/125 mg cada 12h × 7 días.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // INFECTOLOGÍA
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'sepsis_choque_septico',
    title: 'Sepsis / Choque Séptico',
    subtitle: 'ATB empírico + volumen + vasopresores',
    category: 'Infectología',
    icon: Icons.emergency_rounded,
    content: '''ATB EMPÍRICO INMEDIATO (dentro de 1h):
1. Cefepime 2 g EV cada 8h
   O Pip + Tazo 4,5 g EV cada 6h
   O Meropenem 1 g EV cada 8h (si riesgo BLEE/multirresistente).

Vancomicina (si sospecha SAMR):
   15–20 mg/kg EV cada 12h.

Reposición de volumen:
   SF 0,9% o Ringer Lactato 500 mL EV
   30 mL/kg en alícuotas de 500 mL. Reevaluar cada hora.

Vasopresor de PRIMERA LÍNEA (si PAM <65 mmHg):
   Noradrenalina BIC: iniciar 0,05 mcg/kg/min → titular.
   (La noradrenalina es el vasopresor de elección en shock séptico — Surviving Sepsis Campaign).

\u26a0\ufe0f Dopamina: NO se recomienda como estándar en shock séptico (mayor mortalidad e incidencia de arritmias vs noradrenalina).
   Usar solo en casos seleccionados: bradicardia + riesgo de taquiarritmias bajo.

Segundo vasopresor (refractario a noradrenalina):
   Vasopresina 0,03\u20130,04 UI/min BIC (efecto ahorrador de catecolaminas).

Inotrópico (si bajo gasto / disfunción miocárdica):
   Dobutamina 2,5\u20120 mcg/kg/min BIC (Solo si evidencia de hipoperfusión tisular y volumen adecuado).

Corticoide (si >0,25 mcg/kg/min de NA × 4h o shock refractario):
   Hidrocortisona 200 mg/día EV (50 mg cada 6h o BIC).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'sifilis_tratamiento',
    title: 'Sífilis',
    subtitle: 'Penicilina benzatínica — primaria/secundaria/latente',
    category: 'Infectología',
    icon: Icons.medical_services_rounded,
    content: '''Reciente (primaria/secundaria):
• Penicilina Benzatínica 1.200.000 UI — 2 amp IM
  1 amp en cada nalga, dosis única.
  (Total: 2.400.000 UI)

Alternativa (alergia a PNC):
• Doxiciclina 100 mg — 1 comprimido cada 12h × 15 días.
  (Contraindicada en embarazo)

Tardía / Latente tardía:
• Penicilina Benzatínica 2.400.000 UI IM cada 7 días × 3 dosis.
  (Total: 7.200.000 UI)

BIZU: Testear VIH en todo paciente con sífilis y viceversa.
Tratar también a parejas sexuales.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'dengue_manejo',
    title: 'Dengue — Manejo',
    subtitle: 'Grupos A/B/C/D — hidratación y monitoreo',
    category: 'Infectología',
    icon: Icons.bug_report_rounded,
    content: '''Grupo A/B (ambulatorio):
1. Dipirona 1 g — 1 comprimido cada 6h, VO.
2. Paracetamol 750 mg — 1 comprimido cada 8h, VO.
3. Hidratación oral: 60 mL/kg/día.
NO usar AINEs ni salicilatos.

Grupo C (internación):
• SF 0,9%: 10 mL/kg/h en 2h. Luego 25 mL/kg en 6h.
• Dipirona 1 g/2 mL — 1 amp EV bolo cada 6h.
• Ondansetrón 4 mg/2 mL — diluir en 100 mL SF; EV en 15 min cada 8h.
• Omeprazol 40 mg/10 mL — 1 amp EV × 24h.

Grupo D (UCI):
• SF 0,9% 20 mL/kg en 20 min. Reevaluar. Repetir si necesario.
• Albúmina 20% si caída del hematocrito.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'pep_vih_sexual',
    title: 'PEP Sexual — VIH',
    subtitle: 'Profilaxis Post-Exposición — inicio <72h — 28 días',
    category: 'Infectología',
    icon: Icons.security_rounded,
    content: '''INICIAR ANTES DE 72h — DURACIÓN: 28 días:

1. Tenofovir 300 mg + Lamivudina 300 mg
   1 comprimido/día, VO.
   □ Cant: 28 comprimidos

2. Dolutegravir 50 mg
   1 comprimido/día, VO.
   □ Cant: 28 comprimidos

Solicitar ANTES del inicio:
• VIH (4ª generación), HBsAg, Anti-HBc, Anti-HCV.
• Glucemia, función renal.

Control posterior: 4–6 semanas y 3 meses.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'tetano_heridas',
    title: 'Profilaxis Antitetánica',
    subtitle: 'Vacuna dT · SAT · IGHAT según esquema',
    category: 'Infectología',
    icon: Icons.vaccines_rounded,
    content: '''Herida de bajo riesgo:
• Inmunizado <5 años → Solo higiene local.
• Inmunizado 5–10 años → Solo higiene.
• Inmunizado >10 años → Vacuna dT 1 dosis refuerzo.
• Sin inmunización → Vacuna dT 3 dosis.

Herida de alto riesgo:
• Inmunizado <5 años → Solo higiene.
• 5–10 años → Vacuna dT + evaluar SAT/IGHAT.
• >10 años → Vacuna dT + SAT/IGHAT.
• Sin inmunización → Vacuna dT 3 dosis + SAT/IGHAT.

Dosis SAT/IGHAT:
• SAT profiláctico: 5.000 UI IM.
• IGHAT profiláctico: 250 UI IM.

ATB (si tétanos activo):
• Penicilina G 2.000.000 UI EV cada 4h × 7–10 días.
• Metronidazol 500 mg EV cada 8h × 7–10 días.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'neutropenia_febril',
    title: 'Neutropenia Febril',
    subtitle: 'Score MASCC — ATB según riesgo',
    category: 'Infectología',
    icon: Icons.biotech_rounded,
    content: '''Bajo riesgo (MASCC ≥21) — VO:
1. Ciprofloxacina 500 mg — 1 comprimido cada 12h × 10–14 días.
2. Amoxicilina + Clavulanato 875/125 mg cada 12h × 10–14 días.

Alto riesgo (MASCC <21) — EV:
Dieta supervisada (neutropénico: evitar crudos).
1. Cefepime 2 g EV cada 8h.
   O Pip + Tazo 4,5 g EV cada 6h.
   O Meropenem 1 g EV cada 8h.

Sospecha SAMR/catéter:
+ Vancomicina 1–2 g EV cada 6h.

Sospecha C. diff:
+ Metronidazol 400 mg VO cada 8h.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'leptospirosis',
    title: 'Leptospirosis',
    subtitle: 'Penicilina G / Ceftriaxona — leve y grave',
    category: 'Infectología',
    icon: Icons.water_rounded,
    content: '''Leve (VO):
1. Doxiciclina 100 mg — 1 comprimido cada 12h × 7 días.
2. Amoxicilina 500 mg — 1 comprimido cada 8h × 7 días.

Grave (EV):
1. Penicilina G Cristalina 1.500.000 U — 1 amp EV cada 6h × 7 días.
2. Ceftriaxona 1 g — 2 amp (2 g) EV cada 24h × 7 días.

Profilaxis post-exposición (exposición de alto riesgo):
• Doxiciclina 200 mg — 2 comprimidos VO, dosis única.
  (Repetir semanalmente si exposición continua)
• Azitromicina 500 mg VO, dosis única.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'herpes_simple',
    title: 'Herpes Simple (VHS)',
    subtitle: 'Aciclovir — imunocompetente e imunocomprometido',
    category: 'Infectología',
    icon: Icons.coronavirus_rounded,
    content: '''Primoinfección:
• Aciclovir 400 mg — 1 comprimido cada 8h × 7–10 días, VO.
• Valaciclovir 1000 mg — 1 comprimido cada 12h × 7–10 días.

Recurrencia (imunocompetente):
• Aciclovir 800 mg cada 8h × 2 días.
• Fanciclovir 1000 mg cada 12h × 1 día.

Terapia supresiva crónica (≥6 episodios/año):
• Aciclovir 200 mg — 2 comp cada 12h × indefinido.

Grave/Inmunosuprimido — EV:
• Aciclovir 5 mg/kg EV cada 8h × 5–7 días.
  (Meningitis herpética: 10–12,5 mg/kg EV cada 8h × 14–21 días)

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // PSIQUIATRÍA
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'agitacion_psicomotora',
    title: 'Agitación Psicomotriz',
    subtitle: 'Haloperidol · Midazolam · Prometazina — guardia',
    category: 'Psiquiatría',
    icon: Icons.psychology_rounded,
    content: '''Oral (si cooperativo):
• Clonazepam 2 mg — repetir cada 1h (máx 8 mg/día).
• Risperidona 2 mg — repetir cada 1h (máx 8 mg/día).
• Olanzapina 10 mg — repetir cada 4h (máx 30 mg/día).

Intramuscular:
• Haloperidol 2,5–10 mg IM — repetir cada 30 min (máx 30 mg/día).
• Haloperidol 5 mg + Midazolam 15 mg IM.
• Haloperidol 5 mg + Prometazina 50 mg IM.
• Midazolam 5–15 mg IM — repetir cada 30 min.
  (Monitorizar depresión respiratoria)

BIZU: ECG previo si se usa haloperidol (QTc <500 ms).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'sindrome_psicotico',
    title: 'Síndrome Psicótico Agudo',
    subtitle: 'Haloperidol · Risperidona · Olanzapina',
    category: 'Psiquiatría',
    icon: Icons.psychology_alt_rounded,
    content: '''1ª Línea:
• Haloperidol 1–5 mg VO (máx 40 mg/día).
  IM: 2–4 mg cada 30 min si agitado (máx 3 veces).
• Risperidona 2–8 mg VO (máx 16 mg/día).
  Iniciar 2 mg/día → ajustar 1 mg/día según respuesta.
• Olanzapina 10–20 mg VO (máx 20 mg/día).
  Iniciar 5 mg/noche → ajustar c/semana.

Adyuvantes (ansiolisis):
• Midazolam 15 mg/1 mL — 0,5 de la amp IM.
• Lorazepam 2 mg VO (máx 12 mg/día).
• Prometazina 50 mg/2 mL — 1 amp IM.

Delirio en adulto mayor:
• Risperidona 0,5 mg/noche → Quetiapina 25 mg/noche.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'ansiedad_panico',
    title: 'Ansiedad Aguda / Crisis de Pánico',
    subtitle: 'Clonazepam · Lorazepam · Diazepam',
    category: 'Psiquiatría',
    icon: Icons.sentiment_very_dissatisfied_rounded,
    content: '''1. Clonazepam 2 mg VO
   Mantenimiento: 0,25–4 mg/día.

2. Lorazepam 0,5–2 mg VO
   Mantenimiento: 2–3 mg/día (máx 10 mg/día).

3. Diazepam 5–10 mg VO
   Mantenimiento: 5–40 mg/día.

4. Alprazolam 0,25–1 mg VO
   Mantenimiento: 0,5–4 mg/día.

BIZU: Benzodiacepinas → uso a corto plazo.
Derivar a psiquiatría para tratamiento definitivo.
No suspender abruptamente.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'acatisia',
    title: 'Acatisia',
    subtitle: 'Efecto adverso extrapiramidal de antipsicóticos',
    category: 'Psiquiatría',
    icon: Icons.directions_walk_rounded,
    content: '''1ª Línea:
• Propranolol 10 mg VO 2×/día
  Titular hasta 20–40 mg × 2–3/día.
  Dosis usual: 40–120 mg/día.
  CI: asma, BAV, IC descompensada.

Coadyuvante:
• Clonazepam 0,5–2,5 mg/día VO
  (Si propranolol insuficiente o CI)

Otras opciones:
• Biperideno 2 mg IM (alivio rápido)
  Mantenimiento: 2 mg VO × 2–3/día.
• Lorazepam 0,5 mg VO × 2/día.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // DISTURBIOS HIDROELECTROLÍTICOS
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'hipercalemia',
    title: 'Hiperpotasemia',
    subtitle: 'Gluconato cálcico · Insulina · Kayexalato',
    category: 'Hidroelectrolítico',
    icon: Icons.science_rounded,
    content: '''Con repercusión en ECG:
1. Gluconato de Calcio 10% — amp 10 mL
   Diluir 1 amp en 50–100 mL SF 0,9%.
   Administrar EV en 3–5 min.
   (Repetir si ECG no mejora — máx 3 veces)

Reducción de K sérico:
2. Salbutamol gotas (micronebulización):
   40 gotas en 3–5 mL SF → nebulizar cada 4h.

3. Glicoinsulina (solución polarizante):
   Insulina regular 10 UI + SG 50% 100 mL (o SG 10% 500 mL).
   BIC en 1h.

4. Sorcal [Kayexalato®] 30 g:
   Diluir en 100 mL manitol 10% → VO cada 4h.

5. Furosemida 20 mg/mL:
   0,5–1 mg/kg EV cada 4h.

Refractaria → Hemodiálisis de urgencia.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'hipocalemia',
    title: 'Hipopotasemia',
    subtitle: 'KCl oral e IV según gravedad',
    category: 'Hidroelectrolítico',
    icon: Icons.science_rounded,
    content: '''Leve (K >3,0 mEq/L) — VO:
1. KCl jarabe 6% (60 mg/mL):
   10–30 mL cada 6h, VO.
2. KCl 600 mg/comprimido:
   1 comprimido después de cada comida cada 6h.

Moderada/Grave (K <3,0 mEq/L) — EV:
• KCl 10% — amp 10 mL
  Diluir 2 amp en 500 mL SF 0,9%.
  Administrar en 2–3h (acceso periférico).
  (Acceso central: hasta 4 amp en 500 mL SF)

⚠ Nunca administrar KCl sin diluir EV.
⚠ No exceder 40 mEq/h por acceso periférico.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'hipomagnesemia',
    title: 'Hipomagnesemia',
    subtitle: 'Sulfato de magnesio — leve/moderada/grave',
    category: 'Hidroelectrolítico',
    icon: Icons.science_rounded,
    content: '''Torsades de Pointes / tetania:
• Sulfato de Magnesio 10% — 2 amp (20 mL) + SG 5% 100 mL
  EV en 2–5 min.

Grave (Mg <1,0):
• Sulfato Mg 10%: 4 amp (40 mL) + SF 0,9% 460 mL.
  BIC en 12–24h.
  (Máx 6 g/día; 3 g si ClCr <30)

Moderada (Mg >1,0):
• 2 amp (20 mL) + SF/SG 480 mL → EV en 4–8h.

Leve (Mg >1,5):
• Óxido de magnesio 800–1600 mg/día VO.
• O: 1 amp (10 mL) 10% + SF 100 mL → EV en 1–2h.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'hiponatremia',
    title: 'Hiponatremia',
    subtitle: 'Solución salina 3% — corrección gradual',
    category: 'Hidroelectrolítico',
    icon: Icons.water_rounded,
    content: '''Preparación SF 3%:
890 mL NaCl 0,9% + 110 mL NaCl 20%.

Cálculo:
[Na solución − Na paciente] / (ACT + 1) = Δ esperado por litro.

ACT: Hombre <65 años = peso × 0,6
     Mujer <65 años = peso × 0,5

Meta: corrección máx 8–12 mEq/L en 24h.
(Evitar corrección brusca: riesgo de mielinolisis pontina)

Sintomática grave:
• Infundir 150 mL SF 3% en 20 min → repetir si necesario.

Hipernatremia:
• SG 5% o SF 0,45% → reducir Na máx 0,5 mEq/L/h.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // TOXICOLOGÍA
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'intoxicacion_paracetamol',
    title: 'Intoxicación — Paracetamol',
    subtitle: 'N-acetilcisteína — antídoto específico',
    category: 'Toxicología',
    icon: Icons.warning_amber_rounded,
    content: '''N-Acetilcisteína — VO:
   Dosis de ataque: 140 mg/kg en 200 mL SG 5%.
   Mantenimiento: 70 mg/kg cada 4h × hasta 17 dosis.

N-Acetilcisteína — EV:
   Ataque: 150 mg/kg EV en 60 min.
   Luego: 50 mg/kg EV en 4h.
   Luego: 100 mg/kg EV en 16h.

Máxima eficacia si se inicia en las primeras 8h.
Indicado si: ingestión >7,5 g o signos de hepatotoxicidad.

Carvón activado (si <1h de ingestión):
• 1 g/kg (máx 50 g) diluido en 200 mL agua → VO.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'intoxicacion_organofosforados',
    title: 'Intoxicación — Organofosforados',
    subtitle: 'Atropina — atropinizar hasta secar secreciones',
    category: 'Toxicología',
    icon: Icons.warning_rounded,
    content: '''1. Atropina 0,5 mg/mL
   1–2 amp EV en bolo según síntomas muscarínicos.
   (Miosis, sialorrea, broncorrea, sudoración, bradicardia)
   No hay dosis máxima — atropinizar hasta secar secreciones.
   Repetir cada 5–10 min hasta respuesta.

2. Pralidoxima (PAM/2-PAM) — si disponible:
   1–2 g EV lento (si se indica).

Descontaminación:
• Carvón activado (si <1h) o lavado gástrico (si <1h).
• Quitarse la ropa y lavar la piel con agua y jabón.

BIZU: Toxicidad colinérgica — SLUDGE:
Sialorrea, Lagrimeo, Uresis, Defecación, GI, Emesis.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'intoxicacion_opioide',
    title: 'Intoxicación — Opioides',
    subtitle: 'Naloxona — antídoto específico',
    category: 'Toxicología',
    icon: Icons.emergency_rounded,
    content: '''1. Naloxona 0,4 mg/mL — amp 1 mL
   0,4 mg EV en bolo.
   Repetir cada 2–3 min hasta 15 mg si no responde.
   (Intranasal o IM si sin acceso venoso)

BIZU: Vida media breve (30–90 min) → puede necesitar BIC si opiáceo de liberación sostenida.
Naloxona en BIC: diluir en SF 0,9%, velocidad según respuesta.

Triada clásica: Miosis + Depresión respiratoria + Coma.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'intoxicacion_benzo',
    title: 'Intoxicación — Benzodiazepinas',
    subtitle: 'Flumazenil — antídoto (usar con precaución)',
    category: 'Toxicología',
    icon: Icons.warning_amber_rounded,
    content: '''1. Flumazenil — amp 0,5 mg/5 mL
   Dosis prueba adulto: 0,3 mg EV
   (Máx acumulado: 3 mg)
   Mantenimiento si recurrencia: 0,2–1 mg/h en BIC.

⚠ CI: Epilepsia tratada con BZD, síndrome de abstinencia,
    coingestión con antidepresivos tricíclicos.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'intoxicacion_alcohol',
    title: 'Intoxicación Alcohólica',
    subtitle: 'Hidratación + Tiamina + Glucosa + Sedación',
    category: 'Toxicología',
    icon: Icons.local_bar_rounded,
    content: '''1. SF 0,9% 500 mL — 1 frasco EV inmediato.
2. Glucosa 50% — 4 amp EV en bolo.
   (O SG 5% 1 frasco EV)
3. Tiamina 100 mg — 1 amp EV cada 8h.
   (SIEMPRE antes de la glucosa si hay desnutrición/hepatopatía)

Agitación psicomotora:
4. Diazepam 5 mg/mL — diluir en 8 mL AD → 5 mg EV.
   O Midazolam 2 mg IM.
   O Lorazepam 2 mg VO.

Refractario a BZD:
5. Haloperidol 5 mg/mL — 1 amp IM.

Abstinencia alcohólica:
+ Fenobarbital 130 mg en 100 mL SF EV.
+ Propofol 1 mg/kg EV lento si refractario.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // ANAFILAXIA / ALERGIAS
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'anafilaxia_choque',
    title: 'Anafilaxia / Choque Anafiláctico',
    subtitle: 'Adrenalina IM — tratamiento de urgencia',
    category: 'Urgencias',
    icon: Icons.warning_rounded,
    content: '''1. Adrenalina 1 mg/mL — 1ª LÍNEA
   Adultos >50 kg: 0,5 mg IM (0,5 mL de 1 mg/mL).
   Pediátrico: 0,01 mg/kg IM (máx 0,3 mg).
   Aplicar en músculo vasto lateral (muslo).
   Repetir cada 5–15 min si necesario.

EV (si refractaria):
• Adrenalina en bolo: diluir 1 amp en 9 mL SF → 0,1 mg/mL
  Administrar 1 mL (0,1 mg) EV.
• BIC: 0,05–0,3 mcg/kg/min.

2. Metilprednisolona 125 mg EV (adyuvante, inicio 4–6h).
3. Difenidramina 50 mg EV (antialérgico adyuvante).

Broncoespasmo:
4. Salbutamol nebulizado: 10–20 gotas en 5 mL SF.
   O Sulfato de Magnesio 2 g EV (adulto).

Volumen: SF 0,9% 1.000–2.000 mL EV rápido.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'alergias_antihistaminicos',
    title: 'Alergias — Antihistamínicos',
    subtitle: 'Loratadina · Desloratadina · Hidroxizina',
    category: 'Urgencias',
    icon: Icons.healing_rounded,
    content: '''Oral:
• Loratadina 10 mg — 1 comprimido a la noche × 5–7 días.
  (En muy sintomático: 10 mg × 2/día)
• Desloratadina 5 mg — 1 comprimido 1–2×/día.
  (Menor riesgo de somnolencia)
• Hidroxizina 25 mg — 1 comprimido a la noche.

IM/EV:
• Prometazina 25 mg IM — puede repetir a las 2h.
  ⚠ Evitar EV (riesgo de gangrena por extravasación).
• Hidrocortisona 50 mg EV — diluida en 100 mL SF.
• Dexametasona 4 mg EV — diluida en 100 mL SF.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // ACCIDENTES OFÍDICOS
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'accidente_botrópico',
    title: 'Accidente Botrópico — Yarará',
    subtitle: 'Suero antibotrópico según gravedad',
    category: 'Urgencias',
    icon: Icons.warning_amber_rounded,
    content: '''Suero Antibotrópico (SAB) — amp 5 mL:
• Leve (edema 1 segmento): 4 amp (20 mL) EV.
• Moderado (edema 2 segmentos): 8 amp (40 mL) EV.
• Grave (≥3 segmentos/sangrado): 12 amp (60 mL) EV.

Preparación: Diluir en SF 0,9% o SG 5% (razón 1:4).
Ejemplo: 8 amp + 160 mL SF = 200 mL total.
Infundir en 20–60 min (vel 8–12 mL/min).

BIZU: NO usar torniquete, hielo, incisiones.
Hidratación vigorosa si moderado/grave (SF 0,9% 20 mL/kg).
Tramadol 50–100 mg EV si dolor intenso.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'accidente_escorpionismo',
    title: 'Escorpionismo',
    subtitle: 'Suero antiescorpiónico según cuadro',
    category: 'Urgencias',
    icon: Icons.pest_control_rounded,
    content: '''Leve (dolor/parestesia local):
• Manejo sintomático + analgesia.
• Observar adulto 2–3h; niño 6–12h.

Moderado:
• Suero antiescorpiónico (SAEsc) 2–3 amp EV en 20–60 min.

Grave (vómitos incoercibles, convulsión, EAP, choque):
• SAEsc 4–6 amp EV en 20–60 min.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // HEMATOLOGÍA
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'anemia_ferropriva',
    title: 'Anemia Ferropénica',
    subtitle: 'Sulfato ferroso VO — hierro EV',
    category: 'Hematología',
    icon: Icons.bloodtype_rounded,
    content: '''Oral:
1. Sulfato ferroso 300 mg (60 mg Fe elemental)
   1 comprimido antes del desayuno, almuerzo y cena.
   Tomar con alimentos ácidos. Evitar lácteos concomitantes.

EV (si no tolera oral, malabsorción):
2. Hierro sacarosa [Noripurum®] 100 mg/5 mL
   Diluir 5–10 mL en 250 mL SF 0,9%.
   Infundir en 30 min. 1–3×/semana según déficit.

3. Carboximaltosa férrica [Ferinject®] 50 mg/mL
   Calcular dosis según déficit de hierro.
   Diluir en 100–250 mL SF. Infundir 1×/semana en 10–15 min.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'hemocomponentes',
    title: 'Hemocomponentes — Transfusión',
    subtitle: 'Glóbulos rojos · Plaquetas · PFC · Crioprecipitado',
    category: 'Hematología',
    icon: Icons.water_drop_rounded,
    content: '''Concentrado de Glóbulos Rojos:
• Vel: 60–120 min (máx 4h). Acceso exclusivo.
• Elevación Hb esperada: 1–1,5 g/dL.
• Irradiado: post-transplante, Hodgkin.
• Lavado: reacción alérgica recurrente.

Concentrado de Plaquetas (adulto: 1 U/10 kg):
• Indicar si Plt <10.000/mm³.
• Sangrado + Plt <50.000 (GI/GU).

Plasma Fresco Congelado (10 mL/kg):
• Déficit múltiple de factores + sangrado activo.
• Pre-procedimiento invasivo si RNI >1,5.

Crioprecipitado (1 U/10 kg):
• Hipofibrinogenemia.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // INTUBACIÓN / PROCEDIMIENTOS
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'intubacion_sri',
    title: 'Intubación de Secuencia Rápida (ISR)',
    subtitle: 'ISR — sedativo + bloqueador neuromuscular — adulto 70 kg',
    category: 'Urgencias',
    icon: Icons.air_rounded,
    content: '''SEDATIVO (elegir 1):
1. Ketamina [Escetamina] 50 mg/mL
   Dosis: 1,5 mg/kg EV → 2 mL bolo (70 kg).
   Cardioestable. Inicio: 45–60 seg.

2. Etomidato 2 mg/mL
   Dosis: 0,3 mg/kg EV → 10 mL bolo (70 kg).
   Cardioestable. Inicio: 15–45 seg.

3. Propofol 10 mg/mL (hipotensor)
   Dosis: 1,5 mg/kg EV → 10 mL bolo.
   Inicio: <50 seg.

4. Midazolam 5 mg/mL
   Dosis: 0,3 mg/kg EV → 4 mL bolo.
   (0,1 mg/kg si inestable)

BLOQUEADOR NEUROMUSCULAR:
1. Rocuronio 10 mg/mL
   Dosis: 1,5 mg/kg → 10 mL bolo.
   Parálisis en 60 seg.

2. Succinilcolina 10 mg/mL
   Dosis: 1,5 mg/kg → 10 mL (1 amp diluida en 10 mL AD).
   Inicio EV: 30–60 seg. CI: hiperK, quemados, lesión medular.

Sedoanalgesia post-IOT:
• Propofol 5 frascos PURO → BIC 20 mL/h inicial.
• Midazolam 40 mL + 60 mL SF → BIC 5–8 mL/h.
• Fentanilo 4 amp PURO → BIC 2 mL/h.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // PÉ DIABÉTICO
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'pie_diabetico',
    title: 'Pie Diabético',
    subtitle: 'ATB ambulatorio y hospitalario',
    category: 'Infectología',
    icon: Icons.accessibility_rounded,
    content: '''Leve (celulitis <2 cm) — ambulatorio:
1. Clindamicina 300–450 mg — 1 comp cada 8h × 10–14 días, VO.
2. Ciprofloxacina 750 mg — 1 comp cada 12h × 10–14 días, VO.

Grave / extensa / necrosis — internación:
• Ceftriaxona 1–2 g EV cada 24h.
• Clindamicina 600 mg EV cada 6h.

Resistente / SAMR:
• Vancomicina 15–20 mg/kg EV cada 12h.
• Pip + Tazo 4,5 g EV cada 6h.

Osteomielitis: derivar para evaluación cirúrgica + RM.

Medidas locales:
• Descarga de presión (palmillas, bastón, muleta).
• Desbridamiento.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // CIRUGÍA / ABDOMEN AGUDO
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'abdome_agudo_cirurgico',
    title: 'Abdomen Agudo Quirúrgico',
    subtitle: 'Manejo inicial + analgesia + hidratación',
    category: 'Cirugía',
    icon: Icons.local_hospital_rounded,
    content: '''1. Dieta oral cero.
2. Sonda nasogástrica abierta.

Analgesia:
3. Dipirona 1 g/2 mL — 1 amp EV en bolo lento cada 6h.
4. Morfina 10 mg/mL — diluir en 10 mL: 4 mL EV cada 4h si dolor.

Antieméticos:
5. Ondansetrón 4 mg — diluir en 100 mL SF; EV en 20 min cada 8h.

Hidratación EV de mantenimiento:
6. SF 0,9% 500 mL + 5 amp SG 50% + 1 amp NaCl 20%
   Administrar EV cada 6h.

Anticoagulación profiláctica:
7. Enoxaparina 40 mg SC cada 12h (o 1 mg/kg SC).

Sonda vesical permanente.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'abdome_agudo_hemorragico',
    title: 'Abdomen Agudo Hemorrágico',
    subtitle: 'Reposición volemia + vasopresores + transfusión',
    category: 'Cirugía',
    icon: Icons.emergency_rounded,
    content: '''1. Ringer Lactato o SF 0,9%
   Máximo 1.000 mL EV (reposición permisiva).

2. Ácido Tranexámico 250 mg/5 mL (trauma contuso):
   Diluir 4 frascos en 100 mL → EV en 30 min.

3. Concentrado de Glóbulos Rojos.

4. Noradrenalina 4 mg/4 mL:
   Diluir 5 amp en 180 mL SF → BIC iniciar 5 mL/h.
   Titular según PAM >65 mmHg.

5. Sonda vesical.
6. 2 accesos venosos calibrosos.

BIZU: La Hb no es confiable en agudo — guiarse por gasometría y hemodinámica.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // OFTALMOLOGÍA
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'conjuntivitis',
    title: 'Conjuntivitis',
    subtitle: 'Viral y bacteriana — colirios',
    category: 'Oftalmología',
    icon: Icons.visibility_rounded,
    content: '''Viral:
1. Hialuronato de Sodio colirio 1 mg/mL (lágrimas artificiales frías)
   1 gota en ojo afectado cada 4h hasta mejoría.
   Compresas frías 10 min cada 6h.
   (Corticosteroides tópicos contraindicados)

Bacteriana aguda:
2. Ciprofloxacina colirio 0,3%
   1–2 gotas en ojo afectado cada 2h mientras despierto × 2 días.
   Luego cada 4h × 5 días más.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // CLÍNICA MÉDICA / GESTANTES
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'prescripciones_gestantes',
    title: 'Prescripción en Gestantes',
    subtitle: 'Categorías A/B/C — medicamentos seguros',
    category: 'Clínica Médica',
    icon: Icons.pregnant_woman_rounded,
    content: '''Náuseas/Vómitos (categoría A/B):
• Meclizina 25–100 mg/día VO.
• Dimeninato 50–100 mg VO cada 4–6h (antes de comidas).
• Metoclopramida 10 mg VO/EV cada 8h.
• Ondansetrón 8 mg VO cada 12h.

Dolor (categoría B):
• Paracetamol 500 mg VO cada 4–6h (máx 4 g/día).

Migraña (categoría C — con cautela):
• Paracetamol 500 mg + Cafeína 65 mg: 2 comp VO cada 6h.
• Dexametasona 0,5–20 mg/día VO/EV.
• Sumatriptán 25–100 mg VO (con supervisión).

Dispepsia (B):
• Pantoprazol 20–40 mg VO/día.
• Hidróxido de aluminio 2–4 comp masticables 1h post-comidas.

Candidiasis vaginal (B):
• Clotrimazol crema 1% vaginal × 7 días.
• Miconazol crema 2% vaginal × 7 días.
• Nistatina crema intravaginal × 7–14 días.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // URGENCIAS — NUEVAS
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'pcr_paro_cardiorrespiratorio',
    title: 'Paro Cardiorrespiratorio (PCR)',
    subtitle: 'ACLS — adrenalina · amiodarona · RCP',
    category: 'Urgencias',
    icon: Icons.monitor_heart_rounded,
    content: '''CONFIRMAR PCR → LLAMAR AYUDA → INICIAR RCP

RCP DE ALTA CALIDAD:
• Compresiones 100–120/min · profundidad 5–6 cm.
• Relación 30:2 (sin vía aérea avanzada).
• Minimizar pausas — máx 10 seg para desfibrilar.
• Rotar compresores cada 2 minutos.

RITMOS DESFIBRILABLES (FV / TV sin pulso):
1. Desfibrilar inmediatamente: 200 J bifásico (360 J monofásico).
2. RCP 2 min → re-evaluar ritmo.
3. Adrenalina (Epinefrina) 1 mg EV/IO cada 3–5 min.
4. 3° choque → Amiodarona 300 mg EV bolus.
   Dosis adicional: 150 mg si persiste FV/TV.
5. Lidocaína (alternativa): 1–1,5 mg/kg EV.

RITMOS NO DESFIBRILABLES (AESP / Asistolia):
1. RCP 2 min → Adrenalina 1 mg EV/IO cada 3–5 min.
2. Tratar causas reversibles — 6H / 5T:
   6H: Hipoxia · Hipovolemia · H⁺ (acidosis) ·
       Hipo/hipercalemia · Hipoglucemia · Hipotermia.
   5T: Neumotórax a tensión · Taponamiento · Tóxicos ·
       TEP · Trombosis coronaria (IAM).

VÍA AÉREA AVANZADA:
• IOT o dispositivo supraglótico.
• Ventilación: 10 resp/min (1 cada 6 seg) — NO hiperventila.
• EtCO₂: objetivo >10 mmHg (buen pronóstico si >20).

BICARBONATO (NaHCO₃):
• Solo si pH <7,1 · hipercalemia severa · intox. ATC.
• 1 mEq/kg EV → no usar de rutina.

POST-RCE (retorno de circulación espontánea):
• O₂: SpO₂ 94–98% (evitar hiperoxia).
• PA objetivo: PAS >90 mmHg.
• Glucemia: 140–180 mg/dL.
• Temperatura objetivo: 32–36°C × 24h (si coma post-PCR).
• ECG 12D inmediato → coronariografía si STEMI.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'fv_tv_sin_pulso',
    title: 'FV / TV sin Pulso — ACLS',
    subtitle: 'Desfibrilación + adrenalina + amiodarona',
    category: 'Urgencias',
    icon: Icons.electric_bolt_rounded,
    content: '''FIBRILACIÓN VENTRICULAR / TV SIN PULSO
→ RITMO SIEMPRE DESFIBRILABLE

ALGORITMO (repetir ciclos de 2 min RCP):
Ciclo 1: Choque 200 J → RCP 2 min
Ciclo 2: Choque 200–360 J → RCP 2 min
         + Adrenalina 1 mg EV (cada 3–5 min todos los ciclos)
Ciclo 3: Choque → RCP 2 min
         + Amiodarona 300 mg EV bolus rápido
Ciclo 4: Choque → RCP 2 min
         + Amiodarona 150 mg EV (2° dosis si persiste)
Ciclo 5+: Choque → RCP → Adrenalina alternando

DESFIBRILADOR:
• Bifásico: 200 J (o energía recomendada del equipo).
• Monofásico: 360 J en todos los choques.
• Paletas: gel conductor obligatorio.
• Posición: ápex-esternón o antero-posterior.

AMIODARONA — preparación:
• 300 mg amp = 6 mL → diluir en 20 mL de SF o DW5%.
• Infusión mantenimiento post-RCE: 150 mg en 10 min,
  luego 1 mg/min × 6h, luego 0,5 mg/min × 18h.

LIDOCAÍNA (alternativa a amiodarona):
• 1–1,5 mg/kg EV bolus → 0,5–0,75 mg/kg a los 5–10 min.
• Máximo: 3 mg/kg en 1 hora.

MAGNESIO (Torsades de Pointes):
• Sulfato de Mg 2 g (4 mL al 50%) diluido en 100 mL SF.
• Infundir EV en 1–2 min.

CAUSAS TRATABLES EN FV REFRACTARIA:
• Hipotermia → recalentar activamente.
• Intox. digitálica → anticuerpos antidigitálicos.
• Hipomagnesemia → Mg 2 g EV.
• Cocaína/simpaticomiméticos → benzodiacepinas.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'choque_cardiogenico',
    title: 'Choque Cardiogénico',
    subtitle: 'Dobutamina · Noradrenalina · Soporte hemodinámico',
    category: 'Cardiovascular',
    icon: Icons.heart_broken_rounded,
    content: '''CRITERIOS DIAGNÓSTICOS:
• PAS <90 mmHg × ≥30 min (o necesidad de vasopresores).
• Índice cardíaco <2,2 L/min/m².
• PCP >15 mmHg (congestión pulmonar).
• Signos de hipoperfusión: oliguria, lactato >2, alteración mental.

CAUSA MÁS FRECUENTE: IAM extenso (VI o VD).

MEDIDAS INICIALES:
1. O₂: SpO₂ >94% — IOT si Glasgow <8 o FR >30.
2. Acceso EV × 2 + monitoreo continuo (ECG, SpO₂, PA invasiva).
3. ECG 12D inmediato → cinecoronariografía de urgencia si STEMI.
4. Sonda vesical → diuresis horaria objetivo >0,5 mL/kg/h.

SOPORTE VASOPRESOR / INOTRÓPICO:
Noradrenalina (vasopresora — 1° línea si PAM <65):
• BIC: 0,05–0,5 mcg/kg/min → titular hasta PAM 65–70 mmHg.

Dobutamina (inotrópica — añadir si débito cardíaco bajo):
• BIC: 2–20 mcg/kg/min → iniciar 2–5 mcg/kg/min.
• Cuidado: puede agravar hipotensión y arritmias.

Dopamina (alternativa si bradicardia asociada):
• BIC: 5–15 mcg/kg/min.
• Evitar en FA y taquicardia.

DIURÉTICOS (solo si congestión sin hipoperfusión severa):
• Furosemida 40–80 mg EV en bolo.

PREPARACIÓN BIC (para 70 kg):
Noradrenalina: 4 mg en 250 mL SF → 0,05 mcg/kg/min = 13 mL/h.
Dobutamina: 250 mg en 250 mL SF → 5 mcg/kg/min = 21 mL/h.

ANTICOAGULACIÓN:
• Heparina no fraccionada 60 UI/kg EV bolus → BIC 12 UI/kg/h.
• Objetivo TTPA: 50–70 seg.

EVITAR:
• Betabloqueantes y calcioantagonistas (empeoran contractilidad).
• Vasodilatadores (nitroprusiato, nitratos) si PAM <70.
• Sobrecarga hídrica excesiva.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'torsades_de_pointes',
    title: 'Torsades de Pointes',
    subtitle: 'TV polimórfica — QT largo — Sulfato de Mg',
    category: 'Cardiovascular',
    icon: Icons.monitor_heart_rounded,
    content: '''TORSADES DE POINTES (TdP)
→ TV polimórfica asociada a QT largo

RECONOCIMIENTO:
• Morfología "en torsión" del eje QRS alrededor de la isolínea.
• QTc >500 ms (hombres) / >520 ms (mujeres) en ritmo basal.
• Frecuencia 200–300 lpm — puede autolimitarse o degenerar en FV.

TRATAMIENTO DE URGENCIA:
1. Si inestable (colapso) → desfibrilar 200 J (no cardiovertir).
2. SUSPENDER todos los fármacos que prolongan QT:
   (antipsicóticos, antiarrítmicos clase IA/III, macrólidos,
    fluoroquinolonas, antifúngicos azólicos, metadona).

SULFATO DE MAGNESIO — tratamiento de elección:
• 2 g (4 mL al 50%) diluidos en 100 mL SF 0,9%.
• Infundir EV en 1–2 minutos.
• Repetir a los 10–15 min si persiste arritmia.
• Mantenimiento: 3–20 mg/min BIC × 24h.

ESTRATEGIA PARA ACORTAR QT (si recurre):
Isoproterenol BIC: 1–4 mcg/min → FC objetivo 90–110 lpm.
(Aumenta FC → acorta QTc → suprime TdP)

MARCAPASOS TRANSVENOSO TEMPORAL:
• Si TdP recurrente refractaria.
• Frecuencia: 90–110 lpm → acorta QT mecánicamente.

CAUSAS FRECUENTES:
• Hipocalemia → reponer K⁺ a 4–4,5 mEq/L.
• Hipomagnesemia → reponer Mg2+.
• Fármacos (ver arriba) → suspender.
• Bradicardia severa → marcapasos.
• Síndrome QT largo congénito → betabloqueante.

EVITAR: amiodarona, sotalol, procainamida (prolongan QT).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'sincope_abordaje',
    title: 'Síncope — Abordaje en Guardia',
    subtitle: 'Clasificación · Riesgo · Criterios de internación',
    category: 'Urgencias',
    icon: Icons.psychology_rounded,
    content: '''SÍNCOPE: pérdida transitoria de consciencia por hipoperfusión cerebral global.

CLASIFICACIÓN Y CAUSAS:
1. Reflejo (vasovagal): desencadenante claro, pródromos, jóvenes.
2. Ortostático: al pararse, medicamentos (antihipertensivos, diuréticos).
3. Cardíaco: sin pródromos, durante esfuerzo, cardiopatía previa — ALTO RIESGO.

ECG INMEDIATO — buscar:
• QTc largo, Brugada, BCRI nuevo, bloqueo AV, delta wave.
• Infra/supradesnivel ST.

SCORE DE RIESGO — San Francisco Syncope Rule (SFSR):
(cualquier ítem = ALTO RIESGO → internar)
☐ Cardiopatía estructural conocida o ICC.
☐ Hematocrito <30%.
☐ Disnea al momento del evento.
☐ PA sistólica <90 mmHg en guardia.
☐ ECG anormal (nuevo, no sinusal o cambios agudos).

MANEJO SEGÚN RIESGO:
Bajo riesgo (vasovagal típico sin cardiopatía):
• Hidratación oral · evitar desencadenantes.
• Aumentar ingesta de sal si recurrente.
• Alta con derivación a clínica.

Alto riesgo / causa cardíaca sospechada:
• Internación + monitoreo continuo.
• Ecocardiograma · holter · electrofisiología según clínica.
• Corrección de causa de base.

Síncope ortostático:
• Suspender/reducir hipotensores, diuréticos, alfa-bloqueantes.
• Hidratación EV: SF 0,9% 500 mL en 30 min si deshidratado.
• Medias de compresión + elevar cabecera de la cama.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'edema_angioneurotico',
    title: 'Edema Angioneurótico',
    subtitle: 'Icatibant · C1-INH · Distinción de anafilaxia',
    category: 'Urgencias',
    icon: Icons.warning_amber_rounded,
    content: '''EDEMA ANGIONEURÓTICO (EAE)
→ Edema subcutáneo/submucoso SIN urticaria ni hipotensión.

TIPOS Y TRATAMIENTO:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. ALERGICO (mediado por IgE — igual a anafilaxia):
• Adrenalina 0,5 mg IM (vasto lateral) si compromiso respiratorio.
• Difenhidramina 50 mg EV + Dexametasona 8 mg EV.
• Responde a antihistamínicos y corticoides.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2. INDUCIDO POR IECA (bradiquinina — NO responde a adrenalina):
• SUSPENDER IECA inmediatamente.
• Icatibant 30 mg SC (antagonista bradicinina B2):
  → Inyectar en abdomen. Puede repetirse a 6h (máx 3 dosis/día).
• C1-Inhibidor humano 20 UI/kg EV (si disponible).
• Ácido tranexámico 1 g EV c/8h (alternativa).
• NO dar antihistamínicos ni corticoides (no son eficaces).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
3. HEREDITARIO (déficit C1-INH congénito):
• C1-INH concentrado: 20 UI/kg EV lento (1° línea).
• Icatibant 30 mg SC (alternativa).
• Plasma fresco congelado 2 UI si no hay C1-INH disponible.
• EVITAR: estrógenos, IECA, estrés.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MANEJO DE VÍA AÉREA (prioridad si afecta laringe):
• Laringoscopía directa lista + equipo de cricotiroidotomía.
• Oxígeno humidificado · posición sentada.
• IOT temprana si estridor o saturación <94%.
• Traqueotomía de urgencia si IOT fallida.

CRITERIOS DE INTERNACIÓN:
• Edema laríngeo, lingual o faríngeo.
• SpO₂ <94% o estridor.
• Edema abdominal severo (dolor intenso, vómitos).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // CARDIOVASCULAR — NUEVAS
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'dolor_toracico_protocolo',
    title: 'Dolor Torácico — Protocolo Inicial',
    subtitle: 'Diagnóstico diferencial · Triaje · Manejo',
    category: 'Cardiovascular',
    icon: Icons.favorite_rounded,
    content: '''DOLOR TORÁCICO EN GUARDIA — ABORDAJE INICIAL

PRIMER PASO — DESCARTAR CAUSAS LIFE-THREATENING:
1. SCA (IAM/AI)  2. TEP  3. Disección aórtica
4. Neumotórax a tensión  5. Taponamiento  6. Esofágo (ruptura)

EVALUACIÓN INMEDIATA (primeros 10 min):
• ECG 12D → buscar: STEMI, BCRI nuevo, Wellens, de Winter, Brugada.
• PA en ambos brazos (diferencia >20 mmHg → disección).
• SpO₂ · FR · FC · Temperatura.
• Acceso EV · monitoreo continuo.
• Troponina I/T ultrasensible: 0h y 1–2h.

CARACTERÍSTICAS DE ALTO RIESGO:
• Irradiación a brazo/mandíbula + diaforesis + náuseas → SCA.
• Inicio brusco desgarrante, migra hacia dorso → Disección Ao.
• Pleurítico + disnea + DVT → TEP.
• Hipersonoridad unilateral + MV abolido → Neumotórax.
• Yugulares ingurgitadas + ruidos cardíacos apagados → Taponamiento.

MANEJO SEGÚN SOSPECHA:
SCA → ver prescripción específica.
TEP → anticoagulación inmediata + imágenes.
Disección → control PA con betabloqueante EV + cirugía.
Neumotórax → toracocentesis de urgencia.

ANALGESIA INICIAL (mientras espera diagnóstico):
• Morfina 2–4 mg EV lento (titular c/5 min) si dolor intenso.
  Alternativa: Ketorolac 30 mg EV (si causa musculoesquelética).

DIAGNÓSTICOS DE MENOR RIESGO (diagnóstico de exclusión):
• Musculoesquelético: dolor reproducible a la palpación.
• Costocondritis: Tietze → AINEs + calor local.
• ERGE/esofágeico: IBP + antiácido + derivación ambulatoria.
• Ansiedad/pánico: ansiolítico + reevaluación.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // NEUROLOGÍA — NUEVAS
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'avc_hemorragico',
    title: 'ACV Hemorrágico — Hemorragia Intracerebral',
    subtitle: 'Control PA · Reversión anticoagulación · Neuroprotección',
    category: 'Neurología',
    icon: Icons.bolt_rounded,
    content: '''ACV HEMORRÁGICO — HEMORRAGIA INTRACEREBRAL (HIC)

DIAGNÓSTICO: TC de cráneo sin contraste (de elección en urgencias).

OBJETIVOS INICIALES (primeras 4h):
• PA sistólica → bajar a 130–140 mmHg si PAS 150–220 mmHg.
  (INTERACT-2: objetivo 130 mmHg si tolera)
• Glucemia: 140–180 mg/dL.
• Temperatura <37,5°C.
• O₂: SpO₂ >94%.
• Cabecera elevada 30°.

CONTROL DE PRESIÓN ARTERIAL EV:
Labetalol: 10–20 mg EV en 2 min → repetir c/10 min (máx 300 mg).
Nicardipina: BIC 5 mg/h → titular 2,5 mg/h c/15 min (máx 15 mg/h).
Nitroprusiato: 0,3 mcg/kg/min BIC → usar solo si refractario.
Hidralazina: 10–20 mg EV c/4–6h.

REVERSIÓN DE ANTICOAGULACIÓN (urgente):
• Warfarina + HIC: Vitamina K 10 mg EV lento (30 min) +
  CCP (complejo protrombínico) 25–50 UI/kg EV.
  Meta: INR <1,5 en <60 min.
• Dabigatrán + HIC: Idarucizumab 5 g EV (2 × 2,5 g).
• Apixabán/Rivaroxabán + HIC: Andexanet alfa (si disponible)
  o CCP 4 factores 50 UI/kg EV.

ANTICONVULSIVANTES:
• No profilácticos de rutina.
• Si convulsión: Levetiracetam 1000 mg EV en 15 min.
  Alternativa: Valproato 15 mg/kg EV.

MANEJO DE PIC ELEVADA:
• Cabecera 30° · evitar hiponatremia · normocapnia (PaCO₂ 35–40).
• Manitol 20%: 1–1,5 g/kg EV en 20 min.
• Suero salino hipertónico 3%: 150–250 mL EV en 30 min.

CIRUGÍA: considerar si:
• Hematoma cerebeloso >3 cm + deterioro.
• HIC lobar >30 mL + deterioro neurológico.
• Hidrocefalia → DVE.

CONTRAINDICACIONES ABSOLUTAS:
• Alteplase (tPA) → CONTRAINDICADO en HIC.
• Heparina → contraindicada en fase aguda.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'meningitis_viral',
    title: 'Meningitis Viral',
    subtitle: 'Aciclovir EV · soporte · diagnóstico diferencial',
    category: 'Neurología',
    icon: Icons.coronavirus_rounded,
    content: '''MENINGITIS VIRAL (aséptica)
→ Más frecuente que bacteriana; generalmente autolimitada.

CAUSAS FRECUENTES:
• Enterovirus (70%) · VHS-2 (meningitis recurrente de Mollaret).
• VHS-1 (encefalitis — forma grave).
• CMV · VEB · VVZ · Parotiditis · VIH (primoinfección).

DIAGNÓSTICO — LCR:
• Leucocitos: 10–1000 (predominio linfocitos).
• Glucosa: normal (>60% glucemia simultánea).
• Proteínas: leve aumento (<150 mg/dL).
• ADA: normal (diferencia de TBC).
• PCR virus en LCR (enterovirus, VHS).

TRATAMIENTO DE SOPORTE:
• Reposo · analgesia (paracetamol/ibuprofeno).
• Hidratación oral o EV según tolerancia.
• Antieméticos: Ondansetrón 8 mg EV c/12h.
• Analgesia: Dipirona 1 g EV c/8h.

ACICLOVIR (si sospecha VHS — SIEMPRE INICIAR EMPÍRICO):
• 10 mg/kg EV c/8h × 14–21 días (encefalitis herpética).
• 10 mg/kg EV c/8h × 10–14 días (meningitis VHS).
• Ajustar en insuficiencia renal (ClCr).
• Diluir en SF 0,9% — infundir en 1 hora.

DEXAMETASONA: NO indicada en viral (sí en bacteriana).

CRITERIOS DE ALTA PRECOZ (viral leve):
• Afebril · LCR viral claro · PCR enterovirus positivo.
• Tolerancia oral · sin signos meníngeos severos.

DERIVAR A UCI si:
• Alteración de consciencia · convulsiones · foco neurológico.
• Sospecha de encefalitis (VHS → tratar empíricamente).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // CLÍNICA MÉDICA — NUEVAS
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'insuficiencia_renal_aguda',
    title: 'Insuficiencia Renal Aguda',
    subtitle: 'Prerrenal · Renal · Postrenal — manejo inicial',
    category: 'Clínica Médica',
    icon: Icons.water_drop_rounded,
    content: '''INSUFICIENCIA RENAL AGUDA (IRA)
Criterios KDIGO: ↑ creat. ≥0,3 mg/dL en 48h · ↑ ≥1,5× basal en 7d · diuresis <0,5 mL/kg/h × 6h.

CLASIFICACIÓN Y MANEJO:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. PRERRENAL (60–70% — hipoperfusión):
• Causa: deshidratación, ICC, sepsis, hepatorrenal.
• Reposición de volumen:
  SF 0,9% 500 mL EV en 30 min → reevaluar diuresis y PA.
  Repetir hasta normovolemia (PVC 8–12, diuresis >0,5 mL/kg/h).
• Suspender: AINEs, IECA/ARA-II, diuréticos.
• Furosemida 40–80 mg EV solo si sobrecarga confirmada.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2. INTRÍNSECA (NTA más frecuente):
• Causa: isquemia, nefrotóxicos (contraste, aminoglucósidos,
  AINEs, mieloma, rabdomiólisis).
• Hidratar · suspender nefrotóxicos.
• Rabdomiólisis: SF 0,9% 1–1,5 L/h → diuresis >200 mL/h.
  Bicarbonato NaHCO₃ si CPK >5000 o mioglobinuria.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
3. POSTRENAL (obstrucción — sonda vesical urgente):
• Sondaje vesical → si obstrucción baja.
• Nefrostomía percutánea → si alta.

MANEJO GENERAL:
• Monitoreo: diuresis horaria · creatinina diaria · electrolitos.
• Hipercalemia: ver prescripción específica.
• Acidosis metabólica: bicarbonato si pH <7,2.
• Restricción proteica: 0,8–1 g/kg/día.
• Ajuste de dosis de todos los fármacos según ClCr.

INDICACIONES DE DIÁLISIS DE URGENCIA (AKI-D):
• Hipercalemia refractaria (K⁺ >6,5 mEq/L).
• Acidosis pH <7,1 refractaria.
• Edema agudo de pulmón refractario.
• Uremia sintomática (encefalopatía, pericarditis).
• Intoxicación diálizable (salicilatos, litio, metanol).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // HIDROELECTROLÍTICO — NUEVAS
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'hipernatremia',
    title: 'Hipernatremia',
    subtitle: 'Na⁺ >145 mEq/L — reposición hídrica controlada',
    category: 'Hidroelectrolítico',
    icon: Icons.science_rounded,
    content: '''HIPERNATREMIA: Na⁺ sérico >145 mEq/L
→ Siempre indica déficit de agua libre.

CAUSAS FRECUENTES:
• Pérdida de agua libre: diarrea, vómitos, sudoración, quemados.
• Diabetes insípida (central o nefrogénica).
• Ingesta inadecuada (ancianos, pacientes con disnea).
• Yatrogénica: suero fisiológico o bicarbonato en exceso.

CÁLCULO DE DÉFICIT DE AGUA LIBRE:
Déficit (L) = ACT × [(Na actual / 140) − 1]
ACT = 0,6 × peso (hombres) · 0,5 × peso (mujeres)
Ej.: Varón 70 kg, Na 158 mEq/L:
ACT = 42 L → Déficit = 42 × [(158/140) − 1] = 5,4 L

REPOSICIÓN:
Regla: NO bajar más de 10–12 mEq/L en 24h
(riesgo de edema cerebral si corrección rápida).

Velocidad máxima: 0,5 mEq/L/hora.

Líquidos de elección:
• Agua libre vía oral/SNG (preferida si tolera).
• Dextrose 5% (agua libre pura EV).
• SF 0,45% (solución hipotónica) si Na >160 mEq/L.

Fórmula de velocidad de infusión:
Volumen en 24h (mL) = Déficit calculado × 1000 / 24h → mL/h.
Agregar pérdidas insensibles + diuresis del día.

DIABETES INSÍPIDA CENTRAL:
• Desmopresina (DDAVP) intranasal 10–40 mcg/día
  o EV 1–4 mcg/día en 2 dosis.

MONITOREO:
• Na⁺ cada 4–6h al inicio → cada 12h cuando estable.
• Peso diario · balance hídrico estricto.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'hipercalcemia',
    title: 'Hipercalcemia',
    subtitle: 'Ca²⁺ >10,5 mg/dL — hidratación · bifosfonatos · calcitonina',
    category: 'Hidroelectrolítico',
    icon: Icons.science_rounded,
    content: '''HIPERCALCEMIA: Ca total >10,5 mg/dL (o Ca iónico >1,3 mmol/L).
GRAVE si Ca >14 mg/dL o síntomas severos.

CAUSAS FRECUENTES:
• Hiperparatiroidismo primario (ambulatoria, crónica, leve).
• Neoplasias (mieloma, metástasis óseas, PTHrP) — hipercalcemia grave.
• Sarcoidosis, TBC, granulomatosis.
• Intoxicación vitamina D · tiazidas · litio.
• Inmovilización prolongada.

SÍNTOMAS (regla "huesos, piedras, quejidos, gemidos"):
• Huesos: dolores óseos, fracturas.
• Piedras: nefrolitiasis, poliuria.
• Quejidos: náuseas, vómitos, estreñimiento.
• Gemidos (neurológicos): confusión, letargia, coma.
• Cardíaco: QT corto, arritmias.

TRATAMIENTO ESCALONADO:
1° HIDRATACIÓN EV VIGOROSA (urgente si Ca >12 mg/dL):
• SF 0,9%: 200–500 mL/h → reponer 2–4 L en las primeras 4–6h.
• Objetivo: diuresis 100–150 mL/h.

2° DIURÉTICO DE ASA (solo tras hidratación adecuada):
• Furosemida 20–40 mg EV c/6–12h.
• NUNCA sin hidratación previa (agrava hipercalcemia).

3° INHIBICIÓN DE RESORCIÓN ÓSEA (neoplasia, hiperPTH):
• Ácido Zoledrónico 4 mg EV en 15 min (efecto 24–48h).
• Pamidronato 60–90 mg EV en 2–4h (alternativa).
• Denosumab 120 mg SC (si falla renal o bifosfonatos contraindicados).

4° CALCITONINA (efecto rápido — primeras 12–24h):
• Calcitonina de salmón 4–8 UI/kg SC/IM c/6–12h.
• Taquifilaxia en 48–72h → usar solo puente con bifosfonatos.

5° CORTICOIDES (hipercalcemia por vitamina D/granuloma):
• Prednisona 40–60 mg/día VO o Hidrocortisona 200 mg/día EV.

DIÁLISIS: si refractaria + IRA + Ca >18 mg/dL.

MONITOREO: Ca²⁺ y electrolitos c/6–12h al inicio.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'hipocalcemia_aguda',
    title: 'Hipocalcemia Aguda',
    subtitle: 'Ca²⁺ <8,5 mg/dL — gluconato de calcio EV',
    category: 'Hidroelectrolítico',
    icon: Icons.science_rounded,
    content: '''HIPOCALCEMIA: Ca total <8,5 mg/dL (o Ca iónico <1,12 mmol/L).
GRAVE y SINTOMÁTICA si Ca <7,5 mg/dL o síntomas neuromusculares.

CAUSAS FRECUENTES:
• Hipoparatiroidismo (post-tiroidectomía o paratiroidectomía).
• Déficit de vitamina D · malabsorción.
• Hipomagnesemia (refractaria al tratamiento sin corregir Mg).
• Pancreatitis aguda severa · sepsis.
• Síndrome del hueso hambriento (post-cirugía paratiroides).
• Rabdomiólisis · transfusión masiva (citrato).

SIGNOS CLÍNICOS:
• Signo de Chvostek: espasmo al percutir nervio facial.
• Signo de Trousseau: espasmo carpal al insuflar manguito 3 min.
• Tetania, parestesias peribucales y en extremidades.
• Convulsiones, laringoespasmo, broncoespasmo.
• ECG: QT prolongado.

TRATAMIENTO EV (sintomática o Ca <7,5):
Gluconato de Calcio 10% — ampola de 10 mL (93 mg Ca elemental):
• Dosis de ataque: 1–2 ampollas (10–20 mL) + 100 mL SF 0,9%.
  Infundir EV en 10–20 minutos.
  (Puede repetirse c/60 min si síntomas persisten)
• Mantenimiento BIC: 4–6 ampollas en 500 mL SF → 50–100 mL/h.

NUNCA administrar Gluconato de Ca en bolo rápido → riesgo de paro.
NUNCA mezclar con bicarbonato → precipita.

TRATAMIENTO ORAL (asintomática, Ca 7,5–8,5):
• Carbonato de calcio 1–3 g/día VO (en 2–3 tomas, con comidas).
• Calcitriol 0,25–0,5 mcg/día (si hipoparatiroidismo).
• Vitamina D₃ 1000–2000 UI/día.

CORREGIR HIPOMAGNESEMIA ASOCIADA:
• Si Mg <1,5 mg/dL → hipocalcemia refractaria.
• Sulfato Mg 2 g EV en 30 min antes de reponer calcio.

MONITOREO: Ca iónico c/4–6h · ECG continuo durante infusión.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // ENDOCRINOLOGÍA — NUEVAS
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'crise_adrenal',
    title: 'Crisis Adrenal / Insuficiencia Suprarrenal Aguda',
    subtitle: 'Hidrocortisona EV de urgencia · reposición salina',
    category: 'Endocrinología',
    icon: Icons.medical_services_rounded,
    content: '''CRISIS ADRENAL: emergencia endocrinológica.
→ Hipotensión refractaria + antecedente de insuficiencia suprarrenal o corticoterapia crónica.

CUADRO CLÍNICO:
• Hipotensión severa, shock (PAM <65 mmHg).
• Náuseas, vómitos, dolor abdominal.
• Astenia extrema, confusión, coma.
• Fiebre, hipoglucemia, hiponatremia, hipercalemia.
• Factor precipitante: infección, cirugía, trauma, suspensión brusca de corticoides.

TRATAMIENTO INMEDIATO:
1. Acceso EV + extracción de cortisol basal (NO esperar resultado).
2. Hidrocortisona (1° elección):
   → 100 mg EV en bolo inmediato.
   → Luego 50–100 mg EV c/6–8h o BIC 200 mg/día.
   → Dexametasona 4 mg EV puede usarse si no hay hidrocortisona
      (no interfiere con test cortisol, pero sin efecto mineralocorticoide).

3. Reposición hídrica:
   SF 0,9% 1 L EV en 30–60 min → repetir según respuesta.
   Objetivo PAM >65 mmHg.

4. Glucosa:
   Dextrose 50%: 40–80 mL EV si hipoglucemia sintomática.
   Mantenimiento: SG 5% o 10% según glucemia.

5. Tratar causa precipitante (ATB si infección, etc.).

REDUCCIÓN PROGRESIVA DE DOSIS:
• Cuando estable: reducir hidrocortisona 50% c/24–48h.
• Volver a dosis fisiológica (15–25 mg/día VO) cuando tolere oral.
• Agregar fludrocortisona 0,1 mg/día VO (mineralocorticoide)
  cuando dosis de hidrocortisona <50 mg/día.

EVITAR: hipoglucemia, hiponatremia, drogas que aumentan catabolismo.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'tormenta_tiroidea',
    title: 'Tormenta Tiroidea',
    subtitle: 'PTU · propranolol · yodo · dexametasona — emergencia endocrina',
    category: 'Endocrinología',
    icon: Icons.local_fire_department_rounded,
    content: '''TORMENTA TIROIDEA — Score de Burch-Wartofsky ≥45 puntos.
→ Emergencia endocrinológica con mortalidad del 10–30%.

DESENCADENANTES: cirugía, infección, trauma, parto, amiodarona, contraste yodado.

CUADRO CLÍNICO:
• Fiebre >38,5°C · taquicardia >140 lpm.
• Agitación, confusión, psicosis, coma.
• FA, ICC, hipertensión.
• Vómitos, diarrea, ictericia.

TRATAMIENTO INMEDIATO:
1. BLOQUEO DE SÍNTESIS (1° paso — iniciar primero):
   Propiltiouracilo (PTU): 600 mg VO/SNG dosis de carga
   → luego 200–300 mg VO c/6h.
   Metimazol (alternativa): 20–25 mg VO c/6h
   (EVITAR metimazol en 1° trimestre embarazo).

2. BLOQUEO DE LIBERACIÓN DE YODO (esperar 1h después del PTU):
   Solución de Lugol (yodo-yoduro): 5–10 gotas VO c/8h.
   o Yoduro de potasio (SSKI): 5 gotas VO c/6h.

3. BLOQUEO DE CONVERSIÓN T4→T3:
   Dexametasona 2 mg EV c/6h (también cubre insuf. adrenal relativa).
   Hidrocortisona 300 mg/día EV (alternativa).

4. BETABLOQUEANTE (control de síntomas simpáticos):
   Propranolol: 60–80 mg VO c/4–6h.
   o EV: 0,5–1 mg en 5 min (con monitoreo ECG) → luego 1–2 mg c/15 min.
   Atenolol 25–50 mg VO (alternativa si broncoespasmo leve).
   EVITAR betabloqueante si ICC descompensada → usar diltiazem.

5. ANTIPIRÉTICO:
   Paracetamol 1 g EV c/6h.
   EVITAR AAS (libera T4 de proteínas transportadoras).

6. SOPORTE:
   SF 0,9% + glucosa · monitoreo continuo · UTI.
   Tratamiento de causa desencadenante.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'hipotiroidismo_mixedema',
    title: 'Coma Mixedematoso',
    subtitle: 'Levotiroxina EV · hidrocortisona · soporte — urgencia endocrina',
    category: 'Endocrinología',
    icon: Icons.thermostat_rounded,
    content: '''COMA MIXEDEMATOSO: hipotiroidismo severo descompensado.
→ Mortalidad 30–60% sin tratamiento. Urgencia endocrinológica.

DESENCADENANTES: frío, infecciones, fármacos (sedantes, amiodarona), cirugía.

CUADRO CLÍNICO:
• Alteración de consciencia (desde somnolencia hasta coma).
• Hipotermia severa (<35°C) — característica.
• Bradicardia, hipotensión, hipoventilación.
• Mixedema facial (edema periorbital, lengua grande, voz ronca).
• Hiponatremia, hipoglucemia, hipercapnia.

TRATAMIENTO:
1. TIROXINA EV (Levotiroxina):
   Dosis de carga: T4 200–400 mcg EV en bolus único lento.
   Luego: 50–100 mcg EV c/24h.
   Si disponible: T3 (liotironina) 10 mcg EV c/4–6h
   (inicio de acción más rápido que T4).

2. HIDROCORTISONA (insuf. adrenal asociada frecuente):
   100 mg EV bolo → 50 mg EV c/6h.
   INICIAR antes o junto con tiroxina (riesgo de crisis adrenal).

3. SOPORTE RESPIRATORIO:
   O₂ humidificado · IOT si pCO₂ >60 mmHg o GCS <8.

4. RECALENTAMIENTO ACTIVO PASIVO:
   Mantas térmicas · temperatura ambiental caliente.
   EVITAR recalentamiento externo agresivo (vasodilatación periférica).

5. CORRECCIÓN DE COMPLICACIONES:
   Hiponatremia: SF 0,9% (restricción hídrica si SIADH asociado).
   Hipoglucemia: Dextrose 50% 40 mL EV.
   Bradicardia severa: marcapasos temporal si FC <40 lpm.

MONITOREO: TSH + T4 libre · temperatura · ECG continuo.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'cetoacidosis_alcoholica',
    title: 'Cetoacidosis Alcohólica',
    subtitle: 'Tiamina · glucosa · hidratación — distinto de CAD',
    category: 'Endocrinología',
    icon: Icons.local_bar_rounded,
    content: '''CETOACIDOSIS ALCOHÓLICA (CAA)
→ Acidosis metabólica con anión gap alto por cetonas.
Glucemia NORMAL o BAJA (diferencia clave vs CAD).

CUADRO CLÍNICO:
• Náuseas, vómitos, dolor abdominal (típicamente 24–72h tras ingesta).
• Glucemia normal o baja (<200 mg/dL).
• Acidosis metabólica con AG alto (>12 mEq/L).
• Cetonemia/cetonuria positiva.
• Sin o con leve hiperglucemia.

DIFERENCIAS CON CAD DIABÉTICA:
• Glucemia: normal/baja (CAA) vs alta >250 mg/dL (CAD).
• Insulina: no se usa en CAA.
• Respuesta al tratamiento: rápida en CAA (horas).

TRATAMIENTO:
1. TIAMINA (PRIMERO — antes de glucosa):
   100 mg EV lento (evitar síndrome de Wernicke-Korsakoff).
   Luego 100 mg/día EV/IM × 3–5 días.

2. GLUCOSA (simultánea con tiamina si hipoglucemia):
   Dextrose 5% 1 L → luego según glucemia.
   Objetivo: glucemia 80–180 mg/dL.

3. HIDRATACIÓN:
   SF 0,9% 1 L en 1h → SF 0,9% + K⁺ según ionograma.
   (Reponer electrolitos: K⁺, Mg²⁺, fosfato frecuentemente bajos).

4. NO USAR INSULINA (agrava hipoglucemia).
5. NO BICARBONATO (pH se corrige con glucosa/tiamina).

COMPLICACIONES A BUSCAR:
• Pancreatitis aguda (lipasa/amilasa).
• Sangrado digestivo (hematemesis).
• Convulsiones por abstinencia.
• Wernicke: ataxia + oftalmoplegia + confusión.

ALTA: cuando tolerancia oral, cetonuria negativa, pH >7,35.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // INFECTOLOGÍA — NUEVAS
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'endocarditis_bacteriana',
    title: 'Endocarditis Bacteriana',
    subtitle: 'Cobertura SAMR/SAOS · hemocultivos · duración',
    category: 'Infectología',
    icon: Icons.favorite_border_rounded,
    content: '''ENDOCARDITIS INFECCIOSA (EI)
→ Diagnóstico: Criterios de Duke modificados.
Hemocultivos × 3 (de 3 sitios distintos, aerobio/anaerobio) ANTES de ATB.

GÉRMENES FRECUENTES:
• Streptococcus viridans (válvula nativa, boca).
• Staphylococcus aureus (SARM y SASM — más virulento).
• Enterococcus faecalis (ancianos, manipulaciones GU).
• Estafilococo coagulasa negativo (válvula protésica).

TRATAMIENTO EMPÍRICO INICIAL:
Válvula NATIVA — comunidad:
• Ampicilina-Sulbactam 3 g EV c/6h
  + Gentamicina 1 mg/kg EV c/8h.

Si sospecha SARM o UCI:
• Vancomicina 15–20 mg/kg EV c/12h (ajustar según nivel valle).
  + Gentamicina 1 mg/kg EV c/8h (primeros 5 días).

Válvula PROTÉSICA (<12 meses post-cirugía):
• Vancomicina 15–20 mg/kg EV c/12h
  + Rifampicina 300 mg VO c/8h
  + Gentamicina 1 mg/kg EV c/8h.

DURACIÓN (mínima):
• Streptococcus sensible: 4 semanas EV.
• Staphylococcus válvula nativa: 6 semanas EV.
• Válvula protésica: 6 semanas EV (mínimo).

INDICACIONES QUIRÚRGICAS DE URGENCIA:
• ICC refractaria por disfunción valvular.
• Infección no controlada (fiebre persistente, absceso).
• Embolia mayor recurrente con vegetación >10 mm.
• Hongo o SARM con vegetación grande.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'fasciitis_necrotizante',
    title: 'Fasciitis Necrotizante / Celulitis Necrotizante',
    subtitle: 'Cirugía urgente + meropenem + vancomicina',
    category: 'Infectología',
    icon: Icons.emergency_rounded,
    content: '''FASCIITIS NECROTIZANTE — EMERGENCIA QUIRÚRGICA
→ Infección de tejidos blandos profundos con necrosis fascial.
Mortalidad 25–35% sin desbridamiento temprano.

SIGNOS DE ALARMA (distingue de celulitis simple):
• Dolor DESPROPORCIONADO al examen externo.
• Crepitación a la palpación (gas en tejidos).
• Bula hemorrágica o necrosis cutánea.
• Progresión rápida de eritema/edema.
• Shock séptico asociado.
• TC: gas en tejidos planos (diagnóstico confirmatorio).

SCORE LRINEC ≥6: alta probabilidad de fasciitis.
(PCR, leucocitos, Na, glucemia, creatinina, hemoglobina)

TRATAMIENTO:
1. CIRUGÍA URGENTE (prioridad absoluta):
   Desbridamiento quirúrgico amplio + fasciotomía.
   Reexploración en 24h. Amputación si necesario.

2. ANTIBIOTICOTERAPIA EMPÍRICA EV INMEDIATA:
   Meropenem 1 g EV c/8h (cobertura gram-negativos y anaerobios)
   + Vancomicina 15–20 mg/kg EV c/12h (SAMR)
   + Clindamicina 600–900 mg EV c/8h (antitoxínico para estreptococo).

Alternativa:
   Pip/Tazo 4,5 g EV c/6h + Vancomicina + Clindamicina.

3. SOPORTE INTENSIVO:
   Reposición hídrica agresiva + vasopresores según necesidad.
   Transfusión si Hb <7 g/dL.

4. GAMMAGLOBULINA EV (Estreptococo grupo A):
   IVIG 1–2 g/kg en 24h (considerar si toxicidad estreptocócica).

5. OXÍGENO HIPERBÁRICO (adjunto — si disponible):
   2,5 atm × 90 min c/12h × 5–10 sesiones.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'gonorrea_chlamydia_its',
    title: 'Gonorrea / Clamidia — ITS',
    subtitle: 'Ceftriaxona + azitromicina · uretritis · cervicitis',
    category: 'Infectología',
    icon: Icons.medical_information_rounded,
    content: '''INFECCIONES DE TRANSMISIÓN SEXUAL (ITS)
Neisseria gonorrhoeae / Chlamydia trachomatis

TRATAMIENTO SIMULTÁNEO (coinfección frecuente ~40%):

GONORREA UROGENITAL NO COMPLICADA:
• Ceftriaxona 500 mg IM dosis única (1° elección).
  Si peso >150 kg: 1 g IM dosis única.
• Alternativa (si alergia a cefalosporinas):
  Gentamicina 240 mg IM + Azitromicina 2 g VO — dosis única.

CLAMIDIA:
• Doxiciclina 100 mg VO c/12h × 7 días (1° elección).
• Azitromicina 1 g VO dosis única (alternativa — menos eficaz).
• Embarazadas: Azitromicina 1 g VO dosis única.

GONORREA DISEMINADA (artritis, bacteriemia):
• Ceftriaxona 1 g EV/IM c/24h × 7 días.

URETRITIS / CERVICITIS (sin microbiología disponible):
• Ceftriaxona 500 mg IM + Doxiciclina 100 mg VO c/12h × 7 días.

ENFERMEDAD INFLAMATORIA PÉLVICA (EIP) AMBULATORIA:
• Ceftriaxona 500 mg IM dosis única
  + Doxiciclina 100 mg VO c/12h × 14 días
  + Metronidazol 500 mg VO c/12h × 14 días.

EIP INTERNADA:
• Cefoxitina 2 g EV c/6h + Doxiciclina 100 mg EV/VO c/12h × 14 días.
• O: Clindamicina 900 mg EV c/8h + Gentamicina 1,5 mg/kg EV c/8h.

NOTIFICACIÓN OBLIGATORIA + tratamiento de contactos.
Abstinencia sexual hasta 7 días post-tratamiento de ambos.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'covid19_grave',
    title: 'COVID-19 Grave y Crítico',
    subtitle: 'Dexametasona · anticoagulación · O₂ · antiviral',
    category: 'Infectología',
    icon: Icons.coronavirus_rounded,
    content: '''COVID-19 GRAVE (SpO₂ <94% o FR >30 o PaO₂/FiO₂ <300).

ESTRATIFICACIÓN:
• Moderado: SpO₂ 90–94% — hospitalización.
• Grave: SpO₂ <90% — UCI.
• Crítico: IOT / VM.

OXIGENOTERAPIA:
• Objetivo SpO₂ 92–96% (92–95% en EPOC).
• Cánula nasal de alto flujo (CNAF): flujo 40–60 L/min, FiO₂ 60–100%.
• VNI (si CNAF falla): CPAP 5–10 cmH₂O.
• IOT + VM protectora: Vt 4–6 mL/kg peso ideal, PEEP 8–14.
• Decúbito prono 16h/día si PaO₂/FiO₂ <150 (UCI).

DEXAMETASONA (RECOVERY trial — evidencia A):
• Indicada si requerimiento de O₂ suplementario o VM.
• 6 mg VO/EV c/24h × 10 días.
• NO usar sin requerimiento de O₂ (empeora en leves).

ANTICOAGULACIÓN:
• Profiláctica (todos los internados sin contraindicación):
  Enoxaparina 40 mg SC c/24h (o 60 mg si IMC >30).
• Terapéutica (si TVP/TEP confirmado):
  Enoxaparina 1 mg/kg SC c/12h.

ANTIVIRALES (primeras 5 días de síntomas):
• Nirmatrelvir/ritonavir (Paxlovid) — si disponible:
  300/100 mg VO c/12h × 5 días (ajustar en IRA).
• Remdesivir 200 mg EV día 1 → 100 mg/día × 4 días.
  (si síntomas <7 días + O₂ suplementario).

TOCILIZUMAB (anti-IL6 — si CRP >75 mg/L + VM o CNAF):
• 8 mg/kg EV dosis única (máx 800 mg).

BARICITINIB (alternativa a tocilizumab):
• 4 mg VO/día × 14 días.

EVITAR: corticoides sin indicación (primeros días) · antibióticos sin superinfección.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // HEMATOLOGÍA — NUEVAS
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'reversion_anticoagulacion',
    title: 'Reversión de Anticoagulación',
    subtitle: 'Vitamina K · CCP · Idarucizumab · Andexanet',
    category: 'Hematología',
    icon: Icons.bloodtype_rounded,
    content: '''REVERSIÓN DE ANTICOAGULACIÓN DE URGENCIA
→ Hemorragia mayor o procedimiento de emergencia.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WARFARINA (antagonista vitamina K):
Urgente (INR muy elevado + sangrado mayor):
• Vitamina K₁: 10 mg EV lento (30 min) — efecto en 4–6h.
• CCP 4 factores (Octaplex/Beriplex): 25–50 UI/kg EV.
  (Efecto inmediato — 1° elección en emergencia).
• Plasma Fresco Congelado: 15–20 mL/kg (si no hay CCP).
Objetivo: INR <1,5 en <1h.

Urgente (INR 4,5–10 sin sangrado activo):
• Vitamina K₁ 2–4 mg VO. Repetir c/24h según INR.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DABIGATRÁN (inhibidor directo trombina):
• Idarucizumab (Praxbind) 5 g EV (2 × 2,5 g en 15 min).
  → Antídoto específico — recomendado siempre que disponible.
• Si no hay antídoto: CCP 4F 50 UI/kg o diálisis.
  (Dabigatrán es dializable — único ACOD dializable).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
APIXABÁN / RIVAROXABÁN (anti-Xa):
• Andexanet alfa: dosis según fármaco y última dosis
  (dosis baja: 400 mg bolo + 480 mg BIC × 2h;
   dosis alta: 800 mg bolo + 960 mg BIC × 2h).
• Si no disponible: CCP 4 factores 50 UI/kg EV.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HEPARINA NO FRACCIONADA:
• Protamina: 1 mg por cada 100 UI de HNF administrada.
  (máx 50 mg EV en 10 min — cuidado: hipotensión).

HEPARINA DE BAJO PESO MOLECULAR (HBPM):
• Protamina: 1 mg por cada 100 UI anti-Xa de HBPM (últimas 8h).
  (Neutralización parcial ~60%).

FONDAPARINUX: sin antídoto específico.
CCP 4F 50 UI/kg (eficacia parcial).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'trombocitopenia_purpura',
    title: 'Trombocitopenia — PTI / Manejo',
    subtitle: 'Corticoides · IVIG · transfusión plaquetas',
    category: 'Hematología',
    icon: Icons.water_drop_rounded,
    content: '''TROMBOCITOPENIA EN GUARDIA
→ Plaquetas <100.000/mm³ (sangrado significativo si <20.000).

CAUSAS FRECUENTES (diagnóstico diferencial urgente):
• PTI (Púrpura Trombocitopénica Inmune): diagnóstico de exclusión.
• PTT (Púrpura Trombótica Trombocitopénica): emergencia.
• SHU (Síndrome Hemolítico Urémico).
• Trombocitopenia inducida por heparina (TIH — días 5–10).
• Sepsis · CID · hiperesplenismo · medicamentosa.

ALARMA: PTT = plaquetas bajas + anemia hemolítica microangiopática
→ PLASMAFÉRESIS URGENTE (no transfundir plaquetas en PTT).

PTI (PÚRPURA TROMBOCITOPÉNICA INMUNE):
Primera línea:
• Prednisona 1 mg/kg/día VO × 2–4 semanas → reducción gradual.
  O Dexametasona 40 mg VO c/24h × 4 días (ciclos).
• IVIG (Ig EV) si sangrado grave o necesidad de respuesta rápida:
  1 g/kg/día EV × 1–2 días.

TRANSFUSIÓN DE PLAQUETAS (indicaciones):
• Plaquetas <10.000 sin sangrado (profilaxis).
• Plaquetas <20.000 + petequias/púrpura activa.
• Plaquetas <50.000 + sangrado activo o procedimiento invasivo.
• Plaquetas <100.000 + neurocirugía o cirugía ocular.
Dosis: 1 pool (5–6 unidades) → eleva ~30.000–50.000/mm³.

TIH (TROMBOCITOPENIA INDUCIDA POR HEPARINA):
• SUSPENDER TODA HEPARINA INMEDIATAMENTE.
• Argatrobán BIC 2 mcg/kg/min (ajustar por TTPA 1,5–3× basal).
  O Fondaparinux 7,5 mg SC c/24h.
• NO usar warfarina hasta plaquetas >150.000.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // RESPIRATORIO — NUEVAS
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'absceso_pulmonar',
    title: 'Absceso Pulmonar — Antibioticoterapia',
    subtitle: 'Clindamicina · amoxicilina-clavulánico · drenaje broncoscópico',
    category: 'Respiratorio',
    icon: Icons.air_rounded,
    content: '''ABSCESO PULMONAR
→ Necrosis focal del parénquima pulmonar con formación de cavidad.
Imagen: cavidad con nivel hidroaéreo en Rx/TC tórax.

CAUSAS:
• Bacterias anaerobias (60–80%): Peptostreptococcus, Fusobacterium,
  Prevotella — asociadas a aspiración.
• Klebsiella pneumoniae (absceso primario — alcoholismo).
• S. aureus (SARM — neumonía aspirativa grave).
• Streptococcus milleri.

TRATAMIENTO ANTIBIÓTICO:

AMBULATORIO (leve, sin comorbilidades):
• Amoxicilina-clavulánico 875/125 mg VO c/12h × 4–6 semanas.
  O Clindamicina 300 mg VO c/8h × 4–6 semanas.

INTERNADO:
• Ampicilina-sulbactam 3 g EV c/6h × 4–6 semanas.
  Alternativa: Clindamicina 600 mg EV c/8h + Ceftriaxona 2 g EV c/24h.

Si sospecha SARM:
  Vancomicina 15–20 mg/kg EV c/12h o Linezolid 600 mg EV c/12h.

Si Klebsiella (alcoholismo, imuno comprometido):
  Ceftriaxona 2 g EV c/24h o Meropenem 1 g EV c/8h.

DURACIÓN: mínimo 4–6 semanas (hasta resolución radiológica).

DRENAJE PERCUTÁNEO:
• Si >6 cm, no responde a ATB en 72h, o inmunocomprometido.
• Toracoscopía/cirugía: si complicación (empiema, fístula).

FISIOTERAPIA RESPIRATORIA:
• Drenaje postural · percusión torácica diaria.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // DERMATOLOGÍA — NUEVAS
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'quemaduras_manejo',
    title: 'Quemaduras — Manejo Inicial',
    subtitle: 'Reposición Parkland · clasificación · analgesia',
    category: 'Urgencias',
    icon: Icons.local_fire_department_rounded,
    content: '''QUEMADURAS — CLASIFICACIÓN Y MANEJO INICIAL

CLASIFICACIÓN POR PROFUNDIDAD:
• 1° grado: solo epidermis — eritema, sin ampolla.
• 2° grado superficial: dermis superficial — ampollas, dolorosa.
• 2° grado profunda: dermis profunda — pálida, menos dolorosa.
• 3° grado: espesor total — indolora, coriácea, requiere injerto.

SUPERFICIE CORPORAL QUEMADA (SCQ):
Regla de los 9: cabeza 9%, brazo 9%, pierna 18%,
tronco ant. 18%, tronco post. 18%, periné 1%.
Palma del paciente = 1% SCQ.

REPOSICIÓN HÍDRICA — FÓRMULA DE PARKLAND:
Volumen 24h = 4 mL × kg × % SCQ (2° y 3° grado).
• 50% en primeras 8h desde el momento de la quemadura.
• 50% restante en las próximas 16h.
• Líquido de elección: Ringer Lactato.
Ej.: 70 kg, SCQ 30% → 8.400 mL en 24h → 525 mL/h en 8h.

ANALGESIA:
• Dipirona 1 g EV c/6–8h + Ketorolac 30 mg EV c/8h.
• Morfina 2–4 mg EV c/4–6h (quemaduras moderadas/graves).
• Ketamina 0,5–1 mg/kg EV (procedimientos de curaciones).

CUIDADOS LOCALES:
• 1° grado: humectar, antiinflamatorio tópico.
• 2° grado: limpieza + sulfadiazina de plata 1% (cubrir ampollas intactas).
• 3° grado: curaciones oclusivas + derivación a centro especializado.

DERIVACIÓN A CENTRO DE QUEMADOS:
• SCQ >20% adultos (>10% niños/ancianos).
• Quemaduras de cara, manos, pies, genitales, articulaciones.
• Quemaduras eléctricas o químicas.
• Lesión de vía aérea (estridor, esputo carbonáceo).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // PEDIATRÍA — NUEVAS
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'fiebre_sin_foco_pediatria',
    title: 'Fiebre sin Foco — Pediátrico',
    subtitle: 'Protocolo por franja etaria · ATB empírico',
    category: 'Pediatría',
    icon: Icons.child_care_rounded,
    content: '''FIEBRE SIN FOCO EN PEDIATRÍA
→ T° >38°C (rectal) sin causa evidente tras examen completo.

ESTRATIFICACIÓN POR EDAD:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
< 28 DÍAS (neonato — ALTO RIESGO siempre):
• Hemocultivo + punción lumbar + urocultivo.
• Internar + ATB empírico inmediato:
  Ampicilina 50 mg/kg EV c/8h
  + Gentamicina 5 mg/kg EV c/24h
  + Aciclovir 20 mg/kg EV c/8h si sospecha VHS neonatal.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
29–90 DÍAS:
• Score PECARN / Rochester para estratificar riesgo.
• Bajo riesgo (bien hidratado, sin foco, vacunas completas):
  Observación ambulatoria + antitérmico + control en 24h.
• Alto riesgo (mal aspecto, PCR >20, leucocitos <5.000 o >15.000):
  Internar + Ceftriaxona 50 mg/kg EV c/24h.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
3–36 MESES:
• Vacunas completas + buen estado general → manejo ambulatorio.
• Antitérmico + control en 48h.
• Si PCR >80 o PCT >2 → buscar foco oculto (Rx tórax, orina).
• Ceftriaxona 50 mg/kg IM (si mal estado general o sin vacunas).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ANTITÉRMICOS:
• Paracetamol 10–15 mg/kg/dosis c/6h VO (máx 4 dosis/día).
• Ibuprofeno 5–10 mg/kg/dosis c/8h VO (>3 meses).
• Dipirona 10–15 mg/kg/dosis c/6h VO/EV.
No alternar sistemáticamente — solo si T° no cede en 1h.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'crisis_convulsiva_pediatrica',
    title: 'Crisis Convulsiva — Pediátrico',
    subtitle: 'Diazepam · midazolam · fenobarbital — dosis pediátricas',
    category: 'Pediatría',
    icon: Icons.child_care_rounded,
    content: '''CRISIS CONVULSIVA PEDIÁTRICA
→ Crisis >5 min o 2 crisis sin recuperación completa = Status Epiléptico.

PROTOCOLO POR TIEMPO:

0–5 MIN — Estabilización:
• ABC · O₂ facial · posición lateral de seguridad.
• Glucemia capilar (excluir hipoglucemia).
• Acceso EV/IO.

5–20 MIN — 1° Línea (benzodiacepinas):
Con acceso EV:
• Diazepam 0,2 mg/kg EV lento (máx 10 mg). Repetir 1 vez a 5 min.
• Midazolam 0,1–0,2 mg/kg EV (máx 10 mg).

Sin acceso EV:
• Midazolam intranasal 0,2–0,3 mg/kg (máx 10 mg) — 0,1 mL/kg IN.
• Midazolam bucal 0,3 mg/kg.
• Diazepam rectal 0,5 mg/kg (máx 20 mg).
• Lorazepam IM 0,1 mg/kg (máx 4 mg).

20–40 MIN — 2° Línea (sin respuesta a benzodiacepinas):
• Fenobarbital 20 mg/kg EV en 20 min (1° elección en neonatos).
• Ácido valproico 20–40 mg/kg EV en 5–10 min.
• Levetiracetam 20–60 mg/kg EV en 15 min (máx 4500 mg).
• Fenitoína 15–20 mg/kg EV en 20 min (máx 1 g).

>40 MIN — 3° Línea (Status Refractario → UCI):
• Midazolam BIC: 0,1–0,4 mg/kg/h → titular.
• Propofol (>3 años): 1–2 mg/kg EV → BIC 2–5 mg/kg/h.
• Tiopental 3–5 mg/kg EV → BIC 3–5 mg/kg/h.

CAUSAS TRATABLES A BUSCAR:
• Hipoglucemia: Dextrose 25% 1 mL/kg EV.
• Hiponatremia: salino hipertónico 3% 3–5 mL/kg EV.
• Fiebre alta: antitérmico + buscar foco infeccioso.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'deshidratacion_pediatrica',
    title: 'Deshidratación — Pediátrico',
    subtitle: 'SRO · hidratación EV por peso · clasificación',
    category: 'Pediatría',
    icon: Icons.child_care_rounded,
    content: '''DESHIDRATACIÓN PEDIÁTRICA

CLASIFICACIÓN Y SIGNOS:
Leve (<5%): sed aumentada, mucosas levemente secas.
Moderada (5–10%): ojos hundidos, llanto sin lágrimas,
  turgencia disminuida, taquicardia leve.
Grave (>10%): fontanela deprimida, oliguria <1 mL/kg/h,
  letargia, relleno capilar >3 seg, shock inminente.

PLAN A — LEVE (ambulatorio):
• SRO (suero de rehidratación oral): 50–100 mL/kg en 4h.
• Dar en pequeños sorbos/cucharaditas c/5 min.
• Continuar alimentación habitual.

PLAN B — MODERADA:
• SRO 100 mL/kg en 3–4h (en guardia, supervisado).
• Si vomita: continuar en pequeñas dosis c/2–3 min.
• Ondansetrón 0,15 mg/kg VO (máx 4 mg) si vómitos incoercibles.
• Si no tolera oral → Plan C.

PLAN C — GRAVE / SHOCK:
Fase de reanimación (primeros 30–60 min):
• SF 0,9%: 20 mL/kg EV en 20 min → evaluar respuesta.
  Repetir hasta 3 bolos (60 mL/kg total) si no mejora.
  Si shock persiste → vasopresores.

Fase de reposición (primeras 24h):
• Déficit estimado (mL) = % deshidratación × peso (kg) × 10.
• Reposición: 50% en primeras 8h + 50% en siguientes 16h.
• Líquido: SF 0,9% o RL + K⁺ 20 mEq/L (si diuresis presente).
• Agregar mantenimiento (fórmula de Holliday-Segar):
  4 mL/kg/h (primeros 10 kg) + 2 mL/kg/h (10–20 kg) + 1 mL/kg/h (>20 kg).

ELECTROLITOS:
• K⁺ solo si diuresis presente (riesgo de hipercalemia en oliguria).
• Glucosa: SG 5% en mantenimiento (evitar hipoglucemia).
• Sodio: vigilar hipo/hipernatremia — ajustar solución.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'bronquiolitis_pediatrica',
    title: 'Bronquiolitis — Pediátrico',
    subtitle: 'Salbutamol nebulizado · criterios de internación',
    category: 'Pediatría',
    icon: Icons.child_care_rounded,
    content: '''BRONQUIOLITIS AGUDA
→ Infección viral vías aéreas inferiores en <2 años.
Principal causa: VSR (virus sincitial respiratorio).
Pico: otoño-invierno. Primer episodio de sibilancias.

DIAGNÓSTICO CLÍNICO:
• Pródromo viral (3–5 días): rinorrea, tos, fiebre leve.
• Sibilancias espiratorias + crepitantes finos.
• Aumento trabajo respiratorio: tiraje, aleteo nasal, taquipnea.

SCORE DE WOOD-DOWNES (severidad):
Leve (1–3): FR normal, SatO₂ >95%, tiro subcostal leve.
Moderado (4–7): FR >50, SatO₂ 90–95%, tiraje marcado.
Grave (8–14): FR >70, SatO₂ <90%, exhausto, apnea.

TRATAMIENTO:
Medidas de soporte (evidencia A — única tratamiento probado):
• O₂ si SatO₂ <92% → cánula nasal o mascarilla.
• Aspiración de secreciones nasales (fundamental).
• Hidratación: SRO oral o SNG si FR >60.
  EV si grave: SF 0,9% a necesidades basales.
• Posición semisentado 30°.

Broncodilatadores (prueba terapéutica, suspender si no hay respuesta):
• Salbutamol nebulizado: 0,15 mg/kg/dosis (mín 2,5 mg)
  en 3 mL SF 0,9% × 20 min. Repetir c/4–6h si mejora objetiva.
• Adrenalina nebulizada 1:1000: 0,1 mL/kg (máx 5 mL) + SF 3 mL.

No recomendados rutinariamente (evidencia en contra):
Antibióticos · corticoides sistémicos · mucolíticos · fisioterapia.

CRITERIOS DE INTERNACIÓN:
• SatO₂ <94% · FR >60 · apneas · <3 meses · prematuro · cardiopatía.
• Incapacidad de alimentación oral.

ALTA con retorno a guardia si empeora.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'sepsis_neonatal',
    title: 'Sepsis Neonatal',
    subtitle: 'Ampicilina + gentamicina · hemocultivo · PL',
    category: 'Pediatría',
    icon: Icons.child_care_rounded,
    content: '''SEPSIS NEONATAL
→ Infección bacteriana sistémica en <28 días de vida.
EMERGENCIA — iniciar ATB dentro de 1h del diagnóstico.

CLASIFICACIÓN:
• Temprana (<72h): gérmenes maternos — SGB, E. coli, Listeria.
• Tardía (>72h): nosocomiales — Estafilococo, Klebsiella, Pseudomonas.

SIGNOS DE ALARMA (inespecíficos):
• Inestabilidad térmica (fiebre >38°C o hipotermia <36°C).
• Taquicardia, bradipnea o apnea.
• Letargia, hipotonía, convulsiones.
• Mala coloración: cianosis, palidez, ictericia precoz.
• Dificultad para alimentarse.
• Distensión abdominal, vómitos biliosos.

EVALUACIÓN DIAGNÓSTICA COMPLETA:
• Hemocultivo × 2 (ANTES de ATB).
• Punción lumbar (LCR): citoquímico + cultivo + ADA.
• Urocultivo por punción suprapúbica.
• Hemograma, PCR, PCT, lactato, función renal.

TRATAMIENTO EMPÍRICO — SEPSIS TEMPRANA:
• Ampicilina 50 mg/kg EV c/8h (c/12h si <7 días).
• Gentamicina 5 mg/kg EV c/24h (monitoreo de niveles).

SEPSIS TARDÍA (nosocomial o sospecha SARM):
• Vancomicina 15 mg/kg EV c/8–12h (según edad gestacional).
  + Cefotaxima 50 mg/kg EV c/6–8h.

Si sospecha VHS neonatal:
• Aciclovir 20 mg/kg EV c/8h (hasta descartar).

SOPORTE:
• Glucosa: SG 10% para mantener glucemia 50–120 mg/dL.
• Acceso EV central si vasopresores.
• Vitamina K si no recibió profilaxis.

DURACIÓN: según cultivos y foco (mín 7–14 días meningitis).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // CARDIOVASCULAR — ADICIONALES
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'cardioversion_electrica',
    title: 'Cardioversión Eléctrica Sincronizada',
    subtitle: 'FA/Flutter/TSV inestables — sedación + choque',
    category: 'Cardiovascular',
    icon: Icons.electric_bolt_rounded,
    content: '''CARDIOVERSIÓN ELÉCTRICA SINCRONIZADA (CVE)
→ SIEMPRE sincronizar (botón SYNC activo) — evita FV.

INDICACIONES URGENTES (hemodinámicamente inestable):
• FA/Flutter con FC >150 + hipotensión, EAP, angina, síncope.
• TSV inestable refractaria a adenosina.
• TV con pulso + inestabilidad.

PREPARACIÓN:
1. Acceso EV + monitoreo ECG + desfibrilador listo.
2. Ayuno: si urgencia, no esperar.
3. Sedoanalgesia (si tiempo permite):
   Midazolam 2–5 mg EV lento + Fentanil 1–2 mcg/kg EV.
   O: Propofol 1–1,5 mg/kg EV titulado.
   O: Ketamina 1–2 mg/kg EV (conserva FR — segura en urgencia).
4. O₂ disponible + equipo de IOT listo.
5. Asistencia médica lista para reanimación.

ENERGÍAS RECOMENDADAS (bifásico):
• FA: 120–200 J → aumentar si no revierte.
• Flutter: 50–100 J.
• TSV: 50–100 J.
• TV con pulso: 100 J → aumentar si no revierte.

ANTICOAGULACIÓN PRE-CVE:
• FA >48h o desconocida → anticoagular mínimo 3 semanas previas
  O ecocardiograma transesofágico sin trombo → CVE.
• FA <48h en inestable → CVE inmediata + HBPM simultánea.
• Mantener anticoagulación 4 semanas post-CVE (riesgo de embolía).

POST-CVE MONITOREO:
• ECG 12D inmediato tras conversión.
• Monitoreo mínimo 1h.
• Riesgo de pausas post-conversión (marcapasos disponible).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'endocarditis_profilaxis',
    title: 'Profilaxis de Endocarditis',
    subtitle: 'Amoxicilina · procedimientos dentales · válvulas',
    category: 'Cardiovascular',
    icon: Icons.favorite_border_rounded,
    content: '''PROFILAXIS DE ENDOCARDITIS INFECCIOSA
→ Solo en pacientes de ALTO RIESGO + procedimientos de riesgo.

PACIENTES DE ALTO RIESGO (indicación de profilaxis):
• Válvula protésica (mecánica o biológica).
• EI previa (mayor riesgo de recurrencia).
• Cardiopatía congénita cianótica no corregida.
• Trasplante cardíaco con valvulopatía.

PROCEDIMIENTOS QUE REQUIEREN PROFILAXIS:
• Dentales: manipulación de tejido gingival, región periapical o mucosa oral.
• NO indicada en: inyecciones anestésicas, rx dental, ortodoncia, extracción de dientes de leche.

RÉGIMEN ESTÁNDAR (VO — 1h antes del procedimiento):
• Amoxicilina 2 g VO dosis única (adulto).
  Niños: 50 mg/kg VO.

ALERGIA A PENICILINA:
• Clindamicina 600 mg VO dosis única.
  Niños: 20 mg/kg VO.
• Azitromicina 500 mg VO dosis única.
• Claritromicina 500 mg VO dosis única.

VÍA PARENTERAL (si no puede tomar oral):
• Ampicilina 2 g EV/IM 30–60 min antes.
• Alergia: Clindamicina 600 mg EV 30 min antes.

PROCEDIMIENTOS GASTROINTESTINALES / GENITOURINARIOS:
• NO hay evidencia que justifique profilaxis rutinaria.
• Solo considerar en pacientes de muy alto riesgo con infección activa.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'hipertension_pulmonar',
    title: 'Hipertensión Pulmonar — Crisis',
    subtitle: 'O₂ · sildenafil · óxido nítrico · prostanoides',
    category: 'Cardiovascular',
    icon: Icons.air_rounded,
    content: '''CRISIS DE HIPERTENSIÓN PULMONAR
→ PAPm >25 mmHg + deterioro agudo hemodinámico.

MEDIDAS GENERALES:
• O₂: mantener SpO₂ >92% (reduce vasoconstricción pulmonar hipóxica).
• Evitar hipercapnia, acidosis, dolor, agitación.
• Posición semisentado. Evitar Valsalva.
• Monitoreo invasivo: línea arterial + catéter AP si disponible.

VASODILATADORES PULMONARES:
Sildenafil (inhibidor PDE-5):
• 20–25 mg VO c/8h (o por SNG).
• IV: no disponible en muchos centros.

Óxido Nítrico Inhalado (iNO):
• 20–80 ppm inhalado — vasodilatador selectivo pulmonar.
• Indicado en UCI / post-operatorio.
• Retirada gradual (riesgo de rebote).

Iloprost inhalado (prostaciclina análoga):
• 2,5–5 mcg inhalado c/2–4h.

Epoprostenol EV (prostanoidea):
• BIC: 2 ng/kg/min → titular cada 15 min hasta 10–20 ng/kg/min.

INOTRÓPICOS (si bajo débito cardíaco derecho):
• Dobutamina 2–10 mcg/kg/min BIC.
• Milrinona 0,375–0,75 mcg/kg/min BIC.
• Noradrenalina (si hipotensión sistémica) 0,05–0,5 mcg/kg/min.

EVITAR:
• Fluidos en exceso (agrava VD).
• Nitratos (hipotensión sistémica sin vasodilatación selectiva).
• Betabloqueantes (pueden precipitar insuficiencia VD).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // NEUROLOGÍA — ADICIONALES
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'guillain_barre',
    title: 'Síndrome de Guillain-Barré',
    subtitle: 'IVIG · plasmaféresis · soporte respiratorio',
    category: 'Neurología',
    icon: Icons.psychology_rounded,
    content: '''SÍNDROME DE GUILLAIN-BARRÉ (SGB)
→ Polineuropatía inflamatoria desmielinizante aguda. Urgencia neurológica.

PRESENTACIÓN:
• Paresia ascendente simétrica (comienza en EEII).
• Arreflexia · dolor radicular · disfunción autonómica.
• 30% requiere ventilación mecánica.
• LCR: disociación albumino-citológica (proteínas ↑, células normales).

CRITERIOS DE INTERNACIÓN URGENTE:
• CVF <20 mL/kg o PIM <30 cmH₂O → IOT inminente.
• Disfagia · disfunción autonómica grave · progresión rápida.

MONITOREO RESPIRATORIO (regla 20-30-40):
IOT electiva si: CVF <20 mL/kg ó PIM <30 ó PEM <40 cmH₂O.

TRATAMIENTO ESPECÍFICO (iniciar precoz):
1. IVIG (Inmunoglobulina EV) — 1° elección:
   2 g/kg EV total dividido en 5 días (0,4 g/kg/día).
   O 1 g/kg/día × 2 días.
   
2. PLASMAFÉRESIS — alternativa equivalente:
   5 sesiones en 10 días (250 mL/kg total).
   Indicada si: no disponibilidad de IVIG, falla a IVIG.
   
NO COMBINAR ambas (no suma beneficio).
CORTICOIDES: NO indicados (no eficaces en SGB).

SOPORTE:
• HBPM profiláctica: Enoxaparina 40 mg SC c/24h.
• Analgesia: Gabapentina 300 mg c/8h o Pregabalina 75 mg c/12h.
• Laxantes, SNG si disfagia, fisioterapia precoz.
• Disfunción autonómica: monitoreo continuo ECG, evitar hipotensión brusca.

PRONÓSTICO: 85% recuperación funcional en 12 meses.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'miastenia_crisis',
    title: 'Crisis Miasténica',
    subtitle: 'IVIG · plasmaféresis · piridostigmina · IOT',
    category: 'Neurología',
    icon: Icons.psychology_rounded,
    content: '''CRISIS MIASTÉNICA
→ Debilidad respiratoria aguda por miastenia gravis. Emergencia.

DIAGNÓSTICO DIFERENCIAL — CRISIS COLINÉRGICA:
• Crisis miasténica (falta de ACh): debilidad muscular pura, pupilas normales.
• Crisis colinérgica (exceso neostigmina): bradicardia, hipersecreción,
  miosis, fasciculaciones — SUSPENDER anticolinesterásicos.

EVALUACIÓN RESPIRATORIA URGENTE:
• CVF y PIM cada 4h.
• IOT electiva si CVF <15–20 mL/kg o PIM <20 cmH₂O.

TRATAMIENTO:
1. SUSPENDER piridostigmina/neostigmina (durante crisis — empeora secreciones).

2. PLASMAFÉRESIS (respuesta en 24–48h):
   5–7 sesiones (250 mL/kg total en 10–14 días).
   1° elección si deterioro rápido, pre-cirugía urgente.

3. IVIG (alternativa — respuesta en 3–7 días):
   2 g/kg EV en 2–5 días (0,4 g/kg/día).

4. CORTICOIDES (tratamiento de base — inicio gradual):
   Prednisona 60–80 mg/día VO.
   INICIAR LENTAMENTE (puede empeorar en primeras 2 semanas).

5. INMUNOMODULADORES (mantenimiento):
   Azatioprina 2–3 mg/kg/día VO (inicio lento, efecto en meses).
   Micofenolato 1 g c/12h (alternativa).

PRECIPITANTES A ELIMINAR:
• Infecciones (ATB si corresponde) · cirugía · embarazo.
• Fármacos agravantes: aminoglucósidos, quinolonas, betabloqueantes,
  estatinas, litio, contraste yodado, D-penicilamina.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'hipertension_intracraneal',
    title: 'Hipertensión Intracraneal',
    subtitle: 'Manitol · solución hipertónica · hiperventilación',
    category: 'Neurología',
    icon: Icons.bolt_rounded,
    content: '''HIPERTENSIÓN INTRACRANEAL (HIC)
PIC normal: 5–15 mmHg. HIC: PIC >20 mmHg sostenida.

MEDIDAS GENERALES (todas los pacientes):
• Cabecera 30° (sin flexión de cuello).
• Normocapnia: PaCO₂ 35–40 mmHg.
• Normoxemia: SpO₂ >94% (PaO₂ 80–100 mmHg).
• Normoglucemia: 140–180 mg/dL.
• Temperatura <37,5°C (antipiréticos agresivos).
• Evitar hipotensión: PAM objetivo ≥70 mmHg.
• Normosodemia o leve hipernatremia (Na 140–150).

TRATAMIENTO OSMÓTICO:
Manitol 20% (1° elección clásica):
• 0,5–1 g/kg EV en 15–20 min.
• Repetir c/4–6h según PIC y osmolaridad.
• SUSPENDER si osmolaridad sérica >320 mOsm/kg.
• Monitorear: electrolitos, función renal, volemia.

Solución Salina Hipertónica 3% (alternativa + isovolemia):
• 150–250 mL EV en 20–30 min.
• Infusión continua: 1–2 mL/kg/h.
• Objetivo Na sérico: 145–155 mEq/L.
• EVITAR si hipernatremia previa.

HIPERVENTILACIÓN TERAPÉUTICA (puente — no >24h):
• Objetivo PaCO₂: 30–35 mmHg (reduce PIC en minutos).
• Solo como medida transitoria (herniation inminente).

BARBITÚRICOS (último recurso — UCI):
• Tiopental 3–5 mg/kg EV → BIC 3–5 mg/kg/h.
• Monitoreo EEG (objetivo: burst-suppression).

DERIVACIÓN VENTRICULAR EXTERNA (DVE):
• Indicada si hidrocefalia obstructiva + HIC refractaria.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // RESPIRATORIO — ADICIONALES
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'neumotorax_tratamiento',
    title: 'Neumotórax — Tratamiento',
    subtitle: 'Drenaje · toracocentesis · neumotórax a tensión',
    category: 'Respiratorio',
    icon: Icons.air_rounded,
    content: '''NEUMOTÓRAX — CLASIFICACIÓN Y TRATAMIENTO

NEUMOTÓRAX A TENSIÓN — EMERGENCIA INMEDIATA:
• Diagnóstico CLÍNICO (no esperar Rx):
  Disnea severa + hipotensión + MV abolido unilateral +
  desviación traqueal contralateral + ingurgitación yugular.
• DESCOMPRESIÓN INMEDIATA:
  Aguja 14G en 2° espacio intercostal, línea medioclavicular
  → liberar aire bajo presión.
  Luego: drenaje pleural definitivo.

NEUMOTÓRAX ESPONTÁNEO PRIMARIO:
Pequeño (<2 cm apical en Rx PA):
• Alta + O₂ suplementario + control en 48h.
• Reposo relativo, evitar esfuerzo, vuelos.

Grande (≥2 cm) o sintomático:
• Aspiración simple con aguja 16G (1° intento): 50–60% éxito.
• Si falla → tubo de drenaje.

NEUMOTÓRAX ESPONTÁNEO SECUNDARIO (enfermedad previa):
• Siempre drenaje pleural independiente del tamaño.
• Drenaje: tubo 20–24 Fr + agua sellada.

NEUMOTÓRAX TRAUMÁTICO:
• Hemotórax asociado → tubo 28–32 Fr.
• Indicación de cirugía: >1 L inicial o >200 mL/h en 4h.

TÉCNICA DE DRENAJE PLEURAL:
• Posición: decúbito supino con brazo elevado.
• Sitio: 4°–5° EIC, línea axilar media (triángulo de seguridad).
• Anestesia local: lidocaína 2% hasta pleura.
• Conectar a sello de agua o Heimlich.
• Rx control post-colocación.

PLEURODESIS (si recurrente):
• Talco estéril 4 g intrapleural.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'derrame_pleural',
    title: 'Derrame Pleural — Diagnóstico y Drenaje',
    subtitle: 'Toracocentesis diagnóstica · criterios de Light',
    category: 'Respiratorio',
    icon: Icons.water_drop_rounded,
    content: '''DERRAME PLEURAL — EVALUACIÓN Y MANEJO

INDICACIONES DE TORACOCENTESIS DIAGNÓSTICA:
• Derrame unilateral o bilateral asimétrico sin causa clara.
• Fiebre + derrame (descartar empiema).
• Sospecha de neoplasia o hemotórax.

CRITERIOS DE LIGHT (exudado vs transudado):
Exudado si ≥1 criterio:
• Proteínas pleura/suero >0,5.
• LDH pleura/suero >0,6.
• LDH pleural >2/3 límite superior normal sérico.
Transudado: ningún criterio.

ANÁLISIS DEL LÍQUIDO PLEURAL:
• Físico: color, turbidez, olor.
• Bioquímica: proteínas, LDH, glucosa, pH, ADA.
• Citología: recuento diferencial.
• Microbiología: gram, cultivo, BK.
• ADA >40 UI/L → tuberculosis (alta especificidad).
• pH <7,2 → empiema (drenaje urgente).
• Glucosa <60 mg/dL → empiema o neoplasia.

TÉCNICA DE TORACOCENTESIS:
• Posición: sentado, brazos en mesa.
• Sitio: 1–2 EIC por debajo del límite superior del derrame,
  borde superior de la costilla inferior (evitar paquete neurovascular).
• Anestesia local: lidocaína 2%.
• Aguja 21G o catéter de toracocentesis.
• Extraer máximo 1–1,5 L por sesión (edema pulmonar por re-expansión).

DRENAJE PLEURAL (tubular):
Indicaciones: empiema, hemotórax, quilotórax, neumotórax.
• Tubo 16–28 Fr según viscosidad del líquido.
• Sello de agua o aspiración controlada.

EMPIEMA — TRATAMIENTO:
• ATB EV: Pip/Tazo 4,5 g c/6h + Metronidazol 500 mg c/8h.
• Drenaje precoz obligatorio (pH <7,2 o pus).
• Fibrinolíticos intrapleurales si loculado: Alteplase + DNasa.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'ventilacion_mecanica_basica',
    title: 'Ventilación Mecánica — Parámetros Iniciales',
    subtitle: 'Vt protector · PEEP · FiO₂ · destete',
    category: 'Respiratorio',
    icon: Icons.air_rounded,
    content: '''VENTILACIÓN MECÁNICA INVASIVA — PARÁMETROS INICIALES

MODO: Volumen Control (VC-AC) — 1° elección inicial.

PARÁMETROS SEGÚN CAUSA:

INSUFICIENCIA RESPIRATORIA AGUDA (no SDRA):
• Vt: 6–8 mL/kg peso ideal (PI).
• FR: 14–18/min.
• FiO₂: iniciar 100% → reducir para SpO₂ 94–98%.
• PEEP: 5–8 cmH₂O.
• Flujo inspiratorio: 60 L/min.
• Ti/Te: 1:2.

SDRA (Berlin — PaO₂/FiO₂ <300):
• Vt: 4–6 mL/kg PI (ventilación protectora — ARDSnet).
• FR: 20–35/min (compensar hipercapnia permisiva).
• PEEP: 8–15 cmH₂O (según tabla FiO₂/PEEP).
• Pplateau objetivo: <30 cmH₂O.
• Driving pressure: <15 cmH₂O.
• Decúbito prono 16h/día si PaO₂/FiO₂ <150.

PESO IDEAL (PI):
Hombre: 50 + 0,91 × (talla cm − 152,4).
Mujer: 45,5 + 0,91 × (talla cm − 152,4).

ALARMAS INICIALES:
• Ppico máx: +10 sobre basal.
• Vt mínimo: −20% del programado.
• FR máx: 35/min.
• FiO₂ máx: 1,0.

SEDOANALGESIA:
• Propofol 0,5–3 mg/kg/h BIC (despertar diario).
• Midazolam 0,02–0,1 mg/kg/h (alternativa).
• Fentanil 25–100 mcg/h BIC.
• Objetivo RASS: −1 a −2.

DESTETE (criterios de extubación):
• FR espontánea <30 · SpO₂ >94% con FiO₂ <0,4 · PEEP ≤5.
• Prueba de ventilación espontánea (PVE): TBO o PSV 5/5 × 30–120 min.
• Glasgow ≥8 · tos eficaz · secreciones manejables.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // GASTROENTEROLOGÍA — ADICIONALES
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'hepatitis_fulminante',
    title: 'Hepatitis Fulminante / Insuf. Hepática Aguda',
    subtitle: 'NAC · encefalopatía · trasplante hepático',
    category: 'Gastroenterología',
    icon: Icons.warning_amber_rounded,
    content: '''INSUFICIENCIA HEPÁTICA AGUDA (IHA)
→ Encefalopatía hepática + INR >1,5 en paciente sin hepatopatía previa.

CAUSAS:
• Paracetamol (sobredosis) — más frecuente en Occidente.
• Hepatitis viral A, B, E.
• Medicamentos: isoniazida, halotano, valproato.
• Autoinmune · Wilson · Budd-Chiari · isquemia ("shock liver").

MANEJO UCI:
1. Monitoreo: Glasgow horario, lactato, glucemia, INR c/6–12h.
2. Glucemia: SG 10–50% para mantener 80–120 mg/dL.
3. Encefalopatía: lactulose 15–30 mL c/6–8h (objetivo 2–3 deposiciones/día).
4. HIC (si encefalopatía III/IV): manitol 20% 0,5–1 g/kg EV.
   Cabecera 30° · sedación mínima · evitar estímulos.
5. Coagulopatía: NO corregir INR de rutina.
   PFC solo si sangrado activo o procedimiento invasivo.
6. Infección: ATB empírico si deterioro clínico (norfloxacina 400 mg c/12h profiláctico).
7. Insuf. renal asociada (síndrome hepatorrenal): terlipresina 0,5–2 mg EV c/4–6h.

N-ACETILCISTEÍNA (NAC) — SIEMPRE INDICADA:
• Sobredosis paracetamol: ver prescripción específica.
• CUALQUIER etiología (mejora supervivencia sin trasplante):
  150 mg/kg EV en 1h → 12,5 mg/kg/h × 4h → 6,25 mg/kg/h × 67h.

CRITERIOS DE TRASPLANTE HEPÁTICO (King's College):
Paracetamol:
• pH <7,3 tras reanimación. O:
• PT >100 seg + creatinina >3,4 mg/dL + encefalopatía III/IV.
Otras causas:
• INR >6,5. O: 3 de 5 criterios (edad <10 o >40, etiología, bilirrubina, INR, tiempo).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'colitis_ulcerosa_crohn_crisis',
    title: 'Colitis Ulcerosa / Crohn — Crisis',
    subtitle: 'Corticoides EV · mesalazina · biológicos',
    category: 'Gastroenterología',
    icon: Icons.medical_services_rounded,
    content: '''ENFERMEDAD INFLAMATORIA INTESTINAL (EII) — CRISIS AGUDA

COLITIS ULCEROSA — CRISIS GRAVE (criterios de Truelove-Witts):
≥6 deposiciones/día con sangre + al menos 1 de:
FC >90, T° >37,8°C, Hb <10,5, VSG >30.

TRATAMIENTO CRISIS GRAVE (internación):
1. Corticoides EV (1° línea):
   Hidrocortisona 100 mg EV c/6h (o 300 mg/día BIC).
   O Metilprednisolona 60 mg/día EV.
   Evaluar respuesta en 3–5 días (Oxford Score).

2. Sin respuesta a 3–5 días → 2° línea:
   Ciclosporina 2 mg/kg/día BIC EV (nivel objetivo 250–350 ng/mL).
   O Infliximab 5 mg/kg EV dosis única (en semanas 0, 2, 6).
   O Tacrolimus 0,01 mg/kg/día EV.

3. Enema de mesalazina 4 g/noche (colitis izquierda).

4. Megacolon tóxico (dilatación >6 cm):
   Descomprimir con SNG + Cirugía de urgencia (colectomía).

CROHN EN CRISIS:
Leve-moderada:
• Mesalazina 4 g/día VO (colónica).
• Budesonida 9 mg/día VO × 8 semanas (ileocólica).

Moderada-grave:
• Prednisona 40–60 mg/día VO × 4 semanas → reducción gradual.
• O Metilprednisolona 60 mg/día EV si intolerancia oral.

Biologicos (moderada-grave refractaria):
• Adalimumab 160 mg SC semana 0 → 80 mg semana 2 → 40 mg c/2 semanas.
• Infliximab 5 mg/kg EV semanas 0, 2, 6 → c/8 semanas.
• Vedolizumab 300 mg EV semanas 0, 2, 6 → c/8 semanas.

NUTRICIÓN: soporte enteral precoz. Nutrición parenteral si fístula/obstrucción.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'estreñimiento_fecaloma',
    title: 'Estreñimiento / Fecaloma',
    subtitle: 'Laxantes · enema · extracción manual',
    category: 'Gastroenterología',
    icon: Icons.medical_services_rounded,
    content: '''ESTREÑIMIENTO AGUDO / FECALOMA EN GUARDIA

EVALUACIÓN:
• Tiempo sin deposición · características del dolor · abdomen.
• Descartar: oclusión intestinal (Rx abdomen), fisura anal, vólvulo.
• FR: dieta, deshidratación, opioides, anticolinérgicos, AINEs.

ESTREÑIMIENTO FUNCIONAL:
1° línea — Osmóticos (iniciar):
• Lactulosa 15–30 mL VO c/8h (efecto en 24–48h).
• Macrogol 4000: 1–2 sobres VO c/24h (disuelto en 200 mL agua).
• Leche de Magnesia 30–45 mL VO c/24h.

Estimulantes (acción más rápida — 6–12h):
• Bisacodilo 10 mg VO al acostarse.
• Senósidos 12–24 mg VO al acostarse.

Enema (si estreñimiento 3–5 días sin respuesta a VO):
• Enema de fosfato 133 mL rectal (Fleet).
• Enema de glicerina 120 mL rectal.

FECALOMA ESTABLECIDO:
1. Enema de aceite mineral tibia 500 mL → retener 15–30 min.
2. Si no resuelve: extracción manual digital (con guante + lubricante).
   Sedoanalgesia previa: Midazolam 2–3 mg EV + Dipirona 1 g EV.
3. Post-extracción: Enema de limpieza (SF tibia 500–1000 mL).
4. Mantenimiento: Macrogol + dieta + hidratación.

ESTREÑIMIENTO POR OPIOIDES:
• Metilnaltrexona 8–12 mg SC c/48h (antagonista opioide periférico).
• Naloxegol 25 mg VO c/24h (alternativa).
• Lactulosa diaria preventiva si opioide crónico.

ALARMA — DERIVAR CIRUGÍA:
• Signos de oclusión: dolor severo, vómitos biliosos, Rx niveles hidroaéreos.
• Vólvulo: sigmoidoscopía descompresiva urgente.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // INFECTOLOGÍA — ADICIONALES
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'influenza_oseltamivir',
    title: 'Influenza — Oseltamivir',
    subtitle: 'Inicio precoz <48h · grupos de riesgo · profilaxis',
    category: 'Infectología',
    icon: Icons.coronavirus_rounded,
    content: '''INFLUENZA — TRATAMIENTO ANTIVIRAL

INDICACIONES DE OSELTAMIVIR:
• Siempre: hospitalizados, graves, inmunocomprometidos.
• Inicio dentro de 48h de síntomas (mejor eficacia).
• Grupos de riesgo: >65 años, embarazadas, obesos (IMC >40),
  EPOC, cardiopatía, diabetes, neoplasias.
• Después de 48h: igual tratar si grave o alto riesgo.

OSELTAMIVIR (Tamiflu):
• Tratamiento adulto: 75 mg VO c/12h × 5 días.
• Grave/hospitalizado: 150 mg VO c/12h × 10 días.
• Profilaxis post-exposición: 75 mg VO c/24h × 10 días.
• Profilaxis estacional: 75 mg VO c/24h × 6–12 semanas.

AJUSTE RENAL:
ClCr 10–30 mL/min: 30 mg c/12h (tratamiento) / 30 mg c/24h (profilaxis).
Diálisis: 30 mg post-diálisis.

ZANAMIVIR (alternativa inhalada — resistencia a oseltamivir):
• 10 mg inhalado c/12h × 5 días (2 inhalaciones de 5 mg).
• Contraindicado en EPOC/asma (broncoespasmo).

PERAMIVIR EV (si no tolera oral):
• 600 mg EV en 15–30 min, dosis única.
• Ajustar en insuf. renal.

TRATAMIENTO SINTOMÁTICO:
• Paracetamol 500–1000 mg c/6h (preferir vs. AAS — síndrome Reye).
• Ibuprofeno 400–600 mg c/8h (adultos sin contraindicación).
• Hidratación oral adecuada.

VACUNACIÓN (prevención):
• Vacuna influenza anual — especialmente grupos de riesgo.
• Eficacia 40–60% (según match cepa).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'celulitis_necrotizante_piel',
    title: 'Infección Piel / Partes Blandas — Clasificación',
    subtitle: 'Eritema · pústulas · fascitis · absceso profundo',
    category: 'Infectología',
    icon: Icons.medical_information_rounded,
    content: '''INFECCIONES DE PIEL Y PARTES BLANDAS — CLASIFICACIÓN IDSA

CLASE 1 (Sin sistémicos — ambulatorio):
• Impétigo · forúnculo · foliculitis · celulitis leve.
• Clindamicina 300 mg VO c/8h × 5–7 días.
• Cefalexina 500 mg VO c/6h × 5–7 días.

CLASE 2 (Sistémicos leves — observación +/− internación):
• Celulitis moderada + taquicardia/fiebre/leucocitosis.
• Cefazolina 2 g EV c/8h (SASM).
• SAMR: TMP-SMX 2 comp VO c/12h o Doxiciclina 100 mg c/12h.

CLASE 3 (Sistémicos graves — internación):
• Celulitis extensa, linfangitis, bula hemorrágica.
• Ampicilina-sulbactam 3 g EV c/6h.
• O Pip/Tazo 4,5 g EV c/6h + Vancomicina 15–20 mg/kg c/12h.

CLASE 4 (Sepsis + disfunción orgánica — UCI + cirugía):
• Fasciitis necrotizante, miositis, gangrena.
• Ver prescripción de fasciitis necrotizante.

ABSCESO CUTÁNEO:
• Drenaje quirúrgico (tratamiento principal).
• ATB post-drenaje solo si: celulitis >2 cm, fiebre, múltiples lesiones.
• SASM: Cefadroxilo 500 mg c/12h × 5–7 días.
• SAMR: TMP-SMX 160/800 mg c/12h × 5–7 días.

MORDEDURA HUMANA / ANIMAL:
• Amoxicilina-clavulánico 875/125 mg c/8h × 5 días.
• Profilaxis antitetánica según esquema.
• Humana → profilaxis VIH si riesgo.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'toxoplasmosis_criptococosis',
    title: 'Toxoplasmosis / Criptococosis — VIH',
    subtitle: 'Pirimetamina · fluconazol · paciente inmunocomprometido',
    category: 'Infectología',
    icon: Icons.coronavirus_rounded,
    content: '''INFECCIONES OPORTUNISTAS EN VIH/SIDA

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TOXOPLASMOSIS CEREBRAL (CD4 <100):
Diagnóstico: Lesiones anulares realzadas con gadolinio en RMN
+ serología IgG Toxoplasma + respuesta a tratamiento.

Tratamiento (6 semanas):
• Pirimetamina 200 mg VO día 1 → 50 mg/día (>60 kg: 75 mg/día).
  + Sulfadiazina 1 g VO c/6h (>60 kg: 1,5 g c/6h).
  + Ácido folínico 10–25 mg/día VO (previene toxicidad hematológica).
Alergia a sulfas:
• Pirimetamina + Clindamicina 600 mg EV/VO c/6h.
• O Trimetrexato + Ácido folínico.

Mantenimiento (profilaxis secundaria):
• Pirimetamina 25 mg/día + Sulfadiazina 500 mg c/6h + Ácido folínico.
• Suspender si CD4 >200 × 6 meses con TARV.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CRIPTOCOCOSIS MENÍNGEA (CD4 <100):
Inducción (2 semanas):
• Anfotericina B desoxicolato 0,7–1 mg/kg/día EV
  + Flucitosina 25 mg/kg VO c/6h.
  O Anfotericina liposomal 3–4 mg/kg/día EV + Flucitosina.

Consolidación (8 semanas):
• Fluconazol 400 mg/día VO.

Mantenimiento:
• Fluconazol 200 mg/día VO → suspender si CD4 >100 × 6 meses.

PL de descarga de PIC alta: si PIC >25 cmH₂O → PL diaria 20–30 mL.
EVITAR: corticoides (aumentan mortalidad en criptococosis).

PNEUMOCYSTIS JIROVECII (PCP) CD4 <200:
• TMP-SMX (sulfametoxazol-trimetoprima) EV/VO: 15–20 mg/kg/día de TMP
  dividido c/6–8h × 21 días.
• Prednisona 40 mg VO c/12h × 5d → 40 mg c/24h × 5d → 20 mg c/24h × 11d
  (si PaO₂ <70 mmHg o gradiente A-a >35).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // DERMATOLOGÍA — ADICIONALES
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'psoriasis_tratamiento',
    title: 'Psoriasis — Tratamiento',
    subtitle: 'Tópicos · metotrexato · biológicos · criterios',
    category: 'Dermatología',
    icon: Icons.medical_information_rounded,
    content: '''PSORIASIS — TRATAMIENTO ESCALONADO

EVALUACIÓN DE SEVERIDAD (PASI):
• Leve: PASI <10 · BSA <10% · DLQI <10.
• Moderada-grave: PASI ≥10 O BSA ≥10 O DLQI ≥10.

TRATAMIENTO TÓPICO (leve):
• Corticoides tópicos: Clobetasol 0,05% crema 2×/día (potente).
  Betametasona 0,1% + Calcipotriol 50 mcg/g (combinado — 1° elección).
  Hidrocortisona 1% (cara/pliegues — potencia baja).
• Análogos vitamina D: Calcipotriol 0,005% crema/espuma 2×/día.
• Antralina (ditranol): 0,1–2% crema × 20–30 min/día.
• Emolientes: vaselina, urea 10%.

FOTOTERAPIA (moderada):
• UVB de banda estrecha (NB-UVB): 3×/semana → 20–30 sesiones.
• PUVA: psoraleno oral + UVA 2×/semana.

TRATAMIENTO SISTÉMICO (moderada-grave):
• Metotrexato 10–25 mg/semana VO/SC + ácido folínico 5 mg × 1/semana.
  Monitoreo: hemograma, LFT c/3 meses. Contraindicado en embarazo.
• Ciclosporina 2,5–5 mg/kg/día VO (máx 1 año continuo).
  Monitoreo: PA + función renal c/2 semanas.
• Acitretina 25–50 mg/día VO (útil en eritrodérmica/pustulosa).

BIOLÓGICOS (grave refractaria o artritis psoriásica):
• Adalimumab 80 mg SC semana 0 → 40 mg c/2 semanas.
• Secukinumab 300 mg SC semanas 0–4 → c/4 semanas.
• Ixekizumab 160 mg SC semana 0 → 80 mg c/4 semanas.
• Risankizumab 150 mg SC semanas 0, 4 → c/12 semanas.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'reaccion_adversa_medicamento',
    title: 'Reacción Adversa Grave a Fármacos',
    subtitle: 'Stevens-Johnson · DRESS · NET — corticoides · soporte',
    category: 'Dermatología',
    icon: Icons.warning_amber_rounded,
    content: '''REACCIONES ADVERSAS GRAVES A FÁRMACOS

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SÍNDROME DE STEVENS-JOHNSON (SJS) / NET:
SJS: <10% SCQ · NET: >30% SCQ · Solapamiento: 10–30%.
Mortalidad NET: 30–50%.

FÁRMACOS CAUSANTES:
Alopurinol · carbamazepina · lamotrigina · sulfas · penicilinas ·
fluoroquinolonas · AINEs · nevirapina · inhibidores de checkpoint.

TRATAMIENTO:
1. SUSPENDER fármaco culpable INMEDIATAMENTE.
2. UCI/quemados (NET) → manejo similar a gran quemado.
3. Hidratación EV: SF 0,9% + coloides según BSA afectada.
4. Analgesia: Morfina + Ketamina en curaciones.
5. Cuidados locales: curativos no adherentes estériles diarios.
6. Soporte ocular: colirios ciclopléjicos + antibióticos oculares.
7. IVIG 1 g/kg/día × 3 días (evidencia moderada).
8. Ciclosporina 3–5 mg/kg/día EV (detiene progresión).
9. EVITAR: corticoides sistémicos (aumentan sepsis).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DRESS (Drug Reaction Eosinophilia Systemic Symptoms):
Latencia 2–8 semanas · fiebre + rash + eosinofilia + órgano afectado.

Fármacos: carbamazepina · fenitoína · alopurinol · sulfas · minociclina.

TRATAMIENTO:
1. Suspender fármaco culpable.
2. Prednisona 1–2 mg/kg/día VO × 4–6 semanas → reducción gradual lenta.
3. Monitoreo: hemograma, LFT, creatinina, TSH c/2 semanas.
4. Reactivación VHH-6 frecuente → antivirales si necesario.

EVITAR reintroducir o usar fármacos de la misma clase.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // OSTEOMUSCULAR — ADICIONALES
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'artritis_septica',
    title: 'Artritis Séptica',
    subtitle: 'Punción articular · ATB EV · drenaje quirúrgico',
    category: 'Osteomuscular',
    icon: Icons.medical_services_rounded,
    content: '''ARTRITIS SÉPTICA — EMERGENCIA ORTOPÉDICA
→ Destrucción articular en 24–48h sin tratamiento.

DIAGNÓSTICO — PUNCIÓN ARTICULAR:
• Leucocitos >50.000/mm³ (PMN >90%) → diagnóstico.
  2.000–50.000 → sospechoso.
• Gram + cultivo (positivo en 50–70%).
• Glucosa <50% sérica · proteínas elevadas.

CRITERIOS DE KOCHER (rodilla — diagnóstico diferencial artritis séptica vs artritis reactiva):
• Fiebre >38,5°C · incapacidad de apoyo · VES >40 · leucocitos >12.000.
  4 criterios: probabilidad 99% de séptica.

GÉRMENES MÁS FRECUENTES:
• S. aureus (cualquier edad — más frecuente).
• Streptococcus grupo A (adultos).
• N. gonorrhoeae (adultos jóvenes sexualmente activos).
• Gram negativos (neonatos, ancianos, inmunocomprometidos).

TRATAMIENTO ATB EMPÍRICO EV:
SAMR no sospechado (SASM):
• Cefazolina 2 g EV c/8h (adulto).

Sospecha SAMR (uso reciente ATB, factores de riesgo):
• Vancomicina 15–20 mg/kg EV c/12h.

N. gonorrhoeae:
• Ceftriaxona 1 g EV c/24h × 7 días.

DURACIÓN TOTAL: 4–6 semanas (2–4 EV → completar VO si mejoría).

DRENAJE ARTICULAR (obligatorio):
• Artrocentesis diaria (si responde) o artroscopía de lavado.
• Artrotomía abierta si: cadera, hombro, no responde en 72h.

INMOVILIZACIÓN:
• Tracción + elevación del miembro en posición funcional.
• Iniciar movilización pasiva precoz (previene rigidez).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'osteoporosis_fractura',
    title: 'Osteoporosis / Fractura Osteoporótica',
    subtitle: 'Bifosfonatos · calcio · vitamina D · analgesia',
    category: 'Osteomuscular',
    icon: Icons.medical_services_rounded,
    content: '''OSTEOPOROSIS Y FRACTURA OSTEOPORÓTICA

DIAGNÓSTICO (OMS): T-score ≤ −2,5 en DMO.
Fractura osteoporótica: fragilidad con trauma mínimo.

ANALGESIA AGUDA (fractura vertebral):
• Paracetamol 1 g EV/VO c/6h.
• Dipirona 1 g EV c/6h.
• Ketorolac 30 mg EV c/8h (corto plazo).
• Calcitonina de salmón 100 UI IM/SC c/24h × 2 semanas (efecto analgésico).
• Tramadol 50–100 mg VO c/8h si dolor moderado-grave.

TRATAMIENTO DE BASE:
Calcio elemental:
• 1000–1200 mg/día VO (en 2–3 tomas con comidas).
  Carbonato de Ca: 1250 mg = 500 mg elemental.
  Citrato de Ca: preferir si hipoclorhidria o IBP.

Vitamina D₃:
• 800–2000 UI/día VO (objetivo 25-OH-VitD >30 ng/mL).

Bifosfonatos (1° elección DMO baja + fractura):
• Alendronato 70 mg VO 1×/semana (en ayunas + 30 min erguido + agua).
• Risedronato 35 mg VO 1×/semana.
• Zoledronato 5 mg EV 1×/año (infusión 15 min).
  (Contraindicado si TFG <35 mL/min).

Denosumab (alternativa — IRA):
• 60 mg SC c/6 meses (no requiere ajuste renal).

Ranelato de estroncio / Teriparatida (anabólico):
• Teriparatida 20 mcg SC/día × máx 2 años (fracturas múltiples, GIOP).

Vitamina D deficiencia severa (<12 ng/mL):
• Vitamina D₃ 50.000 UI VO/semana × 8 semanas → dosis mantenimiento.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'rabdomiolisis',
    title: 'Rabdomiólisis',
    subtitle: 'Hidratación agresiva · alcalinización · diálisis',
    category: 'Osteomuscular',
    icon: Icons.warning_amber_rounded,
    content: '''RABDOMIÓLISIS
→ Destrucción muscular → mioglobinuria → IRA.
CPK >1000 U/L (significativa) / >5000 (alto riesgo renal).

CAUSAS:
• Trauma/aplastamiento · hipertermia maligna · rabdomiólisis esfuerzo.
• Estatinas (especialmente + fibratos/ciclosporina).
• Cocaína, anfetaminas, alcohol.
• Convulsiones prolongadas · miositis · síndrome de compartimento.

DIAGNÓSTICO:
• CPK: elevar hasta ×10.000 normal.
• Mioglobinuria: orina color "coca-cola".
• IRA (creatinina ↑), hipercalemia, acidosis, hipocalcemia.
• Coagulopatía (CID en casos graves).

TRATAMIENTO:

HIDRATACIÓN AGRESIVA (objetivo principal):
• SF 0,9%: 1–1,5 L/h en las primeras horas.
• Meta: diuresis >200–300 mL/h (o 3 mL/kg/h).
• Continuar hasta CPK <5000 U/L y orina clara.
• Volumen total: 6–12 L en 24h (monitorear volemia).

ALCALINIZACIÓN DE ORINA (CPK >5000 o mioglobinuria):
• Bicarbonato de sodio 1 mEq/kg en SF 0,9% → luego 50–100 mEq/L mantenimiento.
• Objetivo pH urinario >6,5 (evita precipitación mioglobina).

FUROSEMIDA (solo si oliguria persistente + buena volemia):
• 40–200 mg EV para forzar diuresis.

HIPERCALEMIA:
• Ver prescripción específica si K⁺ >5,5 mEq/L.

SÍNDROME COMPARTIMENTAL:
• Fasciotomía urgente si presión >30 mmHg.

INDICACIONES DE DIÁLISIS:
• Hipercalemia refractaria · IRA oligúrica · acidosis grave.

SUSPENDER CAUSA: estatina, ejercicio extenuante, alcohol.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // PSIQUIATRÍA — ADICIONALES
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'sindrome_abstinencia_alcohol',
    title: 'Síndrome de Abstinencia Alcohólica',
    subtitle: 'Diazepam · tiamina · CIWA-Ar · delirium tremens',
    category: 'Psiquiatría',
    icon: Icons.psychology_rounded,
    content: '''SÍNDROME DE ABSTINENCIA ALCOHÓLICA (SAA)
→ 6–24h post-última ingesta. Pico: 24–72h.
DELIRIUM TREMENS: emergencia — mortalidad 5–15% sin tratamiento.

CLÍNICA POR ESTADIOS:
• Temprana (6–24h): ansiedad, temblor, diaforesis, taquicardia.
• Moderada (12–48h): alucinaciones, convulsiones.
• Grave — Delirium Tremens (48–72h): confusión, fiebre, convulsiones,
  inestabilidad autonómica, deshidratación.

ESCALA CIWA-Ar (evaluar c/1–4h):
<8: tratamiento sintomático.
8–15: benzodiacepinas leves.
>15: benzodiacepinas agresivas + internación UCI.

BENZODIACEPINAS (tratamiento de elección):
Protocolo guiado por síntomas (CIWA-Ar):
• Diazepam 10 mg VO/EV c/4–6h → evaluar respuesta.
  Dosis máxima carga: 20 mg c/2h hasta sedación (sin techo).
• Lorazepam 2–4 mg VO/EV c/4–6h (preferir en hepatopatía — sin metabolito activo).
• Clordiazepóxido 25–100 mg VO c/6h (si disponible).

DELIRIUM TREMENS (refractario):
• Fenobarbitol 10–15 mg/kg EV + Propofol BIC (UCI).
• Dexmedetomidina BIC 0,2–1 mcg/kg/h (útil en UCI).

TIAMINA (ANTES de glucosa):
• 100–500 mg EV c/8h × 3 días → 100 mg/día VO.

HIDRATACIÓN:
• SF 0,9% + reposición de Mg²⁺ y K⁺ (frecuentemente bajos).

HALOPERIDOL (alucinaciones sin sedación excesiva):
• 2–5 mg EV/IM c/4–6h (NO monoterapia — usar con benzo).

PROFILAXIS CONVULSIONES:
• Valproato 500 mg VO c/8h (si contraindicación a benzo).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'depresion_mayor_tratamiento',
    title: 'Depresión Mayor — Tratamiento',
    subtitle: 'ISRS · IRSN · TCA · criterios de internación',
    category: 'Psiquiatría',
    icon: Icons.psychology_rounded,
    content: '''DEPRESIÓN MAYOR — TRATAMIENTO FARMACOLÓGICO

CRITERIOS DSM-5 (≥5 síntomas × ≥2 semanas):
Ánimo deprimido · anhedonia · cambio de peso · insomnio/hipersomnia ·
fatiga · inutilidad/culpa · concentración · pensamientos de muerte.

PRIMERA LÍNEA — ISRS:
• Sertralina 50 mg/día VO → 100–200 mg/día.
• Escitalopram 10 mg/día VO → 20 mg/día (mejor tolerabilidad).
• Fluoxetina 20 mg/día VO → 40–60 mg/día (vida media larga — útil en adherencia).
• Paroxetina 20 mg/día VO → 40–60 mg/día (más sedante).

SEGUNDA LÍNEA — IRSN (si fallo ISRS o dolor asociado):
• Venlafaxina 75 mg/día VO → 150–225 mg/día.
• Duloxetina 30 mg/día VO → 60–120 mg/día (dolor neuropático + depresión).

ALTERNATIVAS:
• Mirtazapina 15–45 mg/noche (sedante — útil con insomnio y bajo peso).
• Bupropión 150 mg/día VO → 300 mg/día (no ISRS, útil si disfunción sexual).

TIEMPO DE RESPUESTA:
• Efecto antidepresivo: 2–4 semanas.
• Efecto ansiolítico ISRS: 1–2 semanas.
• Duración mínima tratamiento: 6–12 meses post-remisión.

POTENCIACIÓN (respuesta parcial):
• Litio 300 mg VO c/8h → nivel 0,6–0,8 mEq/L.
• Quetiapina 50–300 mg/noche (augmenting).
• Aripiprazol 5–10 mg/día.

CRITERIOS DE INTERNACIÓN URGENTE:
• Ideación suicida con plan/intención/acceso a medios.
• Psicosis, agitación severa, incapacidad de autocuidado.
• Episodio maníaco en trastorno bipolar.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'trastorno_bipolar_manía',
    title: 'Trastorno Bipolar — Episodio Maníaco',
    subtitle: 'Litio · valproato · antipsicóticos · estabilizadores',
    category: 'Psiquiatría',
    icon: Icons.psychology_rounded,
    content: '''TRASTORNO BIPOLAR — EPISODIO MANÍACO AGUDO

MANÍA AGUDA (internación frecuente):
• Grandiosidad, disminución de sueño, pensamiento acelerado,
  impulsividad, desinhibición, psicosis en manía grave.

TRATAMIENTO FARMACOLÓGICO:
ESTABILIZADORES DEL ÁNIMO:
• Valproato (1° elección manía aguda):
  Carga: 20–30 mg/kg/día VO → dosis habitual 750–2000 mg/día.
  Nivel sérico: 50–125 mcg/mL (objetivo para manía: 80–120).
  Monitoreo: LFT + hemograma + nivel.

• Litio (eficaz pero inicio lento):
  300 mg VO c/8h → aumentar hasta nivel 0,8–1,2 mEq/L (manía aguda).
  Nivel mantenimiento: 0,6–0,8 mEq/L.
  Monitoreo: función renal + TSH + litemia c/3 meses.

• Carbamazepina: 200 mg VO c/12h → 600–1200 mg/día.

ANTIPSICÓTICOS ATÍPICOS (manía aguda + sedación):
• Olanzapina 10–20 mg/noche.
• Risperidona 2–6 mg/día.
• Quetiapina 400–800 mg/noche.
• Aripiprazol 15–30 mg/día.

BENZODIACEPINAS (agitación aguda):
• Lorazepam 2–4 mg VO/EV c/4–6h.
• Diazepam 5–10 mg VO/EV c/6h.
• Clonazepam 2–4 mg VO c/8–12h.

EVITAR:
• Antidepresivos en monoterapia (precipitan hipomanía/manía).
• Interrupción brusca de litio (rebote).

TERAPIA ELECTROCONVULSIVA (TEC):
• Indicada en manía grave refractaria o catatónica.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // GENITOURINARIO — ADICIONALES
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'retención_urinaria',
    title: 'Retención Urinaria Aguda',
    subtitle: 'Sondaje vesical · alfa-bloqueante · prostatismo',
    category: 'Genitourinario',
    icon: Icons.medical_services_rounded,
    content: '''RETENCIÓN URINARIA AGUDA (RUA)
→ Incapacidad de vaciar la vejiga + globo vesical palpable.

CAUSAS:
• Prostatismo / HBP (más frecuente en hombres >60).
• Medicamentos: anticolinérgicos, opioides, antidepresivos ATC, alfa-agonistas.
• Fecaloma / estreñimiento severo.
• Neurológico: lesión medular, SD cauda equina, esclerosis múltiple.
• Infección urinaria grave · estenosis uretral · coágulos.

MANEJO URGENTE:
1. Sondaje vesical uretral 18 Fr (doble vía si >600 mL).
   Técnica estéril. Lubricar generosamente.
   Vaciamiento progresivo: 300 mL → esperar 5 min → continuar.
   (Previene hematuria ex-vacuo y bradicardia refleja).

2. Si falla sonda uretral → cistostomía suprapúbica (urólogo).

3. Medir volumen vaciado: >300 mL confirma RUA.

TRATAMIENTO DE CAUSA + PREVENCIÓN RECURRENCIA:
HBP — α-bloqueantes (favorecen retiro de sonda en 48–72h):
• Tamsulosina 0,4 mg VO c/24h (después de cena).
• Alfuzosina 10 mg VO c/24h.
• Terazosina 1–5 mg/noche.

Prueba de retiro de sonda vesical:
• Iniciar α-bloqueante 24–48h antes.
• Retirar sonda en horario diurno.
• Si retención nuevamente → derivar urgología.

DIURESIS POST-OBSTRUCTIVA (>1500 mL/h tras alivio):
• SF 0,9% a 50% de la diuresis horaria hasta estabilización.
• Monitoreo de electrolitos c/4–6h.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'orquiepididimitis_torsion',
    title: 'Orquiepididimitis / Torsión Testicular',
    subtitle: 'ATB · doxiciclina · cirugía de urgencia en torsión',
    category: 'Genitourinario',
    icon: Icons.medical_services_rounded,
    content: '''ESCROTO AGUDO — DIAGNÓSTICO DIFERENCIAL URGENTE

TORSIÓN TESTICULAR — EMERGENCIA QUIRÚRGICA:
• Dolor súbito unilateral + testículo elevado + ausencia de reflejo cremastérico.
• Doppler color (si disponible) → ausencia de flujo.
• EXPLORACIÓN QUIRÚRGICA INMEDIATA sin esperar estudios (ventana 6h).
  >6h: 50% salvación. >24h: <10%.
• Detorsión manual (mientras aguarda cirugía):
  Rotar testículo hacia afuera (como abrir libro) 360–540°.

ORQUIEPIDIDIMITIS:
Origen sexualmente transmitido (<35 años):
• Ceftriaxona 500 mg IM dosis única
  + Doxiciclina 100 mg VO c/12h × 10 días.

Origen entérico (>35 años, BPH, instrumentación):
• Ofloxacino 300 mg VO c/12h × 10 días.
• O Ciprofloxacino 500 mg VO c/12h × 10–14 días.

Grave (absceso escrotal o inmunocomprometido):
• Ceftriaxona 2 g EV c/24h + Metronidazol 500 mg EV c/8h.

MEDIDAS GENERALES:
• Reposo · elevación escrotal · AINEs: Ibuprofeno 400 mg c/8h.
• Dipirona 1 g EV c/6h (dolor agudo).
• Hielo local primeras 24h.

EPIDIDIMITIS CRÓNICA:
• Doxiciclina 100 mg c/12h × 4 semanas + AINEs.
• Derivar urología si recurrente.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // TOXICOLOGÍA — ADICIONALES
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'intoxicacion_antidepresivos_atc',
    title: 'Intoxicación — Antidepresivos Tricíclicos',
    subtitle: 'Bicarbonato · arritmias · QRS ancho · benzodiacepinas',
    category: 'Toxicología',
    icon: Icons.warning_amber_rounded,
    content: '''INTOXICACIÓN POR ANTIDEPRESIVOS TRICÍCLICOS (ATC)
(Amitriptilina, Imipramina, Nortriptilina, Clomipramina)
→ Emergencia toxicológica de alta mortalidad.

MECANISMO DE TOXICIDAD:
• Bloqueo de canales Na⁺ → QRS ancho → arritmias.
• Bloqueo α1 → hipotensión.
• Bloqueo muscarínico → anticolinérgico.
• GABA-A antagonismo → convulsiones.

TRIADA CLÁSICA:
• Alteración neurológica (sedación → coma → convulsiones).
• Cardiotoxicidad (QRS >100 ms, BAV, arritmias ventriculares).
• Síndrome anticolinérgico (midriasis, retención, íleo, fiebre, taquicardia).

TRATAMIENTO:
1. ABC + acceso EV + monitoreo ECG continuo.

2. BICARBONATO DE SODIO 8,4% (tratamiento de elección):
   INDICADO si: QRS >100 ms, arritmia ventricular, hipotensión.
   Bolus: 1–2 mEq/kg EV → objetivo pH arterial 7,45–7,55.
   Mantenimiento: 150 mEq en 1L SG5% a 150–250 mL/h.
   Continuar hasta QRS <100 ms y normalización hemodinámica.

3. CONVULSIONES:
   Diazepam 10 mg EV lento → Lorazepam 4 mg EV.
   EVITAR fenitoína (empeora cardiotoxicidad).
   Fenobarbital 15 mg/kg EV si refractario.

4. HIPOTENSIÓN:
   SF 0,9% 500 mL EV bolus → Noradrenalina BIC si refractario.
   EVITAR dopamina (taquiarritmias).

5. CARBÓN ACTIVADO: 1 g/kg VO (solo si <1h y consciente).

6. EVITAR: flumazenil (convulsiones), fisostigmina, antiarrítmicos IA/IC.

LAVADO GÁSTRICO: considerar si <1h y grandes cantidades ingeridas.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'intoxicacion_cocaina_simpaticomimet',
    title: 'Intoxicación — Cocaína / Simpaticomiméticos',
    subtitle: 'Benzodiacepinas · nitratos · evitar betabloqueantes',
    category: 'Toxicología',
    icon: Icons.warning_amber_rounded,
    content: '''INTOXICACIÓN POR COCAÍNA / SIMPATICOMIMÉTICOS
(Cocaína, Anfetaminas, MDMA, Mefedrona, Cafeína en exceso)

EFECTOS CLÍNICOS:
• SNC: agitación, psicosis, convulsiones.
• Cardiovascular: taquicardia, HTA severa, vasoespasmo coronario, IAM.
• Otros: hipertermia, rabdomiólisis, ACV.

TRATAMIENTO GENERAL:
1. Ambiente tranquilo, estimulación mínima.
2. Monitoreo ECG + PA + temperatura.
3. Acceso EV + SF 0,9%.

AGITACIÓN / ANSIEDAD / CONVULSIONES:
• Diazepam 10 mg EV lento → repetir c/5 min hasta sedación.
• Lorazepam 2–4 mg EV (alternativa).
• Midazolam 5 mg IM/EV (si agitación severa sin acceso).

HIPERTENSIÓN SEVERA (PAD >120):
• Nicardipina 5 mg/h BIC → titular.
• Nitropruside 0,3 mcg/kg/min BIC (crisis hipertensiva grave).
• Nitroglicerina 10–100 mcg/min BIC (si angina/vasoespasmo).
• Fentolamina 5 mg EV bolus (alfa-bloqueante — vasoespasmo).

DOLOR TORÁCICO / VASOSPASMO CORONARIO:
• Nitroglicerina SL + ASS 300 mg VO.
• Benzodiacepinas + calcioantagonistas (diltiazem, verapamil).

HIPERTERMIA:
• Medidas físicas de enfriamiento activo.
• Dantroleno 1 mg/kg EV si T° >39°C con rigidez.

EVITAR ABSOLUTAMENTE:
• Betabloqueantes (propranolol, metoprolol): ↑ vasoconstricción coronaria sin oposición → IAM.
• Naloxona (solo si opioides coingesta confirmada).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // GINECOLOGÍA — ADICIONALES
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'preeclampsia_eclampsia',
    title: 'Preeclampsia / Eclampsia',
    subtitle: 'Sulfato de Mg · labetalol · nifedipino · parto',
    category: 'Ginecología',
    icon: Icons.pregnant_woman_rounded,
    content: '''PREECLAMPSIA / ECLAMPSIA — EMERGENCIA OBSTÉTRICA

DEFINICIÓN:
• Preeclampsia: PA ≥140/90 + proteinuria >300 mg/24h después de semana 20.
• Grave: PAS ≥160 O PAD ≥110 (en 2 mediciones × 15 min).
• Eclampsia: convulsión en preeclampsia (sin otra causa).

SULFATO DE MAGNESIO (prevención y tratamiento de eclampsia):
Dosis de ataque:
• MgSO₄ 50% 4–6 g (8–12 mL) en 100 mL SF → EV en 15–20 min.

Mantenimiento:
• MgSO₄ 50% 1–2 g/h BIC (diluir 5 g en 250 mL SF → 50 mL/h = 1 g/h).

Monitoreo c/1h:
• Reflejos patelares (abolición = toxicidad).
• FR >12/min.
• Diuresis >25 mL/h.
• Si toxicidad → Gluconato de Ca 1 g EV en 3 min (antídoto).
• Suspender si FR <12, reflejos abolidos o diuresis <25 mL/h.

CONTROL DE PA SEVERA (PAS ≥160 o PAD ≥110):
• Labetalol 20 mg EV → 40 mg → 80 mg c/10 min (máx 300 mg total).
• Nifedipino 10 mg VO → repetir c/30 min si necesario (máx 30 mg).
• Hidralazina 5–10 mg EV c/15–20 min (alternativa).
• Objetivo PA: 140–155 / 90–105 mmHg (no bajar demasiado).

ECLAMPSIA ACTIVA:
• MgSO₄ 2–4 g EV en 5 min (dosis adicional) → mantenimiento.
• Diazepam 10 mg EV solo si MgSO₄ no disponible.
• Proteger de traumatismos · O₂ · posición lateral.

RESOLUCIÓN: parto es el tratamiento definitivo.
Estabilizar PA + MgSO₄ → parto (vaginal si posible, cesárea si necesario).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'parto_pretermino_amenaza',
    title: 'Amenaza de Parto Pretérmino',
    subtitle: 'Tocolíticos · corticoides · sulfato de Mg · criterios',
    category: 'Ginecología',
    icon: Icons.pregnant_woman_rounded,
    content: '''AMENAZA DE PARTO PRETÉRMINO (APP)
→ Contracciones regulares + cambios cervicales antes de 37 semanas.

EVALUACIÓN:
• Tocometría + especuloscopía + tacto vaginal.
• Fibronectina fetal (si disponible): VPN >99% si negativa.
• Ecografía: longitud cervical <25 mm → alto riesgo.

CORTICOIDES (maduración pulmonar fetal — 24 a 34 semanas):
→ PRIORIDAD si se espera parto en <7 días.
• Betametasona 12 mg IM c/24h × 2 dosis (preferida).
• O Dexametasona 6 mg IM c/12h × 4 dosis.
Máximo beneficio: 24h a 7 días post-primera dosis.

SULFATO DE MAGNESIO (neuroprotección fetal — <32 semanas):
• 4 g EV bolo en 30 min → 1–2 g/h BIC hasta parto o 24h.
• Monitoreo: FR, reflejos patelares, diuresis.

TOCOLÍTICOS (para ganar tiempo para corticoides + traslado):
• Atosibán (antagonista oxitocina — 1° elección en Europa/AR):
  6,75 mg EV bolus → BIC 18 mcg/min × 3h → 6 mcg/min × 45h.
• Nifedipino (alternativa oral):
  10–20 mg VO c/6h × 48h (cuidado: potencia efecto MgSO₄).
• Indometacina <32 semanas:
  100 mg VO/rectal dosis carga → 25 mg c/6h × 48h (máx).

ATB (si rotura de membranas):
• Ampicilina 2 g EV c/6h + Eritromicina 250 mg VO c/6h × 7 días.
• O Amoxicilina-clavulánico (si no hay ampicilina disponible).

CONTRAINDICACIONES DE TOCOLÍTICOS:
• Sufrimiento fetal · corioamnionitis · desprendimiento placentario.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // CLÍNICA MÉDICA — ADICIONALES
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'shock_hipovolemico',
    title: 'Shock Hemorrágico',
    subtitle: 'Reposición · transfusión · control de sangrado — protocolo',
    category: 'Urgencias',
    icon: Icons.emergency_rounded,
    content: '''SHOCK HIPOVOLÉMICO / HEMORRÁGICO
→ Hipoperfusión tisular por pérdida de volumen intravascular.

CLASIFICACIÓN ATLS:
Clase I (<15% volemia): FC <100, PA normal, asintomático.
Clase II (15–30%): FC >100, taquipnea, ansiedad.
Clase III (30–40%): FC >120, hipotensión, confusión.
Clase IV (>40%): FC >140, colapso, anuria, coma.

REANIMACIÓN INICIAL (ABCDE):
• 2 accesos EV gruesos (16G) + monitoreo continuo.
• Cristaloides: SF 0,9% o Ringer Lactato 1–2 L EV en 20–30 min.
  (Evitar exceso de cristaloides → acidosis hiperclorémica, dilución coagulación).

CONTROL DE SANGRADO (prioridad):
• Compresión directa externa.
• Torniquete si extremidad.
• Ácido tranexámico 1 g EV en 10 min → 1 g EV en 8h (máx <3h del trauma).

TRANSFUSIÓN (objetivos Hb >7–8 g/dL, en trauma/hemorragia activa >10):
• GRD: 1 unidad ↑ Hb ~1 g/dL.
• Protocolo masivo (clase III/IV):
  Razón 1:1:1 — GRD : PFC : Plaquetas.
• Si shock refractario a cristaloides → transfundir sin esperar tipificación
  (GRD O negativo universal).

VASOPRESORES (si hipotensión persiste tras volumen adecuado):
• Noradrenalina BIC: 0,05–0,5 mcg/kg/min.
• Solo como puente para control de sangrado — no sustituye volumen.

MONITOREO RESPUESTA:
• PAM objetivo ≥65 mmHg (50–65 si trauma craneoencefálico).
• Diuresis >0,5 mL/kg/h.
• Lactato inicial → reevaluar c/2h (objetivo normalización).
• BE (base excess) · Hb · coagulación c/1h en activo.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'dolor_cronico_manejo',
    title: 'Dolor Crónico — Manejo Multimodal',
    subtitle: 'Escalera OMS · coadyuvantes · opioides crónicos',
    category: 'Analgesia',
    icon: Icons.medical_services_rounded,
    content: '''DOLOR CRÓNICO — MANEJO MULTIMODAL (OMS)

ESCALERA ANALGÉSICA OMS — ADAPTACIÓN CRÓNICO:
Escalón 1 (leve): Paracetamol 500–1000 mg c/6h +/− AINEs.
Escalón 2 (moderado): Tramadol 50–100 mg c/6–8h + escalón 1.
Escalón 3 (grave): Opioides fuertes + escalón 1.
Escalón 4 (refractario): Procedimientos intervencionistas.

ANALGÉSICOS COADYUVANTES:
• Gabapentina 300–1200 mg c/8h (neuropático, oncológico).
• Pregabalina 75–300 mg c/12h (neuropático).
• Amitriptilina 10–75 mg/noche (neuropático, crónico difuso).
• Duloxetina 60–120 mg/día (fibromialgia, neuropático).

OPIOIDES CRÓNICOS (solo si fracaso escalones previos):
Tramadol SR: 100–200 mg c/12h.
Morfina SR: 15–30 mg c/12h → titular c/48–72h.
Oxicodona SR: 10–20 mg c/12h (+ Naloxona: Targinact evita constipación).
Buprenorfina transdérmica: 5–70 mcg/h (patch 7 días — útil en adherencia).
Fentanil transdérmico: 12–100 mcg/h (patch 72h — crónico estabilizado).

ROTACIÓN DE OPIOIDES (si tolerancia o efectos adversos):
Reducir 25–30% de la dosis equianalgésica al cambiar.

PREVENCIÓN DE EFECTOS ADVERSOS:
• Estreñimiento: Naloxegol 25 mg/día o Metilnaltrexona SC.
• Náuseas: Ondansetrón 8 mg c/8h (primeras semanas).
• Somnolencia: Metilfenidato 5–10 mg/mañana (oncológico).

EVITAR: combinación opioides + benzodiacepinas (riesgo respiratorio).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'hiperglucemia_corticoides',
    title: 'Hiperglucemia Inducida por Corticoides',
    subtitle: 'Insulina NPH · esquema deslizante · control glucémico',
    category: 'Endocrinología',
    icon: Icons.monitor_heart_rounded,
    content: '''HIPERGLUCEMIA INDUCIDA POR CORTICOIDES (HIC)
→ Frecuente en internados con corticoterapia. Empeora pronóstico.

PATRÓN GLUCÉMICO CARACTERÍSTICO:
• Pico post-almuerzo/cena (corticoides actúan en horas post-dosis).
• Glucemia matinal puede ser normal con pico vespertino elevado.
• Glucometría c/6h al inicio del tratamiento.

ESQUEMA DE INSULINA SEGÚN CORTICOIDE:
Corticoide de acción intermedia (prednisona/prednisolona — dosis matinal):
• Insulina NPH: 0,1 UI/kg junto con la dosis matinal del corticoide.
  Si glucemia >200: 0,2 UI/kg de NPH matinal.
  Titular: aumentar 10–20% si glucemia >180 mg/dL post-almuerzo.

Corticoide de acción larga (dexametasona — 1 dosis/día):
• Insulina glargina: 0,1–0,2 UI/kg SC c/24h (noche).

Corticoide EV continuo o pulsos:
• Insulina regular BIC: iniciar 0,5–1 UI/h → titular por glucemia horaria.

OBJETIVOS GLUCÉMICOS:
• Internado no crítico: 140–180 mg/dL.
• UCI: 140–180 mg/dL (objetivo estrecho 110–140 solo en seleccionados).

ESQUEMA DE RESCATE (si glucemia >300 sin insulina pautada):
• Insulina regular SC: 1 UI por cada 50 mg/dL >200 mg/dL.
  (Ej.: glucemia 350 → (350-200)/50 = 3 UI regular SC).

POST-CORTICOIDES:
• Reducir insulina paralelamente a reducción de dosis del corticoide.
• Si corticoide suspendido → reducir insulina 50% y reevaluar.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'insuficiencia_hepatica_cronica',
    title: 'Complicaciones de Cirrosis — Manejo',
    subtitle: 'PBE · SHR · HDA varicosa · profilaxis secundaria',
    category: 'Gastroenterología',
    icon: Icons.medical_services_rounded,
    content: '''COMPLICACIONES DE CIRROSIS HEPÁTICA

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PERITONITIS BACTERIANA ESPONTÁNEA (PBE):
Diagnóstico: PMN >250 células/mm³ en líquido ascítico.
• Cefotaxima 2 g EV c/8h × 5 días (1° elección).
• O Ciprofloxacino 400 mg EV c/12h × 5 días.
• Albumina 1,5 g/kg EV día 1 → 1 g/kg día 3 (previene SHR).
Profilaxis secundaria: Norfloxacina 400 mg/día VO indefinido.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SÍNDROME HEPATORRENAL (SHR):
Tipo 1 (agudo — Cr >2,5 en 2 semanas): urgencia.
• Terlipresina 0,5–2 mg EV c/4–6h + Albumina 1 g/kg/día.
  (Objetivo: reducir creatinina <1,5 mg/dL en 2 semanas).
• Alternativa: Noradrenalina BIC + Albumina (UCI).
• Evitar nefrotóxicos + AINES + aminoglucósidos.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HDA VARICOSA (ver prescripción específica + agregar):
Profilaxis secundaria obligatoria post-HDA:
• Propranolol 20–40 mg VO c/12h (titular: FC objetivo 55–60 lpm).
• O Carvedilol 6,25–12,5 mg c/12h.
• Ligadura endoscópica c/3–4 semanas hasta erradicación.
TIPS si hemorragia refractaria.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ENCEFALOPATÍA HEPÁTICA AGUDA:
• Identificar y tratar precipitante: hemorragia, infección, constipación.
• Lactulosa: 30 mL c/2h hasta 2–3 deposiciones blandas/día.
• Rifaximina 550 mg c/12h (profilaxis secundaria + agudo).
• Restricción proteica transitoria 0,5 g/kg/día (solo fase aguda severa).
• Zinc 220 mg c/12h (déficit frecuente en cirróticos).

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // PRESCRIPCIONES ADICIONALES
  // ══════════════════════════════════════════════════════════════════════════

  _PrescriptionModel(
    id: 'cerumen_impactado',
    title: 'Tapón de Cerumen',
    subtitle: 'Lavado ótico · Ceruminolíticos',
    category: 'Otorrinolaringología',
    icon: Icons.hearing_rounded,
    content: '''Uso Ótico:
1. Gotas ceruminolíticas (ej. Otocerum® / Glicerina carbonatada)
   Aplicar 5 gotas en el oído afectado.
   Mantener la cabeza inclinada con el oído hacia arriba por 5 minutos.
   Aplicar cada 8h por 5 días.

Guardia:
1. Dipirona 1 g IM (si hay queja de dolor o prurito intenso local).

---
⚕ Modelo educativo — derivar a extracción/lavado si no resuelve.''',
  ),

  _PrescriptionModel(
    id: 'dermatitis_seborreica_leve',
    title: 'Dermatitis Seborreica Leve',
    subtitle: 'Ketoconazol · Hidrocortisona tópica',
    category: 'Dermatología',
    icon: Icons.face_retouching_natural_rounded,
    content: '''Uso Tópico:
1. Ketoconazol shampoo 2% (ej. Eumicel® / Micoral®)
   Aplicar en el cuero cabelludo 3 veces por semana.
   Dejar actuar por 5 minutos y enjuagar. Continuar por 4 semanas.

2. Hidrocortisona crema 1%
   Aplicar una fina capa 2 veces al día en las áreas eccematosas por 5 días.

Guardia:
1. Dipirona 1 g IM (si hay dolor o prurito muy intenso que afecte el descanso).''',
  ),

  _PrescriptionModel(
    id: 'enterobiasis_oxiuros',
    title: 'Enterobiasis / Oxiuriasis',
    subtitle: 'Albendazol · Tratamiento familiar',
    category: 'Infectología',
    icon: Icons.bug_report_rounded,
    content: '''Uso Oral:
1. Albendazol 400 mg (o Mebendazol 200 mg)
   Tomar 1 comprimido vía oral como dosis única.
   Repetir la misma dosis a los 14 días.

Pautas y Orientación:
→ Lavar ropa de cama, pijamas y toallas con agua caliente.
→ Higiene estricta de manos y uñas (mantenerlas cortas).
→ TRATAR A TODOS los contactos domiciliarios simultáneamente.

Guardia:
1. Dipirona 1 g IM o antihistamínico (si el prurito anal es intolerable).''',
  ),

  _PrescriptionModel(
    id: 'heridas_leves_escoriaciones',
    title: 'Escoriaciones / Heridas Leves',
    subtitle: 'Limpieza local · Sulfadiazina de plata',
    category: 'Dermatología',
    icon: Icons.healing_rounded,
    content: '''Uso Tópico / Cuidados Locales:
1. Solución Fisiológica (SF) 0,9%
   Lavar la herida 2 veces al día antes de aplicar la crema.

2. Sulfadiazina de Plata crema (ej. Platsul-A®)
   Aplicar una fina capa sobre la lesión 1 a 2 veces al día hasta la cicatrización.

Guardia:
1. Dipirona 1 g IM dosis única (analgesia local aguda).
→ Chequear esquema de vacunación antitetánica.''',
  ),

  _PrescriptionModel(
    id: 'enfermedad_hemorroidal',
    title: 'Enfermedad Hemorroidal / Hemorroides',
    subtitle: 'Diosmina · Cremas tópicas · Laxantes suaves',
    category: 'Gastroenterología',
    icon: Icons.medical_services_rounded,
    content: '''Uso Oral:
1. Aceite Mineral (o Lactulosa)
   Tomar 15 mL vía oral cada 8h (evitar constipación).

2. Diosmina + Hesperidina 500 mg (ej. Daflon® / Venosmil®)
   Tomar 1 comp cada 4h por 4 días → luego cada 6h por 3 días → luego cada 12h por 3 meses.

3. Ibuprofeno 400 mg
   Tomar 1 comp vía oral cada 12h por 5 días.

4. Dipirona 500 mg
   Tomar 1 comp vía oral cada 6h en caso de dolor.

Uso Tópico:
5. Policresuleno + Cinchocaína (ej. Proctyl®) o Lidocaína/Hidrocortisona (ej. Xyloprocto®)
   Aplicar una fina capa en la región anal 2 a 3 veces al día.

Guardia:
1. Dipirona 1 g IM + Dexametasona (Decadron®) 4 mg IM.''',
  ),

  _PrescriptionModel(
    id: 'intoxicacion_alimentaria_leve',
    title: 'Intoxicación Alimentaria Leve',
    subtitle: 'SRO · Metoclopramida · Soporte sintomático',
    category: 'Gastroenterología',
    icon: Icons.restaurant_menu_rounded,
    content: '''Uso Oral:
1. Sales de Rehidratación Oral (SRO)
   Ingerir a demanda, especialmente un vaso después de cada evacuación líquida.

2. Metoclopramida 10 mg (ej. Reliverán®)
   Tomar 1 comp vía oral cada 8h si hay náuseas o vómitos (por un máximo de 3 días).

3. Dipirona 500 mg (o Paracetamol)
   Tomar 1 comp vía oral cada 6h si hay dolor abdominal tipo cólico o fiebre.

Guardia:
1. Metoclopramida 10 mg IM (si hay vómitos activos que impiden la vía oral).''',
  ),

  _PrescriptionModel(
    id: 'molusco_contagioso',
    title: 'Molusco Contagioso',
    subtitle: 'Conducta expectante · Educación al paciente',
    category: 'Dermatología',
    icon: Icons.coronavirus_rounded,
    content: '''Conducta General / Ambulatoria:
→ Orientar conducta expectante (la resolución suele ser espontánea entre 6 y 12 meses).
→ Evitar la manipulación, rascado o afeitado de las lesiones.
→ No compartir toallas, esponjas ni ropa.

Guardia:
1. Dipirona 1 g IM (solo si hay dolor local significativo por inflamación).

---
⚕ Modelo educativo — Derivar a dermatología (para curetaje o crioterapia) si las lesiones son muy extensas, persistentes o están sobreinfectadas.''',
  ),

  _PrescriptionModel(
    id: 'picadura_insecto_inflamatoria',
    title: 'Picadura de Insecto',
    subtitle: 'Reacción inflamatoria local · Antihistamínicos',
    category: 'Dermatología',
    icon: Icons.bug_report_rounded,
    content: '''Uso Oral:
1. Difenhidramina 50 mg (ej. Benadryl®) o Dexclorfeniramina 2 mg
   Tomar 1 comp vía oral cada 8h por 5 días.

2. Prednisona 20 mg
   Tomar 1 comp vía oral 1 vez al día (por la mañana) por 3 días.

3. Dipirona 500 mg
   Tomar 1 comp vía oral cada 6h en caso de dolor o febrícula local.

Guardia (Reacción severa sin anafilaxia):
1. Hidrocortisona 100 mg IM (o Dexametasona 8 mg) + Dipirona 1 g IM.''',
  ),

  _PrescriptionModel(
    id: 'tos_seca_persistente',
    title: 'Tos Seca Persistente',
    subtitle: 'Antitusivos · Antihistamínicos · Lavado nasal',
    category: 'Respiratorio',
    icon: Icons.air_rounded,
    content: '''Uso Oral:
1. Dextrometorfano 15 mg o Levodropropizina 60 mg (o Benzonatato si disponible)
   Tomar 1 comp (o 10 mL de jarabe) vía oral cada 8h por hasta 5 días.

2. Loratadina 10 mg
   Tomar 1 comp vía oral 1 vez al día por 7 días.

Uso Local:
3. Solución Fisiológica (SF) 0,9%
   Instilar en las fosas nasales (lavado nasal) 3 veces al día.

Guardia:
1. Dipirona 1 g IM (si presenta dolor torácico muscular/costal secundario al esfuerzo tusígeno).''',
  ),

  _PrescriptionModel(
    id: 'varices_miembros_inferiores',
    title: 'Várices en Miembros Inferiores',
    subtitle: 'Venotónicos · Analgesia tópica',
    category: 'Cardiovascular',
    icon: Icons.accessibility_rounded,
    content: '''Uso Oral:
1. Diosmina + Hesperidina 500 mg (ej. Daflon® / Venosmil®)
   Tomar 1 comp vía oral cada 12h por 30 días.

Uso Tópico (si hay dolor/pesadez local):
2. Polisulfato de Mucopolisacárido gel/crema (ej. Hirudoid®)
   Aplicar una fina capa 2 veces al día en las piernas, con masaje ascendente.

Guardia:
1. Dipirona 1 g IM (si la paciente consulta por dolor local agudo/intenso).''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // PRESCRIPCIONES ADICIONALES — Frecuentes en Guardia/Consultorio Argentina
  // ══════════════════════════════════════════════════════════════════════════

  _PrescriptionModel(
    id: 'transgresion_alimentaria_colico',
    title: 'Dispepsia Alimentaria Aguda',
    subtitle: 'Antiespasmódico + Analgésico (Sertal Compuesto / Buscapina)',
    category: 'Gastroenterología',
    icon: Icons.fastfood_rounded,
    content: '''Uso Oral:
1. Propinoxato + Clonixinato de Lisina (ej. Sertal Compuesto®)
   Tomar 1 comp vía oral cada 8h en caso de dolor tipo cólico.

2. Metoclopramida 10 mg (ej. Reliverán®)
   Tomar 1 comp vía oral cada 8h si presenta náuseas.

Guardia (Crisis de dolor cólico intenso):
1. Hioscina (Buscapina®) 1 ampolla + Dipirona 1 g diluidos en 100 mL de SF 0,9% EV a pasar en 30 min.''',
  ),

  _PrescriptionModel(
    id: 'mordedura_perro_gato',
    title: 'Mordedura de Animal (Perro/Gato)',
    subtitle: 'Profilaxis con Amoxicilina-Clavulánico (Optamox)',
    category: 'Infectología',
    icon: Icons.pets_rounded,
    content: '''Uso Oral:
1. Amoxicilina + Ácido Clavulánico 875/125 mg (ej. Optamox® / Amoxiclav®)
   Tomar 1 comp vía oral cada 12h por 5 a 7 días.
   (Pacientes alérgicos: Clindamicina + Ciprofloxacina).

2. Ibuprofeno 400 mg
   Tomar 1 comp vía oral cada 8h por 3 días para inflamación y dolor.

Guardia:
1. Lavado profuso con agua, jabón y solución fisiológica.
2. Chequear y actualizar vacuna Antitetánica.
3. Evaluar necesidad de profilaxis Antirrábica según protocolo epidemiológico local.''',
  ),

  _PrescriptionModel(
    id: 'cervicalgia_contractura',
    title: 'Cervicalgia / Contractura Muscular',
    subtitle: 'Diclofenac + Pridinol (Dioxaflex Plus / Blokium)',
    category: 'Osteomuscular',
    icon: Icons.accessibility_new_rounded,
    content: '''Uso Oral:
1. Diclofenac 50 mg + Pridinol 4 mg (ej. Dioxaflex Plus® / Blokium Flex®)
   Tomar 1 comp vía oral cada 12h por 3 a 5 días (idealmente después de las comidas).
   *Advertir al paciente que puede dar somnolencia.*

Uso Tópico / Físico:
2. Calor local
   Aplicar paños tibios o almohadilla térmica 15 min, 3 veces al día en la zona afectada.

Guardia:
1. Diclofenac 75 mg IM + Dexametasona 4 mg IM (en jeringas separadas o combinados si la presentación lo permite).''',
  ),

  _PrescriptionModel(
    id: 'herida_cortante_sutura',
    title: 'Herida Cortante / Sutura',
    subtitle: 'Cuidados post-sutura en guardia',
    category: 'Urgencias',
    icon: Icons.healing_rounded,
    content: '''Indicaciones Post-Sutura:
1. Ibuprofeno 400 mg (o Dipirona 500 mg)
   Tomar 1 comp vía oral cada 8h en caso de dolor.

2. Cefalexina 500 mg (Opcional, solo si la herida es sucia o de alto riesgo)
   Tomar 1 comp vía oral cada 6h por 5 días.

Cuidados locales:
→ Mantener el vendaje seco y limpio las primeras 24h.
→ Luego, lavar diariamente con agua y jabón neutro, secar sin frotar y aplicar Povidona Yodada (Pervinox®) o Clorhexidina.
→ Regresar a la guardia o centro de salud en 7 a 10 días para el retiro de puntos.''',
  ),

  _PrescriptionModel(
    id: 'resfrio_comun_irs',
    title: 'Resfrío Común / Cuadro Viral VRA',
    subtitle: 'Tratamiento puramente sintomático',
    category: 'Clínica Médica',
    icon: Icons.sick_rounded,
    content: '''Uso Oral:
1. Paracetamol 500 mg (o Ibuprofeno 400 mg)
   Tomar 1 comp vía oral cada 8h si presenta fiebre (≥38°C), dolor de cabeza o malestar general.

2. Antigripal compuesto (ej. Qura Plus® / Refrianex®) - Opcional
   Tomar 1 comp cada 8h por 3 a 5 días para la congestión severa.
   (Contraindicado en hipertensos severos por contener Pseudoefedrina).

Medidas Generales:
→ Reposo relativo.
→ Abundante hidratación (agua, tés, sopas).
→ Lavados nasales con Solución Fisiológica a demanda.''',
  ),

  _PrescriptionModel(
    id: 'asma_pediatrica_crisis',
    title: 'Crisis de Asma Pediátrica',
    subtitle: 'Salbutamol + Meprednisona (Cortipyren)',
    category: 'Pediatría',
    icon: Icons.child_care_rounded,
    content: '''Tratamiento Ambulatorio (Crisis Leve):
1. Salbutamol aerosol (100 mcg/dosis)
   Hacer 2 a 4 puffs (disparos) con aerocámara, cada 4 o 6 horas.
   (Agitar antes de cada disparo, esperar 30 seg entre uno y otro).

2. Meprednisona gotas 4 mg/mL (ej. Deltisona B® / Cortipyren®)
   Dar 1 gota por kg de peso/día (máximo 40 gotas), preferentemente a la mañana, por 3 a 5 días.

Guardia (Crisis Moderada):
1. Oxígeno por cánula si SatO2 < 92%.
2. Salbutamol: 4-8 puffs con aerocámara cada 20 min por 1 hora.
3. Dexametasona 0.6 mg/kg VO o IM (dosis única, máximo 12 mg) o Meprednisona 1 mg/kg VO.''',
  ),

  _PrescriptionModel(
    id: 'gastroenteritis_pediatrica',
    title: 'Gastroenteritis Pediátrica',
    subtitle: 'SRO + Probióticos (Enterogermina) + Ondansetrón',
    category: 'Pediatría',
    icon: Icons.child_care_rounded,
    content: '''Uso Oral:
1. Sales de Rehidratación Oral (SRO)
   Ofrecer con cucharita o jeringa, 5 a 10 mL cada 5 minutos, especialmente después de cada vómito o diarrea.

2. Ondansetrón gotas o comprimidos (0.15 mg/kg)
   Dar vía oral cada 8h SOLO si hay vómitos que impidan la tolerancia a líquidos.

3. Probióticos (ej. Enterogermina® / Floratil®)
   Tomar 1 frasco ampolla (o sobre) vía oral, 1 a 2 veces al día por 5 días para reponer flora intestinal.

Alimentación:
→ Continuar con lactancia materna a demanda.
→ Dieta astringente sin forzar (arroz, polenta, manzana rallada, pollo hervido).''',
  ),

  _PrescriptionModel(
    id: 'dismenorrea_dolor_menstrual',
    title: 'Dismenorrea / Dolor Menstrual',
    subtitle: 'Ácido Mefenámico (Ponstil) o AINEs',
    category: 'Ginecología',
    icon: Icons.bloodtype_rounded,
    content: '''Uso Oral:
1. Ácido Mefenámico 500 mg (ej. Ponstil Forte®)
   Tomar 1 comp vía oral cada 8h durante los días de dolor menstrual intenso.
   (Tomar siempre con el estómago lleno).

2. Ibuprofeno 600 mg o Naproxeno 500 mg (Como alternativa)
   Tomar 1 comp vía oral cada 8 a 12h.

Guardia (Si el dolor es incapacitante):
1. Hioscina (Buscapina®) + Dipirona 1 g EV diluido a pasar en 20 min.
2. Descartar abdomen agudo quirúrgico, EPI, o embarazo ectópico si es atípico.''',
  ),

  _PrescriptionModel(
    id: 'mastitis_puerperal',
    title: 'Mastitis Puerperal',
    subtitle: 'Cefalexina + Vaciado mamario',
    category: 'Ginecología',
    icon: Icons.pregnant_woman_rounded,
    content: '''Uso Oral:
1. Cefalexina 500 mg
   Tomar 1 comp vía oral cada 6h por 10 a 14 días.
   (Es seguro durante la lactancia).

2. Ibuprofeno 400 mg (o Paracetamol 500 mg)
   Tomar 1 comp vía oral cada 8h para dolor e inflamación.

Indicaciones Fundamentales:
→ NO suspender la lactancia. El vaciado frecuente de la mama es parte del tratamiento.
→ Aplicar compresas tibias antes de amamantar y compresas frías después.
→ Asegurar buen acople del bebé al pezón.
→ Consultar urgente si aparece absceso (bulto fluctuante).''',
  ),

  _PrescriptionModel(
    id: 'balanopostitis',
    title: 'Balanopostitis',
    subtitle: 'Higiene + Miconazol/Hidrocortisona (Macril)',
    category: 'Urología',
    icon: Icons.medical_services_rounded,
    content: '''Uso Tópico / Higiene:
1. Jabón de Glicerina o Neutro
   Realizar higiene retrayendo suavemente el prepucio 2 veces al día. Secar completamente sin frotar.

2. Miconazol + Hidrocortisona crema (ej. Macril® / Daktacort®)
   Aplicar una fina capa en el glande y cara interna del prepucio, 2 veces al día por 7 días.

Recomendaciones:
→ Evitar relaciones sexuales hasta la curación clínica.
→ Considerar tratamiento de la pareja si presenta candidiasis a repetición.
→ Descartar Diabetes Mellitus si es a repetición.''',
  ),

  _PrescriptionModel(
    id: 'aftas_estomatitis',
    title: 'Aftas Bucales / Estomatitis',
    subtitle: 'Anestésicos locales (Plac-Out / Bucal-Tacc)',
    category: 'Odontología / Clínica',
    icon: Icons.face_rounded,
    content: '''Uso Tópico / Local:
1. Clorhexidina + Bencidamina spray o colutorio (ej. Plac-Out®)
   Realizar enjuagues o aplicar 2 aspersiones directamente sobre el afta, 3 a 4 veces al día (después de comer).

2. Gel con anestésico (ej. Oralsone® o Bucal-Tacc®)
   Aplicar una pequeña cantidad sobre el afta con hisopo de algodón, 10 minutos antes de las comidas para aliviar el dolor.

Medidas Generales:
→ Evitar alimentos cítricos, muy calientes, picantes o muy salados.
→ Mantener buena hidratación (líquidos fríos alivian).''',
  ),

  _PrescriptionModel(
    id: 'pediculosis_piojos',
    title: 'Pediculosis (Piojos)',
    subtitle: 'Permetrina loción + Peine fino',
    category: 'Dermatología',
    icon: Icons.pest_control_rounded,
    content: '''Uso Tópico:
1. Permetrina Loción 1% (ej. Nopucid®)
   Aplicar sobre el cabello seco, masajeando desde el cuero cabelludo hasta las puntas.
   Dejar actuar 10 a 15 minutos (según prospecto).
   Lavar el cabello con champú normal.
   Repetir todo el procedimiento exactamente a los 7-10 días.

Mecánico (Clave del tratamiento):
2. Peine fino (lendrera)
   Pasar todos los días por el cabello húmedo para retirar liendres y piojos muertos.

Precauciones:
→ Lavar ropa de cama, gorros y bufandas con agua caliente.
→ No compartir peines ni accesorios de cabello.''',
  ),

  _PrescriptionModel(
    id: 'prostatitis_aguda',
    title: 'Prostatitis Aguda',
    subtitle: 'Ciprofloxacina prolongada + Tamsulosina',
    category: 'Urología',
    icon: Icons.healing_rounded,
    content: '''Uso Oral:
1. Ciprofloxacina 500 mg
   Tomar 1 comp vía oral cada 12h por 14 a 28 días.
   (El tratamiento es prolongado por la baja penetración del ATB en la próstata).

2. Tamsulosina 0.4 mg (ej. Secotex®)
   Tomar 1 comp vía oral por la noche, después de cenar, por 30 días.

3. Ibuprofeno 400 mg (o Diclofenac)
   Tomar 1 comp vía oral cada 8h por 5 a 7 días.

Guardia (si hay retención aguda de orina o sepsis):
→ NO colocar sonda Foley por uretra si hay fuerte sospecha de prostatitis aguda severa. Valorar punción suprapúbica.
→ Internación para Ceftriaxona EV si hay fiebre alta y compromiso de estado general.''',
  ),

  _PrescriptionModel(
    id: 'vomitos_embarazo',
    title: 'Vómitos en el Embarazo (Hiperemesis Leve)',
    subtitle: 'Doxilamina-Piridoxina / Metoclopramida',
    category: 'Ginecología',
    icon: Icons.pregnant_woman_rounded,
    content: '''Uso Oral:
1. Doxilamina 10 mg + Piridoxina 10 mg (ej. Nauseol® / Reliverán Ingesta®)
   Tomar 2 comprimidos juntos al acostarse. Si los síntomas persisten, tomar 1 comp a la mañana y 2 a la noche.

2. Metoclopramida 10 mg
   Tomar 1 comp vía oral cada 8h (como rescate si no mejora con lo anterior).

Medidas Dietéticas:
→ Fraccionar comidas: comer pequeñas porciones cada 2-3 horas.
→ Evitar líquidos junto con comidas sólidas.
→ Consumir galletitas secas o tostadas antes de levantarse de la cama.
→ Evitar grasas, picantes y olores fuertes.''',
  ),

  _PrescriptionModel(
    id: 'hemorragia_subconjuntival',
    title: 'Hemorragia Subconjuntival (Derrame Ocular)',
    subtitle: 'Lágrimas artificiales + Control de Presión',
    category: 'Oftalmología',
    icon: Icons.visibility_rounded,
    content: '''Tratamiento Local:
1. Lágrimas Artificiales (Hialuronato de sodio)
   Instilar 1 gota en el ojo afectado 3 a 4 veces al día (solo para sensación de roce/cuerpo extraño).

Orientación al Paciente:
→ Tranquilizar: Es una condición benigna que se reabsorbe sola como un moretón (suele tardar 1 a 3 semanas).
→ No requiere colirios antibióticos ni corticoides.
→ Controlar la Presión Arterial, ya que los picos hipertensivos son la causa más frecuente.
→ Evitar frotarse el ojo, levantar peso o hacer maniobras de Valsalva intensas.''',
  ),

  _PrescriptionModel(
    id: 'ulcera_corneal_abrasion',
    title: 'Abrasión Corneal / Úlcera Traumática',
    subtitle: 'Eritromicina ungüento / Gotas de Tobramicina',
    category: 'Oftalmología',
    icon: Icons.visibility_rounded,
    content: '''Uso Oftalmológico:
1. Tobramicina gotas (o Ciprofloxacina gotas)
   Instilar 1 gota en el ojo afectado cada 4 a 6 horas por 5 a 7 días.

2. Eritromicina Ungüento oftálmico (si está disponible)
   Aplicar una pequeña tira dentro del párpado inferior por la noche.

Uso Oral:
3. Ibuprofeno 400 mg
   Tomar 1 comp vía oral cada 8h para el dolor ocular.

Guardia:
→ Tinte con Fluoresceína para confirmar la abrasión.
→ Lavado ocular profuso con solución fisiológica si hubo cuerpo extraño.
→ NUNCA recetar colirios con anestésico para uso ambulatorio (retrasan la cicatrización).
→ Derivar urgente a oftalmología.''',
  ),

  _PrescriptionModel(
    id: 'fascitis_plantar',
    title: 'Fascitis Plantar / Talalgia',
    subtitle: 'Elongación + AINEs + Plantillas',
    category: 'Osteomuscular',
    icon: Icons.directions_walk_rounded,
    content: '''Medidas Físicas y Kinesiológicas (Lo más importante):
1. Frío local
   Hacer rodar una botella de agua congelada bajo la planta del pie por 15 minutos, 3 veces al día.
2. Ejercicios de elongación
   Estirar la pantorrilla (gemelos) y la fascia plantar antes de pisar el suelo a la mañana.
3. Uso de calzado adecuado (talón levemente elevado y acolchado, evitar andar descalzo). Considerar taloneras de silicona.

Uso Oral:
4. Ibuprofeno 600 mg o Naproxeno 500 mg
   Tomar 1 comp vía oral cada 12h por 7 a 10 días para desinflamar.

Guardia:
→ Dipirona o Diclofenac IM si el dolor es agudamente inhabilitante. Derivar a Traumatología.''',
  ),

  _PrescriptionModel(
    id: 'tricomoniasis_urogenital',
    title: 'Tricomoniasis Urogenital',
    subtitle: 'Metronidazol oral dosis única (ITS)',
    category: 'Infectología / Ginecología',
    icon: Icons.coronavirus_rounded,
    content: '''Uso Oral:
1. Metronidazol 500 mg (ej. Flagyl®)
   Tomar 4 comprimidos juntos (Total 2 gramos) como DOSIS ÚNICA.
   (Alternativa: 500 mg vía oral cada 12h por 7 días).

Indicaciones Estrictas:
→ TRATAMIENTO DE LA PAREJA SEXUAL es obligatorio (mismo esquema empírico), aunque esté asintomático.
→ Abstinencia sexual hasta 7 días después de haber tomado la medicación.
→ Efecto Antabús: PROHIBIDO consumir alcohol durante el tratamiento y hasta 48h después de terminado.''',
  ),

  _PrescriptionModel(
    id: 'ataque_panico_guardia',
    title: 'Ataque de Pánico en Guardia',
    subtitle: 'Clonazepam SL + Contención verbal',
    category: 'Psiquiatría',
    icon: Icons.psychology_rounded,
    content: '''Manejo Inmediato en Guardia:
1. Descartar patología orgánica (ECG, enzimas y evaluación clínica según riesgo).
2. Contención verbal y ambiente tranquilo (bajar luces, aislar ruidos).
3. Ejercicios de respiración diafragmática o en bolsa de papel si hay hiperventilación severa.

Farmacológico:
4. Clonazepam 0.25 mg a 0.5 mg Sublingual (SL)
   Colocar debajo de la lengua (acción rápida en 15-20 min).
   (Alternativa: Lorazepam 1 mg SL o VO).

Al Alta:
→ Orientar que el ECG y el corazón están sanos.
→ No dejar la benzodiacepina como tratamiento crónico sin control.
→ Derivar a Psiquiatría y Psicología para tratamiento de base.''',
  ),

  _PrescriptionModel(
    id: 'herpes_labial',
    title: 'Herpes Labial',
    subtitle: 'Aciclovir tópico/oral',
    category: 'Dermatología',
    icon: Icons.face_rounded,
    content: '''Uso Tópico (Fase de Pródromo o inicial):
1. Aciclovir 5% crema
   Aplicar sobre las vesículas 5 veces al día (cada 4 horas omitiendo la noche), por 5 días.
   (Lavarse bien las manos antes y después de aplicar).

Uso Oral (Solo si es muy extenso, doloroso o en inmunosuprimidos):
2. Aciclovir 400 mg
   Tomar 1 comp vía oral cada 8h por 5 a 7 días.

Medidas de prevención y alivio:
→ Aplicar hielo local envuelto en un paño en las primeras horas puede reducir la inflamación.
→ Evitar compartir vasos, cubiertos, toallas o mate.
→ Evitar besar bebés o inmunodeprimidos hasta que las lesiones estén en fase de costra seca.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // PRESCRIPCIONES ADICIONALES 2 (Frecuentes en Guardia/Consultorio Argentina)
  // ══════════════════════════════════════════════════════════════════════════

  _PrescriptionModel(
    id: 'esguince_tobillo_traumatismo',
    title: 'Esguince de Tobillo / Traumatismo Leve',
    subtitle: 'Protocolo RICE + AINEs (Diclofenac/Ibuprofeno)',
    category: 'Osteomuscular',
    icon: Icons.personal_injury_rounded,
    content: '''Uso Oral:
1. Ibuprofeno 600 mg o Diclofenac 50 mg
   Tomar 1 comp vía oral cada 8h (siempre con las comidas) por 5 a 7 días.

Uso Tópico:
2. Diclofenac gel 1% (ej. Oxa® Gel / Dioxaflex®)
   Aplicar una fina capa en la zona afectada 3 veces al día.

Indicaciones Físicas (RICE):
→ Reposo: evitar el apoyo del pie las primeras 48h (usar muletas si es necesario).
→ Ice (Hielo): aplicar hielo envuelto en un paño por 15-20 min, cada 4 horas.
→ Compresión: vendaje elástico tipo "ocho" (no muy ajustado).
→ Elevación: mantener el pie elevado por encima del nivel del corazón al estar acostado o sentado.''',
  ),

  _PrescriptionModel(
    id: 'absceso_odontologico_flemon',
    title: 'Absceso Odontológico / Flemón',
    subtitle: 'Amoxicilina-Clavulánico (Optamox) + Analgesia',
    category: 'Odontología / Clínica',
    icon: Icons.face_rounded,
    content: '''Uso Oral:
1. Amoxicilina + Ácido Clavulánico 875/125 mg (ej. Optamox® / Amoxiclav®)
   Tomar 1 comp vía oral cada 12h por 7 días.
   (Alérgicos a penicilina: Clindamicina 300 mg cada 8h).

2. Ketorolac 10 mg Sublingual (ej. Sinalgico® / Dómina®)
   Dejar disolver 1 comp debajo de la lengua cada 8h en caso de dolor intenso (máximo 5 días).

Guardia:
1. Diclofenac 75 mg IM + Dexametasona 4 mg IM.
→ Derivar de urgencia al odontólogo para drenaje o tratamiento de conducto.''',
  ),

  _PrescriptionModel(
    id: 'lumbociatalgia_aguda_complejob',
    title: 'Lumbociatalgia Aguda / Ciática',
    subtitle: 'Diclofenac + Betametasona + Vit. B12 (Blokium B12)',
    category: 'Osteomuscular',
    icon: Icons.accessibility_rounded,
    content: '''Uso Oral:
1. Diclofenac 50 mg + Betametasona + Vit. B12 (ej. Dioxaflex B12® / Blokium B12®)
   Tomar 1 comp vía oral cada 12h por 3 a 5 días (luego continuar solo con AINE sin corticoide).

2. Pregabalina 75 mg (opcional si hay fuerte dolor neuropático)
   Tomar 1 comp por la noche.

Guardia (Crisis muy dolorosa):
1. Inyectable combinado (ej. Dioxaflex B12 ampolla o Nervobión®) intramuscular profundo.
→ Indicar reposo relativo en posición fetal o con almohada debajo de las rodillas.
→ Calor local a partir de las 48h.''',
  ),

  _PrescriptionModel(
    id: 'sindrome_intestino_irritable',
    title: 'Síndrome de Intestino Irritable (SII)',
    subtitle: 'Trimebutina + Simeticona (Miropen / Eumotil)',
    category: 'Gastroenterología',
    icon: Icons.medical_services_rounded,
    content: '''Uso Oral:
1. Trimebutina 200 mg + Simeticona 120 mg (ej. Miropen® / Eumotil® / Plidex®)
   Tomar 1 comp vía oral 20 a 30 minutos ANTES del almuerzo y la cena, por 15 a 30 días.

Indicaciones:
→ Evitar bebidas gaseosas, mate en exceso, café, fritos y picantes.
→ Derivar a Gastroenterología si hay "banderas rojas" (sangrado, pérdida de peso, anemia, edad >50 sin colonoscopía previa).''',
  ),

  _PrescriptionModel(
    id: 'conjuntivitis_alergica',
    title: 'Conjuntivitis Alérgica',
    subtitle: 'Olopatadina (Patanol) + Lágrimas',
    category: 'Oftalmología',
    icon: Icons.visibility_rounded,
    content: '''Uso Oftalmológico:
1. Olopatadina 0,1% o 0,2% (ej. Patanol® / Olopat®)
   Instilar 1 gota en cada ojo afectado cada 12h (o 1 vez al día si es 0,2%), durante 7 a 14 días.

2. Lágrimas Artificiales (Hialuronato de Sodio)
   Instilar 1 gota en cada ojo 3 a 4 veces al día (preferentemente frías de la heladera, alivia el prurito).

Medidas Generales:
→ No frotarse los ojos (empeora el cuadro).
→ Aplicar compresas frías limpias cerrando los ojos por 10 minutos.
→ Evitar exposición al polvo, polen o alérgenos conocidos.''',
  ),

  _PrescriptionModel(
    id: 'onicocriptosis_una_encarnada',
    title: 'Onicocriptosis (Uña Encarnada) Infectada',
    subtitle: 'Cefalexina + Baños con Pervinox',
    category: 'Dermatología',
    icon: Icons.healing_rounded,
    content: '''Uso Oral:
1. Cefalexina 500 mg
   Tomar 1 comp vía oral cada 6h por 7 días.

2. Ibuprofeno 400 mg
   Tomar 1 comp vía oral cada 8h para alivio del dolor e inflamación.

Medidas Locales:
3. Povidona Yodada (ej. Pervinox®)
   Realizar baños de pie ("pediluvio"): colocar agua tibia en un recipiente, agregar un chorrito de Pervinox y sumergir el pie por 15 minutos, 2 veces al día.
   Secar muy bien y no usar calzado ajustado.

Guardia:
→ Derivar a podología o cirugía general para matricectomía / extirpación de espícula si el cuadro es severo.''',
  ),

  _PrescriptionModel(
    id: 'dolor_odontologico_pulpitis',
    title: 'Dolor Odontológico Agudo (Pulpitis)',
    subtitle: 'Ketorolac SL + Paracetamol',
    category: 'Odontología / Clínica',
    icon: Icons.face_rounded,
    content: '''Uso Oral:
1. Ketorolac 10 mg Sublingual (ej. Sinalgico® / Dómina®)
   Dejar disolver 1 comp debajo de la lengua cada 8h en caso de dolor punzante/pulsátil (máximo 5 días).

2. Paracetamol 1 g (o Ibuprofeno 600 mg)
   Tomar 1 comp vía oral alternando con el Ketorolac (cada 8h) para mantener ventana analgésica estable.

Guardia:
1. Dipirona 1 g IM + Ketorolac 30 mg IM (si el dolor no cede).
→ El dolor pulpar no se cura con analgésicos, requiere derivación odontológica urgente para apertura de la pieza dentaria.''',
  ),

  _PrescriptionModel(
    id: 'tendinitis_hombro_codo',
    title: 'Tendinitis / Bursitis (Hombro/Codo)',
    subtitle: 'Etoricoxib (Arcoxia) o Diclofenac + Hielo',
    category: 'Osteomuscular',
    icon: Icons.accessibility_new_rounded,
    content: '''Uso Oral:
1. Etoricoxib 90 mg (ej. Arcoxia®) o Meloxicam 15 mg
   Tomar 1 comp vía oral 1 vez al día (por la mañana), durante 7 días.
   (Etoricoxib protege estómago pero se debe evitar en HTA severa o cardiópatas).

Uso Tópico:
2. Diclofenac gel 1%
   Aplicar en la zona dolorosa 2 veces al día.

Indicaciones:
→ Aplicar hielo 15 min, 3 veces al día.
→ Evitar el movimiento que desencadenó el dolor (suspender actividad deportiva temporalmente).
→ Solicitar Ecografía articular y derivar a Traumatología / Kinesiología.''',
  ),

  _PrescriptionModel(
    id: 'candidiasis_oral_muguet',
    title: 'Candidiasis Oral (Muguet)',
    subtitle: 'Nistatina suspensión (Micostatin)',
    category: 'Infectología / Pediatría',
    icon: Icons.coronavirus_rounded,
    content: '''Uso Tópico Bucal:
1. Nistatina Suspensión Oral 100.000 UI/mL (ej. Micostatin®)
   - Adultos: 5 mL (1 cucharita) cada 6h. Hacer buches, retener en la boca el mayor tiempo posible y luego tragar.
   - Lactantes/Niños: 2 mL (con jeringa o gotero) esparciendo por las paredes de la boca y encías, cada 6h, después de amamantar o comer.
   Continuar por 7 a 14 días (y hasta 48h después de la curación clínica).

Indicaciones en lactantes:
→ Si el bebé amamanta, la madre debe tratar sus pezones con crema de Miconazol (limpiar antes de la toma).
→ Hervir tetinas y chupetes.''',
  ),

  _PrescriptionModel(
    id: 'cinetosis_mareo_viaje',
    title: 'Mareo por Cinetosis (Viajes)',
    subtitle: 'Dimenhidrinato (Dramamine)',
    category: 'Neurología / Clínica',
    icon: Icons.directions_car_rounded,
    content: '''Uso Oral:
1. Dimenhidrinato 50 mg (ej. Dramamine®)
   Tomar 1 comp vía oral 30 a 60 minutos antes de iniciar el viaje.
   Repetir 1 comp cada 6 a 8 horas durante el viaje si es necesario.

(En niños >2 años, se usan gotas o jarabe pediátrico según peso, habitualmente 1,25 mg/kg por dosis).

Precauciones:
→ Produce somnolencia marcada (no conducir vehículos si se toma la medicación).
→ Evitar lectura o usar pantallas durante el trayecto. Mirar al horizonte.''',
  ),

  _PrescriptionModel(
    id: 'dispepsia_indigestion_biliar',
    title: 'Dispepsia Biliar / Indigestión ("Ataque al hígado")',
    subtitle: 'Domperidona (Peridon) + Dieta Hepatoprotectora',
    category: 'Gastroenterología',
    icon: Icons.restaurant_menu_rounded,
    content: '''Uso Oral:
1. Domperidona 10 mg (ej. Peridon® / Moperidona®)
   Tomar 1 comp vía oral 20 minutos ANTES del almuerzo y la cena, por 3 a 5 días.

2. Omeprazol 20 mg (Opcional, si hay acidez asociada)
   Tomar 1 comp vía oral en ayunas.

Dieta Hepatoprotectora Estricta:
→ Evitar fritos, grasas, manteca, quesos duros, fiambres.
→ Evitar mate, café, chocolate y alcohol.
→ Consumir pollo hervido, zapallo, arroz, manzana rallada, caldos desgrasados.''',
  ),

  _PrescriptionModel(
    id: 'acne_inflamatorio_leve',
    title: 'Acné Inflamatorio Leve a Moderado',
    subtitle: 'Peróxido de Benzoílo / Adapaleno',
    category: 'Dermatología',
    icon: Icons.face_retouching_natural_rounded,
    content: '''Uso Tópico:
1. Peróxido de Benzoílo gel 5% (ej. Benzac AC® / Cupex®) o Adapaleno 0.1%
   Aplicar una fina capa (tamaño de una arveja para toda la cara) ÚNICAMENTE por las noches sobre las lesiones.
   (Advertir: Mancha/destiñe la ropa de cama y toallas).

2. Jabón/Gel limpiador para pieles acneicas
   Lavar el rostro por la mañana y por la noche.

Precauciones:
→ Lavar el rostro por la mañana para retirar el producto nocturno.
→ Uso obligatorio de Protector Solar FPS >30 (no comedogénico) durante el día.
→ Derivar a Dermatología si no hay respuesta en 6-8 semanas o hay riesgo de cicatrices.''',
  ),

  _PrescriptionModel(
    id: 'vppb_vertigo_posicional',
    title: 'Vértigo Posicional (VPPB)',
    subtitle: 'Betahistina (Meniex) + Maniobra de Epley',
    category: 'Neurología / ORL',
    icon: Icons.rotate_right_rounded,
    content: '''Tratamiento Físico (Guardia / Consultorio):
1. Realizar Maniobra de Epley o Semont en la camilla (es el tratamiento curativo de elección para el VPPB).

Uso Oral (Sintomático y mantenimiento):
2. Betahistina 16 mg o 24 mg (ej. Meniex® / Microser®)
   Tomar 1 comp vía oral cada 12h, con las comidas, por 15 a 30 días.

3. Dimenhidrinato 50 mg (Opcional, como rescate)
   Tomar 1 comp solo si hay náuseas o mareo muy inhabilitante al inicio.

Indicaciones:
→ Evitar dormir del lado afectado.
→ Levantarse de la cama de forma muy lenta.
→ Derivar a ORL o Neurología Clínica si no resuelve.''',
  ),

  _PrescriptionModel(
    id: 'itu_embarazada',
    title: 'Infección Urinaria en Embarazada',
    subtitle: 'Cefalexina 500 mg (Antibiótico seguro)',
    category: 'Obstetricia / Infectología',
    icon: Icons.pregnant_woman_rounded,
    content: '''Uso Oral:
1. Cefalexina 500 mg
   Tomar 1 comp vía oral cada 6h por 7 días.
   (Categoría B en el embarazo, es totalmente seguro).

2. Paracetamol 500 mg
   Tomar 1 comp vía oral cada 8h en caso de fiebre o dolor lumbar leve.

Conducta Obligatoria:
→ Solicitar Urocultivo + Antibiograma ANTES de iniciar el antibiótico empírico (vital en obstetricia).
→ Aumentar la ingesta de agua (>2 litros/día).
→ Control urgente por obstetricia si presenta fiebre alta, dolor lumbar intenso o contracciones uterinas.''',
  ),

  _PrescriptionModel(
    id: 'hipo_persistente_singulto',
    title: 'Hipo Persistente (Singulto)',
    subtitle: 'Metoclopramida o Clorpromazina',
    category: 'Gastroenterología / Clínica',
    icon: Icons.air_rounded,
    content: '''Medidas Físicas:
1. Estimulación vagal: Retener la respiración (apnea voluntaria), beber un vaso de agua fría rápidamente, o respirar en una bolsa de papel.

Uso Oral (Si dura >48h o agota al paciente):
2. Metoclopramida 10 mg
   Tomar 1 comp vía oral cada 8h.

3. Baclofeno 10 mg o Clorpromazina 25 mg (2da línea, si falla lo anterior)
   Tomar 1 comp vía oral cada 8h.

Guardia:
1. Metoclopramida 10 mg IM o EV lento.
→ Descartar causas graves si es refractario (uremia, ACV, tumores, reflujo severo, IAM inferior).''',
  ),

  _PrescriptionModel(
    id: 'trombosis_hemorroidal_externa',
    title: 'Trombosis Hemorroidal Externa',
    subtitle: 'Daflon dosis ataque + Cirugía local',
    category: 'Proctología',
    icon: Icons.healing_rounded,
    content: '''Uso Tópico / Físico:
1. Hielo local
   Aplicar compresas frías en la región anal por 10 minutos, 3 veces al día (disminuye el edema y el dolor agudo).

Uso Oral:
2. Diosmina + Hesperidina 500 mg (ej. Daflon®)
   Dosis de ataque: Tomar 2 comp cada 8h por 4 días → luego 2 comp cada 12h por 3 días.
3. Diclofenac 50 mg o Ketorolac 10 mg
   Tomar 1 comp vía oral cada 8h para el dolor intenso.
4. Lactulosa 15 mL cada 12h (evitar constipación).

Guardia:
→ Si la trombosis tiene < 72h y el dolor es extremo: Incisión y drenaje bajo anestesia local en la guardia (cirugía menor) alivia inmediatamente el dolor.''',
  ),

  _PrescriptionModel(
    id: 'dermatitis_panal',
    title: 'Dermatitis del Pañal',
    subtitle: 'Pasta al agua / Óxido de Zinc (Hipoglós)',
    category: 'Pediatría / Dermatología',
    icon: Icons.child_friendly_rounded,
    content: '''Cuidados e Higiene (Fundamental):
1. Cambio frecuente de pañal.
2. Limpiar la zona con algodón y óleo calcáreo o agua tibia. EVITAR las toallitas húmedas perfumadas.
3. Dejar al bebé sin pañal (al aire) el mayor tiempo posible.

Uso Tópico:
4. Pomada protectora con Óxido de Zinc y Vitamina A (ej. Hipoglós® / Pasta al agua)
   Aplicar una capa gruesa ("efecto revoque") en la zona del pañal en cada cambio.

Si hay sospecha de sobreinfección por Cándida (lesiones rojo brillante, bordes netos, lesiones satélites):
5. Miconazol crema o Nistatina ungüento
   Aplicar una fina capa 2 veces al día por 7 días, debajo de la pasta protectora.''',
  ),

  _PrescriptionModel(
    id: 'golpe_de_calor_agotamiento',
    title: 'Golpe de Calor / Agotamiento por Calor',
    subtitle: 'SRO + Enfriamiento + Paracetamol',
    category: 'Urgencias',
    icon: Icons.wb_sunny_rounded,
    content: '''Medidas Físicas y Ambulatorias:
1. Reposo absoluto en ambiente fresco, ventilado o con aire acondicionado.
2. Aplicar paños de agua fría en axilas, ingles y nuca.
3. Ropa holgada y ligera.

Rehidratación Oral:
4. Sales de Rehidratación Oral (SRO) o bebidas deportivas (ej. Gatorade® diluido a la mitad con agua).
   Ingerir líquidos de a pequeños sorbos, continuo, hasta calmar la sed.

Uso Oral:
5. Paracetamol 500 mg
   Tomar 1 comp vía oral cada 8h si hay cefalea o fiebre.
   (EVITAR AINEs como Ibuprofeno o Diclofenac, ya que en cuadros de deshidratación severa pueden precipitar insuficiencia renal aguda).

Guardia:
→ Si presenta alteración del estado de conciencia, vómitos incoercibles o no suda: Vía EV con Solución Fisiológica e internación (emergencia).''',
  ),

  _PrescriptionModel(
    id: 'ojo_seco_fatiga_visual',
    title: 'Ojo Seco / Fatiga Visual',
    subtitle: 'Lágrimas con Hialuronato (Hyabak)',
    category: 'Oftalmología',
    icon: Icons.visibility_rounded,
    content: '''Uso Oftalmológico:
1. Lágrimas Artificiales con Hialuronato de Sodio (ej. Hyabak® / Systane®)
   Instilar 1 gota en cada ojo 4 a 6 veces al día, según necesidad y sensación de cuerpo extraño/arenilla.

Medidas de Higiene Visual:
→ Regla 20-20-20: cada 20 minutos de uso de pantallas, desviar la mirada a 20 pies (6 metros) de distancia, durante 20 segundos.
→ Evitar la exposición directa a ventiladores o aire acondicionado.
→ Parpadear conscientemente al usar la computadora o celular.''',
  ),

  _PrescriptionModel(
    id: 'pitiriasis_versicolor_micose',
    title: 'Pitiriasis Versicolor',
    subtitle: 'Ketoconazol Shampoo + Fluconazol',
    category: 'Dermatología',
    icon: Icons.spa_rounded,
    content: '''Uso Tópico:
1. Ketoconazol Shampoo 2% (ej. Eumicel® / Micoral®)
   Utilizar como "jabón" líquido en la ducha sobre el pecho, espalda y áreas afectadas.
   Hacer espuma, dejar actuar 5 a 10 minutos y luego enjuagar.
   Realizar esto todos los días por 14 días.

Uso Oral (Si las lesiones son muy extensas o recurrentes):
2. Fluconazol 150 mg
   Tomar 2 cápsulas juntas (300 mg) como DOSIS ÚNICA. Repetir la misma dosis a los 7 días.
   (Alternativa: Itraconazol 200 mg/día por 7 días).

Educación al paciente:
→ Aclarar que el hongo muere rápido, pero las "manchas" blancas pueden tardar semanas o meses en volver a pigmentar con la exposición solar normal.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // PRESCRIPCIONES ADICIONALES 3 (Nuevas - Guardia/Consultorio Argentina)
  // ══════════════════════════════════════════════════════════════════════════

  _PrescriptionModel(
    id: 'flujo_vaginal_mixto',
    title: 'Flujo Vaginal Mixto / Vulvovaginitis',
    subtitle: 'Óvulos polivalentes (Ovumix / Tricomicon)',
    category: 'Ginecología',
    icon: Icons.spa_rounded,
    content: '''Uso Intravaginal:
1. Metronidazol + Miconazol + Neomicina + Centella (ej. Ovumix® / Tricomicon®)
   Colocar 1 óvulo profundamente en la vagina, por la noche antes de acostarse, durante 6 días consecutivos.

Uso Tópico Vulvar (Si hay mucha irritación externa):
2. Crema asociada (misma marca que los óvulos o Macril®)
   Aplicar una fina capa en la zona vulvar externa, 2 veces al día por 5 días.

Indicaciones:
→ Continuar el tratamiento aunque inicie el período menstrual.
→ Evitar relaciones sexuales hasta finalizar el tratamiento.
→ No realizar duchas vaginales.''',
  ),

  _PrescriptionModel(
    id: 'orzuelo_chalazion',
    title: 'Orzuelo / Chalazión',
    subtitle: 'Tobramicina+Dexametasona ungüento + Calor',
    category: 'Oftalmología',
    icon: Icons.visibility_rounded,
    content: '''Tratamiento Físico (Fundamental):
1. Compresas calientes
   Aplicar un paño limpio embebido en agua caliente (tolerable) sobre el ojo cerrado durante 10 a 15 minutos, 3 o 4 veces al día. (Ayuda a drenar la glándula obstruida).

Uso Oftalmológico:
2. Tobramicina + Dexametasona ungüento (ej. TobaDex® / Poenbioptal®)
   Aplicar una pequeña cantidad (tira de medio centímetro) en el borde del párpado afectado o fondo de saco, cada 8 horas, por 5 a 7 días.

Guardia:
→ Explicar que NUNCA debe apretarse ni "reventarse" el orzuelo.
→ Si no resuelve en 2 semanas o se enquista (chalazión), derivar a Oftalmología para eventual drenaje quirúrgico.''',
  ),

  _PrescriptionModel(
    id: 'tec_leve_pautas',
    title: 'Traumatismo de Cráneo (TEC) Leve',
    subtitle: 'Analgesia y Pautas de Alarma (Guardia)',
    category: 'Urgencias',
    icon: Icons.personal_injury_rounded,
    content: '''Uso Oral:
1. Ibuprofeno 400 mg o Paracetamol 500 mg
   Tomar 1 comp vía oral cada 8h en caso de cefalea leve.
   (Evitar analgésicos más fuertes o sedantes que puedan enmascarar síntomas neurológicos).

Pautas de Alarma Escritas (Entregar al paciente/familiar):
Consultar INMEDIATAMENTE por Guardia si presenta en las próximas 48h:
→ Vómitos explosivos o a repetición (más de 2).
→ Somnolencia excesiva o dificultad para despertarlo.
→ Dolor de cabeza intenso que no cede con analgésicos.
→ Alteración en el habla, debilidad en un brazo o pierna.
→ Convulsiones o movimientos anormales.
→ Sangrado o salida de líquido claro por nariz u oídos.

(Despertar al paciente cada 3-4 horas durante la primera noche para comprobar que responde con normalidad).''',
  ),

  _PrescriptionModel(
    id: 'bruxismo_atm',
    title: 'Bruxismo / Disfunción de ATM',
    subtitle: 'Miorrelajantes nocturnos + Calor local',
    category: 'Odontología / Clínica',
    icon: Icons.face_retouching_natural_rounded,
    content: '''Uso Oral:
1. Diclofenac 50 mg + Pridinol 4 mg (ej. Dioxaflex Plus® / Blokium Flex®)
   Tomar 1 comp vía oral por la noche, luego de la cena, por 5 días. (El miorrelajante ayudará a disminuir la tensión maseterina durante el sueño).

Medidas Locales:
2. Calor húmedo local
   Aplicar compresas tibias en la zona de las mandíbulas (delante de los oídos) durante 15 minutos antes de dormir.
3. Dieta blanda
   Evitar masticar chicle, comer frutos secos, carnes duras o sándwiches grandes por 7 días.

Derivación:
→ Solicitar interconsulta con Odontología para confección de Placa de Descanso (Miorelajante) rígida.''',
  ),

  _PrescriptionModel(
    id: 'rinitis_alergica_estacional',
    title: 'Rinitis Alérgica Estacional',
    subtitle: 'Mometasona spray + Levocetirizina',
    category: 'Otorrinolaringología',
    icon: Icons.air_rounded,
    content: '''Uso Intranasal (Eje del tratamiento):
1. Mometasona Furoato spray nasal 50 mcg (ej. Hexaler Nasal® / Nasonex®)
   Aplicar 2 "puffs" en cada fosa nasal 1 vez al día (por la mañana), durante 15 a 30 días.
   (Explicar técnica: apuntar hacia la oreja del mismo lado, no hacia el tabique).

Uso Oral:
2. Levocetirizina 5 mg o Desloratadina 5 mg
   Tomar 1 comp vía oral 1 vez al día (preferentemente a la noche), durante 10 días o mientras duren los síntomas severos (prurito, estornudos en salva).

Medidas Ambientales:
→ Ventilar ambientes al mediodía, evitar alfombras y peluches, no barrer (usar trapo húmedo).''',
  ),

  _PrescriptionModel(
    id: 'parasitosis_intestinal_empirica',
    title: 'Parasitosis Intestinal (Giardiasis / Amebiasis)',
    subtitle: 'Nitazoxanida o Secnidazol',
    category: 'Infectología',
    icon: Icons.bug_report_rounded,
    content: '''Uso Oral (Opción 1 - Corta duración):
1. Secnidazol 500 mg (ej. Secnidal®)
   Tomar 4 comprimidos JUNTOS (Total 2 gramos) como DOSIS ÚNICA.
   (Tomar preferentemente con la cena. NO consumir alcohol por 48h).

Uso Oral (Opción 2 - Amplio espectro):
2. Nitazoxanida 500 mg (ej. Nizonide®)
   Tomar 1 comp vía oral cada 12h, con las comidas, por 3 días.
   (Advertir al paciente que la orina puede teñirse de color amarillo verdoso fluorescente, es normal).

Medidas Higiénico-Dietéticas:
→ Lavado estricto de manos antes de comer y después de ir al baño.
→ Consumir agua hervida o embotellada si no hay red segura.
→ Lavar minuciosamente frutas y verduras frescas.''',
  ),

  _PrescriptionModel(
    id: 'foliculitis_leve',
    title: 'Foliculitis Leve / Infección del Vello',
    subtitle: 'Jabón Antiséptico + Mupirocina',
    category: 'Dermatología',
    icon: Icons.healing_rounded,
    content: '''Uso Tópico / Higiene:
1. Jabón de Clorhexidina al 4% o Jabón de Glicerina
   Lavar la zona afectada durante el baño diario, dejar actuar 2 minutos y enjuagar.

2. Mupirocina 2% ungüento o crema (ej. Mupirox® / Bactroban®)
   Aplicar una fina capa sobre las lesiones (pústulas) 2 a 3 veces al día, por 7 días.

Precauciones:
→ Suspender temporalmente la depilación (cera o rasuradora) en la zona afectada hasta la curación total.
→ Usar ropa holgada de algodón para evitar la fricción.
→ Si presenta fiebre, celulitis circundante o forúnculo mayor, rotar a Cefalexina vía oral.''',
  ),

  _PrescriptionModel(
    id: 'bursitis_trocanterea_cadera',
    title: 'Bursitis Trocantérea (Dolor de Cadera)',
    subtitle: 'AINEs + Reposo + Kinesiología',
    category: 'Osteomuscular',
    icon: Icons.directions_walk_rounded,
    content: '''Uso Oral:
1. Naproxeno 500 mg o Diclofenac 75 mg
   Tomar 1 comp vía oral cada 12h, siempre con el estómago lleno, por 7 a 10 días.

Uso Tópico:
2. Hielo local
   Aplicar hielo envuelto en la cara lateral de la cadera por 15 minutos, 3 veces al día.

Indicaciones:
→ Evitar dormir sobre el lado afectado. Colocar un cojín entre las rodillas si duerme de lado.
→ Evitar largas caminatas, subir escaleras o estar mucho tiempo de pie.
→ Derivar a Traumatología para indicar Fisioterapia/Kinesiología (elongación de banda iliotibial) o eventual infiltración con corticoides si no cede.''',
  ),

  _PrescriptionModel(
    id: 'dermatitis_atopica_eccema',
    title: 'Eccema / Dermatitis Atópica (Brote)',
    subtitle: 'Corticoide Tópico (Novacort) + Emolientes',
    category: 'Dermatología',
    icon: Icons.face_retouching_natural_rounded,
    content: '''Uso Tópico (Para el brote agudo inflamatorio):
1. Betametasona crema 0,1% (ej. Novacort® / Beta Micoter®)
   Aplicar una fina capa SOLO sobre las placas rojas y pruriginosas, 1 vez al día (de noche) por un MÁXIMO de 5 a 7 días.

Uso Tópico (Mantenimiento diario fundamental):
2. Crema Emoliente sin perfume (ej. Dermaglós® / Cetaphil® / Bagóvit A)
   Aplicar en todo el cuerpo, especialmente después del baño (con la piel aún húmeda) al menos 2 veces al día, de forma indefinida.

Uso Oral (Si el prurito interfiere con el sueño):
3. Hidroxicina 25 mg o Difenhidramina 50 mg
   Tomar 1 comp a la noche, por 5 días.

Recomendaciones:
→ Baños cortos (menos de 10 min) con agua tibia, no caliente.
→ Usar jabones "Syndet" o de glicerina neutra solo en zonas de olor.''',
  ),

  _PrescriptionModel(
    id: 'hpb_sintomatica',
    title: 'Hiperplasia Prostática Benigna (Síntomas Leves/Mod)',
    subtitle: 'Tamsulosina (Secotex)',
    category: 'Urología',
    icon: Icons.wc_rounded,
    content: '''Uso Oral:
1. Tamsulosina 0.4 mg (ej. Secotex® / Omnic®)
   Tomar 1 comp (o cápsula de liberación prolongada) vía oral 1 vez al día, SIEMPRE unos 30 minutos después de la cena.
   (Advertir: Puede causar hipotensión ortostática al inicio, mareos al levantarse rápido, o eyaculación retrógrada).

Indicaciones Generales:
→ Evitar la ingesta abundante de líquidos después de las 19:00 hs para reducir la nocturia.
→ Evitar café, alcohol y picantes.
→ Derivar a Urología para control de PSA, tacto rectal y ecografía vesicoprostática con residuo post-miccional.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // PRESCRIPCIONES ADICIONALES 4 (Nuevas - Guardia/Consultorio Argentina)
  // ══════════════════════════════════════════════════════════════════════════

  _PrescriptionModel(
    id: 'artrosis_osteoartritis',
    title: 'Artrosis / Osteoartritis (Rodilla/Cadera)',
    subtitle: 'Paracetamol + Meloxicam + Medidas físicas',
    category: 'Osteomuscular',
    icon: Icons.accessible_forward_rounded,
    content: '''Uso Oral:
1. Paracetamol 1 g (ej. Tafirol Forte®)
   Tomar 1 comp vía oral cada 8h en caso de dolor leve a moderado.

2. Meloxicam 15 mg (ej. Mobic® / Tenaron®)
   Tomar 1 comp vía oral 1 vez al día (por la mañana, después del desayuno) por un MÁXIMO de 7 a 10 días para los empujes inflamatorios agudos.

Medidas Físico-Dietéticas:
→ Control de peso (fundamental para articulaciones de carga).
→ Ejercicio de bajo impacto (natación, bicicleta fija, caminata en agua).
→ Calor local seco (almohadilla térmica) 15 minutos, 2 veces al día para aliviar rigidez matinal.''',
  ),

  _PrescriptionModel(
    id: 'fisura_anal_aguda',
    title: 'Fisura Anal Aguda',
    subtitle: 'Lidocaína/Hidrocortisona + Baños de asiento',
    category: 'Proctología',
    icon: Icons.medical_services_rounded,
    content: '''Uso Tópico / Físico:
1. Pomada de Lidocaína + Hidrocortisona (ej. Xyloprocto®)
   Aplicar una pequeña cantidad en el margen anal, 2 a 3 veces al día, especialmente después de evacuar y antes de dormir, por 7 días.

2. Baños de asiento
   Sumergir la zona anal en agua tibia (agradable, no caliente) durante 10 a 15 minutos, 3 veces al día (relaja el esfínter y mejora el dolor).

Uso Oral (Para evitar constipación):
3. Lactulosa (ej. Someral® / Tenual®)
   Tomar 15 mL vía oral por la noche.
   Aumentar la ingesta de fibra (frutas, verduras) y agua (mínimo 2 litros/día).

(Nota: Si la fisura se vuelve crónica, derivar a proctología para tratamiento con Diltiazem gel o toxina botulínica).''',
  ),

  _PrescriptionModel(
    id: 'rosacea_brote',
    title: 'Rosácea (Brote Pápulo-pustuloso)',
    subtitle: 'Metronidazol gel + Fotoprotección',
    category: 'Dermatología',
    icon: Icons.face_retouching_natural_rounded,
    content: '''Uso Tópico:
1. Metronidazol 0.75% gel o crema (ej. Rozex®)
   Aplicar una fina capa en todo el rostro (evitando el contorno de ojos), 1 vez al día por la noche, durante 4 a 8 semanas.

2. Protector Solar Facial FPS 50+ (Pieles sensibles o con tendencia a rosácea)
   Aplicar todas las mañanas y reaplicar cada 3 horas durante el día.

Medidas Generales:
→ Evitar desencadenantes: exposición al sol sin protección, cambios bruscos de temperatura, duchas muy calientes.
→ Evitar comidas muy picantes, especiadas, y el consumo de alcohol.
→ Usar limpiadores faciales suaves ("Syndet") sin frotar con toalla.''',
  ),

  _PrescriptionModel(
    id: 'larva_migrans_cutanea',
    title: 'Larva Migrans Cutánea (Bicho Geográfico)',
    subtitle: 'Ivermectina dosis única',
    category: 'Dermatología / Infectología',
    icon: Icons.pest_control_rounded,
    content: '''Uso Oral:
1. Ivermectina 6 mg (ej. Securo®)
   Tomar 2 comprimidos (12 mg, calculando 200 mcg/kg para un adulto de 60 kg) JUNTOS como DOSIS ÚNICA.
   (En casos de múltiples trayectos o resistencia, se puede repetir la misma dosis al día siguiente).

Uso Tópico (Opcional, si hay mucho prurito):
2. Betametasona crema 0.1%
   Aplicar sobre el trayecto de la larva 2 veces al día por 3 a 5 días para desinflamar.

(Nota: Frecuente tras viajes a playas en el norte argentino o Brasil, por contacto con arena contaminada con heces de perros/gatos).''',
  ),

  _PrescriptionModel(
    id: 'verrugas_vulgares_plantares',
    title: 'Verrugas Vulgares / Plantares',
    subtitle: 'Ácido Salicílico + Láctico (Verruclean)',
    category: 'Dermatología',
    icon: Icons.healing_rounded,
    content: '''Uso Tópico:
1. Ácido Salicílico 27% + Ácido Láctico (ej. Verruclean® / Colloplus®)
   Aplicar EXACTAMENTE sobre la verruga con el pincel aplicador, 1 vez al día (por la noche), durante 4 a 6 semanas.

Procedimiento de aplicación (Explicar al paciente):
→ Antes de aplicar: remojar la zona en agua tibia por 5 minutos y secar.
→ Proteger la piel sana de alrededor con vaselina sólida o esmalte transparente.
→ Aplicar el producto, dejar secar.
→ A la noche siguiente, retirar la "telita" blanca que se forma, limar suavemente con piedra pómez o lima de cartón desechable y volver a aplicar.

(Derivar a Dermatología para crioterapia si no hay respuesta).''',
  ),

  _PrescriptionModel(
    id: 'vaginitis_atrofica_menopausia',
    title: 'Vaginitis Atrófica (Menopausia)',
    subtitle: 'Estriol tópico (Colpotrofin)',
    category: 'Ginecología',
    icon: Icons.spa_rounded,
    content: '''Uso Intravaginal / Tópico:
1. Promestriene o Estriol crema 1 mg/g (ej. Colpotrofin® / Ovestin®)
   Aplicar 1 aplicador lleno profundamente en la vagina, por la noche, todos los días durante 2 a 3 semanas.
   Mantenimiento: Aplicar 1 aplicador, 2 veces por semana.

Medidas Coadyuvantes:
2. Gel lubricante íntimo a base de agua o ácido hialurónico (ej. K-Y Gel® / Evagina®)
   Utilizar a demanda, especialmente previo a las relaciones sexuales para evitar dispareunia.

(Nota: Descartar contraindicaciones hormonales, como antecedentes de cáncer de mama hormonodependiente, antes de indicar estrógenos locales).''',
  ),

  _PrescriptionModel(
    id: 'fibromialgia_dolor_cronico',
    title: 'Fibromialgia (Dolor Crónico y Fatiga)',
    subtitle: 'Pregabalina + Duloxetina',
    category: 'Clínica Médica / Reumatología',
    icon: Icons.accessibility_rounded,
    content: '''Uso Oral (Titulación progresiva):
1. Pregabalina 75 mg (ej. Plenica® / Lyrica®)
   Tomar 1 cápsula por la noche durante 1 semana.
   Si lo tolera, aumentar a 1 cápsula a la mañana y 1 a la noche (150 mg/día).

2. Duloxetina 30 mg (ej. Duxetin® / Cymbalta®) - Adyuvante antidepresivo/analgésico
   Tomar 1 cápsula por la mañana (después del desayuno).

Pilares No Farmacológicos (Indispensables):
→ Higiene del sueño (evitar pantallas 1 hora antes de dormir).
→ Actividad física aeróbica graduada (comenzar con 15 minutos de caminata o yoga, e ir subiendo lentamente).
→ Apoyo psicoterapéutico.''',
  ),

  _PrescriptionModel(
    id: 'gingivitis_enfermedad_periodontal',
    title: 'Gingivitis / Sangrado de Encías',
    subtitle: 'Clorhexidina colutorio + Técnicas de cepillado',
    category: 'Odontología',
    icon: Icons.face_rounded,
    content: '''Uso Bucal (Tópico):
1. Clorhexidina 0.12% Colutorio (ej. Plac-Out®)
   Realizar buches con 15 mL (sin diluir) durante 1 minuto, 2 veces al día (mañana y noche, media hora DESPUÉS del cepillado dental).
   No enjuagar con agua después del buche.
   Utilizar por un máximo de 10 a 14 días (el uso prolongado mancha los dientes de forma reversible y altera el gusto).

Conducta / Prevención:
→ Usar cepillo de cerdas SUAVES.
→ Incorporar el uso diario de hilo dental o cepillos interdentales.
→ Derivar al Odontólogo para limpieza por ultrasonido (tartrectomía), ya que la medicación no elimina el sarro endurecido.''',
  ),

  _PrescriptionModel(
    id: 'caida_cabello_efluvio_telogeno',
    title: 'Caída de Cabello (Efluvio Telógeno)',
    subtitle: 'Minoxidil loción + Suplementos',
    category: 'Dermatología',
    icon: Icons.face_retouching_natural_rounded,
    content: '''Uso Tópico:
1. Minoxidil 5% loción capilar (ej. Ylox® / Anagen®)
   Aplicar 1 mL (o 6 a 8 pulverizaciones) directamente sobre el cuero cabelludo seco, 1 a 2 veces al día.
   Masajear suavemente con las yemas de los dedos. No lavar el cabello por al menos 4 horas.

Uso Oral (Suplementos de sostén):
2. Complejo vitamínico con L-Cistina y Biotina (ej. Megacistin® / Valcatil Max®)
   Tomar 1 a 2 cápsulas al día (o 1 sobre disuelto en agua), preferentemente por la mañana, por 3 meses.

(Nota: Explicar al paciente que en las primeras 2-4 semanas de Minoxidil puede haber una caída temporal por "efecto shedding", es normal. Los resultados reales se ven a los 4-6 meses).''',
  ),

  _PrescriptionModel(
    id: 'cesacion_tabaquica_trn',
    title: 'Dejar de Fumar (Cesación Tabáquica)',
    subtitle: 'Terapia de Reemplazo de Nicotina (Parches + Chicles)',
    category: 'Clínica Médica / Prevención',
    icon: Icons.smoke_free_rounded,
    content: '''Uso Transdérmico (Base diaria):
1. Parches de Nicotina 21 mg (ej. Niquitin® / Nicotinell®) - Si fuma >10 cig/día
   Aplicar 1 parche nuevo cada mañana sobre la piel limpia, seca y sin vello (brazo, pecho, espalda), rotando el sitio cada día.
   Retirar antes de dormir si causa insomnio o sueños vívidos (uso de 16 a 24 horas).
   Usar dosis de 21 mg por 4 semanas → luego 14 mg por 2 semanas → luego 7 mg por 2 semanas.

Uso Oral (Para picos de "craving" o deseo intenso):
2. Chicles o Comprimidos dispersables de Nicotina 2 mg
   Masticar LENTAMENTE un chicle hasta sentir picor/sabor fuerte, luego "estacionarlo" entre la mejilla y la encía hasta que pase el sabor. Volver a masticar.
   Usar a demanda cuando aparezcan ganas fuertes de fumar (máx 10-15 al día).

(Regla de oro: NO FUMAR NADA mientras se utilicen los parches para evitar intoxicación).''',
  ),

  _PrescriptionModel(
    id: 'nutricion_enteral_parenteral',
    title: 'Nutrición Clínica — Soporte Nutricional',
    subtitle: 'Enteral · parenteral · requerimientos · indicaciones',
    category: 'Clínica Médica',
    icon: Icons.medical_services_rounded,
    content: '''SOPORTE NUTRICIONAL EN INTERNACIÓN

REQUERIMIENTOS CALÓRICO-PROTEICOS:
• Calorías: 25–30 kcal/kg/día (peso ajustado en obeso).
• Proteínas: 1,2–2 g/kg/día (1,5–2 en críticos, sépticos, quemados).
• Agua: 25–35 mL/kg/día.

INDICACIÓN DE SOPORTE NUTRICIONAL:
• IMC <18,5 o pérdida >10% peso en 3 meses.
• Previsión de ayuno >5 días (3 días en desnutrido).
• Ingesta <60% requerimientos × >7 días.

VÍA ENTERAL (preferida — siempre que tracto GI funcione):
Sonda Nasogástrica (SNG) — estómago funcionante:
• Dieta polimérica estándar 1 kcal/mL.
  Iniciar: 20–30 mL/h → aumentar 10–20 mL/h c/4–6h.
  Objetivo: 60–80 mL/h (depende del requerimiento).
• Cabecera 30–45° (prevenir aspiración).
• Medir residuo gástrico c/4h (suspender si >500 mL).

Procinético si intolerancia gástrica:
• Metoclopramida 10 mg EV c/6h.
• Eritromicina 200 mg EV c/8h (procinético potente).

VÍA PARENTERAL:
Indicaciones: tracto GI no funcionante, fístula de alto débito, íleo prolongado.
• NPT central (osmolaridad >900 mOsm/L → CVC obligatorio):
  Glucosa 150–200 g/día + Aminoácidos 1–1,5 g/kg/día + Lípidos 1 g/kg/día.
• Vitaminas y oligoelementos diarios.
• Monitoreo: glucemia c/6h · LFT semanal · triglicéridos 2×/semana.

SÍNDROME DE REALIMENTACIÓN (evitar):
• Riesgo en desnutrición severa (BMI <14, ayuno >5 días).
• Reponer tiamina 100 mg EV antes de iniciar.
• Iniciar hipocalórico: 10 kcal/kg/día → aumentar gradual en 5–7 días.
• Monitoreo: fosfato, K⁺, Mg²⁺ c/12–24h las primeras 72h.

---
⚕ Modelo educativo — adaptar al paciente.''',
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
    final activeColor = dark ? const Color(0xFFFFE8A6) : const Color(0xFF0F1C14);
    final activeBg = dark
        ? const Color(0xFF1A3528)
        : const Color(0xFF0F1C14).withValues(alpha: 0.09);
    final inactiveBg = dark ? const Color(0xFF121F17) : Colors.white;
    final inactiveBorder = dark ? const Color(0xFF1E3526) : const Color(0xFFDDD8CC);

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
                ? (dark ? const Color(0xFF2A4A38) : const Color(0xFF0F1C14).withValues(alpha: 0.25))
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: dark
              ? const Color(0xFF0F1C14)
              : const Color(0xFF0F1C14).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFF0F1C14).withValues(alpha: 0.12),
          ),
        ),
        child: Row(children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFFD4A017),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
              color: dark ? const Color(0xFFD4A017) : const Color(0xFF0F1C14),
            ),
          ),
        ]),
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
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final es = widget.es;
    final p = context.watch<AppProvider>();
    final isFav = p.favPrescriptions.contains(widget.model.id);
    final cardBg = dark ? const Color(0xFF121F17) : Colors.white;
    final borderCol = dark ? const Color(0xFF1E3526) : const Color(0xFFE8E1D2);
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
                      : const Color(0xFF0F1C14).withValues(alpha: 0.07),
                ),
                child: Icon(widget.model.icon, size: 18,
                  color: dark ? const Color(0xFFFFE8A6) : const Color(0xFF1F6B48)),
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
                const SizedBox(height: 5),
                // Badge educacional
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: dark
                        ? const Color(0xFF1A3528)
                        : const Color(0xFF1F6B48).withValues(alpha: 0.08),
                    border: Border.all(
                      color: dark
                          ? const Color(0xFF2A4A38)
                          : const Color(0xFF1F6B48).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    es ? 'Ejemplo educativo' : 'Exemplo educacional',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: dark ? const Color(0xFF6EAF90) : const Color(0xFF1F6B48),
                    ),
                  ),
                ),
              ])),
              const SizedBox(width: 8),
              // Favorito + Copiar + chevron
              Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: () => context.read<AppProvider>().toggleFavPrescription(widget.model.id),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Icon(
                      isFav ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      size: 20,
                      color: isFav ? const Color(0xFFD8B4FE) : (dark ? Colors.white30 : const Color(0xFFBBBBBB)),
                    ),
                  ),
                ),
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
                              : const Color(0xFF0F1C14).withValues(alpha: 0.08)),
                      border: Border.all(
                        color: _copied
                            ? const Color(0xFF065F46)
                            : (dark ? const Color(0xFF2A4A38) : const Color(0xFF0F1C14).withValues(alpha: 0.2)),
                      ),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(
                        _copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 15,
                        color: _copied
                            ? Colors.white
                            : (dark ? const Color(0xFFFFE8A6) : const Color(0xFF0F1C14)),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _copied
                            ? (es ? '¡Copiado!' : 'Copiado!')
                            : (es ? 'Copiar ejemplo' : 'Copiar exemplo'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _copied
                              ? Colors.white
                              : (dark ? const Color(0xFFFFE8A6) : const Color(0xFF0F1C14)),
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
                  : const Color(0xFF0F1C14).withValues(alpha: 0.07)),
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
                : (dark ? const Color(0xFFFFE8A6) : const Color(0xFF0F1C14)),
          ),
          const SizedBox(width: 5),
          Text(
            copied ? (es ? '¡Copiado!' : 'Copiado!') : (es ? 'Copiar' : 'Copiar'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: copied
                  ? Colors.white
                  : (dark ? const Color(0xFFFFE8A6) : const Color(0xFF0F1C14)),
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
