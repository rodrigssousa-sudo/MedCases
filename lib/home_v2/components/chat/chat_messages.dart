// ============================================================================
// MEDCASES PRO
// HOME V2
// CHAT MESSAGES
// ============================================================================

import 'package:flutter/material.dart';

import 'ai_bubble.dart';
import 'user_bubble.dart';
import 'thinking_indicator.dart';

class ChatMessages extends StatelessWidget{

  final List<Map<String,dynamic>> messages;

  final bool thinking;

  final String stream;

  const ChatMessages({

    super.key,

    required this.messages,

    required this.thinking,

    required this.stream,

  });

  @override
  Widget build(BuildContext context){

    return ListView.builder(

      reverse:false,

      padding:const EdgeInsets.fromLTRB(

        14,

        14,

        14,

        18,

      ),

      itemCount:

          messages.length +

          (thinking?1:0),

      itemBuilder:(context,index){

        if(

          thinking &&

          index==messages.length

        ){

          if(stream.isEmpty){

            return const Padding(

              padding:EdgeInsets.only(

                bottom:10,

              ),

              child:ThinkingIndicator(),

            );

          }

          return AiBubble(

            text:stream,

            streaming:true,

          );

        }

        final item=messages[index];

        final role=item["role"];

        final text=item["text"] ?? "";

        if(role=="user"){

          return UserBubble(

            text:text,

          );

        }

        return AiBubble(

          text:text,

          streaming:false,

        );

      },

    );

  }

}
