import 'dart:convert';

class Workplace {
  String name;
  String ipAddress;
  List<dynamic> products;

  Workplace({required this.name, required this.ipAddress, this.products = const []});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ipAddress': ipAddress,
      'products': json.encode(products),
    };
  }

  factory Workplace.fromMap(Map<String, dynamic> map) {
    return Workplace(
      name: map['name'],
      ipAddress: map['ipAddress'],
      products: json.decode(map['products']),
    );
  }
}
