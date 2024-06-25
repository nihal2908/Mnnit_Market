import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mnnit/firebase/firebase_storage.dart';
import 'package:mnnit/pages/landing_page.dart';
import 'package:mnnit/widgets/circular_progress.dart';

class AddProductPage extends StatefulWidget {
  AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final TextEditingController name = TextEditingController();
  final TextEditingController price = TextEditingController();
  final TextEditingController description = TextEditingController();
  final TextEditingController details = TextEditingController();
  final TextEditingController new_category = TextEditingController();
  final TextEditingController location = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<File> _images = [];
  bool _isUploading = false;
  List<String> _uploadedImageUrls = [];
  String category = '';
  List<String> categories = [];
  bool negotiable = false;

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  void fetchCategories() async {
    final firestore = FirebaseFirestore.instance;
    final querySnapshot = await firestore.collection('categories').get();
    setState(() {
      categories = querySnapshot.docs.map((doc) => doc.id).toList();
      categories.add('Other');
      category = categories[0];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Product'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Name',
              ),
            ),
            DropdownButtonFormField<String>(
              value: category.isNotEmpty ? category : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              items: categories
                  .map((category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  category = value!;
                  if (value == 'Other') {
                    new_category.clear();
                  } else {
                    new_category.text = value;
                  }
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
            if (category == 'Other')
              TextField(
                controller: new_category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                ),
              ),
            TextField(
              controller: description,
              decoration: const InputDecoration(
                labelText: 'Description',
              ),
            ),
            TextField(
              controller: details,
              decoration: const InputDecoration(
                labelText: 'Details',
              ),
            ),
            TextField(
              controller: location,
              decoration: const InputDecoration(
                labelText: 'Location',
              ),
            ),
            TextField(
              controller: price,
              decoration: const InputDecoration(
                labelText: 'Price',
              ),
            ),
            const SizedBox(height: 10,),
            StatefulBuilder(
              builder: (context, chipState){
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ChoiceChip(
                      label: const Text('Negotiable'),
                      selected: negotiable,
                      onSelected: (_){
                        chipState((){
                          negotiable = true;
                        });
                      },
                      selectedColor: Colors.green,
                    ),
                    ChoiceChip(
                      label: const Text('Non-negotiable'),
                      selected: !negotiable,
                      onSelected: (_){
                        chipState((){
                          negotiable = false;
                        });
                    },
                      selectedColor: Colors.green,
                    ),
                  ],
                );
              }
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 200,
              width: MediaQuery.of(context).size.width,
              child: ListView.builder(
                itemCount: _images.length,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  return Card(
                    child: Stack(
                      children: [
                        Image.file(_images[index] as File, fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _images.removeAt(index);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Add Image'),
            ),
            ElevatedButton(
              onPressed: () async {
                showProgress(context);
                final Firebase storage = Firebase();
                await _uploadImages().then((value) async {
                  _uploadedImageUrls = value;
                  await storage.addProduct(
                      name: name.text,
                      description: description.text,
                      category: new_category.text.isNotEmpty ? new_category.text : category,
                      price: price.text,
                      negotiable: negotiable,
                      details: details.text,
                      location: location.text,
                      images: _uploadedImageUrls//imageControllers.map((image) => image.text).toList(),
                  );
                });
                Navigator.pop(context);
                showDone(context);
              },
              child: const Text('Save'),
            ),
            TextButton(onPressed: (){
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>LandingPage()));
            }, child: Text('back'))
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles != null) {
        setState(() {
          _images.addAll(pickedFiles.map((pickedFile) => File(pickedFile.path)).toList());
        });
      }
    } catch (e) {
      print('Error picking images: $e');
    }
  }

  Future<List<String>> _uploadImages() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No images selected')));
      return [];
    }

    setState(() {
      _isUploading = true;
    });
    List<String> imageUrls = [];
    try {
      for (File image in _images) {
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        Reference ref = FirebaseStorage.instance.ref().child('images').child(fileName);
        UploadTask uploadTask;

        uploadTask = ref.putFile(image as File);

        TaskSnapshot snapshot = await uploadTask.whenComplete(() {});
        String downloadUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      }

      // await FirebaseFirestore.instance.collection('images').add({'urls': imageUrls});

      setState(() {
        _isUploading = false;
        _images.clear();
        // _uploadedImageUrls = imageUrls;
      });

      // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Images uploaded successfully')));
    } catch (e) {
      print('Error uploading images: $e');
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error uploading images')));
    }
    return imageUrls;
  }

  void showProgress(BuildContext context){
    showDialog(
      context: context,
      builder: (context){
        return AlertDialog(
          title: Text('Uploading'),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CenterIndicator(color: Colors.deepPurple,),
            ],
          ),
        );
      },
      barrierDismissible: false
    );
  }

  void showDone(BuildContext context){
    showDialog(context: context, builder: (context){
      return AlertDialog(
        title: const Text('Successfully Added'),
        content: const Text('Refresh your Products Page to sync changes'),
        actions: [
          ElevatedButton(
              onPressed: (){
                Navigator.pop(context);
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>AddProductPage()));
              },
              child: const Text('OK', style: TextStyle(color: Colors.green),)
          ),
        ],
      );
    });
  }

}