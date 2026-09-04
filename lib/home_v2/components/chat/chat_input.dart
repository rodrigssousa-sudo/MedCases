// ============================================================================
// MEDCASES PRO
// HOME V2
// CHAT INPUT
// ============================================================================

import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {

  final TextEditingController controller;

  final FocusNode focusNode;

  final VoidCallback onSend;

  final bool thinking;

  const ChatInput({

    super.key,

    required this.controller,

    required this.focusNode,

    required this.onSend,

    required this.thinking,

  });

  @override
  Widget build(BuildContext context){

    return Container(

      padding:const EdgeInsets.fromLTRB(12,10,12,12),

      decoration:const BoxDecoration(

        border:Border(

          top:BorderSide(

            color:Color(0xffECECEC),

          ),

        ),

      ),

      child:Row(

        children:[

          Expanded(

            child:TextField(

              controller:controller,

              focusNode:focusNode,

              minLines:1,

              maxLines:5,

              textInputAction:TextInputAction.send,

              onSubmitted:(_)=>onSend(),

              decoration:InputDecoration(

                hintText:"Pergunte qualquer coisa...",

                filled:true,

                fillColor:const Color(0xffF7F7F7),

                contentPadding:const EdgeInsets.symmetric(

                  horizontal:16,

                  vertical:12,

                ),

                border:OutlineInputBorder(

                  borderRadius:BorderRadius.circular(18),

                  borderSide:BorderSide.none,

                ),

              ),

            ),

          ),

          const SizedBox(width:8),

          SizedBox(

            width:48,

            height:48,

            child:FilledButton(

              onPressed:thinking?null:onSend,

              style:FilledButton.styleFrom(

                shape:const CircleBorder(),

                padding:EdgeInsets.zero,

              ),

              child:thinking

                  ? const SizedBox(

                      width:18,

                      height:18,

                      child:CircularProgressIndicator(

                        strokeWidth:2,

                        color:Colors.white,

                      ),

                    )

                  : const Icon(

                      Icons.arrow_upward_rounded,

                    ),

            ),

          ),

        ],

      ),

    );

  }

}
