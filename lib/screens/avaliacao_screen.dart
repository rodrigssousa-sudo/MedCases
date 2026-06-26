import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/clinical_history_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AVALIAÇÃO FÍSICA — perguntas estruturadas por sistema
// ─────────────────────────────────────────────────────────────────────────────

const _kGreen  = Color(0xFF10B981);
const _kGold   = Color(0xFFC5A365);
const _kDark   = Color(0xFF0F1116);
const _kBorder = Color(0xFFE5E7EB);

// ── Modelo de uma pergunta ────────────────────────────────────────────────────
class _Question {
  final String id;
  final String label;          // Texto da pergunta (PT)
  final String labelEs;        // Texto da pergunta (ES)
  final String hint;           // Placeholder (PT)
  final String hintEs;         // Placeholder (ES)
  final bool multiline;
  final int lines;
  final List<String> options;    // Chips de seleção rápida (PT)
  final List<String> optionsEs;  // Chips de seleção rápida (ES)
  final bool detailedOnly;       // Se true, aparece só no modo Detalhado

  const _Question({
    required this.id,
    required this.label,
    required this.labelEs,
    required this.hint,
    required this.hintEs,
    this.multiline = false,
    this.lines = 2,
    this.options = const [],
    this.optionsEs = const [],
    this.detailedOnly = false,
  });
}

// ── Modelo de uma seção ───────────────────────────────────────────────────────
class _Section {
  final String id;
  final String title;
  final String titleEs;
  final IconData icon;
  final Color color;
  final List<_Question> questions;

  const _Section({
    required this.id,
    required this.title,
    required this.titleEs,
    required this.icon,
    required this.color,
    required this.questions,
  });
}

