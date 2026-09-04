// ============================================================================
// MEDCASES PRO
// HOME V2
// CHAT STREAM
// ============================================================================

import 'dart:async';

typedef StreamChunk = void Function(String);

class ChatStream{

  Timer? _timer;

  void fakeStream({

    required String text,

    required StreamChunk onChunk,

    required VoidCallback onDone,

  }){

    _timer?.cancel();

    int i=0;

    String current="";

    final words=text.split(" ");

    _timer=Timer.periodic(

      const Duration(milliseconds:35),

      (t){

        if(i>=words.length){

          t.cancel();

          onDone();

          return;

        }

        current += "${words[i]} ";

        onChunk(current.trimRight());

        i++;

      },

    );

  }

  void cancel(){

    _timer?.cancel();

  }

}

typedef VoidCallback = void Function();
