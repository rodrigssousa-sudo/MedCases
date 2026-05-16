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

      // ── Header premium ───────────────────────────────────────────────────
      PremiumCard(child: SectionTitle(
        eyebrow: es ? 'Uso exclusivamente educacional' : 'Uso exclusivamente educacional',
        title: es ? 'Ejemplos de Prescripción' : 'Exemplos de Prescrição',
        subtitle: es
            ? 'Modelos educativos de referencia — siempre adaptar al caso clínico'
            : 'Modelos educacionais de referência — sempre adaptar ao caso clínico',
        light: true,
      )),
      const SizedBox(height: 12),

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
                  label: cat,
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
    title: 'TSV — Adenosina',
    subtitle: 'Taquicardia supraventricular paroxística',
    category: 'Cardiovascular',
    icon: Icons.favorite_rounded,
    content: '''1. Adenosina 6 mg/2 mL (amp)
   Administrar 6 mg EV en bolo rápido.
   Si no revierte en 2 min → repetir con 12 mg.
   Acceso venoso antecubital o yugular.

Notas:
- Monitorización ECG continua.
- Equipo de reanimación disponible.
- Contraindicada en: BAV 2°/3°, FA/Flutter, WPW.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'tv_amiodarona',
    title: 'TV — Amiodarona',
    subtitle: 'Taquicardia ventricular con pulso',
    category: 'Cardiovascular',
    icon: Icons.monitor_heart_rounded,
    content: '''1. Amiodarona 150 mg/3 mL (amp)
   Dosis de ataque: 150 mg EV en 10 min.
   Mantenimiento: 1 mg/min en BIC por 6h;
   luego 0,5 mg/min en BIC por 18h.

Preparación BIC:
   Diluir 3 amp (450 mg) en 250 mL SG 5%.
   Velocidad inicial: ~33 mL/h (1 mg/min).

- Si inestable hemodinámicamente → cardioversión eléctrica.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'fa_flutter_aguda',
    title: 'FA / Flutter — Control de FC',
    subtitle: 'Fibrilación auricular aguda',
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

