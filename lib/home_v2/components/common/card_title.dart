import 'package:flutter/material.dart';

class CardTitle extends StatelessWidget{

  final String title;

  final String subtitle;

  final IconData icon;

  const CardTitle({

    super.key,

    required this.title,

    required this.subtitle,

    required this.icon,

  });

  @override
  Widget build(BuildContext context){

    return Row(

      children:[

        Icon(icon,size:28),

        const SizedBox(width:14),

        Expanded(

          child:Column(

            crossAxisAlignment:CrossAxisAlignment.start,

            mainAxisAlignment:MainAxisAlignment.center,

            children:[

              Text(

                title,

                style:const TextStyle(

                  fontSize:17,

                  fontWeight:FontWeight.w700,

                ),

              ),

              const SizedBox(height:2),

              Text(

                subtitle,

                style:const TextStyle(

                  fontSize:12,

                ),

              ),

            ],

          ),

        ),

      ],

    );

  }

}
