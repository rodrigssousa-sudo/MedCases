// ============================================================================
// MEDCASES PRO
// HOME V2
// CHAT CONTROLLER
// FASE 13
// ============================================================================

import 'package:flutter/material.dart';

import 'chat_storage.dart';
import 'chat_stream.dart';

class ChatController extends ChangeNotifier{

  final text = TextEditingController();

  final focus = FocusNode();

  final storage = ChatStorage();

  final streamEngine = ChatStream();

  final List<Map<String,dynamic>> _messages=[];

  List<Map<String,dynamic>> get messages=>_messages;

  bool _thinking=false;

  bool get thinking=>_thinking;

  String _stream="";

  String get stream=>_stream;

  ChatController(){

    restore();

  }

  Future<void> restore() async{

    final old=await storage.load();

    _messages

      ..clear()

      ..addAll(old);

    notifyListeners();

  }

  Future<void> send() async{

    final question=text.text.trim();

    if(question.isEmpty)return;

    text.clear();

    _messages.add({

      "role":"user",

      "text":question,

    });

    _thinking=true;

    _stream="";

    notifyListeners();

    streamEngine.fakeStream(

      text:"Resposta temporária da Home V2. O streaming real será conectado ao motor da IA nas próximas etapas da migração.",

      onChunk:(value){

        _stream=value;

        notifyListeners();

      },

      onDone:() async{

        _messages.add({

          "role":"assistant",

          "text":_stream,

        });

        _thinking=false;

        _stream="";

        await storage.save(_messages);

        notifyListeners();

      },

    );

  }

  Future<void> clear() async{

    streamEngine.cancel();

    _thinking=false;

    _stream="";

    _messages.clear();

    await storage.clear();

    notifyListeners();

  }

  @override
  void dispose(){

    streamEngine.cancel();

    text.dispose();

    focus.dispose();

    super.dispose();

  }

}
