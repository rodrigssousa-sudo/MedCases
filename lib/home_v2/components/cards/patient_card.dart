
import 'package:flutter/material.dart';

import '../common/med_card.dart';
import '../common/card_title.dart';

class PatientCard extends StatelessWidget{

  const PatientCard({super.key});

  @override
  Widget build(BuildContext context){

    return MedCard(

      onTap:(){},

      child:Padding(

        padding:const EdgeInsets.all(18),

        child:CardTitle(

          title:"Paciente",

          subtitle:"Internação e Dados Clínicos",

          icon:Icons.badge_rounded,

        ),

      ),

    );

  }

}
