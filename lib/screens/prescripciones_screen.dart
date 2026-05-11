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
        eyebrow: 'Clinical Templates',
        title: es ? 'Prescripciones' : 'Prescrições',
        subtitle: es
            ? 'Modelos listos para copiar y adaptar'
            : 'Modelos prontos para copiar e adaptar',
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
            '${filtered.length} ${es ? 'modelos' : 'modelos'}',
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

  // ── Analgesia / Dolor ─────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'cefalea_tensional',
    title: 'Cefalea Tensional',
    subtitle: 'Dolor de cabeza común',
    category: 'Analgesia',
    icon: Icons.psychology_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Dipirona 500 mg
   1 comprimido cada 6h si hay dolor, VO
   □ Qtd: 10 comprimidos

2. Ibuprofeno 400 mg
   1 comprimido cada 12h por 5 días, VO
   □ Qtd: 10 comprimidos

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'dor_muscular_lombalgia',
    title: 'Dolor Muscular / Lumbalgia',
    subtitle: 'Contractura / Dolor de espalda',
    category: 'Analgesia',
    icon: Icons.accessibility_new_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Dipirona 500 mg
   1 comprimido cada 6h si hay dolor, VO
   □ Qtd: 10 comprimidos

2. Diclofenac 75 mg
   1 comprimido cada 12h por 5 días, VO
   □ Qtd: 10 comprimidos

3. Ciclobenzaprina o Pridinol
   1 comprimido antes de dormir por 5 días, VO
   □ Qtd: 5 comprimidos

---
En Guardia: Dipirona 1g IM + Diclofenac 75mg IM
⚕ Modelo educacional — adaptar al paciente.''',
  ),

  // ── Cardiovascular ────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'crisis_hipertensiva',
    title: 'Crisis Hipertensiva',
    subtitle: 'Urgencia hipertensiva',
    category: 'Cardiovascular',
    icon: Icons.speed_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Captopril 25 mg
   1 comprimido VO. Repetir en 1h si no baja
   □ Qtd: 2 comprimidos

2. Furosemida 40 mg
   1 comprimido VO si hay edemas o congestión
   □ Qtd: 1 comprimido

---
En Guardia: Captopril 25 mg sublingual
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'varizes_mmii',
    title: 'Várices MMII',
    subtitle: 'Insuficiencia venosa crónica',
    category: 'Cardiovascular',
    icon: Icons.favorite_border_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Diosmina / Hesperidina 500 mg
   1 comprimido cada 12h por 30 días, VO
   □ Qtd: 60 comprimidos

2. Gel con Heparina (tipo Hirudoid)
   Aplicar 2 veces al día en piernas cansadas, Tópico
   □ Qtd: 1 pomo

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),

  // ── Cirugía ───────────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'escoriacoes_feridas',
    title: 'Escoriaciones / Heridas Leves',
    subtitle: 'Raspaduras y cortes superficiales',
    category: 'Cirugía',
    icon: Icons.healing_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Sulfadiazina de Plata (Crema)
   Aplicar 1 o 2 veces al día hasta cicatrización, Tópica
   □ Qtd: 1 pomo

2. Solución Fisiológica 0.9%
   Lavar la herida antes de aplicar la crema
   □ Qtd: 1 frasco

---
En Guardia: Analgesia local (Dipirona IM) + Verificar vacunas antitetánicas
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'hemorroidas_manejo',
    title: 'Hemorroides',
    subtitle: 'Crisis hemorroidal',
    category: 'Cirugía',
    icon: Icons.warning_amber_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Daflon 500 mg (Diosmina/Hesperidina)
   1 comp c/4h por 4 días, luego c/6h por 3 días,
   luego c/12h por meses, VO
   □ Qtd: según etapa

2. Crema Proctológica (ej. Proctoglyvenol)
   Aplicar 2-3 veces al día en zona anal
   □ Qtd: 1 pomo

3. Ibuprofeno 400 mg
   1 comprimido cada 12h por 5 días, VO
   □ Qtd: 10 comprimidos

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),

  // ── Clínica Médica ────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'febre_sem_foco',
    title: 'Fiebre Sin Foco',
    subtitle: 'Síndrome febril inespecífico',
    category: 'Clínica Médica',
    icon: Icons.thermostat_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Dipirona 500 mg o Paracetamol 500 mg
   1 comprimido cada 6h si hay fiebre, VO
   □ Qtd: 10 comprimidos

2. Hidratación Abundante
   Beber agua o Sales de Rehidratación Oral (SRO)

---
Nota: Si la fiebre persiste >48h o aparecen manchas
en piel, acudir a guardia.
⚕ Modelo educacional — adaptar al paciente.''',
  ),

  // ── Dermatología ──────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'dermatite_contato',
    title: 'Dermatitis de Contacto',
    subtitle: 'Reacción alérgica leve',
    category: 'Dermatología',
    icon: Icons.coronavirus_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Loratadina 10 mg
   1 comprimido por noche por 7 días, VO
   □ Qtd: 7 comprimidos

