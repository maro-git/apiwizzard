import 'package:apiwizzard/models/category.dart';

class Api {
  String name;
  Category category;
  Uri baseUrl;
  String session;

  Api(
      {required this.name,
      required this.category,
      required this.baseUrl,
      required this.session});
}
