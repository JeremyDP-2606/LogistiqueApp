import 'dart:io';
import 'package:wabap/models/Colis.dart';

class GroupedColisResult {
  final Map<String, List<Colis>> groupedColis;
  final List<String> listNameClients;

  GroupedColisResult({required this.groupedColis, required this.listNameClients});
}