import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:masterwebserver/widgets/widget_deviceList.dart';
import 'package:masterwebserver/widgets/widget_itemList.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../model/productItem.dart';
import '../model/wokrplace.dart';



class ProductList extends StatefulWidget {
  final Workplace workplace;

  ProductList({required this.workplace});

  @override
  _ProductListState createState() => _ProductListState();
}

class _ProductListState extends State<ProductList> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
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
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? allProducts = prefs.getStringList('allProducts');

    if (allProducts != null) {
      _products = allProducts.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
      _filteredProducts = _products;
    }

    setState(() {});
  }

  void _filterProducts(String query) {
    if (query.isEmpty) {
      _filteredProducts = _products;
    } else {
      _filteredProducts = _products.where((product) {
        return product['name'].toLowerCase().contains(query.toLowerCase());
      }).toList();
    }
    setState(() {});
  }

  Future<void> _handleProduct(int index) async {
    final product = _filteredProducts[index];
    final List<ProductItem> items = (product['items'] as List)
        .map((item) => ProductItem.fromMap(item))
        .toList();

    List<List<int>> data = await _buildData(items);
    await _externalDevice(data);

    setState(() {
      _controller.clear();
      _filteredProducts = _products;
    });

    // Vrátenie fokusu na TextField po krátkom oneskorení
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  Future<void> _deleteProduct(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? allProducts = prefs.getStringList('allProducts');

    if (allProducts != null && index >= 0 && index < allProducts.length) {
      allProducts.removeAt(index);
      await prefs.setStringList('allProducts', allProducts);
      setState(() {
        _products.removeAt(index);
        _filteredProducts.removeAt(index);
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
    try {
      const url = 'http://192.168.0.184/data';
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"data": data}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request successful!")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request failed: ${response.statusCode}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to connect to the device: $e")));
    }
  }
  Future<List<List<int>>> _buildData(List<ProductItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceListData = prefs.getString('devices');
    List<int> deviceList = [];

    if (deviceListData != null) {
      try {
        List<dynamic> decodedList = json.decode(deviceListData);
        deviceList = decodedList.map((item) => int.parse(item.toString())).toList();
      } catch (e) {
        print("Chyba pri dekódovaní: $e");
      }
    }

    print("Loaded devices: $deviceList");

    List<List<int>> data = [
      deviceList,
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
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.device_hub),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DeviceList()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              focusNode: _focusNode,
              controller: _controller,
              decoration: InputDecoration(
                labelText: "Enter product ID",
                suffixIcon: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    if (_filteredProducts.isNotEmpty) {
                      _handleProduct(0);
                    }
                  },
                ),
              ),
             // keyboardType: TextInputType.number,
              onChanged: (value) => _filterProducts(value),
              onSubmitted: (value) {
                if (_filteredProducts.isNotEmpty) {
                  _handleProduct(0);
                }
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
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
                      onPressed: () async {
                        List<List<int>> data = await _buildData(items);
                        _externalDevice(data);
                      },
                      child: Text("Call"),
                    ),
                    onTap: () => _openProductForm(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewProductForm,
        child: Icon(Icons.add),
        tooltip: "Add",
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