// ── Base de dados de perguntas ────────────────────────────────────────────────
const _kSections = <_Section>[
  // ── GERAL ──────────────────────────────────────────────────────────────────
  _Section(
    id: 'geral',
    title: 'Geral',
    titleEs: 'General',
    icon: Icons.person_outline_rounded,
    color: Color(0xFF10B981),
    questions: [
      _Question(
        id: 'estado_geral',
        label: 'Estado geral',
        labelEs: 'Estado general',
        hint: 'BEG, REG, MEG...',
        hintEs: 'BEG, REG, MEG...',
        options: ['BEG', 'REG', 'MEG'],
        optionsEs: ['BEG', 'REG', 'MEG'],
      ),
      _Question(
        id: 'consciencia',
        label: 'Nível de consciência',
        labelEs: 'Nivel de conciencia',
        hint: 'Lúcido e orientado...',
        hintEs: 'Lúcido y orientado...',
        options: ['Lúcido e orientado', 'Confuso', 'Torporoso', 'Comatoso'],
        optionsEs: ['Lúcido y orientado', 'Confuso', 'Estuporoso', 'Comatoso'],
      ),
      _Question(
        id: 'coloracao',
        label: 'Coloração / perfusão',
        labelEs: 'Coloración / perfusión',
        hint: 'Corado, normocorado, pálido...',
        hintEs: 'Coloreado, normocoloreado, pálido...',
        options: ['Normocorado', 'Pálido +', 'Pálido ++', 'Pálido +++'],
        optionsEs: ['Normocoloreado', 'Pálido +', 'Pálido ++', 'Pálido +++'],
      ),
      _Question(
        id: 'hidratacao',
        label: 'Hidratação',
        labelEs: 'Hidratación',
        hint: 'Hidratado, desidratado leve...',
        hintEs: 'Hidratado, deshidratado leve...',
        options: ['Hidratado', 'Desidratado +', 'Desidratado ++', 'Desidratado +++'],
        optionsEs: ['Hidratado', 'Deshidratado +', 'Deshidratado ++', 'Deshidratado +++'],
      ),
      _Question(
        id: 'acianose',
        label: 'Cianose',
        labelEs: 'Cianosis',
        hint: 'Acianótico, cianose central...',
        hintEs: 'Acianótico, cianosis central...',
        options: ['Acianótico', 'Cianose periférica', 'Cianose central'],
        optionsEs: ['Acianótico', 'Cianosis periférica', 'Cianosis central'],
      ),
      _Question(
        id: 'aicterica',
        label: 'Icterícia',
        labelEs: 'Ictericia',
        hint: 'Aictérico, ictérico +/+++...',
        hintEs: 'Anictérico, ictérico +/+++...',
        options: ['Aictérico', 'Ictérico +', 'Ictérico ++', 'Ictérico +++'],
        optionsEs: ['Anictérico', 'Ictérico +', 'Ictérico ++', 'Ictérico +++'],
      ),
      _Question(
        id: 'afebril',
        label: 'Temperatura / estado febril',
        labelEs: 'Temperatura / estado febril',
        hint: 'Afebril, febril (38,5°C)...',
        hintEs: 'Afebril, febril (38,5°C)...',
        options: ['Afebril', 'Subfebril', 'Febril', 'Hipertérmico'],
        optionsEs: ['Afebril', 'Subfebril', 'Febril', 'Hipertérmico'],
      ),
      _Question(
        id: 'edema',
        label: 'Edema',
        labelEs: 'Edema',
        hint: 'Ausente, MMII ++/4+...',
        hintEs: 'Ausente, EEII ++/4+...',
        options: ['Ausente', 'MMII +/4+', 'MMII ++/4+', 'MMII +++/4+', 'Anasarca'],
        optionsEs: ['Ausente', 'EEII +/4+', 'EEII ++/4+', 'EEII +++/4+', 'Anasarca'],
      ),
      _Question(
        id: 'estado_nutricional',
        label: 'Estado nutricional',
        labelEs: 'Estado nutricional',
        hint: 'Eutrófico, emagrecido, obeso...',
        hintEs: 'Eutrófico, adelgazado, obeso...',
        options: ['Eutrófico', 'Emagrecido', 'Sobrepeso', 'Obeso'],
        optionsEs: ['Eutrófico', 'Adelgazado', 'Sobrepeso', 'Obeso'],
        detailedOnly: true,
      ),
      _Question(
        id: 'mobilidade',
        label: 'Mobilidade / deambulação',
        labelEs: 'Movilidad / deambulación',
        hint: 'Deambula sem auxílio, acamado...',
        hintEs: 'Deambula sin ayuda, encamado...',
        options: ['Deambula sem auxílio', 'Deambula com auxílio', 'Acamado'],
        optionsEs: ['Deambula sin ayuda', 'Deambula con ayuda', 'Encamado'],
        detailedOnly: true,
      ),
    ],
  ),

  // ── SINAIS VITAIS ──────────────────────────────────────────────────────────
  _Section(
    id: 'vitais',
    title: 'Sinais Vitais',
    titleEs: 'Signos Vitales',
    icon: Icons.favorite_outline_rounded,
    color: Color(0xFFDC2626),
    questions: [
      _Question(
        id: 'pa',
        label: 'Pressão arterial (mmHg)',
        labelEs: 'Presión arterial (mmHg)',
        hint: '120/80',
        hintEs: '120/80',
        options: [],
        optionsEs: [],
      ),
      _Question(
        id: 'fc',
        label: 'Frequência cardíaca (bpm)',
        labelEs: 'Frecuencia cardíaca (lpm)',
        hint: '72',
        hintEs: '72',
        options: [],
        optionsEs: [],
      ),
      _Question(
        id: 'fr',
        label: 'Frequência respiratória (irpm)',
        labelEs: 'Frecuencia respiratoria (rpm)',
        hint: '16',
        hintEs: '16',
        options: [],
        optionsEs: [],
      ),
      _Question(
        id: 'temp',
        label: 'Temperatura (°C)',
        labelEs: 'Temperatura (°C)',
        hint: '36,8',
        hintEs: '36,8',
        options: [],
        optionsEs: [],
      ),
      _Question(
        id: 'spo2',
        label: 'Saturação O₂ (%)',
        labelEs: 'Saturación O₂ (%)',
        hint: '98',
        hintEs: '98',
        options: [],
        optionsEs: [],
      ),
      _Question(
        id: 'dextro',
        label: 'Glicemia capilar (mg/dL)',
        labelEs: 'Glucemia capilar (mg/dL)',
        hint: '95',
        hintEs: '95',
        options: [],
        optionsEs: [],
      ),
      _Question(
        id: 'peso',
        label: 'Peso (kg)',
        labelEs: 'Peso (kg)',
        hint: '70',
        hintEs: '70',
        options: [],
        optionsEs: [],
        detailedOnly: true,
      ),
      _Question(
        id: 'altura',
        label: 'Altura (cm)',
        labelEs: 'Talla (cm)',
        hint: '170',
        hintEs: '170',
        options: [],
        optionsEs: [],
        detailedOnly: true,
      ),
    ],
  ),

  // ── CABEÇA E PESCOÇO ───────────────────────────────────────────────────────
  _Section(
    id: 'cabeca',
    title: 'Cabeça e Pescoço',
    titleEs: 'Cabeza y Cuello',
    icon: Icons.face_rounded,
    color: Color(0xFF7C3AED),
    questions: [
      _Question(
        id: 'cranio',
        label: 'Crânio',
        labelEs: 'Cráneo',
        hint: 'Normocéfalo, sem abaulamentos...',
        hintEs: 'Normocéfalo, sin abultamientos...',
        options: ['Normocéfalo, sem alterações', 'Com alteração (descrever)'],
        optionsEs: ['Normocéfalo, sin alteraciones', 'Con alteración (describir)'],
      ),
      _Question(
        id: 'olhos',
        label: 'Olhos / pupilas',
        labelEs: 'Ojos / pupilas',
        hint: 'Pupilas isocóricas e fotorreativas...',
        hintEs: 'Pupilas isocóricas y fotorreactivas...',
        options: ['Pupilas isocóricas fotorreativas', 'Anisocoria', 'Midríase', 'Miose'],
        optionsEs: ['Pupilas isocóricas fotorreactivas', 'Anisocoria', 'Midriasis', 'Miosis'],
      ),
      _Question(
        id: 'mucosas',
        label: 'Mucosas orais',
        labelEs: 'Mucosas orales',
        hint: 'Úmidas e coradas, ressecadas...',
        hintEs: 'Húmedas y coloreadas, resecas...',
        options: ['Úmidas e coradas', 'Ressecadas', 'Hipocoradas'],
        optionsEs: ['Húmedas y coloreadas', 'Resecas', 'Hipocoloreadas'],
      ),
      _Question(
        id: 'pescoco',
        label: 'Pescoço / JVP',
        labelEs: 'Cuello / PVY',
        hint: 'Sem adenomegalias, JVP normal...',
        hintEs: 'Sin adenomegalias, PVY normal...',
        options: ['Sem adenomegalias, JVP normal', 'Adenomegalia presente', 'TJP aumentada'],
        optionsEs: ['Sin adenomegalias, PVY normal', 'Adenomegalia presente', 'PVY aumentada'],
      ),
      _Question(
        id: 'tireoide',
        label: 'Tireoide',
        labelEs: 'Tiroides',
        hint: 'Não palpável, sem bócio...',
        hintEs: 'No palpable, sin bocio...',
        options: ['Não palpável', 'Bócio grau I', 'Bócio grau II'],
        optionsEs: ['No palpable', 'Bocio grado I', 'Bocio grado II'],
        detailedOnly: true,
      ),
      _Question(
        id: 'meningismo',
        label: 'Sinais meníngeos',
        labelEs: 'Signos meníngeos',
        hint: 'Rigidez de nuca negativa...',
        hintEs: 'Rigidez de nuca negativa...',
        options: ['Rigidez de nuca negativa', 'Kernig negativo', 'Brudzinski negativo', 'Meningismo presente'],
        optionsEs: ['Rigidez de nuca negativa', 'Kernig negativo', 'Brudzinski negativo', 'Meningismo presente'],
        detailedOnly: true,
      ),
    ],
  ),

  // ── CARDIOVASCULAR ────────────────────────────────────────────────────────
  _Section(
    id: 'cardio',
    title: 'Cardiovascular',
    titleEs: 'Cardiovascular',
    icon: Icons.monitor_heart_rounded,
    color: Color(0xFFDC2626),
    questions: [
      _Question(
        id: 'ritmo',
        label: 'Ritmo cardíaco',
        labelEs: 'Ritmo cardíaco',
        hint: 'Rítmico, arrítmico...',
        hintEs: 'Rítmico, arrítmico...',
        options: ['Rítmico', 'Arrítmico', 'Irregular'],
        optionsEs: ['Rítmico', 'Arrítmico', 'Irregular'],
      ),
      _Question(
        id: 'bulhas',
        label: 'Bulhas cardíacas',
        labelEs: 'Ruidos cardíacos',
        hint: 'RCR 2T normofonéticas, sem sopros...',
        hintEs: 'RC 2T normofonéticos, sin soplos...',
        options: ['RCR 2T normofonéticas', 'RCR 2T hipofonéticas', 'RCR 3T', 'RCR 4T'],
        optionsEs: ['RC 2T normofonéticos', 'RC 2T hipofonéticos', 'RC 3T', 'RC 4T'],
      ),
      _Question(
        id: 'sopro',
        label: 'Sopros',
        labelEs: 'Soplos',
        hint: 'Sem sopros, sopro sistólico 2+/6+ em foco aórtico...',
        hintEs: 'Sin soplos, soplo sistólico 2+/6+ en foco aórtico...',
        options: ['Sem sopros', 'Sopro sistólico', 'Sopro diastólico', 'Sopro holossistólico'],
        optionsEs: ['Sin soplos', 'Soplo sistólico', 'Soplo diastólico', 'Soplo holosistólico'],
      ),
      _Question(
        id: 'pulso',
        label: 'Pulsos periféricos',
        labelEs: 'Pulsos periféricos',
        hint: 'Pulsos cheios, simétricos, amplos...',
        hintEs: 'Pulsos llenos, simétricos, amplios...',
        options: ['Cheios e simétricos', 'Diminuídos', 'Filiformes', 'Ausentes'],
        optionsEs: ['Llenos y simétricos', 'Disminuidos', 'Filiformes', 'Ausentes'],
      ),
      _Question(
        id: 'tec',
        label: 'Tempo de enchimento capilar (s)',
        labelEs: 'Tiempo de llenado capilar (s)',
        hint: '< 2s',
        hintEs: '< 2s',
        options: ['< 2s (normal)', '2–3s', '> 3s (prolongado)'],
        optionsEs: ['< 2s (normal)', '2–3s', '> 3s (prolongado)'],
      ),
      _Question(
        id: 'ictus',
        label: 'Ictus cordis',
        labelEs: 'Choque de punta',
        hint: 'Não palpável, 5° EIE LMC...',
        hintEs: 'No palpable, 5° EII LMC...',
        options: ['Não palpável', 'Normal (5° EIE LMC)', 'Deslocado'],
        optionsEs: ['No palpable', 'Normal (5° EII LMC)', 'Desplazado'],
        detailedOnly: true,
      ),
    ],
  ),

  // ── RESPIRATÓRIO ──────────────────────────────────────────────────────────
  _Section(
    id: 'respiratorio',
    title: 'Respiratório',
    titleEs: 'Respiratorio',
    icon: Icons.air_rounded,
    color: Color(0xFF0891B2),
    questions: [
      _Question(
        id: 'torax',
        label: 'Inspeção do tórax',
        labelEs: 'Inspección del tórax',
        hint: 'Simétrico, expansibilidade preservada...',
        hintEs: 'Simétrico, expansibilidad conservada...',
        options: ['Simétrico, expansibilidade preservada', 'Assimétrico', 'Taquipneico', 'Esforço respiratório'],
        optionsEs: ['Simétrico, expansibilidad conservada', 'Asimétrico', 'Taquipneico', 'Trabajo respiratorio'],
      ),
      _Question(
        id: 'mv',
        label: 'Murmúrio vesicular (MV)',
        labelEs: 'Murmullo vesicular (MV)',
        hint: 'MV+ bilateral sem ruídos adventícios...',
        hintEs: 'MV+ bilateral sin ruidos adventicios...',
        options: ['MV+ bilateral sem RA', 'MV diminuído à direita', 'MV diminuído à esquerda', 'MV abolido'],
        optionsEs: ['MV+ bilateral sin RA', 'MV disminuido a derecha', 'MV disminuido a izquierda', 'MV abolido'],
      ),
      _Question(
        id: 'ruidos',
        label: 'Ruídos adventícios',
        labelEs: 'Ruidos adventicios',
        hint: 'Sem RA, crepitações, sibilos...',
        hintEs: 'Sin RA, crepitantes, sibilancias...',
        options: ['Sem RA', 'Crepitações em bases', 'Sibilos difusos', 'Roncos', 'Atrito pleural'],
        optionsEs: ['Sin RA', 'Crepitantes en bases', 'Sibilancias difusas', 'Roncus', 'Frote pleural'],
      ),
      _Question(
        id: 'percussao',
        label: 'Percussão',
        labelEs: 'Percusión',
        hint: 'Sonoridade preservada, macicez...',
        hintEs: 'Sonoridad conservada, matidez...',
        options: ['Sonoridade preservada', 'Macicez em base D', 'Macicez em base E', 'Hipersonoridade'],
        optionsEs: ['Sonoridad conservada', 'Matidez en base D', 'Matidez en base I', 'Hiperresonancia'],
        detailedOnly: true,
      ),
      _Question(
        id: 'dispneia_tipo',
        label: 'Dispneia (se presente)',
        labelEs: 'Disnea (si presente)',
        hint: 'Ausente, aos grandes esforços...',
        hintEs: 'Ausente, a grandes esfuerzos...',
        options: ['Ausente', 'Aos grandes esforços', 'Aos pequenos esforços', 'Em repouso', 'Ortopneia'],
        optionsEs: ['Ausente', 'A grandes esfuerzos', 'A pequeños esfuerzos', 'En reposo', 'Ortopnea'],
        detailedOnly: true,
      ),
    ],
  ),

  // ── ABDOME ────────────────────────────────────────────────────────────────
  _Section(
    id: 'abdome',
    title: 'Abdome',
    titleEs: 'Abdomen',
    icon: Icons.radio_button_unchecked_rounded,
    color: Color(0xFFD97706),
    questions: [
      _Question(
        id: 'inspecao_abd',
        label: 'Inspeção',
        labelEs: 'Inspección',
        hint: 'Plano, escavado, globoso, distendido...',
        hintEs: 'Plano, excavado, globoso, distendido...',
        options: ['Plano', 'Escavado', 'Globoso', 'Distendido', 'Gravídico'],
        optionsEs: ['Plano', 'Excavado', 'Globoso', 'Distendido', 'Grávido'],
      ),
      _Question(
        id: 'rha',
        label: 'Ruídos hidroaéreos (RHA)',
        labelEs: 'Ruidos hidroaéreos (RHA)',
        hint: 'RHA+ normoativos...',
        hintEs: 'RHA+ normoactivos...',
        options: ['RHA+ normoativos', 'RHA+ hipoativos', 'RHA+ hiperativos', 'RHA ausentes'],
        optionsEs: ['RHA+ normoactivos', 'RHA+ hipoactivos', 'RHA+ hiperactivos', 'RHA ausentes'],
      ),
      _Question(
        id: 'palpacao',
        label: 'Palpação',
        labelEs: 'Palpación',
        hint: 'Indolor à palpação superficial e profunda...',
        hintEs: 'Indoloro a la palpación superficial y profunda...',
        options: ['Indolor à palpação', 'Dor à palpação superficial', 'Dor à palpação profunda', 'Resistência abdominal'],
        optionsEs: ['Indoloro a la palpación', 'Dolor a palpación superficial', 'Dolor a palpación profunda', 'Resistencia abdominal'],
      ),
      _Question(
        id: 'visceras',
        label: 'Vísceras / massas',
        labelEs: 'Vísceras / masas',
        hint: 'Sem hepatoesplenomegalia, sem massas...',
        hintEs: 'Sin hepatoesplenomegalia, sin masas...',
        options: ['Sem hepatoesplenomegalia', 'Hepatomegalia', 'Esplenomegalia', 'Massa palpável'],
        optionsEs: ['Sin hepatoesplenomegalia', 'Hepatomegalia', 'Esplenomegalia', 'Masa palpable'],
      ),
      _Question(
        id: 'sinal_peritonio',
        label: 'Sinais peritoneais',
        labelEs: 'Signos peritoneales',
        hint: 'Blumberg negativo, Murphy negativo...',
        hintEs: 'Blumberg negativo, Murphy negativo...',
        options: ['Blumberg negativo', 'Blumberg positivo', 'Murphy negativo', 'Murphy positivo'],
        optionsEs: ['Blumberg negativo', 'Blumberg positivo', 'Murphy negativo', 'Murphy positivo'],
        detailedOnly: true,
      ),
      _Question(
        id: 'ascite',
        label: 'Ascite',
        labelEs: 'Ascitis',
        hint: 'Sem ascite, piparote negativo...',
        hintEs: 'Sin ascitis, signo de la oleada negativo...',
        options: ['Sem ascite', 'Macicez móvel +', 'Piparote positivo'],
        optionsEs: ['Sin ascitis', 'Matidez desplazable +', 'Signo de la oleada positivo'],
        detailedOnly: true,
      ),
    ],
  ),

  // ── NEUROLÓGICO ───────────────────────────────────────────────────────────
  _Section(
    id: 'neuro',
    title: 'Neurológico',
    titleEs: 'Neurológico',
    icon: Icons.psychology_rounded,
    color: Color(0xFF6B21A8),
    questions: [
      _Question(
        id: 'glasgow',
        label: 'Escala de Glasgow',
        labelEs: 'Escala de Glasgow',
        hint: 'Olhos: 4, Verbal: 5, Motor: 6 = 15/15',
        hintEs: 'Ocular: 4, Verbal: 5, Motor: 6 = 15/15',
        options: ['15/15 (normal)', '14/15', '13/15', '< 13 (descrever)'],
        optionsEs: ['15/15 (normal)', '14/15', '13/15', '< 13 (describir)'],
      ),
      _Question(
        id: 'orientacao',
        label: 'Orientação',
        labelEs: 'Orientación',
        hint: 'Orientado no tempo e espaço...',
        hintEs: 'Orientado en tiempo y espacio...',
        options: ['Orientado em tempo e espaço', 'Desorientado no tempo', 'Desorientado no espaço', 'Desorientação global'],
        optionsEs: ['Orientado en tiempo y espacio', 'Desorientado en tiempo', 'Desorientado en espacio', 'Desorientación global'],
      ),
      _Question(
        id: 'forca',
        label: 'Força muscular',
        labelEs: 'Fuerza muscular',
        hint: 'Força preservada globalmente, 5/5...',
        hintEs: 'Fuerza conservada globalmente, 5/5...',
        options: ['Preservada globalmente 5/5', 'Hemiparesia D', 'Hemiparesia E', 'Paraparesia', 'Tetraparesia'],
        optionsEs: ['Conservada globalmente 5/5', 'Hemiparesia D', 'Hemiparesia I', 'Paraparesia', 'Tetraparesia'],
      ),
      _Question(
        id: 'marcha',
        label: 'Marcha',
        labelEs: 'Marcha',
        hint: 'Normal, atáxica, espástica...',
        hintEs: 'Normal, atáxica, espástica...',
        options: ['Normal', 'Atáxica', 'Espástica', 'Parkinsoniana', 'Antálgica'],
        optionsEs: ['Normal', 'Atáxica', 'Espástica', 'Parkinsoniana', 'Antálgica'],
        detailedOnly: true,
      ),
      _Question(
        id: 'reflexos',
        label: 'Reflexos',
        labelEs: 'Reflejos',
        hint: 'Reflexos preservados e simétricos...',
        hintEs: 'Reflejos conservados y simétricos...',
        options: ['Preservados e simétricos', 'Hiperreflexia', 'Hiporreflexia', 'Babinski presente'],
        optionsEs: ['Conservados y simétricos', 'Hiperreflexia', 'Hiporreflexia', 'Babinski presente'],
        detailedOnly: true,
      ),
      _Question(
        id: 'fala',
        label: 'Linguagem / fala',
        labelEs: 'Lenguaje / habla',
        hint: 'Fluente, coerente, sem disartria...',
        hintEs: 'Fluente, coherente, sin disartria...',
        options: ['Fluente e coerente', 'Disartria', 'Afasia de Broca', 'Afasia de Wernicke'],
        optionsEs: ['Fluente y coherente', 'Disartria', 'Afasia de Broca', 'Afasia de Wernicke'],
        detailedOnly: true,
      ),
      _Question(
        id: 'nc',
        label: 'Nervos cranianos',
        labelEs: 'Nervios craneales',
        hint: 'Pares cranianos preservados...',
        hintEs: 'Pares craneales conservados...',
        options: ['Preservados', 'VII par paralisado', 'Alteração oculomotora'],
        optionsEs: ['Conservados', 'VII par paralizado', 'Alteración oculomotora'],
        detailedOnly: true,
      ),
    ],
  ),

  // ── MEMBROS ───────────────────────────────────────────────────────────────
  _Section(
    id: 'membro',
    title: 'Membros',
    titleEs: 'Extremidades',
    icon: Icons.accessibility_new_rounded,
    color: Color(0xFF065F46),
    questions: [
      _Question(
        id: 'mmss',
        label: 'Membros superiores',
        labelEs: 'Extremidades superiores',
        hint: 'Sem edema, sem cianose, pulsos palpáveis...',
        hintEs: 'Sin edema, sin cianosis, pulsos palpables...',
        options: ['Sem edema ou alterações', 'Edema MMSS', 'Cianose de extremidades', 'Dedos em baqueta'],
        optionsEs: ['Sin edema ni alteraciones', 'Edema EESS', 'Cianosis de extremidades', 'Acropaquia'],
      ),
      _Question(
        id: 'mmii',
        label: 'Membros inferiores',
        labelEs: 'Extremidades inferiores',
        hint: 'Sem edema, sem varizes, pulsos palpáveis...',
        hintEs: 'Sin edema, sin varices, pulsos palpables...',
        options: ['Sem edema ou varizes', 'Edema MMII +/4+', 'Edema MMII ++/4+', 'Edema MMII +++/4+'],
        optionsEs: ['Sin edema ni varices', 'Edema EEII +/4+', 'Edema EEII ++/4+', 'Edema EEII +++/4+'],
      ),
      _Question(
        id: 'varizes',
        label: 'Varizes',
        labelEs: 'Várices',
        hint: 'Ausentes, presentes em safena...',
        hintEs: 'Ausentes, presentes en safena...',
        options: ['Ausentes', 'Varizes tronculares', 'Varizes reticulares'],
        optionsEs: ['Ausentes', 'Várices tronculares', 'Várices reticulares'],
        detailedOnly: true,
      ),
      _Question(
        id: 'dvt',
        label: 'Sinal de TVP',
        labelEs: 'Signo de TVP',
        hint: 'Sinal de Homans negativo...',
        hintEs: 'Signo de Homans negativo...',
        options: ['Homans negativo', 'Homans positivo', 'Edema assimétrico'],
        optionsEs: ['Homans negativo', 'Homans positivo', 'Edema asimétrico'],
        detailedOnly: true,
      ),
      _Question(
        id: 'pele',
        label: 'Pele / fâneros',
        labelEs: 'Piel / faneras',
        hint: 'Íntegra, sem lesões ativas...',
        hintEs: 'Íntegra, sin lesiones activas...',
        options: ['Íntegra sem lesões', 'Lesões eritematosas', 'Úlceras', 'Xantomas'],
        optionsEs: ['Íntegra sin lesiones', 'Lesiones eritematosas', 'Úlceras', 'Xantomas'],
        detailedOnly: true,
      ),
    ],
  ),

  // ── OUTROS ────────────────────────────────────────────────────────────────
  _Section(
    id: 'outros',
    title: 'Outros',
    titleEs: 'Otros',
    icon: Icons.add_circle_outline_rounded,
    color: Color(0xFF374151),
    questions: [
      _Question(
        id: 'coluna',
        label: 'Coluna vertebral',
        labelEs: 'Columna vertebral',
        hint: 'Sem desvios, sem dor à palpação...',
        hintEs: 'Sin desviaciones, sin dolor a la palpación...',
        options: ['Sem desvios ou dor', 'Dor lombar', 'Dor cervical', 'Escoliose'],
        optionsEs: ['Sin desviaciones ni dolor', 'Dolor lumbar', 'Dolor cervical', 'Escoliosis'],
        detailedOnly: true,
      ),
      _Question(
        id: 'linfonodos',
        label: 'Linfonodos',
        labelEs: 'Ganglios linfáticos',
        hint: 'Cadeias ganglionares impalpáveis...',
        hintEs: 'Cadenas ganglionares no palpables...',
        options: ['Impalpáveis', 'Cervicais palpáveis', 'Axilares palpáveis', 'Inguinais palpáveis'],
        optionsEs: ['No palpables', 'Cervicales palpables', 'Axilares palpables', 'Inguinales palpables'],
        detailedOnly: true,
      ),
      _Question(
        id: 'retal',
        label: 'Toque retal (se indicado)',
        labelEs: 'Tacto rectal (si indicado)',
        hint: 'Não realizado / próstata normal...',
        hintEs: 'No realizado / próstata normal...',
        options: ['Não realizado', 'Próstata normal', 'Próstata aumentada', 'Ampola retal vazia'],
        optionsEs: ['No realizado', 'Próstata normal', 'Próstata aumentada', 'Ampolla rectal vacía'],
        detailedOnly: true,
      ),
      _Question(
        id: 'observacoes',
        label: 'Observações adicionais',
        labelEs: 'Observaciones adicionales',
        hint: 'Achados relevantes não contemplados acima...',
        hintEs: 'Hallazgos relevantes no contemplados arriba...',
        options: [],
        optionsEs: [],
        multiline: true,
        lines: 3,
      ),
    ],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// TELA PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class AvaliacaoScreen extends StatefulWidget {
  const AvaliacaoScreen({super.key});
  @override
  State<AvaliacaoScreen> createState() => _AvaliacaoScreenState();
}

class _AvaliacaoScreenState extends State<AvaliacaoScreen> {
  bool _detailed = false;   // false = Básico, true = Detalhado
  int  _sectionIdx = 0;

  // Mapa chave → TextEditingController
  late final Map<String, TextEditingController> _ctrls;
  // Mapa chave → chips selecionados (pode ser multi-select)
  final Map<String, Set<String>> _chips = {};

  final _pageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _ctrls = {};
    for (final sec in _kSections) {
      for (final q in sec.questions) {
        _ctrls[q.id] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── Compila resultado como texto formatado ────────────────────────────────
  String _compileResult(bool isEs) {
    final buf = StringBuffer();
    for (final sec in _kSections) {
      final visibleQ = _detailed
          ? sec.questions
          : sec.questions.where((q) => !q.detailedOnly).toList();
      final parts = <String>[];
      for (final q in visibleQ) {
        final chips = (_chips[q.id] ?? {}).join(', ');
        final text  = _ctrls[q.id]!.text.trim();
        final val   = [chips, text].where((s) => s.isNotEmpty).join(' — ');
        if (val.isNotEmpty) {
          parts.add('${isEs ? q.labelEs : q.label}: $val');
        }
      }
      if (parts.isNotEmpty) {
        buf.writeln(isEs ? sec.titleEs.toUpperCase() : sec.title.toUpperCase());
        for (final p in parts) buf.writeln('  $p');
        buf.writeln();
      }
    }
    return buf.toString().trim();
  }

  // ── Verifica se há algum dado preenchido ─────────────────────────────────
  bool get _hasData {
    for (final sec in _kSections) {
      for (final q in sec.questions) {
        if (_ctrls[q.id]!.text.trim().isNotEmpty) return true;
        if ((_chips[q.id] ?? {}).isNotEmpty) return true;
      }
    }
    return false;
  }

  // ── Salvar na História Clínica ────────────────────────────────────────────
  void _saveToHistory(BuildContext ctx, AppProvider p) {
    final isEs = p.lang == 'es';
    final text = _compileResult(isEs);
    if (text.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(isEs ? 'No hay datos para guardar.' : 'Nenhum dado preenchido.'),
      ));
      return;
    }
    final uid   = p.currentUser?.uid ?? 'local';
    final name  = p.currentUser?.displayName ?? p.currentUser?.email ?? (isEs ? 'Anónimo' : 'Anônimo');
    final email = p.currentUser?.email ?? '';
    final hc = ClinicalHistoryModel.blank(authorUid: uid, authorName: name, authorEmail: email)
        .copyWith(physicalExam: text);
    p.saveHistory(hc);
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(isEs ? 'Guardado en Historia Clínica' : 'Salvo na História Clínica'),
      backgroundColor: _kGreen,
    ));
    Navigator.of(ctx).pop();
  }

  // ── Copiar para área de transferência ────────────────────────────────────
  void _copyText(BuildContext ctx, AppProvider p) {
    final isEs = p.lang == 'es';
    final text = _compileResult(isEs);
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Text(isEs ? 'Copiado al portapapeles' : 'Copiado para a área de transferência'),
      backgroundColor: _kGreen,
    ));
  }

  // ── Apagar tudo ───────────────────────────────────────────────────────────
  void _clearAll(BuildContext ctx, AppProvider p) {
    final isEs = p.lang == 'es';
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          isEs ? 'Descartar evaluación' : 'Descartar avaliação',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          isEs ? '¿Eliminar todos los datos ingresados?' : 'Apagar todos os dados preenchidos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isEs ? 'Cancelar' : 'Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                for (final c in _ctrls.values) c.clear();
                _chips.clear();
              });
            },
            child: Text(
              isEs ? 'Eliminar' : 'Apagar',
              style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  // ── Navegar entre seções ──────────────────────────────────────────────────
  void _goTo(int idx) {
    setState(() => _sectionIdx = idx);
    _pageCtrl.animateToPage(idx,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final sec  = _kSections[_sectionIdx];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        _AvalHeader(
          isEs: isEs,
          detailed: _detailed,
          onToggleMode: () => setState(() => _detailed = !_detailed),
          onBack: () => _confirmBack(context, p),
        ),

        // ── Navegação de seções ─────────────────────────────────────────────
        _SectionNav(
          sections: _kSections,
          currentIdx: _sectionIdx,
          detailed: _detailed,
          isEs: isEs,
          chips: _chips,
          ctrls: _ctrls,
          onSelect: _goTo,
        ),

        // ── Conteúdo das perguntas (PageView) ──────────────────────────────
        Expanded(
          child: PageView.builder(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _kSections.length,
            itemBuilder: (_, i) {
              final s = _kSections[i];
              final visQ = _detailed
                  ? s.questions
                  : s.questions.where((q) => !q.detailedOnly).toList();
              return _SectionContent(
                section: s,
                questions: visQ,
                isEs: isEs,
                ctrls: _ctrls,
                chips: _chips,
                onChipChanged: (qid, val, selected) {
                  setState(() {
                    _chips.putIfAbsent(qid, () => <String>{});
                    if (selected) {
                      _chips[qid]!.add(val);
                    } else {
                      _chips[qid]!.remove(val);
                    }
                  });
                },
              );
            },
          ),
        ),

        // ── Barra de navegação seção anterior/próxima + ações ───────────────
        _BottomBar(
          sectionIdx: _sectionIdx,
          total: _kSections.length,
          isEs: isEs,
          hasData: _hasData,
          onPrev: _sectionIdx > 0 ? () => _goTo(_sectionIdx - 1) : null,
          onNext: _sectionIdx < _kSections.length - 1 ? () => _goTo(_sectionIdx + 1) : null,
          onSaveHistory: () => _saveToHistory(context, p),
          onCopy: () => _copyText(context, p),
          onClear: () => _clearAll(context, p),
          section: sec,
          isLastSection: _sectionIdx == _kSections.length - 1,
        ),
      ]),
    );
  }

  void _confirmBack(BuildContext ctx, AppProvider p) {
    if (!_hasData) { Navigator.of(ctx).pop(); return; }
    final isEs = p.lang == 'es';
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          isEs ? 'Salir sin guardar' : 'Sair sem salvar',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          isEs ? 'Los datos se perderán.' : 'Os dados preenchidos serão perdidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isEs ? 'Continuar' : 'Continuar'),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.of(ctx).pop(); },
            child: Text(
              isEs ? 'Salir' : 'Sair',
              style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _AvalHeader extends StatelessWidget {
  final bool isEs, detailed;
  final VoidCallback onToggleMode, onBack;
  const _AvalHeader({
    required this.isEs,
    required this.detailed,
    required this.onToggleMode,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F1116), Color(0xFF1B3D2A), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Row(children: [
            // Voltar
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            // Título — BUILD 283 ORDEM 7: padrão canônico (título w700/20 branco + subtítulo ouro)
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  isEs ? 'EVALUACIÓN FÍSICA' : 'AVALIAÇÃO FÍSICA',
                  style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: -0.2,
                  ),
                ),
                const Text(
                  'MEDCASES PRO',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: Color(0xFFD4AF37), letterSpacing: 1.2,
                  ),
                ),
              ]),
            ),
            // Toggle Básico / Detalhado
            GestureDetector(
              onTap: onToggleMode,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: detailed ? _kGold : Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: detailed ? _kGold : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    detailed ? Icons.zoom_in_rounded : Icons.zoom_out_rounded,
                    size: 13,
                    color: detailed ? _kDark : Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    detailed
                        ? (isEs ? 'Detallado' : 'Detalhado')
                        : (isEs ? 'Básico' : 'Básico'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: detailed ? _kDark : Colors.white,
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAVEGAÇÃO DE SEÇÕES (scroll horizontal)
// ─────────────────────────────────────────────────────────────────────────────
class _SectionNav extends StatelessWidget {
  final List<_Section> sections;
  final int currentIdx;
  final bool detailed, isEs;
  final Map<String, Set<String>> chips;
  final Map<String, TextEditingController> ctrls;
  final ValueChanged<int> onSelect;

  const _SectionNav({
    required this.sections,
    required this.currentIdx,
    required this.detailed,
    required this.isEs,
    required this.chips,
    required this.ctrls,
    required this.onSelect,
  });

  bool _sectionHasData(_Section s) {
    for (final q in s.questions) {
      if ((ctrls[q.id]?.text.trim().isNotEmpty ?? false)) return true;
      if ((chips[q.id] ?? {}).isNotEmpty) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // BUILD 283 ORDEM 7: green gradient continuity + circular(12) canonical pills
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F1116), // dark base — herda do TopBar
            Color(0xFF1B3D2A), // verde médio
            Color(0xFF10B981), // verde esmeralda
          ],
        ),
        border: Border(bottom: BorderSide(color: Color(0xFF1E2330), width: 0.5)),
      ),
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: sections.length,
        itemBuilder: (_, i) {
          final sec    = sections[i];
          final active = currentIdx == i;
          final filled = _sectionHasData(sec);
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: active
                    ? Colors.white.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: active
                      ? Colors.white.withValues(alpha: 0.70)
                      : (filled
                          ? const Color(0xFF10B981).withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.18)),
                  width: active ? 1.5 : 1,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  sec.icon,
                  size: 12,
                  color: active ? Colors.white : (filled ? sec.color : Colors.white54),
                ),
                const SizedBox(width: 5),
                Text(
                  isEs ? sec.titleEs : sec.title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : (filled ? sec.color : Colors.white54),
                  ),
                ),
                if (filled && !active) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: sec.color),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTEÚDO DA SEÇÃO — perguntas com chips + texto livre
