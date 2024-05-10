
import 'package:masterwebserver/model/productItem.dart';

class Product {
  int name;
  int pocetPL;
  List<ProductItem> items;

  // Constructor to initialize all fields
  Product({required this.name, required this.pocetPL, required this.items});

  // Method to display the object as a string (optional)
  @override
  String toString() {
    return 'Product(name: $name, pocetPL: $pocetPL, items: $items)';
  }
}
