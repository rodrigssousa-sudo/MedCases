// ============================================================================
// MEDCASES PRO
// HOME V2
// WEBVIEW ROUTER
//
// ESTE ARQUIVO SERÁ O ÚNICO RESPONSÁVEL POR ABRIR
// AS WEBVIEWS DO MEDCASES.
//
// Calculadoras
// Farmacos
// Biblioteca Externa
//
// Nenhum card abrirá Navigator diretamente.
// ============================================================================

import 'package:flutter/material.dart';

class WebViewRouter{

  const WebViewRouter();

  void openCalculator(BuildContext context){

    debugPrint(
      "[WEBVIEW] CALCULADORAS"
    );

  }

  void openDrugs(BuildContext context){

    debugPrint(
      "[WEBVIEW] FARMACOS"
    );

  }

  void openCalculatorAndDrugs(BuildContext context){

    debugPrint(
      "[WEBVIEW] CALCULADORAS + FARMACOS"
    );

  }

  void openExternal(

    BuildContext context,

    String route,

  ){

    debugPrint(
      "[WEBVIEW] $route"
    );

  }

}