// ─────────────────────────────────────────────────────────────────────────────
class _SectionContent extends StatelessWidget {
  final _Section section;
  final List<_Question> questions;
  final bool isEs;
  final Map<String, TextEditingController> ctrls;
  final Map<String, Set<String>> chips;
  final Function(String qid, String val, bool selected) onChipChanged;

  const _SectionContent({
    required this.section,
    required this.questions,
    required this.isEs,
    required this.ctrls,
    required this.chips,
    required this.onChipChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: questions.length + 1, // +1 header
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: section.color,
                ),
                child: Icon(section.icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(
                isEs ? section.titleEs : section.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: section.color,
                ),
              ),
            ]),
          );
        }
        final q = questions[i - 1];
        return _QuestionCard(
          question: q,
          ctrl: ctrls[q.id]!,
          selectedChips: chips[q.id] ?? {},
          sectionColor: section.color,
          isEs: isEs,
          onChipChanged: (val, sel) => onChipChanged(q.id, val, sel),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE PERGUNTA
// ─────────────────────────────────────────────────────────────────────────────
class _QuestionCard extends StatelessWidget {
  final _Question question;
  final TextEditingController ctrl;
  final Set<String> selectedChips;
  final Color sectionColor;
  final bool isEs;
  final Function(String val, bool selected) onChipChanged;

  const _QuestionCard({
    required this.question,
    required this.ctrl,
    required this.selectedChips,
    required this.sectionColor,
    required this.isEs,
    required this.onChipChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Seleciona os dados corretos conforme idioma
    final label   = isEs ? question.labelEs   : question.label;
    final hint    = isEs ? question.hintEs    : question.hint;
    final options = isEs ? question.optionsEs : question.options;

    final hasSelection = selectedChips.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(
          color: hasSelection ? sectionColor.withValues(alpha: 0.35) : _kBorder,
          width: hasSelection ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Label
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
            color: hasSelection ? sectionColor : const Color(0xFF6B7280),
          ),
        ),
        // Chips de seleção rápida
        if (options.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((opt) {
              final sel = selectedChips.contains(opt);
              return GestureDetector(
                onTap: () => onChipChanged(opt, !sel),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: sel ? sectionColor : const Color(0xFFF3F4F6),
                    border: Border.all(
                      color: sel ? sectionColor : const Color(0xFFD1D5DB),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (sel) ...[
                      const Icon(Icons.check_rounded, size: 11, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      opt,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : const Color(0xFF444444),
                      ),
                    ),
                  ]),
                ),
              );
            }).toList(),
          ),
        ],
        // Campo de texto livre (para complementar ou quando sem chips)
        if (options.isEmpty || question.multiline) ...[
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            minLines: question.multiline ? question.lines : 1,
            maxLines: question.multiline ? null : 2,
            keyboardType: question.multiline ? TextInputType.multiline : TextInputType.text,
            // ── Sugestões nativas + autocorreção pelo idioma do teclado ──────
            enableSuggestions: true,
            autocorrect: true,
            textCapitalization: TextCapitalization.sentences,
            // ─────────────────────────────────────────────────────
            style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF222222),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: sectionColor, width: 1.5),
              ),
            ),
          ),
        ] else if (options.isNotEmpty && !question.multiline) ...[
          // Campo complementar compacto
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            maxLines: 1,
            // ── Sugestões nativas + autocorreção pelo idioma do teclado ──────
            enableSuggestions: true,
            autocorrect: true,
            textCapitalization: TextCapitalization.sentences,
            // ─────────────────────────────────────────────────────
            style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF555555),
            ),
            decoration: InputDecoration(
              hintText: isEs ? 'Complementar...' : 'Complementar...',
              hintStyle: const TextStyle(fontSize: 11, color: Color(0xFFA8B2C1)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: sectionColor),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BARRA INFERIOR — navegação + ações finais
// ─────────────────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int sectionIdx, total;
  final bool isEs, hasData, isLastSection;
  final VoidCallback? onPrev, onNext;
  final VoidCallback onSaveHistory, onCopy, onClear;
  final _Section section;

  const _BottomBar({
    required this.sectionIdx,
    required this.total,
    required this.isEs,
    required this.hasData,
    required this.isLastSection,
    required this.onPrev,
    required this.onNext,
    required this.onSaveHistory,
    required this.onCopy,
    required this.onClear,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Linha 1: Anterior / Progresso / Próximo
        Row(children: [
          // Anterior
          GestureDetector(
            onTap: onPrev,
            child: AnimatedOpacity(
              opacity: onPrev != null ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 150),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                  color: Colors.white,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.chevron_left_rounded, size: 18, color: _kDark),
                  Text(
                    isEs ? 'Anterior' : 'Anterior',
                    style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: _kDark,
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Indicador de progresso
          Expanded(
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  final active = i == sectionIdx;
                  final done   = i < sectionIdx;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: active
                          ? section.color
                          : (done
                              ? section.color.withValues(alpha: 0.4)
                              : _kBorder),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '${sectionIdx + 1} / $total',
                style: const TextStyle(
                  fontSize: 9, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          // Próximo / Siguiente
          GestureDetector(
            onTap: onNext,
            child: AnimatedOpacity(
              opacity: onNext != null ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 150),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: onNext != null ? section.color : Colors.grey.shade200,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    isEs ? 'Siguiente' : 'Próximo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: onNext != null ? Colors.white : const Color(0xFFAAAAAA),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: onNext != null ? Colors.white : const Color(0xFFAAAAAA),
                  ),
                ]),
              ),
            ),
          ),
        ]),

        // Linha 2: Ações finais (visíveis ao chegar na última seção ou quando há dados)
        if (isLastSection || hasData) ...[
          const SizedBox(height: 10),
          Row(children: [
            // Apagar / Eliminar
            Expanded(
              child: GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                    ),
                    color: const Color(0xFFDC2626).withValues(alpha: 0.05),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                    const SizedBox(width: 5),
                    Text(
                      isEs ? 'Eliminar' : 'Apagar',
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFDC2626),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Copiar
            Expanded(
              child: GestureDetector(
                onTap: onCopy,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                    color: Colors.white,
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.copy_rounded, size: 15, color: _kDark),
                    const SizedBox(width: 5),
                    Text(
                      isEs ? 'Copiar' : 'Copiar',
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: _kDark,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Salvar na HC / Guardar en HC
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: onSaveHistory,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1116), Color(0xFF10B981)],
                    ),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.save_alt_rounded, size: 15, color: _kGold),
                    const SizedBox(width: 6),
                    Text(
                      isEs ? 'Guardar en HC' : 'Salvar na HC',
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}
