import 'dart:async';

import 'package:flutter/material.dart';

import '../SQLite/database_helper.dart';
import '../model/task.dart';
import './processProductData.dart';
import './widget_productForm.dart'; // Uistite sa, že máte správny import pre ProductForm

class ProductList extends StatefulWidget {
  final String workplaceId;

  final DatabaseHelper databaseHelper;

  ProductList({required this.workplaceId,  required this.databaseHelper,});

  @override
  _ProductListState createState() => _ProductListState();
}

class _ProductListState extends State<ProductList> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> _allProducts = [];
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _filterController = TextEditingController();
  final FocusNode _filterFocusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    _loadProducts();
    _filterFocusNode.requestFocus();
  }

  Future<void> _loadProducts() async {
    final results = await _databaseHelper.getProductsForWorkplace(widget.workplaceId);
    setState(() {
      _allProducts = results;
     // products = results;
      products = List.from(_allProducts);
    });
  }
  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        products = List.from(_allProducts);
      } else {
        products = _allProducts
            .where((product) => product['product'].toString().toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }
  void _handleEnterPressed() {
    if (products.isNotEmpty) {
      handleCall(products.first['product']);
    }
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
    // showDialog(
    //   context: context,
    //   barrierDismissible: false,
    //   builder: (BuildContext context) {
    //     return WillPopScope(
    //       onWillPop: () async => false,
    //       child: Center(child: CircularProgressIndicator()),
    //     );
    //   },
    // );

    try {
   //   await processProductData(productName, widget.workplaceId);
      Future<void> generateFakeData() async {

          final task = Task(
            product: productName,
            forWorkstation: widget.workplaceId,
            timestampCreated: DateTime.now().toUtc(),
            status: 'NEW',
          );
          await widget.databaseHelper.insertTask(task);

        print('Generated  CALL tasks for workplace $widget.workplace');
      }
      await generateFakeData();


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
  Future<void> _deleteProduct(String productName) async {
    await widget.databaseHelper.deleteProduct(productName, widget.workplaceId);
    _loadProducts();
  }
  void _showDeleteConfirmation(String productName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Product'),
          content: Text('Are you sure you want to delete $productName?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteProduct(productName);
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Product List for ${widget.workplaceId}"),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 250),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                    borderSide: BorderSide(color: Colors.blue, width: 2.0),
                  ),
                  labelText: "New product name",
                  suffixIcon: IconButton(
                    icon: Icon(Icons.add),
                    onPressed: _addProduct,
                  ),
                ),
                onSubmitted: (value) => _addProduct(),
              ),
            ),
          ],
        ),
      ),

      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),

              child: TextField(
                controller: _filterController,
                focusNode: _filterFocusNode,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Filter Products",
                  suffixIcon: Icon(Icons.search),
                ),
                onChanged: _filterProducts,
                onSubmitted: (_) => _handleEnterPressed(),
              ),
            ),

          Expanded(
            child: ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${index + 1}', // Index záznamu, pripočíta sa 1, pretože index začína od 0
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black54,
                          ),
                        ),
                        SizedBox(width: 8), // Medzera medzi číslom a ikonou

                      ],
                    ),
                    title: Text(
                      'Product: ${product['product']}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Details: ${product['details']}',
                      style: TextStyle(color: Colors.black54),
                    ),
                    // trailing: ElevatedButton(
                    //   style: ElevatedButton.styleFrom(
                    //     elevation: 6, // Zvýšená hodnota pre výraznejší vystúpený efekt
                    //     primary: Colors.greenAccent, // Farba pozadia tlačidla
                    //     shape: RoundedRectangleBorder(
                    //       borderRadius: BorderRadius.circular(8),
                    //     ),
                    //     shadowColor: Colors.green.withOpacity(0.4), // Jemný tieň pre vystúpený efekt
                    //   ),
                    //   child: Text(
                    //     'Call',
                    //     style: TextStyle(
                    //       color: Colors.white,
                    //       fontWeight: FontWeight.bold,
                    //     ),
                    //   ),
                    //   onPressed: () => handleCall(product['product']),
                    // ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    ElevatedButton(
                    style: ElevatedButton.styleFrom(
                    elevation: 4,
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      shadowColor: Colors.black.withOpacity(0.95),
                    ),
                    child: Text(
                      'Call',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => handleCall(product['product']),
                  ),
                        SizedBox(width: 28),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 4,
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      shadowColor: Colors.black.withOpacity(0.95),
                    ),
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _showDeleteConfirmation(product['product']),
                  ),
                      ],
                    ),



                    onTap: () => _openProductForm(product),
                  ),
                )
                ;

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
    _filterFocusNode.dispose();
    _filterController.dispose();
    super.dispose();
  }
}