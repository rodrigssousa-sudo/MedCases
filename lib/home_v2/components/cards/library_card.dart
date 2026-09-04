
import 'package:flutter/material.dart';

import '../common/med_card.dart';
import '../common/card_title.dart';

class LibraryCard extends StatelessWidget{

  const LibraryCard({super.key});

  @override
  Widget build(BuildContext context){

    return MedCard(

      onTap:(){},

      child:Padding(

        padding:const EdgeInsets.all(18),

        child:CardTitle(

          title:"Biblioteca",

          subtitle:"Guias • Protocolos • PDFs",

          icon:Icons.menu_book_rounded,

        ),

      ),

    );

  }

}