2. Betametasona + Gentamicina (Crema)
   Aplicar fina capa 2 veces al día por 7 días, Tópica
   □ Qtd: 1 pomo

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'dermatite_seborreica',
    title: 'Dermatitis Seborreica',
    subtitle: 'Caspa / Eccema seborreico',
    category: 'Dermatología',
    icon: Icons.face_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Ketoconazol Shampoo 2%
   Aplicar 3 veces por semana, dejar 5 min,
   enjuagar (4 semanas)
   □ Qtd: 1 frasco

2. Hidrocortisona Crema 1%
   Aplicar 2 veces al día por 5 días en áreas rojas, Tópica
   □ Qtd: 1 pomo

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'dermatofitose',
    title: 'Dermatofitosis / Pie de Atleta',
    subtitle: 'Micosis interdigital',
    category: 'Dermatología',
    icon: Icons.do_not_step_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Clotrimazol Crema 1%
   Aplicar fina capa 2 veces al día por 14 días, Tópica
   □ Qtd: 1 pomo

---
Orientación: Mantener pies secos y cambiar medias diario.
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'escabiose_sarna',
    title: 'Escabiosis / Sarna',
    subtitle: 'Acarosis cutánea',
    category: 'Dermatología',
    icon: Icons.texture_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Permetrina 5% (Crema)
   Aplicar de cuello a pies por la noche (8-12h),
   lavar por la mañana. Repetir a los 7 días.
   □ Qtd: 1 pomo

2. Ivermectina 6 mg
   2-3 comprimidos (según peso) dosis única VO.
   Repetir a los 7 días.
   □ Qtd: según peso

---
Orientación: Tratar a toda la familia simultáneamente.
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'impetigo_manejo',
    title: 'Impétigo',
    subtitle: 'Infección cutánea bacteriana',
    category: 'Dermatología',
    icon: Icons.face_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Cefalexina 500 mg
   1 comprimido cada 6h por 7 días, VO
   □ Qtd: 28 comprimidos

2. Mupirocina (Pomada)
   Aplicar en lesiones 3 veces al día por 7 días, Tópica
   □ Qtd: 1 pomo

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'molusco_contagioso',
    title: 'Molusco Contagioso',
    subtitle: 'Lesiones cutáneas virales',
    category: 'Dermatología',
    icon: Icons.coronavirus_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

Conducta: Las lesiones suelen curar solas en 6-12 meses.

Indicaciones:
- NO compartir toallas ni manipular lesiones.
- Derivación a Dermatología para curetaje o crioterapia
  si son extensas.

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'psoriase_leve',
    title: 'Psoriasis Leve',
    subtitle: 'Placas cutáneas crónicas',
    category: 'Dermatología',
    icon: Icons.texture_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Crema con Ácido Salicílico + Urea
   Aplicar 2 veces al día sobre placas
   □ Qtd: 1 pomo

2. Hidrocortisona Crema 1%
   Aplicar 2 veces al día por 7 días (en brotes), Tópica
   □ Qtd: 1 pomo

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'urticaria_aguda',
    title: 'Urticaria Aguda',
    subtitle: 'Ronchas y picazón',
    category: 'Dermatología',
    icon: Icons.coronavirus_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Loratadina 10 mg o Cetirizina 10 mg
   1 comprimido por día por 7 días, VO
   □ Qtd: 7 comprimidos

2. Meprednisona 40 mg
   1 comprimido por día por 3 días, VO
   □ Qtd: 3 comprimidos

