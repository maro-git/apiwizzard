import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:apiwizzard/apis/api_interface.dart';
import 'package:apiwizzard/models/bubble.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ApiInterfaceScreen extends StatefulWidget {
  @override
  _ApiInterfaceScreenState createState() => _ApiInterfaceScreenState();
}

class _ApiInterfaceScreenState extends State<ApiInterfaceScreen> {
  final TextEditingController _textController = TextEditingController();
  late Database _database;
  bool _isDbInitialized = false;
  List<Map<String, dynamic>> _apiHistory = [];

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'api_database.db');
    _database = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
        CREATE TABLE IF NOT EXISTS api_history (
          requested_text TEXT,
          response_data TEXT
        )
      ''');
        },
        readOnly: false, // Ensure write access
      ),
    );

    setState(() {
      _database = _database;
      _isDbInitialized = true; // Set flag to true after database initialization
    });
  }

  Future<void> _sendRequest() async {
    final requestText = _textController.text;
    final apiInterface = ApiInterface(baseUrl: "api.stability.ai");
    final response = await apiInterface.post(
      "v2beta/stable-image/generate/sd3",
      body: {
        "prompt": requestText,
        "model": "sd3",
        "aspect_ratio": "16:9",
        "output_format": "jpeg",
        //"seed": "3619566124",
      },
    );

    _textController.clear();

    if (response.statusCode == 200) {
      final responseDataDecoded = jsonDecode(response.body);
      final responseData = {
        'image': responseDataDecoded[
            "image"], // Assuming the image is directly in the response body
        'finish_reason': responseDataDecoded["finish_reason"],
        'seed': responseDataDecoded["seed"],
      };
      final encodedResponse = jsonEncode(responseData);

      if (_database != null && _isDbInitialized) {
        await _database!.transaction((txn) async {
          final id = await txn.insert('api_history', {
            "requested_text": requestText,
            "response_data": encodedResponse,
          });
        });
      }
    } else {
      print(response.statusCode);
      print(response.body);
    }
  }

  Future<List<Map<String, dynamic>>> _loadApiHistory() async {
    List<Map<String, dynamic>> apiHistory = [];

    if (_database != null && _isDbInitialized) {
      // Check if database is initialized before accessing it
      await _database!.transaction((txn) async {
        final result = await txn.query('api_history');
        apiHistory = result;
      });
    }

    return apiHistory;
  }

  Future<void> _saveFile(Uint8List image) async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Your File to the desired location',
      fileName: "image-${DateTime.now().millisecondsSinceEpoch}.jpeg",
    );
    if (outputFile != null) {
      File returnedFile = File('$outputFile');
      await returnedFile.writeAsBytes(image);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('API Interface'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder(
                future: _loadApiHistory(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  _apiHistory = snapshot.data as List<Map<String, dynamic>>;

                  return ListView.builder(
                    itemCount: _apiHistory.length,
                    itemBuilder: (context, index) {
                      Map<String, dynamic> responseData =
                          jsonDecode(_apiHistory[index]['response_data']);

                      if (responseData.containsKey('image')) {
                        Uint8List uint8list =
                            base64Decode(responseData["image"].toString());
                        return Column(
                          children: [
                            Bubble(
                              message: _apiHistory[index]['requested_text'],
                              color: Colors.orange,
                              isMe: true,
                            ),
                            GestureDetector(
                              onTap: () {
                                _saveFile(uint8list);
                              },
                              child: Bubble(
                                message: "seed:${responseData["seed"]}",
                                color: Colors.red,
                                isMe: false,
                                child: Image.memory(
                                  uint8list,
                                  width: 300,
                                  height: 300,
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Bubble(
                            message: _apiHistory[index]['requested_text'],
                            color: Colors.orange,
                            isMe: true);
                      }
                    },
                  );
                },
              ),
            ),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter request text',
              ),
              onSubmitted: (value) => _sendRequest(),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _sendRequest,
              child: Text('Send Request'),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
