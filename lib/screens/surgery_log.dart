import 'package:flutter/material.dart';

class SurgeryLogScreen extends StatelessWidget {
  final String title;
  final List<String> surgeries;

  const SurgeryLogScreen({Key? key, required this.title, required this.surgeries}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: ListView.builder(
        itemCount: surgeries.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(surgeries[index]),
          );
        },
      ),
    );
  }
} 