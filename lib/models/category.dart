import 'package:apiwizzard/models/api.dart';

class Category {
  String name;
  List<Api> apis;

  Category({required this.name}) : apis = [];
}
