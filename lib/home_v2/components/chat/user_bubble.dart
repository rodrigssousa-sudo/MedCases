// ============================================================================
// MEDCASES PRO
// HOME V2
// USER BUBBLE
// ============================================================================

import 'package:flutter/material.dart';

import 'chat_theme.dart';

class UserBubble extends StatelessWidget {

  final String text;

  const UserBubble({

    super.key,

    required this.text,

  });

  @override
  Widget build(BuildContext context){

    return Align(

      alignment: Alignment.centerRight,

      child: Container(

        constraints: const BoxConstraints(

          maxWidth: 340,

        ),

        margin: const EdgeInsets.only(

          bottom: ChatTheme.bubbleSpacing,

        ),

        padding: const EdgeInsets.symmetric(

          horizontal: 14,

          vertical: 10,

        ),

        decoration: BoxDecoration(

          color: ChatTheme.userBubble,

          borderRadius: BorderRadius.circular(

            ChatTheme.radius,

          ),

          border: Border.all(

            color: ChatTheme.border,

          ),

        ),

        child: SelectableText(

          text,

          style: const TextStyle(

            fontSize: 14,

            height: 1.45,

            color: ChatTheme.text,

            fontWeight: FontWeight.w500,

          ),

        ),

      ),

    );

  }

}
