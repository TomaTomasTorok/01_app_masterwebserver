import 'package:flutter/material.dart';
import 'package:masterwebserver/widgets/widget_workPlaceList.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializácia sqflite_common_ffi pre Windows
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: WorkplaceList(),
    );
  }
}



//
//
// import 'package:flutter/material.dart';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';
// import 'package:path/path.dart';
// import 'dart:io';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   // Inicializácia sqflite_common_ffi pre Windows
//   sqfliteFfiInit();
//   databaseFactory = databaseFactoryFfi;
//
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Product Data',
//       home: ProductDataPage(),
//     );
//   }
// }
//
// class ProductDataPage extends StatefulWidget {
//   @override
//   _ProductDataPageState createState() => _ProductDataPageState();
// }
//
// class _ProductDataPageState extends State<ProductDataPage> {
//   List<Map<String, dynamic>> productData = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _loadProductData();
//   }
//
//   Future<void> _loadProductData() async {
//     try {
//       final desktopPath = join(Platform.environment['USERPROFILE']!, 'Desktop');
//       final databasePath = join(desktopPath, 'SQLtest.db');
//
//       print('Pokúšam sa otvoriť databázu na: $databasePath');
//
//       if (!File(databasePath).existsSync()) {
//         throw Exception('Databázový súbor neexistuje na ceste: $databasePath');
//       }
//
//       final database = await databaseFactoryFfi.openDatabase(
//         databasePath,
//         options: OpenDatabaseOptions(
//           readOnly: true,
//           version: 1,
//         ),
//       );
//
//       final results = await database.query('product_data');
//
//       print('Počet nájdených záznamov: ${results.length}');
//
//       setState(() {
//         productData = results;
//       });
//
//       await database.close();
//     } catch (e) {
//       print('Chyba pri načítaní dát: $e');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Informácie o produktoch'),
//       ),
//       body: productData.isEmpty
//           ? Center(child: Text('Žiadne dáta neboli nájdené'))
//           : ListView.builder(
//         itemCount: productData.length,
//         itemBuilder: (context, index) {
//           final item = productData[index];
//           return ExpansionTile(
//             title: Text('Produkt: ${item['product']}'),
//             children: [
//               ListTile(title: Text('Master IP: ${item['master_ip']}')),
//               ListTile(title: Text('Slave: ${item['slave']}')),
//               ListTile(title: Text('Sensor: ${item['sensor']}')),
//               ListTile(title: Text('Sensor Type: ${item['sensor_type']}')),
//               ListTile(title: Text('Sensor Value: ${item['sensor_value']}')),
//             ],
//           );
//         },
//       ),
//     );
//   }
// }//