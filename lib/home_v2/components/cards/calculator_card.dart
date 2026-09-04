
import 'package:flutter/material.dart';

import '../common/med_card.dart';
import '../common/card_title.dart';

class CalculatorCard extends StatelessWidget{

  const CalculatorCard({super.key});

  @override
  Widget build(BuildContext context){

    return MedCard(

      onTap:(){},

      child:Padding(

        padding:const EdgeInsets.all(18),

        child:CardTitle(

          title:"Calculadoras",

          subtitle:"421 Fármacos • Scores • WebView",

          icon:Icons.calculate_rounded,

        ),

      ),

    );

  }

}
