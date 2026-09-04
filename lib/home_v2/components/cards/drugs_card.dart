
import 'package:flutter/material.dart';

import '../common/med_card.dart';
import '../common/card_title.dart';

class DrugsCard extends StatelessWidget{

  const DrugsCard({super.key});

  @override
  Widget build(BuildContext context){

    return MedCard(

      onTap:(){},

      child:Padding(

        padding:const EdgeInsets.all(18),

        child:CardTitle(

          title:"Fármacos",

          subtitle:"Busca Inteligente e Interações",

          icon:Icons.medication_rounded,

        ),

      ),

    );

  }

}
