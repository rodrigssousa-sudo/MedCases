// ============================================================================
// MEDCASES PRO
// HOME V2
// CHAT NAVIGATION
//
// FASE 13
// Nesta etapa somente criamos a interface.
// A ligação com AiScreen será feita posteriormente.
// ============================================================================

import 'package:flutter/material.dart';

class ChatNavigation{

  const ChatNavigation();

  void openHistory(BuildContext context){

    debugPrint("[HOME V2] HISTORY");

  }

  void openSettings(BuildContext context){

    debugPrint("[HOME V2] SETTINGS");

  }

  void openNewChat(BuildContext context){

    debugPrint("[HOME V2] NEW CHAT");

  }

  void openFullChat(BuildContext context){

    debugPrint("[HOME V2] OPEN AI");

  }

  void handoff({

    required BuildContext context,

    required List<Map<String,dynamic>> history,

  }){

    debugPrint(

      "[HOME V2] HANDOFF ${history.length} mensagens",

    );

  }

}
