import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';

class DatabaseHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final desktopPath = join(Platform.environment['USERPROFILE']!, 'Desktop');
    final databasePath = join(desktopPath, 'SQLtest.db');

    return await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _onCreate,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Nebudeme vytvárať novú tabuľku, keďže už existuje
  }

  Future<List<Map<String, dynamic>>> getWorkplaces() async {
    final db = await database;
    return await db.query('product_data', distinct: true, columns: ['workplace_id']);
  }

  Future<int> insertWorkplace(String name) async {
    final db = await database;
    return await db.insert('product_data', {
      'workplace_id': name,
      'product': 'Default Product',
      'master_ip': 'Default IP',
      'slave': 0,
      'sensor': 0,
      'sensor_type': 'Default Type',
      'sensor_value': 0.0,
      'sequence': 1
    });
  }
  Future<int> insertWorkplaceWithMasterIP(String name, String masterIP) async {
    final db = await database;
    return await db.insert('product_data', {
      'workplace_id': name,
      'product': 'Default Product',
      'master_ip': masterIP,
      'slave': 0,
      'sensor': 0,
      'sequence': 0,
      'sensor_value': 0.0,
    });
  }


  Future<List<Map<String, dynamic>>> getMasterIPsForWorkplace(String workplaceId) async {
    final db = await database;
    return await db.query(
      'product_data',
      distinct: true,
      columns: ['master_ip'],
      where: 'workplace_id = ?',
      whereArgs: [workplaceId],
    );
  }

  Future<int> insertMasterIP(String workplaceId, String masterIP) async {
    final db = await database;
    return await db.insert('product_data', {
      'workplace_id': workplaceId,
      'master_ip': masterIP,
      'product': 'Default Product',  // môžete zmeniť podľa potreby
      'slave': 0,
      'sensor': 0,
      'sequence': 0,
      'sensor_value': 0.0
    });
  }

  Future<List<Map<String, dynamic>>> getProductsForWorkplace(String workplaceId) async {
    final db = await database;
    return await db.query(
      'product_data',
      distinct: true,
      columns: ['product'],
      where: 'workplace_id = ?',
      whereArgs: [workplaceId],
    );
  }

  Future<int> insertProduct(String name, String workplaceId) async {
    final db = await database;
    return await db.insert('product_data', {
      'workplace_id': workplaceId,
      'product': name,
      'master_ip': 'Default IP',
      'slave': 0,
      'sensor': 0,
      'sensor_type': 'Default Type',
      'sensor_value': 0.0,
      'sequence': 1
    });
  }

  Future<List<Map<String, dynamic>>> getProductDataWithMasterIP(String productName, String workplaceId) async {
    final db = await database;
    return await db.query(
      'product_data',
      where: 'product = ? AND workplace_id = ?',
      whereArgs: [productName, workplaceId],
    );
  }
  Future<int> insertProductData(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('product_data', data);
  }

  Future<int> updateProductData(int id, Map<String, dynamic> data) async {
    final db = await database;
    return await db.update(
      'product_data',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

}