// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
//
// import '../model/productItem.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
//
// import '../model/productItem.dart';
// import '../model/product.dart'; // Import Product class
//
// class ProductForm extends StatefulWidget {
//   final int? editIndex;
//   final String initialName;
//   final String? workplace;
//   final List<ProductItem> initialItems;
//
//   ProductForm({this.editIndex, required this.initialName, required this.initialItems, this.workplace});
//
//   @override
//   _ProductFormState createState() => _ProductFormState();
// }
//
// class _ProductFormState extends State<ProductForm> {
//   final TextEditingController _productNameController = TextEditingController();
//   List<ProductItem> _productItems = [];
//   final FocusNode _idPLFocusNode = FocusNode();
//
//   @override
//   void initState() {
//     super.initState();
//     _productNameController.text = widget.initialName;
//     _productItems = widget.initialItems;
//   }
//
//   void _showAddOrEditItemDialog({int? index}) {
//     final TextEditingController poradieController = TextEditingController(
//       text: index != null ? _productItems[index].poradie.toString() : (_productItems.length + 1).toString(),
//     );
//     final TextEditingController statusController = TextEditingController(
//       text: index != null ? _productItems[index].status.toString() : '1',
//     );
//     final TextEditingController idPLController = TextEditingController(
//       text: index != null ? _productItems[index].idPL.toString() : '',
//     );
//
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (BuildContext context, StateSetter setState) {
//             WidgetsBinding.instance.addPostFrameCallback((_) {
//               FocusScope.of(context).requestFocus(_idPLFocusNode);
//             });
//             return AlertDialog(
//               title: index == null ? Text("Add Product Item") : Text("Edit Product Item"),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextField(
//                     controller: poradieController,
//                     decoration: InputDecoration(labelText: "Poradie"),
//                     keyboardType: TextInputType.number,
//                   ),
//                   TextField(
//                     controller: statusController,
//                     decoration: InputDecoration(labelText: "Status"),
//                     keyboardType: TextInputType.number,
//                   ),
//                   TextField(
//                     focusNode: _idPLFocusNode,
//                     controller: idPLController,
//                     decoration: InputDecoration(labelText: "IDPL"),
//                     keyboardType: TextInputType.number,
//                     onSubmitted: (_) => _submitAndCloseDialog(context, poradieController, statusController, idPLController, index),
//                   ),
//                 ],
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () {
//                     Navigator.of(context).pop();
//                   },
//                   child: Text("Cancel"),
//                 ),
//                 TextButton(
//                   onPressed: () => _submitAndCloseDialog(context, poradieController, statusController, idPLController, index),
//                   child: Text(index == null ? "Add" : "Save"),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }
//
//   void _submitAndCloseDialog(BuildContext context, TextEditingController poradieController,
//       TextEditingController statusController, TextEditingController idPLController, int? index) {
//     int poradie = int.tryParse(poradieController.text) ?? _productItems.length + 1;
//     int status = int.tryParse(statusController.text) ?? 1;
//     int idPL = int.tryParse(idPLController.text) ?? _productItems.length + 1;
//
//     setState(() {
//       if (index == null) {
//         _productItems.add(ProductItem(poradie: poradie, status: status, idPL: idPL));
//       } else {
//         _productItems[index] = ProductItem(poradie: poradie, status: status, idPL: idPL);
//       }
//     });
//
//     Navigator.of(context).pop();
//   }
//
//   Future<void> _saveData() async {
//     final prefs = await SharedPreferences.getInstance();
//     final Product newProduct = Product(
//       name: _productNameController.text,
//       pocetPL: _productItems.length,
//       workplace: widget.workplace??"", // Update with appropriate value
//       items: _productItems,
//     );
//     final String newProductJson = jsonEncode(newProduct.toMap());
//
//     List<String> allProducts = prefs.getStringList('allProducts') ?? [];
//
//     if (widget.editIndex != null) {
//       allProducts[widget.editIndex!] = newProductJson;
//     } else {
//       allProducts.add(newProductJson);
//     }
//
//     await prefs.setStringList('allProducts', allProducts);
//
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Data saved successfully!')));
//   }
//
//   @override
//   void dispose() {
//     _productNameController.dispose();
//     _idPLFocusNode.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Product Form"),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             TextField(
//               controller: _productNameController,
//               decoration: InputDecoration(labelText: "Product Name"),
//             ),
//             SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: () => _showAddOrEditItemDialog(),
//               child: Text("Add Product Item"),
//             ),
//             SizedBox(height: 16),
//             Text("Product Items:"),
//             Expanded(
//               child: ListView.builder(
//                 itemCount: _productItems.length,
//                 itemBuilder: (context, index) {
//                   final item = _productItems[index];
//                   return ListTile(
//                     title: Text("Item ${item.poradie}: Status ${item.status}, IDPL ${item.idPL}"),
//                     onTap: () => _showAddOrEditItemDialog(index: index),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _saveData,
//         child: Icon(Icons.save),
//         tooltip: "Save",
//       ),
//     );
//   }
// }
//
