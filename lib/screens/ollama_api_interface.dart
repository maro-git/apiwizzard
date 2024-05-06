import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ollama_dart/ollama_dart.dart';
import 'package:cross_file/cross_file.dart';

import 'package:apiwizzard/models/bubble.dart';

class OllamaApiInterface extends StatefulWidget {
  @override
  State<OllamaApiInterface> createState() => _OllamaApiInterfaceScreenState();
}

class _OllamaApiInterfaceScreenState extends State<OllamaApiInterface> {
  final TextEditingController _textController = TextEditingController();
  late Database _database;
  bool _isDbInitialized = false;
  List<Map<String, dynamic>> _apiHistory = [];
  List<String> _selectedFiles = [];

  final OllamaClient client = OllamaClient();
  List<int> weights = [];
  List<String> images = [];
  String currentResponse = "";
  bool initializing = true;
  bool new_message = false;
  String model = "llama3";

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'ollama_database.db');
    _database = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
        CREATE TABLE IF NOT EXISTS ollama_api (
          requested_text TEXT,
          response_data TEXT,
          memory TEXT,
          files TEXT
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

  Future<void> _createModelStream(
      OllamaClient client, String modelName, String createPrompt) async {
    final stream = client.createModelStream(
      request: CreateModelRequest(
        name: modelName,
        modelfile: 'FROM llama3 \nSYSTEM $createPrompt',
      ),
    );
    await for (final res in stream) {
      setState(() {
        currentResponse += "${res.status}";
      });
    }
  }

  Future<void> _sendRequest() async {
    String requestText = _textController.text;
    _textController.clear();
    new_message = true;
    String commandResponse = ''; // Store command response for API history

    if (requestText.startsWith("/")) {
      String commandString = requestText.substring(1); // Remove the leading '/'
      List<String> args = commandString.split(" ");
      if (args.isNotEmpty) {
        switch (args[0]) {
          case "help":
            commandResponse =
                "Here's a list of commands:\n/help - Display help functionality\n/create [model] [create-prompt] - Create a model with specified parameters";
            break;
          case "create":
            if (args.length >= 3) {
              String modelName = args[1];
              String createPrompt = args.sublist(2).join(" ");
              await _createModelStream(client, modelName, createPrompt);
              commandResponse =
                  "Model '$modelName' created with prompt: '$createPrompt'";
            } else {
              commandResponse =
                  "Invalid command usage. Usage: /command create [model] [create-prompt]";
            }
            break;
          case "change":
            if (args.length >= 2) {
              setState(() {
                model = args[1];
                commandResponse = "Changing to model $model";
              });
            } else {
              commandResponse =
                  "Invalid command usage. Usage: /command change [model]";
            }
            break;
          case "reset":
            setState(() {
              weights.clear();
              commandResponse = "Model reset!";
            });

            break;

          default:
            commandResponse =
                "Invalid command. Type /command help for available commands.";
        }
        // Database operation to save the request
        if (_database != null && _isDbInitialized) {
          await _database.transaction((txn) async {
            final id = await txn.insert(
              'ollama_api',
              {
                'requested_text': requestText,
                'response_data': commandResponse,
                'memory': jsonEncode(weights),
                'files': jsonEncode(_selectedFiles),
              },
            );
          });
        }

        setState(() {
          // Update API history with command response
          _apiHistory.add({
            "requested_text": requestText,
            "response_data": commandResponse,
            "memory": List<int>.from(
                weights), // Assuming weights are part of the memory
            "files": List<String>.from(_selectedFiles),
          });
        });
      }
    } else {
      // Append selected file paths to the request text for API
      String filesTextForAPI = '';
      if (_selectedFiles.isNotEmpty) {
        for (String filePath in _selectedFiles) {
          File file = File(filePath);
          String fileContents = await file.readAsString();
          filesTextForAPI +=
              '\n---\nAttachement:${basename(filePath)}\nContent:$fileContents';
        }
      }

      // Query the last message from the database
      List<Map<String, dynamic>> lastMessage = await _database.rawQuery(
        'SELECT * FROM ollama_api ORDER BY memory ASC LIMIT 1',
      );

      if (lastMessage.isNotEmpty && initializing == true) {
        initializing = false;
        List<int> memoryData = [];
        print("initializing");
        if (lastMessage.last != null && lastMessage.last["memory"].isNotEmpty) {
          memoryData =
              List<int>.from(jsonDecode(lastMessage.last['memory'].toString()));
        }

        // Assuming memoryData contains the weights
        setState(() {
          weights = memoryData;
        });
      }

      final newApiHistoryItem = {
        "requested_text": requestText,
        "response_data": "", // Empty for now, will be filled later
        "memory": List<int>.from(
            weights), // Create a new list to prevent reference issues
        "files": List<String>.from(_selectedFiles),
      };

      // Concatenate the new chat bubble with previous history
      List<Map<String, dynamic>> updatedHistory = List.from(_apiHistory);
      updatedHistory.add(newApiHistoryItem);

      setState(() {
        _apiHistory = updatedHistory;
      });

      // Database operation to save the request
      if (_database != null && _isDbInitialized) {
        await _database.transaction((txn) async {
          final id = await txn.insert(
            'ollama_api',
            {
              'requested_text': requestText,
              'response_data': '',
              'memory': "",
              'files': jsonEncode(_selectedFiles),
            },
          );
        });
      }

      final stream = client.generateCompletionStream(
        request: GenerateCompletionRequest(
          model: model,
          prompt: requestText + filesTextForAPI,
          context: weights,
          images: images,
        ),
      );

      await for (final res in stream) {
        if (new_message == true) {
          currentResponse = "";
          new_message = false;
        }
        setState(() {
          // Concatenate new response to the existing one
          currentResponse += res.response ?? '';
          newApiHistoryItem["response_data"] = currentResponse;
        });
        if (res.done ?? false) {
          weights = res.context!.toList();
        }
      }

      // Database operation to update the response
      if (_database != null && _isDbInitialized) {
        await _database.transaction((txn) async {
          await txn.update(
            'ollama_api',
            {
              'response_data': currentResponse,
              'memory': jsonEncode(weights),
            },
            where: 'requested_text = ?',
            whereArgs: [requestText + filesTextForAPI],
          );
        });
      }
      //print(jsonEncode(weights));

      _selectedFiles.clear();
      images.clear();
    }
  }

  Future<List<Map<String, dynamic>>> _loadRequests() async {
    List<Map<String, dynamic>> requests = [];

    if (_database != null) {
      await _database.transaction((txn) async {
        final result = await txn.query('ollama_api');
        for (var request in result) {
          requests.add({
            'id': request['id'],
            'text': request['requested_text'],
            'response': request["response_data"],
            'files': List<String>.from(jsonDecode(request["files"].toString())),
          });
        }
      });
    }

    return requests;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ollama API Interface'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder(
                future: _loadRequests(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  _apiHistory = snapshot.data as List<Map<String, dynamic>>;

                  return ListView.builder(
                    itemCount: _apiHistory.length,
                    itemBuilder: (context, index) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Text bubble
                          Bubble(
                            message: "",
                            color: Color.fromARGB(255, 179, 179, 179),
                            isMe: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  _apiHistory[index]['text'] ?? '',
                                  style: TextStyle(
                                      color: const Color.fromARGB(
                                          255, 47, 47, 47)),
                                ),
                                // Display file icons for selected files
                                Wrap(
                                  children: _apiHistory[index]['files']
                                      .map<Widget>((filePath) {
                                    File file = File(filePath);
                                    return Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Column(
                                        children: [
                                          Icon(Icons.insert_drive_file),
                                          Text('${basename(filePath)}'),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          // Response bubble
                          Bubble(
                            message: '',
                            color: Color.fromARGB(255, 231, 231, 231),
                            isMe: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  index == _apiHistory.length - 1 &&
                                          currentResponse.isNotEmpty &&
                                          currentResponse != " "
                                      ? currentResponse
                                      : _apiHistory[index]['response'] ?? "",
                                  style: TextStyle(
                                      color: const Color.fromARGB(
                                          255, 71, 71, 71)),
                                ),
                              ],
                            ),
                          )
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter request text',
                    ),
                    onSubmitted: (value) async {
                      _sendRequest();
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.attach_file),
                  onPressed: () async {
                    FilePickerResult? result =
                        await FilePicker.platform.pickFiles(
                      allowMultiple: true,
                    );
                    if (result != null) {
                      setState(() {
                        _selectedFiles.addAll(result.files.map((e) => e.path!));
                      });
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                _sendRequest();
              },
              child: Text('Send Request'),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
