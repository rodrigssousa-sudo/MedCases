
import 'package:flutter/material.dart';

import '../common/med_card.dart';
import '../common/card_title.dart';

class NotesCard extends StatelessWidget{

  const NotesCard({super.key});

  @override
  Widget build(BuildContext context){

    return MedCard(

      onTap:(){},

      child:Padding(

        padding:const EdgeInsets.all(18),

        child:CardTitle(

          title:"Notas",

          subtitle:"Anotações rápidas",

          icon:Icons.edit_note_rounded,

        ),

      ),

    );

  }

}
