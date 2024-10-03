import 'package:ai/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';  // Timer için gerekli
import 'menu.dart';

// Mesajları yöneteceğimiz basit bir sınıf
class Message {
  final String text;
  final bool isUserMessage;

  Message({required this.text, required this.isUserMessage});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Message> messages = [];  // Mesajları Message objesi olarak tutuyoruz
  final TextEditingController _controller = TextEditingController();
  bool isModelLoaded = false;
  bool isWaitingForResponse = false;  // Model yanıt veriyor mu
  String modelResponse = '';  // Gelen tokenleri biriktireceğimiz değişken
  Timer? responseTimer;  // 5 saniyelik timeout için timer
  static const MethodChannel llamaChannel = MethodChannel('com.vertex.ai/llama');

  @override
  void initState() {
    super.initState();
    loadModel();

    // Native tarafından gelen yanıtları dinleyin
    llamaChannel.setMethodCallHandler((call) async {
      if (call.method == 'onMessageResponse') {
        String token = call.arguments;
        setState(() {
          modelResponse += token;  // Gelen tokeni yanıtın sonuna ekle
        });
        _startResponseTimeout();  // Her token geldiğinde timeout sıfırlanır
      } else if (call.method == 'onMessageComplete') {
        setState(() {
          // Model yanıtını mesajlar listesine model mesajı olarak ekle
          messages.add(Message(text: modelResponse, isUserMessage: false));
          modelResponse = '';  // Model yanıtını sıfırla
          isWaitingForResponse = false;  // Yanıt beklenmiyor artık
        });
        responseTimer?.cancel();  // Yanıt tamamlandığında timer iptal edilir
      } else if (call.method == 'onModelLoaded') {
        setState(() {
          isModelLoaded = true;
        });
      }
    });
  }

  // 5 saniyelik timeout timer başlatma
  void _startResponseTimeout() {
    responseTimer?.cancel();  // Eğer eski bir timer varsa iptal et
    responseTimer = Timer(const Duration(seconds: 5), () {
      setState(() {
        isWaitingForResponse = false;  // 5 saniye sonra buton tekrar aktif olur
      });
    });
  }

  Future<void> loadModel() async {
    final prefs = await SharedPreferences.getInstance();
    final modelPath = prefs.getString('selected_model_path');  // Model yolu burada alınır
    if (modelPath != null) {
      print('Yüklenen model yolu: $modelPath');
      // Model yükleme işlemi burada devam eder
      // modelPath ile gerekli işlemleri yapabilirsiniz.
    } else {
      print('Model yolu bulunamadı.');
    }
    llamaChannel.invokeMethod('loadModel', {'path': modelPath});
  }

  void _sendMessage() {
    String text = _controller.text.trim();

    if (text.isNotEmpty) {
      setState(() {
        // Kullanıcı mesajını mesajlar listesine kullanıcı mesajı olarak ekle
        messages.add(Message(text: text, isUserMessage: true));
        _controller.clear();
        modelResponse = '';  // Her yeni mesaj gönderiminde önceki yanıtı sıfırla
        isWaitingForResponse = true;  // Model yanıtı bekleniyor
      });

      // Eğer kullanıcı "FATİH BULUT" yazdıysa modeli çağırmadan direkt cevap veriyoruz
      if (text.toUpperCase() == "FATİH BULUT") {
        setState(() {
          messages.add(Message(text: "ALEMİN KRALI", isUserMessage: false));
          isWaitingForResponse = false;  // Yanıt beklenmiyor artık
        });
      } else {
        // Eğer "FATİH BULUT" değilse, normal model çağırma süreci devam eder
        llamaChannel.invokeMethod('sendMessage', {'message': text});
        _startResponseTimeout();  // Mesaj gönderildiğinde 5 saniye için timeout başlat
      }
    }
  }


  @override
  void dispose() {
    _controller.dispose();
    responseTimer?.cancel();  // Timer varsa iptal et
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
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
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
              itemCount: messages.length + (modelResponse.isNotEmpty ? 1 : 0),  // Mesaj listesi ve aktif model yanıtı
              itemBuilder: (context, index) {
                if (index == messages.length && modelResponse.isNotEmpty) {
                  // Halen model yanıt veriyor
                  return ListTile(
                    title: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          modelResponse.isEmpty ? "Model yanıtlıyor..." : modelResponse,
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  );
                } else {
                  // Kullanıcı mesajı mı model mesajı mı diye kontrol ediyoruz
                  bool isUserMessage = messages[index].isUserMessage;
                  return ListTile(
                    title: Align(
                      alignment: isUserMessage
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isUserMessage ? Colors.blue[100] : Colors.green[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          messages[index].text,
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          isModelLoaded
              ? Padding(
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
                      if (!isWaitingForResponse) _sendMessage();
                    },
                    enabled: !isWaitingForResponse,  // Mesaj yazma alanını pasif yap
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: isWaitingForResponse ? Colors.grey : Colors.blue,
                  onPressed: isWaitingForResponse ? null : _sendMessage,  // Mesaj gönderme pasif
                ),
              ],
            ),
          )
              : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Konuşmak için bir model seçmen gerek, ayarlar ekranından yapabilirsin!',
              style: TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