Alta (anticoagulación):
• Apixabán 5 mg — 1 comprimido cada 12h, VO
• Rivaroxabán 20 mg — 1 comprimido/día con cena, VO

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  _PrescriptionModel(
    id: 'bradiarritmia_atropina',
    title: 'Bradiarritmia Sintomática',
    subtitle: 'Atropina / Dopamina / Adrenalina',
    category: 'Cardiovascular',
    icon: Icons.heart_broken_rounded,
    content: '''1. Atropina 0,5 mg/mL (amp 1 mL)
   Administrar 0,5–1 mg EV en bolo.
   Repetir cada 3–5 min (máx 3 mg).

2. Dopamina 50 mg/10 mL (amp)
   Si refractaria a atropina.
   Diluir 5 amp en 200 mL SF 0,9% → BIC 5 a 20 mcg/kg/min.

3. Adrenalina 1 mg/mL (amp 1 mL)
   Si sin respuesta a dopamina.
   Diluir en BIC: 0,05–1 mcg/kg/min.

- Preparar marcapasos transcutáneo/transvenoso.

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
    subtitle: 'Urgencia / Emergencia hipertensiva',
    category: 'Cardiovascular',
    icon: Icons.speed_rounded,
    content: '''Urgencia Hipertensiva (sin daño orgánico):
1. Captopril 25 mg sublingual (SL)
   Repetir cada 20–30 min si necesario.

Emergencia Hipertensiva (daño orgánico):
1. Nitroprusiato [Nipride®] 50 mg/2 mL
   Diluir en 248 mL SG 5%.
   BIC: iniciar 5 mL/h → titular.
   FT: 0,3–2,0 mcg/kg/min.

2. Nitroglicerina [Tridil®] 50 mg/10 mL
   Diluir en 240 mL SF 0,9% → BIC 1–2 mL/h.
   Dosis inicial: 5 mcg/min.

Disección Aórtica:
• Esmolol 10 mg/mL → BIC: titular FC <60 lpm
• Metoprolol 5 mg EV lento + Morfina 2–4 mg EV

---
⚕ Modelo educativo — adaptar al paciente.''',
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
    title: 'Aminas Vasoactivas — BIC',
    subtitle: 'Noradrenalina · Dobutamina · Dopamina',
    category: 'Cardiovascular',
    icon: Icons.science_rounded,
    content: '''Noradrenalina 2 mg/mL (amp 4 mL):
   Diluir 4 amp (16 mg) en 234 mL SF 0,9%.
   FT: 0,05–2,0 mcg/kg/min.
   Iniciar 5 mL/h → titular.

Dobutamina 250 mg/20 mL:
   Diluir 4 amp en 170 mL SF 0,9% (4 mg/mL).
   BIC: iniciar 2 mL/h.
   FT: 2,5–20 mcg/kg/min.

Dopamina 50 mg/10 mL:
   Diluir 5 amp en 200 mL SF 0,9% (10 mg/mL).
   FT: 5–20 mcg/kg/min.

Vasopresina 20 UI/amp:
   Diluir 3 amp en 57 mL SF 0,9% (1 UI/mL).
   BIC: 0,01–0,04 UI/min.

---
⚕ Modelo educativo — adaptar al paciente.''',
  ),

  // ══════════════════════════════════════════════════════════════════════════
  // NEUROLOGÍA
  // ══════════════════════════════════════════════════════════════════════════
  _PrescriptionModel(
    id: 'migrana_jaqueca',
    title: 'Migraña / Jaqueca',
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
    title: 'Vértigo / Síndrome Vestibular',
    subtitle: 'Dimeninato · Cinarizina',
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
    title: 'ACV Isquémico — tPA',
    subtitle: 'Alteplase en ventana terapéutica',
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
    title: 'Hemorragia Digestiva Alta — Varicosa',
    subtitle: 'Terlipresina · Octreotide · Somatostatina',
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
    title: 'Hemorragia Digestiva Alta — No Varicosa',
    subtitle: 'Úlcera péptica sangrante',
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
    id: 'reflux_dup',
    title: 'Reflujo / Úlcera Péptica',
    subtitle: 'IBP · Erradicación H. Pylori',
    category: 'Gastroenterología',
    icon: Icons.medication_rounded,
    content: '''Tratamiento base:
1. Omeprazol 40 mg — 1 comprimido VO en ayunas × 8 semanas.
   (Alternativa: Pantoprazol 40 mg o Esomeprazol 40 mg)

H. Pylori positivo — Terapia triple × 14 días:
1. Omeprazol 40 mg — 1 comprimido VO cada 12h.
2. Amoxicilina 1 g — 1 comprimido VO cada 12h.
3. Claritromicina 500 mg — 1 comprimido VO cada 12h.

H. Pylori — Segunda línea (si falla):
• Bismuto + Metronidazol + Tetraciclina + IBP × 14 días.

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
    title: 'CAD / EHH — Insulinoterapia',
    subtitle: 'Cetoacidosis diabética · Estado hiperosmolar',
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
    title: 'ITU Baja — Cistitis',
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

Vasopresor (si PAM <65 mmHg):
   Noradrenalina BIC: iniciar 0,05 mcg/kg/min → titular.

Corticoide (si >0,25 mcg/kg/min de NA × 4h):
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
    title: 'PPE Sexual — VIH',
    subtitle: 'Profilaxis post-exposición — inicio <72h',
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
    title: 'Agitación Psicomotora',
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
    title: 'Hipercalemia — Hiperpotasemia',
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
    title: 'Hipocalemia — Hipopotasemia',
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
    title: 'Intubación — SRI',
    subtitle: 'Secuencia Rápida de Intubación — adulto 70 kg',
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
              color: const Color(0xFFFFE8A6),
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
              color: dark ? const Color(0xFFFFE8A6) : const Color(0xFF0F1C14),
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
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final es = widget.es;
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
