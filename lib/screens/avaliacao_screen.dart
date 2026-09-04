import 'dart:ui' show ImageFilter;
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
// MEDCASES_PHYSICAL_EXAM_VISUAL_DENSITY_REBALANCE_V1_B_R0_R3
// Escala visual LOCAL da Avaliação Física. Não altera tokens globais.
class _AssessmentVisualScale {
  const _AssessmentVisualScale._();

  static const double screenTitle = 16.0;
  static const double tabLabel = 11.0;
  static const double fieldHint = 11.0;
  static const double sectionLabel = 10.0;
  static const double clinicalOption = 12.5;
  static const double inputFree = 12.5;
  static const double inputComplement = 11.5;
  static const double navPrimary = 11.0;
  static const double navSecondary = 10.0;
  static const double progress = 8.5;
}

class AvaliacaoScreen extends StatefulWidget {
  const AvaliacaoScreen({
    super.key,
    this.embeddedInMainShell = false,
    this.onBack,
  });

  final bool embeddedInMainShell;
  final VoidCallback? onBack;
  @override
  State<AvaliacaoScreen> createState() => _AvaliacaoScreenState();
}

class _AvaliacaoScreenState extends State<AvaliacaoScreen> {
  // SUPER ORDEM MASTER 14 M11: modo Detalhado fixo — pill destruída
  final bool _detailed = true;
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
    final p = context.watch<AppProvider>();
    final isEs = p.lang == 'es';
    final sec = _kSections[_sectionIdx];
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pageBackground =
        dark ? const Color(0xFF1A1D23) : const Color(0xFFF7F8FA);