---
En Guardia: Hidrocortisona EV/IM + Antihistamínico IM
⚕ Modelo educacional — adaptar al paciente.''',
  ),

  // ── Endocrinología ────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'hiperglucemia_descomp',
    title: 'Hiperglucemia (DB2)',
    subtitle: 'Diabetes Descompensada (Leve)',
    category: 'Endocrinología',
    icon: Icons.monitor_heart_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

En Guardia:
1. Hidratación con Fisiológico 500 mL EV
   si hay deshidratación.

2. Investigar causas (infecciones, falta de medicación).

3. Derivación a Diabetología para ajuste
   de insulina/metformina.

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'hipotireoidismo',
    title: 'Hipotiroidismo',
    subtitle: 'Sustitución hormonal — Levotiroxina',
    category: 'Endocrinología',
    icon: Icons.water_drop_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Levotiroxina
   Dosis: 1,6 mcg/kg/día, VO, en ayunas.
   (iniciar con 25-50 mcg/día si >65 años o cardiopatía)
   □ Qtd: según dosis

---
Tomar 30-60 min antes del desayuno.
No tomar junto a hierro, calcio o antiácidos.
Laboratorio en 6 semanas: TSH.
Meta: TSH 0,5–2,5 mUI/L (adultos jóvenes).
⚕ Modelo educacional — adaptar al paciente.''',
  ),

  // ── Gastroenterología ─────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'colico_biliar_renal',
    title: 'Cólico Biliar / Renal',
    subtitle: 'Litiasis o barro biliar/renal',
    category: 'Gastroenterología',
    icon: Icons.emergency_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Hioscina + Dipirona (Buscapina Composite)
   1 comprimido cada 6h si hay dolor, VO

2. Ibuprofeno 400 mg
   1 comprimido cada 12h por 5 días, VO

3. Tramadol 50 mg
   1 comprimido cada 8h si el dolor es intenso, VO

4. Ondansetrón 8 mg o Metoclopramida 10 mg
   1 comprimido cada 8h si hay náuseas, VO

---
En Guardia: Dipirona + Hioscina EV en 100ml Fisiológico
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'constipacion_funcional',
    title: 'Constipación Funcional',
    subtitle: 'Estreñimiento',
    category: 'Gastroenterología',
    icon: Icons.water_drop_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Lactulosa Jarabe
   15 a 30 mL por día, VO
   □ Qtd: 1 frasco

2. Vaselina líquida médica (Aceite mineral)
   15 mL cada 8h por hasta 7 días si heces duras, VO
   □ Qtd: 1 frasco

---
Orientación: Beber 2L de agua/día y aumentar fibras.
En Guardia: Enema evacuante si es necesario.
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'gastrite_erge',
    title: 'Gastritis / Reflujo / ERGE',
    subtitle: 'Dispepsia / Ardor estomacal',
    category: 'Gastroenterología',
    icon: Icons.medication_liquid_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Omeprazol 20 mg
   1 cápsula en ayunas por 30 días, VO
   □ Qtd: 30 cápsulas

2. Metoclopramida (Reliverán) 10 mg
   1 comprimido 30 min antes de comidas, VO
   □ Qtd: 30 comprimidos

3. Hioscina + Dipirona (Buscapina Composite)
   1 comprimido cada 6h si hay dolor, VO
   □ Qtd: 10 comprimidos

---
En Guardia: Dipirona IM + Antiemético IM
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'geca_diarreia',
    title: 'GEA — Gastroenteritis Aguda',
    subtitle: 'Diarrea y vómitos',
    category: 'Gastroenterología',
    icon: Icons.water_drop_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Sales de Rehidratación Oral (SRO)
   Beber después de cada deposición líquida
   □ Qtd: 1 caja

2. Metoclopramida 10 mg o Ondansetrón 8 mg
   1 comprimido cada 8h si hay náuseas, VO
   □ Qtd: 10 comprimidos

3. Hioscina + Dipirona
   1 comprimido cada 6h si hay cólicos, VO
   □ Qtd: 10 comprimidos

Si hay sangre en heces o fiebre alta:
4. Ciprofloxacina 500 mg
   1 comprimido cada 12h por 5 días, VO
   □ Qtd: 10 comprimidos

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),

  // ── Ginecología ───────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'candidiasis_vaginal',
    title: 'Candidiasis Vaginal',
    subtitle: 'Flujo y prurito vulvovaginal',
    category: 'Ginecología',
    icon: Icons.female_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Fluconazol 150 mg
   1 comprimido, dosis única, VO
   □ Qtd: 1 comprimido

