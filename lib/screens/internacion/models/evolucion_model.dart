// ─────────────────────────────────────────────────────────────────────────────
// EvolucionModel — modelo SOAP imutável
//
// Build 162: FarmacoEntry adicionado — medicamento + dosagem com CRUD manual
// e extração automática pela IA. EvolucionModel estendido com List<FarmacoEntry>.
// ─────────────────────────────────────────────────────────────────────────────
library internacion.models;

import 'package:flutter/foundation.dart';

// ── Fármaco com dosagem (Build 162) ──────────────────────────────────────────
@immutable
class FarmacoEntry {
  final String medicamento; // nome do fármaco
  final String dosagem;     // ex: "500 mg VO 8/8h", "40 mg EV 1x/dia"

  const FarmacoEntry({
    required this.medicamento,
    this.dosagem = '',
  });

  FarmacoEntry copyWith({String? medicamento, String? dosagem}) =>
      FarmacoEntry(
        medicamento: medicamento ?? this.medicamento,
        dosagem:     dosagem     ?? this.dosagem,
      );

  // JSON round-trip (para SharedPreferences)
  Map<String, dynamic> toJson() =>
      {'medicamento': medicamento, 'dosagem': dosagem};

  factory FarmacoEntry.fromJson(Map<String, dynamic> j) => FarmacoEntry(
        medicamento: j['medicamento']?.toString() ?? '',
        dosagem:     j['dosagem']?.toString()     ?? '',
      );
}

// ── Status clínico do paciente ────────────────────────────────────────────────
enum EstadoClinical { mejorando, estable, empeorando }

extension EstadoClinicalLabel on EstadoClinical {
  String label(String lang) {
    final isEs = lang == 'es';
    switch (this) {
      case EstadoClinical.mejorando:
        return isEs ? 'Mejorando' : 'Melhorando';
      case EstadoClinical.estable:
        return isEs ? 'Estable' : 'Estável';
      case EstadoClinical.empeorando:
        return isEs ? 'Empeorando' : 'Piorando';
    }
  }

  // Cor semântica para cada estado
  int get colorValue {
    switch (this) {
      case EstadoClinical.mejorando:  return 0xFF22C55E; // verde
      case EstadoClinical.estable:    return 0xFFF59E0B; // âmbar
      case EstadoClinical.empeorando: return 0xFFEF4444; // vermelho
    }
  }
}

// ── S — Subjetivo ─────────────────────────────────────────────────────────────
@immutable
class SubjetivoData {
  final String notePasaNoche;   // Como passou a noite
  final int?   dolorEscala;     // EVA 0-10
  final bool   fiebre;
  final bool   disnea;
  final bool   nauseas;
  final bool   tos;
  final String alimentacion;    // Bem / Regular / Mal
  final String diuresis;        // Normal / Oliguria / Anuria
  final String evacuacion;      // Normal / Constipado / Diarréia
  final bool   suenoRestado;
  final String notasLibres;

  const SubjetivoData({
    this.notePasaNoche = '',
    this.dolorEscala,
    this.fiebre = false,
    this.disnea = false,
    this.nauseas = false,
    this.tos = false,
    this.alimentacion = '',
    this.diuresis = '',
    this.evacuacion = '',
    this.suenoRestado = false,
    this.notasLibres = '',
  });

  SubjetivoData copyWith({
    String? notePasaNoche,
    int? dolorEscala,
    bool? fiebre,
    bool? disnea,
    bool? nauseas,
    bool? tos,
    String? alimentacion,
    String? diuresis,
    String? evacuacion,
    bool? suenoRestado,
    String? notasLibres,
  }) => SubjetivoData(
    notePasaNoche: notePasaNoche ?? this.notePasaNoche,
    dolorEscala:   dolorEscala ?? this.dolorEscala,
    fiebre:        fiebre ?? this.fiebre,
    disnea:        disnea ?? this.disnea,
    nauseas:       nauseas ?? this.nauseas,
    tos:           tos ?? this.tos,
    alimentacion:  alimentacion ?? this.alimentacion,
    diuresis:      diuresis ?? this.diuresis,
    evacuacion:    evacuacion ?? this.evacuacion,
    suenoRestado:  suenoRestado ?? this.suenoRestado,
    notasLibres:   notasLibres ?? this.notasLibres,
  );
}

// ── O — Objetivo ──────────────────────────────────────────────────────────────
@immutable
class SignosVitales {
  final String pa;          // Pressão arterial ex: "120/80"
  final String fc;          // Freq. cardíaca
  final String fr;          // Freq. respiratória
  final String satO2;       // SatO₂ %
  final String temperatura; // ºC

  const SignosVitales({
    this.pa = '', this.fc = '', this.fr = '',
    this.satO2 = '', this.temperatura = '',
  });

  SignosVitales copyWith({
    String? pa, String? fc, String? fr,
    String? satO2, String? temperatura,
  }) => SignosVitales(
    pa: pa ?? this.pa, fc: fc ?? this.fc, fr: fr ?? this.fr,
    satO2: satO2 ?? this.satO2, temperatura: temperatura ?? this.temperatura,
  );

  bool get isEmpty => pa.isEmpty && fc.isEmpty && fr.isEmpty
      && satO2.isEmpty && temperatura.isEmpty;
}

