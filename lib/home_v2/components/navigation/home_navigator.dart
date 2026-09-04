import 'package:flutter/material.dart';

import '../../webviews/webview_router.dart';

class HomeNavigator {

  const HomeNavigator();

  void openCalculadora(BuildContext context){

    WebViewRouter.open(context,"calculadora");

  }

  void openFarmacos(BuildContext context){

    WebViewRouter.open(context,"farmacos");

  }

  void openAdulto(BuildContext context){

    debugPrint("[HOME V2] Adulto");

  }

  void openPediatria(BuildContext context){

    debugPrint("[HOME V2] Pediatria");

  }

  void openPaciente(BuildContext context){

    debugPrint("[HOME V2] Paciente");

  }

  void openBiblioteca(BuildContext context){

    debugPrint("[HOME V2] Biblioteca");

  }

  void openHistoria(BuildContext context){

    debugPrint("[HOME V2] História");

  }

  void openNotas(BuildContext context){

    debugPrint("[HOME V2] Notas");

  }

  void openAvaliacao(BuildContext context){

    debugPrint("[HOME V2] Avaliação");

  }

  void openMiGuardia(BuildContext context){

    debugPrint("[HOME V2] Mi Guardia");

  }

}