2. Nistatina (crema vaginal u óvulos)
   1 aplicador/óvulo por noche por 7 días, Vía Vaginal
   □ Qtd: 1 caja/pomo

---
Orientación: Evitar relaciones sexuales durante el tratamiento.
⚕ Modelo educacional — adaptar al paciente.''',
  ),

  // ── Hematología ───────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'anemia_ferropenica',
    title: 'Anemia Ferropénica',
    subtitle: 'Sintomática / Déficit de Hierro',
    category: 'Hematología',
    icon: Icons.bloodtype_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Sulfato Ferroso 200 mg (u otro complejo de hierro)
   1 comprimido cada 12h por 3 meses (mínimo), VO
   □ Qtd: 3 cajas (dependiendo de presentación)

---
Orientaciones: Tomar preferentemente con jugo de naranja
para mejorar absorción.
⚕ Modelo educacional — adaptar al paciente.''',
  ),

  // ── Infectología ──────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'absceso_forunculo',
    title: 'Absceso / Forúnculo',
    subtitle: 'Infección de piel y partes blandas',
    category: 'Infectología',
    icon: Icons.healing_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Cefalexina 500 mg
   1 comprimido cada 6h por 10 días, VO
   □ Qtd: 40 comprimidos

2. Ibuprofeno 400 mg
   1 comprimido cada 8h por 5 días, VO
   □ Qtd: 15 comprimidos

3. Dipirona 500 mg
   1 comprimido cada 6h si hay dolor o fiebre, VO
   □ Qtd: 10 comprimidos

4. Mupirocina 2% (crema)
   Aplicar en zona afectada 3 veces al día por 10 días
   □ Qtd: 1 pomo

---
En Guardia: Drenaje si fluctúa + Dipirona 1 amp IM
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'dengue_manejo',
    title: 'Dengue',
    subtitle: 'Sospecha de Dengue (Sin signos de alarma)',
    category: 'Infectología',
    icon: Icons.bug_report_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Paracetamol 500 mg o 1g
   1 comprimido cada 6h si hay fiebre o dolor, VO
   □ Qtd: 20 comprimidos

2. Metoclopramida (Reliverán) 10 mg o Ondansetrón 8 mg
   1 comprimido cada 8h si hay náuseas, VO
   □ Qtd: 10 comprimidos

3. SRO (Sales de Rehidratación Oral)
   Diluir sobre en 1L de agua. Beber durante el día
   □ Qtd: 1 caja

---
⚠ PROHIBIDO: Ibuprofeno, Aspirina, Diclofenac
Hidratación: Mínimo 80 mL/kg/día
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'enterobiase',
    title: 'Enterobiasis / Oxiuros',
    subtitle: 'Parásitos intestinales',
    category: 'Infectología',
    icon: Icons.bug_report_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Albendazol 400 mg
   Dosis única VO. Repetir en 14 días.
   □ Qtd: 2 comprimidos

---
Orientación: Tratar a todos los convivientes
y lavar ropa de cama a 60°C.
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'erisipela_manejo',
    title: 'Erisipela',
    subtitle: 'Infección dermo-epidérmica',
    category: 'Infectología',
    icon: Icons.warning_amber_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Cefalexina 500 mg
   1 comprimido cada 6h por 10 días, VO
   □ Qtd: 40 comprimidos

2. Ibuprofeno 400 mg
   1 comprimido cada 8h por 5 días, VO
   □ Qtd: 15 comprimidos

---
En Guardia: Ceftriaxona 1g IM + Dipirona IM
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'herpes_simples',
    title: 'Herpes Simple',
    subtitle: 'Herpes labial / genital',
    category: 'Infectología',
    icon: Icons.coronavirus_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Aciclovir 400 mg
   1 comprimido cada 8h por 7 días, VO
   (En gestantes 5 días)
   □ Qtd: 21 comprimidos

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'itu_manejo',
    title: 'Infección Urinaria (ITU)',
    subtitle: 'Cistitis / Uretritis',
    category: 'Infectología',
    icon: Icons.water_drop_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Nitrofurantoína 100 mg
   1 comprimido cada 6h por 7 días, VO
   □ Qtd: 28 comprimidos
   (o Ciprofloxacina 500 mg cada 12h por 7 días)