@immutable
class ExamenFisico {
  final String estadoGeneral;
  final String acv;         // Aparelho cardiovascular
  final String ar;          // Aparelho respiratório
  final String abdomen;
  final String extremidades;

  const ExamenFisico({
    this.estadoGeneral = '', this.acv = '', this.ar = '',
    this.abdomen = '', this.extremidades = '',
  });

  ExamenFisico copyWith({
    String? estadoGeneral, String? acv, String? ar,
    String? abdomen, String? extremidades,
  }) => ExamenFisico(
    estadoGeneral: estadoGeneral ?? this.estadoGeneral,
    acv: acv ?? this.acv, ar: ar ?? this.ar,
    abdomen: abdomen ?? this.abdomen,
    extremidades: extremidades ?? this.extremidades,
  );
}

@immutable
class ExamenesComplementarios {
  final String laboratorio;
  final String imagenes;
  final String culturas;
  final String ecg;

  const ExamenesComplementarios({
    this.laboratorio = '', this.imagenes = '',
    this.culturas = '', this.ecg = '',
  });

  ExamenesComplementarios copyWith({
    String? laboratorio, String? imagenes,
    String? culturas, String? ecg,
  }) => ExamenesComplementarios(
    laboratorio: laboratorio ?? this.laboratorio,
    imagenes: imagenes ?? this.imagenes,
    culturas: culturas ?? this.culturas,
    ecg: ecg ?? this.ecg,
  );
}

@immutable
class ObjetivoData {
  final SignosVitales signosVitales;
  final ExamenFisico examenFisico;
  final ExamenesComplementarios examenes;
  final String tratamientoActual;

  const ObjetivoData({
    this.signosVitales = const SignosVitales(),
    this.examenFisico = const ExamenFisico(),
    this.examenes = const ExamenesComplementarios(),
    this.tratamientoActual = '',
  });

  ObjetivoData copyWith({
    SignosVitales? signosVitales,
    ExamenFisico? examenFisico,
    ExamenesComplementarios? examenes,
    String? tratamientoActual,
  }) => ObjetivoData(
    signosVitales:    signosVitales ?? this.signosVitales,
    examenFisico:     examenFisico ?? this.examenFisico,
    examenes:         examenes ?? this.examenes,
    tratamientoActual: tratamientoActual ?? this.tratamientoActual,
  );
}

// ── A — Evaluación ────────────────────────────────────────────────────────────
@immutable
class EvaluacionData {
  final EstadoClinical? estado;
  final List<String> problemasActivos;
  final String notasEvaluacion;

  const EvaluacionData({
    this.estado,
    this.problemasActivos = const [],
    this.notasEvaluacion = '',
  });

  EvaluacionData copyWith({
    EstadoClinical? estado,
    List<String>? problemasActivos,
    String? notasEvaluacion,
  }) => EvaluacionData(
    estado:           estado ?? this.estado,
    problemasActivos: problemasActivos ?? this.problemasActivos,
    notasEvaluacion:  notasEvaluacion ?? this.notasEvaluacion,
  );
}

// ── P — Plan ──────────────────────────────────────────────────────────────────
@immutable
class PlanData {
  final String planTerapeutico;
  final String criteriosAlta;

  const PlanData({
    this.planTerapeutico = '',
    this.criteriosAlta = '',
  });

  PlanData copyWith({
    String? planTerapeutico,
    String? criteriosAlta,
  }) => PlanData(
    planTerapeutico: planTerapeutico ?? this.planTerapeutico,
    criteriosAlta:   criteriosAlta ?? this.criteriosAlta,
  );
}

// ── Evolución SOAP completa ───────────────────────────────────────────────────
@immutable
class EvolucionModel {
  final String id;
  final DateTime fecha;
  final String autorNombre;
  final SubjetivoData subjetivo;
  final ObjetivoData objetivo;
  final EvaluacionData evaluacion;
  final PlanData plan;
  /// Build 162: lista de fármacos atuais do paciente (medicamento + dosagem).
  final List<FarmacoEntry> farmacos;

  const EvolucionModel({
    required this.id,
    required this.fecha,
    required this.autorNombre,
    this.subjetivo = const SubjetivoData(),
    this.objetivo = const ObjetivoData(),
    this.evaluacion = const EvaluacionData(),
    this.plan = const PlanData(),
    this.farmacos = const [],
  });

  EvolucionModel copyWith({
    String? id,
    DateTime? fecha,
    String? autorNombre,
    SubjetivoData? subjetivo,
    ObjetivoData? objetivo,
    EvaluacionData? evaluacion,
    PlanData? plan,
    List<FarmacoEntry>? farmacos,
  }) => EvolucionModel(
    id:          id ?? this.id,
    fecha:       fecha ?? this.fecha,
    autorNombre: autorNombre ?? this.autorNombre,
    subjetivo:   subjetivo ?? this.subjetivo,
    objetivo:    objetivo ?? this.objetivo,
    evaluacion:  evaluacion ?? this.evaluacion,
    plan:        plan ?? this.plan,
    farmacos:    farmacos ?? this.farmacos,
  );

  String get fechaFormatada {
    final d = fecha;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}
