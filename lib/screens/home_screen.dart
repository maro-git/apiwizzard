import 'package:apiwizzard/models/api.dart';
import 'package:apiwizzard/models/category.dart';
import 'package:apiwizzard/screens/category_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Category AI = Category(name: "AI");
  List<Category> categories = [];

  @override
  void initState() {
    // TODO: implement initState
    Api Lama3 = Api(
        name: "lama3",
        category: AI,
        baseUrl: Uri(host: "localhost"),
        session: "lama3");
    Api sd3 = Api(
        name: "sd3",
        category: AI,
        baseUrl: Uri(host: "stable"),
        session: "sd3");
    AI.apis.add(Lama3);
    AI.apis.add(sd3);
    categories.add(AI);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('API Wizzard'),
      ),
      body: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          Category category = categories[index];
          return ListTile(
            title: Text(category.name),
            subtitle: Text('${category.apis.length} APIs'),
            onTap: () {
              // Navigate to the CategoryScreen
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => CategoryScreen(category: category)),
              );
            },
          );
        },
      ),
    );
  }
}