2. Fenazopiridina 200 mg
   1 comprimido cada 8h por 3 días (Analgésico urinario), VO
   □ Qtd: 9 comprimidos

---
Pielonefritis (Fiebre/Dolor lumbar):
Ceftriaxona 1g IM dosis única + Hospitalizar si es grave.
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'pep_sexual',
    title: 'PPE Sexual',
    subtitle: 'Profilaxis Post-Exposición VIH',
    category: 'Infectología',
    icon: Icons.security_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Tenofovir + Lamivudina (300/300)
   1 comprimido por día, VO
   □ Qtd: 28 comprimidos

2. Dolutegravir 50 mg
   1 comprimido por día, VO
   □ Qtd: 28 comprimidos

---
⚠ DURACIÓN: 28 días.
⚠ Iniciar ANTES de las 72h del evento.
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'tetano_ferimentos',
    title: 'Tétanos — Heridas',
    subtitle: 'Manejo antitetánico en heridas',
    category: 'Infectología',
    icon: Icons.healing_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Limpieza profunda con Fisiológico + Antiséptico.

2. Vacuna Doble Adultos (dT) IM según esquema.

3. Inmunoglobulina Antitetánica IM
   si herida es de alto riesgo.

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),

  // ── Neurología ────────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'crisis_convulsiva',
    title: 'Crisis Convulsiva / Epilepsia',
    subtitle: 'Manejo agudo y post-crisis',
    category: 'Neurología',
    icon: Icons.bolt_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

En Guardia (Urgencia):
1. Diazepam 10 mg EV lento o rectal, dosis única.
2. Oxígeno por máscara si Sat <94%.

Manejo Post-Crisis:
- Derivación a Neurología (no iniciar antiepilépticos
  sin diagnóstico).

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'enxaqueca_migranea',
    title: 'Migraña / Jaqueca',
    subtitle: 'Dolor de cabeza severo',
    category: 'Neurología',
    icon: Icons.psychology_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Dipirona 500 mg o Paracetamol 1g
   1 comprimido cada 6h si hay dolor, VO
   □ Qtd: 10 comprimidos

2. Ibuprofeno 600 mg
   1 comprimido cada 12h por 5 días, VO
   □ Qtd: 10 comprimidos

3. Naratriptán 2.5 mg
   1 comprimido al inicio del dolor.
   Repetir en 4h si es necesario (máx 2/día), VO
   □ Qtd: 4 comprimidos

---
En Guardia: Dipirona 1g IM + Dexametasona 4mg IM + Antiemético
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'insonia_leve',
    title: 'Insomnio Leve / Moderado',
    subtitle: 'Dificultad para dormir',
    category: 'Neurología',
    icon: Icons.bedtime_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Passiflora / Valeriana (Fitoterápicos)
   1 comprimido antes de dormir
   □ Qtd: 30 comprimidos

---
Orientación: Higiene del sueño
(evitar pantallas y cafeína de noche).
⚕ Modelo educacional — adaptar al paciente.''',
  ),

  // ── Oftalmología ──────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'conjuntivitis_aguda',
    title: 'Conjuntivitis',
    subtitle: 'Infección ocular aguda',
    category: 'Oftalmología',
    icon: Icons.visibility_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Tobramicina 0.3% (Gotas)
   2 gotas cada 6h por 5 días, Vía Oftálmica
   □ Qtd: 1 frasco

---
Orientaciones: Compresas frías 20 min.
No usar lentes de contacto.
⚕ Modelo educacional — adaptar al paciente.''',
  ),

  // ── Otorrinolaringología ──────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'amigdalitis_bacteriana',
    title: 'Amigdalitis / Anginas',
    subtitle: 'Faringoamigdalitis purulenta',
    category: 'Otorrinolaringología',
    icon: Icons.record_voice_over_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Amoxicilina + Ácido Clavulánico 875/125 mg
   1 comprimido cada 12h por 7 días, VO
   □ Qtd: 14 comprimidos

2. Ibuprofeno 600 mg
   1 comprimido cada 12h por 5 días, VO
   □ Qtd: 10 comprimidos

3. Dipirona 500 mg
   1 comprimido cada 6h si hay fiebre o dolor, VO
   □ Qtd: 10 comprimidos

