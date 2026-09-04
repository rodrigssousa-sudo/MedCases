// ============================================================================
// MEDCASES PRO
// HOME V2
// HOME ACTIONS
//
// Centraliza TODA navegação da Home.
// Nenhum card terá Navigator próprio.
// ============================================================================

import 'package:flutter/material.dart';

class HomeActions{

  const HomeActions();

  void openAdult(BuildContext context){

    debugPrint("[HOME V2] Adulto");

  }

  void openPediatrics(BuildContext context){

    debugPrint("[HOME V2] Pediatria");

  }

  void openCalculator(BuildContext context){

    debugPrint("[HOME V2] Calculadora + Farmacos (WebView)");

  }

  void openPatient(BuildContext context){

    debugPrint("[HOME V2] Paciente");

  }

  void openLibrary(BuildContext context){

    debugPrint("[HOME V2] Biblioteca");

  }

  void openHistory(BuildContext context){

    debugPrint("[HOME V2] Historia Clinica");

  }

  void openNotes(BuildContext context){

    debugPrint("[HOME V2] Notas");

  }

  void openAssessment(BuildContext context){

    debugPrint("[HOME V2] Avaliacao");

  }

  void openMiGuardia(BuildContext context){

    debugPrint("[HOME V2] Mi Guardia");

  }

}
