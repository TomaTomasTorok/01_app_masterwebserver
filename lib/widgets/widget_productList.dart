import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:masterwebserver/widgets/widget_itemList.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';


import '../model/productItem.dart';

class ProductList extends StatefulWidget {
  @override
  _ProductListState createState() => _ProductListState();
}

class _ProductListState extends State<ProductList> {
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? allProducts = prefs.getStringList('allProducts');

    if (allProducts != null) {
      _products = allProducts.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
    }

    setState(() {});
  }

  void _openProductForm(int index) {
    final product = _products[index];
    final List<ProductItem> items = (product['items'] as List)
        .map((item) => ProductItem.fromMap(item))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductForm(
          editIndex: index,
          initialName: product['name'],
          initialItems: items,
        ),
      ),
    ).then((_) => _loadData());
  }
  Future<void> _deleteProduct(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? allProducts = prefs.getStringList('allProducts');

    if (allProducts != null && index >= 0 && index < allProducts.length) {
      allProducts.removeAt(index);
      await prefs.setStringList('allProducts', allProducts);
      setState(() {
        _products.removeAt(index);
      });
    }
  }


  void _addNewProductForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductForm(
          editIndex: null,
          initialName: '',
          initialItems: [],
        ),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _externalDevice(List<List<int>> data) async {
    for (List<int> item in data) {
      print(item);
    }
    const url = 'http://192.168.0.184/data'; // Skutočná IP adresa ESP01s
    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: json.encode({"data": data}), // Konverzia dát do JSON reťazca
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request successful!")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request failed: ${response.statusCode}")));
    }
  }

  List<List<int>> _buildData(List<ProductItem> items) {
    List<List<int>> data = [
      [items.length], // Počet položiek
    ];

    for (ProductItem item in items) {
      data.add([item.poradie, item.status, item.idPL]);
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Product List"),
      ),
      body: ListView.builder(
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          final List<ProductItem> items = (product['items'] as List)
              .map((item) => ProductItem.fromMap(item))
              .toList();

          return Dismissible(
            key: Key(product['name']),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) => _deleteProduct(index),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Icon(
                Icons.delete,
                color: Colors.white,
              ),
            ),
            child: ListTile(
              title: Text(product['name']),
              trailing: TextButton(
                onPressed: () {
                  List<List<int>> data = _buildData(items);
                  _externalDevice(data);
                },
                child: Text("Call"),
              ),
              onTap: () => _openProductForm(index),
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _addNewProductForm,
        child: Icon(Icons.add),
        tooltip: "Add",
      ),
    );
  }
}