---
En Guardia: Penicilina G Benzatina 1.2M UI IM dosis única
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'cerumen_impactado',
    title: 'Cerumen Impactado',
    subtitle: 'Tapón de cera',
    category: 'Otorrinolaringología',
    icon: Icons.hearing_disabled_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Gotas Otológicas (Glicerina / Carbonato de Sodio)
   5 gotas en oído afectado cada 8h por 5 días,
   Vía Otológica
   □ Qtd: 1 frasco

---
Orientación: Mantener posición de costado 5 min
tras aplicación.
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'faringite_viral',
    title: 'Faringitis Viral',
    subtitle: 'Angina viral común',
    category: 'Otorrinolaringología',
    icon: Icons.record_voice_over_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Dipirona 500 mg o Paracetamol 500 mg
   1 comprimido cada 6h si hay dolor, VO
   □ Qtd: 10 comprimidos

2. Ibuprofeno 400 mg
   1 comprimido cada 8h por 3 días, VO
   □ Qtd: 9 comprimidos

---
⚠ Reposo, hidratación y NO USAR ANTIBIÓTICOS.
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'hemorragia_nasal',
    title: 'Epistaxis Leve',
    subtitle: 'Sangrado nasal',
    category: 'Otorrinolaringología',
    icon: Icons.bloodtype_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Compresión Nasal
   Presionar alas de la nariz 10 min
   con cabeza hacia adelante.

2. Nafazolina (Gotas Nasales)
   1 aplicación si persiste sangrado (máx 3 días), Tópica
   □ Qtd: 1 frasco

---
En Guardia: Taponamiento anterior si no cede.
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'labirintite_vertigem',
    title: 'Laberintitis / Vértigo',
    subtitle: 'Mareos y desequilibrio',
    category: 'Otorrinolaringología',
    icon: Icons.cached_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Meclizina 25 mg
   1 comprimido cada 6h por 7 días, VO
   □ Qtd: 28 comprimidos

2. Dimenhidrinato (Dramamine) 50 mg
   1 comprimido cada 8h si hay náuseas, VO
   □ Qtd: 21 comprimidos

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'otite_externa',
    title: 'Otitis Externa',
    subtitle: 'Infección del conducto auditivo',
    category: 'Otorrinolaringología',
    icon: Icons.hearing_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Gotas Otológicas (Ciprofloxacina + Hidrocortisona)
   3 gotas en oído afectado 3 veces al día por 7 días
   □ Qtd: 1 frasco

2. Ibuprofeno 400 mg
   1 comprimido cada 8h por 5 días, VO
   □ Qtd: 15 comprimidos

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'otite_media',
    title: 'Otitis Media Aguda',
    subtitle: 'Infección del oído medio',
    category: 'Otorrinolaringología',
    icon: Icons.hearing_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Amoxicilina 500 mg o 1g
   1 comprimido cada 8h por 10 días, VO
   □ Qtd: 30 comprimidos

2. Ibuprofeno 400 mg
   1 comprimido cada 8h por 5 días, VO
   □ Qtd: 15 comprimidos

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'rinite_alergica',
    title: 'Rinitis Alérgica',
    subtitle: 'Alergia nasal',
    category: 'Otorrinolaringología',
    icon: Icons.air_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Loratadina 10 mg
   1 comprimido por día por 7 días, VO
   □ Qtd: 7 comprimidos

2. Lavajes Nasales con Solución Fisiológica
   3 veces al día.
   □ Qtd: 1 frasco

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'sinusite_aguda',
    title: 'Sinusitis Aguda',
    subtitle: 'Infección de senos paranasales',
    category: 'Otorrinolaringología',
    icon: Icons.air_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Amoxicilina/Clavulánico 875/125 mg
   1 comprimido cada 12h por 10 días, VO
   □ Qtd: 20 comprimidos

2. Loratadina 10 mg
   1 comprimido por día por 7 días, VO
   □ Qtd: 7 comprimidos

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'tosse_seca',
    title: 'Tos Seca Persistente',
    subtitle: 'Tos irritativa',
    category: 'Otorrinolaringología',
    icon: Icons.record_voice_over_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Antitusivo (ej. Benzonatato o Butamirato)
   1 comprimido cada 8h por 5 días, VO
   □ Qtd: 15 comprimidos

