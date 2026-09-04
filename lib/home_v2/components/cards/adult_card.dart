
import 'package:flutter/material.dart';

import '../common/med_card.dart';
import '../common/card_title.dart';

class AdultCard extends StatelessWidget{

  const AdultCard({super.key});

  @override
  Widget build(BuildContext context){

    return MedCard(

      onTap:(){},

      child:Padding(

        padding:const EdgeInsets.all(18),

        child:CardTitle(

          title:"Adulto",

          subtitle:"Protocolos, IA Clínica e Condutas",

          icon:Icons.monitor_heart_rounded,

        ),

      ),

    );

  }

}
