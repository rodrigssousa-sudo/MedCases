
import 'package:flutter/material.dart';

import '../common/med_card.dart';
import '../common/card_title.dart';

class PediatricsCard extends StatelessWidget{

  const PediatricsCard({super.key});

  @override
  Widget build(BuildContext context){

    return MedCard(

      onTap:(){},

      child:Padding(

        padding:const EdgeInsets.all(18),

        child:CardTitle(

          title:"Pediatria",

          subtitle:"Calculadoras e Referências",

          icon:Icons.child_care_rounded,

        ),

      ),

    );

  }

}
