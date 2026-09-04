
import 'package:flutter/material.dart';

import '../common/med_card.dart';
import '../common/card_title.dart';

class AssessmentCard extends StatelessWidget{

  const AssessmentCard({super.key});

  @override
  Widget build(BuildContext context){

    return MedCard(

      onTap:(){},

      child:Padding(

        padding:const EdgeInsets.all(18),

        child:CardTitle(

          title:"Avaliação",

          subtitle:"Exame Físico",

          icon:Icons.stethoscope_rounded,

        ),

      ),

    );

  }

}
