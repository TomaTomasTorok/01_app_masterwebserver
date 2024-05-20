import 'package:masterwebserver/model/productItem.dart';
import 'package:masterwebserver/model/productItem.dart';
import 'package:masterwebserver/model/productItem.dart';

class Product {
  String name;
  int pocetPL;
  String workplace;
  List<ProductItem> items;

  Product({
    required this.name,
    required this.pocetPL,
    required this.items,
    required this.workplace,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      name: map['name'] ?? '',
      pocetPL: map['pocetPL'] ?? 0,
      workplace: map['workplace'] ?? '',
      items: map['items'] != null
          ? List<ProductItem>.from(map['items'].map((item) => ProductItem.fromMap(item)))
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'pocetPL': pocetPL,
      'workplace': workplace,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  @override
  String toString() {
    return 'Product(name: $name, pocetPL: $pocetPL, items: $items, workplace: $workplace)';
  }
}
