import 'package:flutter/material.dart';

class AdminWorkspaceTabs extends StatelessWidget {
  const AdminWorkspaceTabs(
      {super.key, required this.labels, required this.children});
  final List<String> labels;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: labels.length,
      child: Column(children: [
        Container(
            color: Colors.white,
            alignment: Alignment.centerLeft,
            child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: labels.map((x) => Tab(text: x)).toList())),
        Expanded(child: TabBarView(children: children))
      ]));
}
