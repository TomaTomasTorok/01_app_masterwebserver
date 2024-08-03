import 'package:flutter/material.dart';
import 'package:masterwebserver/widgets/widget_productForm.dart';
import '../SQLite/database_helper.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

class ProductList extends StatefulWidget {
  final String workplaceId;
  final String workplaceName;

  ProductList({required this.workplaceId, required this.workplaceName});

  @override
  _ProductListState createState() => _ProductListState();
}

class _ProductListState extends State<ProductList> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Map<String, dynamic>> products = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final results = await _databaseHelper.getProductsForWorkplace(widget.workplaceId);
    setState(() {
      products = results;
    });
  }

  void _addProduct() async {
    if (_controller.text.isNotEmpty) {
      await _databaseHelper.insertProduct(_controller.text, widget.workplaceId);

      _controller.clear();
      _loadProducts();
    }
  }

  Future<void> _handleCall(String productName) async {
    final productData = await _databaseHelper.getProductDataWithMasterIP(productName, widget.workplaceId);
    if (productData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No data for this product')));
      return;
    }

    final masterIP = productData.first['master_ip'];
    final data = productData.map((item) => [item['slave'], item['sequence'], item['sensor']]).toList();
    data.sort((a, b) => (a[1] as int).compareTo(b[1] as int)); // Sort by sequence

    try {
      final channel = WebSocketChannel.connect(Uri.parse('ws://$masterIP:81'));
      channel.sink.add(json.encode({"data": data}));

      channel.stream.listen(
            (message) {
          print('Received message: $message');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Received: $message')));
        },
        onDone: () {
          print('WebSocket closed');
        },
        onError: (error) {
          print('WebSocket error: $error');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
        },
      );
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection error: $e')));
    }
  }

  void _openProductForm(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductForm(
          workplace: widget.workplaceId,
          masterIp: product['master_ip'] ?? 'Unknown',
          product: product,
        ),
      ),
    ).then((_) => _loadProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Product List for ${widget.workplaceName}"),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: "Enter Product Name",
                suffixIcon: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: _addProduct,
                ),
              ),
              onSubmitted: (value) => _addProduct(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return ListTile(
                  title: Text('Product: ${product['product']}'),
                  trailing: ElevatedButton(
                    child: Text('Call'),
                    onPressed: () => _handleCall(product['product']),
                  ),
                  onTap: () => _openProductForm(product),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}