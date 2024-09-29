import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'menu.dart';
import 'settings.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<String> messages = [];
  final TextEditingController _controller = TextEditingController();
  bool isModelLoaded = false;
  static const MethodChannel llamaChannel = MethodChannel('com.vertex.ai/llama');

  @override
  void initState() {
    super.initState();
    _loadModel();

    // Listen for the model responses from the native side
    llamaChannel.setMethodCallHandler((call) async {
      if (call.method == 'onMessageResponse') {
        String response = call.arguments;
        setState(() {
          messages.add("Model: $response");
        });
      } else if (call.method == 'onModelLoaded') {
        String response = call.arguments;
        setState(() {
          isModelLoaded = true;
          messages.add(response);
        });
      }
    });
  }

  void _loadModel() {
    const modelPath = "/storage/emulated/0/Download/storage/emulated/0/Android/data/com.vertex.ai/files/TinyLlama.gguf";
    llamaChannel.invokeMethod('loadModel', {'path': modelPath});
  }

  void _sendMessage() {
    String text = _controller.text.trim();
    if (!isModelLoaded) {
      setState(() {
        messages.add('Model yüklenmeden mesaj gönderilemez. Lütfen bekleyin...');
      });
      return;
    }

    if (text.isNotEmpty) {
      setState(() {
        messages.add("Sen: $text");
        _controller.clear();
      });

      llamaChannel.invokeMethod('sendMessage', {'message': text});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        toolbarHeight: 60,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MenuScreen()),
            );
          },
        ),
        title: const Center(
          child: Text(
            'Vertex AI',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purple[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                          messages[index], style: const TextStyle(color: Colors.black)),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Mesajınızı yazın...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (text) {
                      _sendMessage();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