    return Scaffold(
      backgroundColor: pageBackground,
      // MainShell owns keyboard resize when Avaliação is embedded.
      resizeToAvoidBottomInset: !widget.embeddedInMainShell,
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        // SUPER ORDEM MASTER 14 M11: Cupertino TopBar
        _AvalHeader(
          isEs: isEs,
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

          reserveGlobalActionBar: widget.embeddedInMainShell &&
              MediaQuery.sizeOf(context).width < 768 &&
              MediaQuery.viewInsetsOf(context).bottom == 0,
        ),
      ]),
    );
  }

  // AVALIACAO_MAIN_SHELL_FOOTER_V1_B_R0_EXIT
  void _exitAvaliacao(BuildContext ctx) {
    if (widget.embeddedInMainShell && widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.of(ctx).pop();
  }

  void _confirmBack(BuildContext ctx, AppProvider p) {
    if (!_hasData) {
      _exitAvaliacao(ctx);
      return;
    }
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
            onPressed: () {
              Navigator.pop(ctx);
              _exitAvaliacao(ctx);
            },
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
// SUPER ORDEM MASTER 14 M11 — Cupertino TopBar pattern
// Destruído: subtítulo 'MEDCASES PRO' + pill toggle Básico/Detalhado
class _AvalHeader extends StatelessWidget {
  final bool isEs;
  final VoidCallback onBack;

  const _AvalHeader({
    required this.isEs,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final topbarGlass = dark
        ? const Color(0xFF252930).withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.70);
    final divider =
        dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    final text = dark ? Colors.white : const Color(0xFF05070A);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: topbarGlass,
            border: Border(
              bottom: BorderSide(color: divider, width: 0.7),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      isEs ? 'EVALUACIÓN FÍSICA' : 'AVALIAÇÃO FÍSICA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: text,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

  bool _sectionHasData(_Section section) {
    for (final question in section.questions) {
      if ((ctrls[question.id]?.text.trim().isNotEmpty ?? false)) {
        return true;
      }
      if ((chips[question.id] ?? {}).isNotEmpty) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
    final divider =
        dark ? const Color(0xFF374151) : const Color(0xFFE7EBEF);
    final inactiveColor =
        dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final activeColor =
        dark ? const Color(0xFF0D6B57) : const Color(0xFF0D6B57);
    final activeBackground = dark
        ? const Color(0xFF0D6B57).withValues(alpha: 0.10)
        : const Color(0xFF0D6B57).withValues(alpha: 0.08);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(color: divider, width: 0.7),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: sections.length,
        itemBuilder: (_, index) {
          final section = sections[index];
          final active = currentIdx == index;
          _sectionHasData(section);

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => onSelect(index),
                behavior: HitTestBehavior.opaque,
                child: IntrinsicWidth(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 40,
                    constraints: const BoxConstraints(minWidth: 92),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: active ? activeBackground : Colors.transparent,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: Text(
                            isEs ? section.titleEs : section.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: active ? activeColor : inactiveColor,
                              letterSpacing: 0.05,
                            ),
                          ),
                        ),
                        if (active)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 9,
                            child: Container(
                              height: 2,
                              color: const Color(0xFF0D6B57),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (index < sections.length - 1)
                SizedBox(
                  width: 0.7,
                  height: 40,
                  child: Center(
                    child: Container(
                      width: 0.7,
                      height: 20,
                      color: divider,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border =
        dark ? const Color(0xFF374151) : const Color(0xFFD8DEE7);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _SectionSurface.build(
          dark: dark,
          border: border,
          child: Column(
            children: [
              for (var index = 0;
                  index < questions.length;
                  index++) ...[
                _QuestionCard(
                  question: questions[index],
                  ctrl: ctrls[questions[index].id]!,
                  selectedChips:
                      chips[questions[index].id] ?? {},
                  sectionColor: section.color,
                  isEs: isEs,
                  onChipChanged: (value, selected) {
                    onChipChanged(
                      questions[index].id,
                      value,
                      selected,
                    );
                  },
                ),
                if (index < questions.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.7,
                    color: border,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionSurface {
  // Superfície clínica contínua, sem recuo ou bordas laterais.
  // ignore: unused_element
  const _SectionSurface();

  static Widget build({
    required bool dark,
    required Color border,
    required Widget child,
  }) {
    final surface =
        dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          top: BorderSide(color: border, width: 0.7),
          bottom: BorderSide(color: border, width: 0.7),
        ),
      ),
      child: child,
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final label = isEs ? question.labelEs : question.label;
    final hint = isEs ? question.hintEs : question.hint;
    final options = isEs ? question.optionsEs : question.options;

    final surface =
        dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
    final surfaceStrong =
        dark ? const Color(0xFF2D3340) : const Color(0xFFEFF2F5);
    final border =
        dark ? const Color(0xFF374151) : const Color(0xFFD8DEE7);
    final text =
        dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final secondary =
        dark ? const Color(0xFFB2C0D0) : const Color(0xFF6B7280);
    final hasSelection = selectedChips.isNotEmpty;

    InputDecoration fieldDecoration({
      required String fieldHint,
      required double radius,
      required EdgeInsetsGeometry contentPadding,
    }) {
      return InputDecoration(
        hintText: fieldHint,
        hintStyle: TextStyle(
          fontSize: _AssessmentVisualScale.fieldHint,
          color: secondary,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: options.isEmpty ? surface : surfaceStrong,
        isDense: true,
        contentPadding: contentPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: border, width: 0.7),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: border, width: 0.7),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: sectionColor, width: 1.2),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: _AssessmentVisualScale.sectionLabel,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: hasSelection ? sectionColor : secondary,
            ),
          ),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 7,
              children: options.map((option) {
                final selected = selectedChips.contains(option);

                return GestureDetector(
                  onTap: () => onChipChanged(option, !selected),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: selected
                              ? sectionColor
                              : border.withOpacity(
                                  dark ? 0.75 : 1.0,
                                ),
                          width: selected ? 2 : 0.7,
                        ),
                      ),
                    ),
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: _AssessmentVisualScale.clinicalOption,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: selected ? sectionColor : text,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            minLines: question.multiline ? question.lines : 1,
            maxLines: question.multiline
                ? null
                : (options.isEmpty ? 2 : 1),
            keyboardType: question.multiline
                ? TextInputType.multiline
                : TextInputType.text,
            enableSuggestions: true,
            autocorrect: true,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
              fontSize: options.isEmpty
                  ? _AssessmentVisualScale.inputFree
                  : _AssessmentVisualScale.inputComplement,
              fontWeight: FontWeight.w500,
              color: text,
            ),
            decoration: fieldDecoration(
              fieldHint: options.isEmpty
                  ? hint
                  : 'Complementar...',
              radius: options.isEmpty ? 10 : 8,
              contentPadding: EdgeInsets.symmetric(
                horizontal: options.isEmpty ? 10 : 9,
                vertical: options.isEmpty ? 8 : 7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BARRA INFERIOR — navegação + ações finais
// ─────────────────────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int sectionIdx, total;
  final bool isEs, hasData, isLastSection;
  final bool reserveGlobalActionBar;
  final VoidCallback? onPrev, onNext;
  final VoidCallback onSaveHistory, onCopy, onClear;
  final _Section section;

  const _BottomBar({
    required this.sectionIdx,
    required this.total,
    required this.isEs,
    required this.hasData,
    required this.isLastSection,
    required this.reserveGlobalActionBar,
    required this.onPrev,
    required this.onNext,
    required this.onSaveHistory,
    required this.onCopy,
    required this.onClear,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
    final surfaceStrong =
        dark ? const Color(0xFF2D3340) : const Color(0xFFEFF2F5);
    final border =
        dark ? const Color(0xFF374151) : _kBorder;
    final text = dark ? const Color(0xFFF8FAFC) : _kDark;
    final secondary =
        dark ? const Color(0xFFB2C0D0) : const Color(0xFF6B7280);

    final compactButtonStyle = TextButton.styleFrom(
      foregroundColor: text,
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 6,
      ),
      minimumSize: const Size(40, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    Color progressColor({
      required bool active,
      required bool done,
    }) {
      if (active) return section.color;
      if (done) return section.color.withOpacity(0.40);
      return border;
    }

    final primaryButtonStyle = FilledButton.styleFrom(
      backgroundColor: _kGreen,
      disabledBackgroundColor: surfaceStrong,
      foregroundColor: Colors.white,
      disabledForegroundColor: secondary,
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      minimumSize: const Size(40, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Container(
      // MEDCASES_PHYSICAL_EXAM_BOTTOM_BAR_TOTAL_LIFT_20PX_V1_B_R0
      padding: reserveGlobalActionBar
          ? EdgeInsets.fromLTRB(8, 5, 8, 112.0 + safeBottom)
          : const EdgeInsets.fromLTRB(8, 5, 8, 28),
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          top: BorderSide(color: border, width: 0.7),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: onPrev,
                style: compactButtonStyle,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  size: 19,
                ),
                label: Text(
                  isEs ? 'Anterior' : 'Anterior',
                  style: const TextStyle(
                    fontSize: _AssessmentVisualScale.navPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(total, (index) {
                        final active = index == sectionIdx;
                        final done = index < sectionIdx;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 2,
                          ),
                          width: active ? 14 : 5,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: progressColor(
                              active: active,
                              done: done,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${sectionIdx + 1} / $total',
                      style: TextStyle(
                        fontSize: _AssessmentVisualScale.progress,
                        color: secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: onNext,
                style: primaryButtonStyle,
                iconAlignment: IconAlignment.end,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                ),
                label: Text(
                  isEs ? 'Siguiente' : 'Próximo',
                  style: const TextStyle(
                    fontSize: _AssessmentVisualScale.navPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (isLastSection || hasData) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onClear,
                    style: compactButtonStyle.copyWith(
                      foregroundColor:
                          const WidgetStatePropertyAll(
                        Color(0xFFDC2626),
                      ),
                    ),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                    ),
                    label: Text(
                      isEs ? 'Eliminar' : 'Apagar',
                      style: const TextStyle(
                        fontSize: _AssessmentVisualScale.navSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onCopy,
                    style: compactButtonStyle,
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 15,
                    ),
                    label: const Text(
                      'Copiar',
                      style: TextStyle(
                        fontSize: _AssessmentVisualScale.navSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onSaveHistory,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      minimumSize: const Size(40, 40),
                      tapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.save_alt_rounded,
                      size: 15,
                      color: _kGold,
                    ),
                    label: Text(
                      isEs ? 'Guardar en HC' : 'Salvar na HC',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: _AssessmentVisualScale.navSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
