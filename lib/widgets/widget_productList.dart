import 'dart:async';

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

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );

    try {
      await processProductData(productName, widget.workplaceId);

      if (!mounted) return;

      // Close loading indicator
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Call completed for $productName')));
    } catch (e) {
      print('Error in handleCall: $e');
      if (!mounted) return;

      // Close loading indicator
      Navigator.of(context).pop();

      // Show error popup
      print('Attempting to show error popup');
      showPersistentErrorDialog(context, e.toString());
    }
  }

  void showPersistentErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Start a timer to close the dialog after 10 seconds
        Timer(Duration(seconds: 10), () {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
            print('Popup closed by timer');
          }
        });

        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: Text('Error'),
            content: Text('An error occurred while processing the product: $errorMessage'),
            actions: <Widget>[
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  print('Popup closed by user');
                },
              ),
            ],
          ),
        );
      },
    ).then((_) => print('showDialog completed'));

    // Show the original error snackbar
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $errorMessage')));
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