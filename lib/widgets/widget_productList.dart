//x
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:masterwebserver/widgets/widget_deviceList.dart';
import 'package:masterwebserver/widgets/widget_itemList.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../model/productItem.dart';
import '../model/wokrplace.dart';
import '../model/product.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';

class ProductList extends StatefulWidget {
  final Workplace workplace;

  ProductList({required this.workplace});

  @override
  _ProductListState createState() => _ProductListState();
}

class _ProductListState extends State<ProductList> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  late WebSocketChannel channel;
  bool isWebSocketConnected = false;
  StreamSubscription? streamSubscription;

  @override
  void initState() {
    super.initState();
    initWebSocket();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  void initWebSocket() {
    channel = WebSocketChannel.connect(
      Uri.parse('ws://${widget.workplace.ipAddress}:81'),
    );
    isWebSocketConnected = true;

    streamSubscription = channel.stream.listen(
          (message) {
        print('Received message: $message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Prijaté cez WebSocket: $message")),
        );
      },
      onDone: () {
        print('WebSocket connection closed');
        isWebSocketConnected = false;
      },
      onError: (error) {
        print('WebSocket error: $error');
        isWebSocketConnected = false;
      },
    );
  }

  void _openProductForm(String productId) {
    final product = _products.firstWhere((product) => product.name == productId);
    final List<ProductItem> items = product.items;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductForm(
          editIndex: _products.indexOf(product),
          initialName: product.name,
          initialItems: items,
          workplace: product.workplace,
        ),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? allProducts = prefs.getStringList('allProducts');

    if (allProducts != null) {
      _products = allProducts.map((item) => Product.fromMap(jsonDecode(item))).toList();

      _filteredProducts = widget.workplace != null
          ? _products.where((product) {
        return product.workplace.toLowerCase().contains(widget.workplace.name.toLowerCase());
      }).toList()
          : _products;
    }

    setState(() {});
  }

  void _filterProducts(String query) {
    if (query.isEmpty) {
      _filteredProducts = widget.workplace != null
          ? _products.where((product) {
        return product.workplace.toLowerCase().contains(widget.workplace.name.toLowerCase());
      }).toList()
          : _products;
    } else {
      _filteredProducts = _products.where((product) {
        return product.name.toLowerCase().contains(query.toLowerCase()) &&
            (widget.workplace != null ? product.workplace.toLowerCase().contains(widget.workplace.name.toLowerCase()) : true);
      }).toList();
    }
    setState(() {});
  }

  Future<void> _handleProduct(String productId) async {
    final product = _filteredProducts.firstWhere((product) => product.name == productId);
    final List<ProductItem> items = product.items;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Processing..."),
              ],
            ),
          ),
        );
      },
    );

    List<List<int>> data = await _buildData(items);
    await _externalDevice(data);

    Navigator.of(context).pop();

    setState(() {
      _controller.clear();
      _filterProducts('');
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  Future<void> _deleteProduct(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? allProducts = prefs.getStringList('allProducts');

    if (allProducts != null) {
      _products.removeWhere((product) => product.name == productId);
      allProducts.removeWhere((item) => jsonDecode(item)['name'] == productId);
      await prefs.setStringList('allProducts', allProducts);
      setState(() {
        _filteredProducts = _products.where((product) {
          return widget.workplace != null
              ? product.workplace.toLowerCase().contains(widget.workplace.name.toLowerCase())
              : true;
        }).toList();
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
          workplace: widget.workplace.name,
        ),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _externalDevice(List<List<int>> data) async {
    if (!isWebSocketConnected) {
      initWebSocket();
    }

    try {
      channel.sink.add(json.encode({"data": data}));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Dáta odoslané. Čakám na odpoveď...")),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Chyba pri odosielaní dát: $e")),
      );
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
                labelText: "Search: Enter product ID",
                suffixIcon: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    if (_filteredProducts.isNotEmpty) {
                      _handleProduct(_filteredProducts[0].name);
                    }
                  },
                ),
              ),
              onChanged: (value) => _filterProducts(value),
              onSubmitted: (value) {
                if (_filteredProducts.isNotEmpty) {
                  _handleProduct(_filteredProducts[0].name);
                }
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredProducts.length,
              itemBuilder: (context, index) {
                final product = _filteredProducts[index];
                final List<ProductItem> items = product.items;

                return Dismissible(
                  key: Key(product.name),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) => _deleteProduct(product.name),
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
                    title: Text(product.name),
                    trailing: TextButton(
                      onPressed: () async {
                        List<List<int>> data = await _buildData(items);
                        _externalDevice(data);
                      },
                      child: Text("Call"),
                    ),
                    onTap: () => _openProductForm(product.name),
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
    streamSubscription?.cancel();
    channel.sink.close();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}