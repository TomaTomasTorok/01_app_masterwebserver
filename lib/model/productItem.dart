class ProductItem {
  int poradie;
  int status;
  int idPL;

  // Constructor to initialize all fields
  ProductItem({required this.poradie, required this.status, required this.idPL});
  Map<String, dynamic> toMap() {
    return {
      'poradie': poradie,
      'status': status,
      'idPL': idPL,
    };
  }

  factory ProductItem.fromMap(Map<String, dynamic> map) {
    return ProductItem(
      poradie: map['poradie'],
      status: map['status'],
      idPL: map['idPL'],
    );
  }
  // Method to display the object as a string (optional)
  @override
  String toString() {
    return 'ProductItem(poradie: $poradie, status: $status, idPL: $idPL)';
  }
}