import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meyvee',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHomePage();
  }

  Future<void> _navigateToHomePage() async {
    await Future.delayed(Duration(seconds: 3));
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.purple,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircleAvatar(
            radius: 50,
            backgroundImage: AssetImage('assets/fruit.gif'),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  final picker = ImagePicker();
  String? _predictedFruit;
  String? _fruitInfo;
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  final List<String> classLabels = [
    "apple",
    "banana",
    "avocado",
    "cherry",
    "kiwi",
    "mango",
    "orange",
    "pineapple",
    "strawberry",
    "watermelon"
  ];

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/mobilenetv2_model.tflite');
      setState(() {
        _isModelLoaded = true;
      });
    } catch (e) {
      print('Model yüklenirken bir hata oluştu: $e');
    }
  }

  Float32List normalizeImage(img.Image image) {
    img.Image resizedImage = img.copyResize(image, width: 224, height: 224);
    Float32List imageAsList = Float32List(224 * 224 * 3);
    int bufferIndex = 0;

    for (int y = 0; y < resizedImage.height; y++) {
      for (int x = 0; x < resizedImage.width; x++) {
        img.Pixel pixel = resizedImage.getPixel(x, y);
        imageAsList[bufferIndex++] = pixel.r / 255.0;
        imageAsList[bufferIndex++] = pixel.g / 255.0;
        imageAsList[bufferIndex++] = pixel.b / 255.0;
      }
    }

    return imageAsList;
  }

  Future<void> predictImage(File imageFile) async {
    if (!_isModelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Model henüz yüklenmedi.')),
      );
      return;
    }

    try {
      img.Image image = img.decodeImage(await imageFile.readAsBytes())!;
      Float32List input = normalizeImage(image);
      var output = List.filled(10, 0.0).reshape([1, 10]);

      _interpreter!.run(input.reshape([1, 224, 224, 3]), output);

      print('Model çıktı: $output');

      List<double> outputList = output[0].cast<double>().toList();
      int predictedClassIndex = outputList.indexOf(outputList.reduce(max));
      String predictedClass = classLabels[predictedClassIndex];

      print('Tahmin edilen sınıf: $predictedClass');

      setState(() {
        _predictedFruit = predictedClass;
      });

      String fruitInfo = await fetchFruitInfo(predictedClass);

      setState(() {
        _fruitInfo = fruitInfo;
      });
    } catch (e) {
      print("Görüntü işlenirken bir hata oluştu: $e");
      setState(() {
        _predictedFruit = null;
        _fruitInfo = "Hata: $e";
      });
    }
  }

  Future<void> getImageFromCamera() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
        predictImage(_image!);
      } else {
        print('No photo selected.');
      }
    });
  }

  Future<void> getImageFromGallery() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
        predictImage(_image!);
      } else {
        print('No photo selected.');
      }
    });
  }

  Future<String> fetchFruitInfo(String fruitName) async {
    final url = Uri.parse('https://en.wikipedia.org/w/api.php?action=query&titles=$fruitName&prop=extracts&exintro&explaintext&format=json');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final pages = data['query']['pages'];
        final page = pages.values.first;
        final extract = page['extract'];
        return extract ?? 'No information available';
      } else {
        throw Exception('Meyve bilgisi yüklenemedi. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      return 'Görüntü işlenirken bir hata oluştu: $e';
    }
  }

  static const IconData arrow_back_outlined = IconData(0xee85, fontFamily: 'MaterialIcons', matchTextDirection: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home page'),
        leading: IconButton(
          icon: Icon(arrow_back_outlined),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        color: Colors.purple,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _image == null
                  ? Text('No photo selected.')
                  : Container(
                      height: 150,
                      child: Image.file(_image!),
                    ),
              SizedBox(height: 16),
              _predictedFruit == null
                  ? Container()
                  : Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "predicted fruit: $_predictedFruit",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(10),
                          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _fruitInfo ?? '',
                              style: TextStyle(
                                color: Colors.black,
                              ),
                            ),
                          ),
                          height: 150,
                        ),
                      ],
                    ),
              ElevatedButton(
                onPressed: getImageFromCamera,
                child: Text('Take Photo from Camera'),
              ),
              ElevatedButton(
                onPressed: getImageFromGallery,
                child: Text('Select Photo from Gallery'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }
}
