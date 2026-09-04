
import 'package:flutter/material.dart';

import '../common/med_card.dart';
import '../common/card_title.dart';

class HistoryCard extends StatelessWidget{

  const HistoryCard({super.key});

  @override
  Widget build(BuildContext context){

    return MedCard(

      onTap:(){},

      child:Padding(

        padding:const EdgeInsets.all(18),

        child:CardTitle(

          title:"História Clínica",

          subtitle:"SOAP e Evolução",

          icon:Icons.description_rounded,

        ),

      ),

    );

  }

}
