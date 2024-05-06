import 'package:apiwizzard/models/api.dart';
import 'package:apiwizzard/models/category.dart';
import 'package:apiwizzard/screens/ollama_api_interface.dart';
import 'package:apiwizzard/screens/sd3_api_interface_screen.dart';
import 'package:flutter/material.dart';

class CategoryScreen extends StatelessWidget {
  final Category category;

  CategoryScreen({required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
      ),
      body: ListView.builder(
        itemCount: category.apis.length,
        itemBuilder: (context, index) {
          Api api = category.apis[index];
          return ListTile(
            title: Text(api.name),
            trailing: ElevatedButton(
              child: Text("Create Session"),
              onPressed: () {
                if (api.name == "lama3") {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => OllamaApiInterface()));
                } else if (api.name == "sd3") {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ApiInterfaceScreen()));
                }
              },
            ),
          );
        },
      ),
    );
  }
}
