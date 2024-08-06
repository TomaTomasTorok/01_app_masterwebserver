import 'package:flutter/material.dart';

import '../SQLite/database_helper.dart';
import './processProductData.dart';
import './widget_productForm.dart'; // Uistite sa, že máte správny import pre ProductForm

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

  Future<void> handleCall(String productName) async {
    print('Starting handleCall for product: $productName');
    if (!mounted) {
      print('Widget is not mounted. Exiting handleCall.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(child: CircularProgressIndicator());
      },
    );

    try {
      await processProductData(productName, widget.workplaceId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Call completed for $productName')));
    } catch (e) {
      print('Error in handleCall: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
    } finally {
      if (mounted) {
        Navigator.of(context).pop(); // Zatvorí indikátor priebehu
      }
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
                    onPressed: () => handleCall(product['product']),
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