2. Loratadina 10 mg
   1 comprimido por día por 7 días
   (si hay goteo post-nasal), VO
   □ Qtd: 7 comprimidos

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),

  // ── Respiratorio ──────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'asma_aguda',
    title: 'Asma Aguda Leve / Moderada',
    subtitle: 'Broncoespasmo agudo',
    category: 'Respiratorio',
    icon: Icons.air_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Salbutamol aerosol 100 mcg
   2 disparos (puffs) cada 6h por 5 días, Inhalatoria
   Usar siempre con aerocámara (espaciador).

2. Meprednisona 40 mg
   1 comprimido por la mañana por 5 días, VO
   □ Qtd: 5 comprimidos

---
Orientación: Si no hay mejoría o hay cianosis,
acudir a guardia inmediatamente.
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'dpoc_exacerbacao',
    title: 'EPOC Exacerbado',
    subtitle: 'Enfermedad Pulmonar Obstructiva Crónica',
    category: 'Respiratorio',
    icon: Icons.smoking_rooms_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Meprednisona 40 mg
   1 comprimido cada 12h por 5 días, VO
   □ Qtd: 10 comprimidos

2. Azitromicina 500 mg
   1 comprimido por día por 5 días, VO
   □ Qtd: 5 comprimidos

3. Salbutamol Aerosol
   2 disparos cada 6h con aerocámara.

---
En Guardia: Nebulización (Fenoterol + Ipratropio)
+ Hidrocortisona EV/IM
⚕ Modelo educacional — adaptar al paciente.''',
  ),
  _PrescriptionModel(
    id: 'pneumonias_manejo',
    title: 'Neumonía (NAC)',
    subtitle: 'Neumonía Adquirida en Comunidad',
    category: 'Respiratorio',
    icon: Icons.air_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Amoxicilina + Ácido Clavulánico 875/125 mg
   1 comprimido cada 12h por 7 días, VO
   □ Qtd: 14 comprimidos

2. Meprednisona 40 mg
   1 comprimido por día por 5 días, VO
   □ Qtd: 5 comprimidos

3. Jarabe Expectorante (ej. Ambroxol)
   5 ml cada 8h por 5 días, VO
   □ Qtd: 1 frasco

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),

  // ── Traumatología ─────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'traumatologia_esguince',
    title: 'Esguince / Contusión',
    subtitle: 'Lesión musculoesquelética leve',
    category: 'Traumatología',
    icon: Icons.accessibility_new_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Dipirona 500 mg
   1 comprimido cada 6h si hay dolor, VO
   □ Qtd: 10 comprimidos

2. Diclofenac 75 mg
   1 comprimido cada 12h por 5 días, VO
   □ Qtd: 10 comprimidos

---
Hielo: 15-20 min cada 2h las primeras 48h.
Reposo y elevación del miembro.
⚕ Modelo educacional — adaptar al paciente.''',
  ),

  // ── Urgencias ─────────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'hipoglicemia_aguda',
    title: 'Hipoglucemia Sintomática',
    subtitle: 'Baja de azúcar en sangre',
    category: 'Urgencias',
    icon: Icons.emergency_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

En Guardia:
1. Glucosa 50% (Ampolla 20ml) EV lento
   diluida en 100ml Fisiológico.
   (Si el paciente está consciente, dar azúcar VO).

---
⚕ Modelo educacional — adaptar al paciente.''',
  ),

  // ── Urología ──────────────────────────────────────────────────────────────
  _PrescriptionModel(
    id: 'itu_masculina',
    title: 'ITU Masculina',
    subtitle: 'Infección urinaria en hombre',
    category: 'Urología',
    icon: Icons.male_rounded,
    content: '''Paciente: _______________
Fecha: ___/___/______

1. Ciprofloxacina 500 mg
   1 comprimido cada 12h por 7-14 días, VO
   □ Qtd: 14-28 comprimidos

2. Fenazopiridina 200 mg
   1 comprimido cada 8h por 3 días (Analgésico urinario), VO
   □ Qtd: 9 comprimidos

---
Descartar prostatitis (tacto rectal + PSA).
Si fiebre o dolor lumbar: Ceftriaxona 1g IM + internación.
⚕ Modelo educacional — adaptar al paciente.''',
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
