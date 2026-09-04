import 'package:flutter/material.dart';

class MedCard extends StatelessWidget{

  final Widget child;

  final VoidCallback? onTap;

  final double height;

  const MedCard({

    super.key,

    required this.child,

    this.onTap,

    this.height=120,

  });

  @override
  Widget build(BuildContext context){

    return Material(

      color:Colors.white,

      borderRadius:BorderRadius.circular(20),

      child:InkWell(

        borderRadius:BorderRadius.circular(20),

        onTap:onTap,

        child:Container(

          height:height,

          decoration:BoxDecoration(

            borderRadius:BorderRadius.circular(20),

            border:Border.all(

              color:const Color(0xffE5E7EB),

            ),

            boxShadow:const[

              BoxShadow(

                blurRadius:18,

                offset:Offset(0,5),

                color:Color(0x12000000),

              ),

            ],

          ),

          child:child,

        ),

      ),

    );

  }

}
