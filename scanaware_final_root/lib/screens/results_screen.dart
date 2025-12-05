import 'package:flutter/material.dart';
class ResultsScreen extends StatelessWidget {
  final Map product;
  const ResultsScreen({super.key, required this.product});
  @override Widget build(BuildContext context) => Scaffold(body: Center(child: Text('Result')));
}