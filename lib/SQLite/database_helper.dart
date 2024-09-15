import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';

import '../model/task.dart';

class DatabaseHelper {
  static Database? _database;
  static const String DEFAULT_PRODUCT = 'DEFAULT_PRODUCT';
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
    // Táto metóda sa volá len ak databáza ešte neexistuje
    await db.execute('''
      CREATE TABLE product_data(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workplace_id TEXT NOT NULL,
        product TEXT NOT NULL,
        master_ip TEXT NOT NULL,
        slave INTEGER NOT NULL,
        sensor INTEGER NOT NULL,
        sensor_type TEXT,
        sensor_value REAL,
        sequence INTEGER NOT NULL
      )
    ''');
  }


  Future<int> getMaxSequenceForProduct(String workplaceId, String productName) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT MAX(sequence) as max_sequence
      FROM product_data
      WHERE workplace_id = ? AND product = ?
    ''', [workplaceId, productName]);

    return (result.first['max_sequence'] as int?) ?? 0;
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
      'product': DEFAULT_PRODUCT,
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
      where: 'workplace_id = ? AND product != ?',
      whereArgs: [workplaceId, DEFAULT_PRODUCT],
    );
  }


  Future<int> insertProduct(String name, String workplaceId) async {
    final db = await database;
    return await db.transaction((txn) async {
      // Vloženie nového produktu
      final id = await txn.insert('product_data', {
        'workplace_id': workplaceId,
        'product': name,
        'master_ip': await _getMasterIPForWorkplace(workplaceId, txn),
        'slave': 0,
        'sensor': 0,
        'sensor_type': 'Default Type',
        'sensor_value': 0.0,
        'sequence': 1
      });

      // Kontrola a odstránenie default produktu
      // final defaultProducts = await txn.query(
      //   'product_data',
      //   where: 'workplace_id = ? AND product = ?',
      //   whereArgs: [workplaceId, DEFAULT_PRODUCT],
      // );

      // if (defaultProducts.isNotEmpty) {
      //   await txn.delete(
      //     'product_data',
      //     where: 'workplace_id = ? AND product = ?',
      //     whereArgs: [workplaceId, DEFAULT_PRODUCT],
      //   );
      // }

      return id;
    });
  }
  Future<String> _getMasterIPForWorkplace(String workplaceId, Transaction txn) async {
    final result = await txn.query(
      'product_data',
      columns: ['master_ip'],
      where: 'workplace_id = ?',
      whereArgs: [workplaceId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first['master_ip'] as String : '';
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

  Future<int> deleteWorkplace(String workplaceId) async {
    final db = await database;
    return await db.delete(
      'product_data',
      where: 'workplace_id = ?',
      whereArgs: [workplaceId],
    );
  }
  Future<List<Map<String, dynamic>>> getWorkplaces() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT workplace_id, MAX(master_ip) as master_ip
      FROM product_data
      GROUP BY workplace_id
    ''');
  }

  Future<bool> isWorkplaceUnique(String workplaceId) async {
    final db = await database;
    var result = await db.query(
      'product_data',
      where: 'workplace_id = ?',
      whereArgs: [workplaceId],
      limit: 1,
    );
    return result.isEmpty;
  }

  Future<int> insertWorkplaceWithMasterIP(String workplaceId, String masterIP) async {
    if (await isWorkplaceUnique(workplaceId)) {
      final db = await database;
      return await db.insert('product_data', {
        'workplace_id': workplaceId,
        'master_ip': masterIP,
        'product': DEFAULT_PRODUCT,
        'slave': 0,
        'sensor': 0,
        'sequence': 0,
        'sensor_value': 0.0,
      });
    } else {
      throw Exception('Workplace with this ID already exists');
    }
  }
  Future<int> deleteProduct(String productName, String workplaceId) async {
    final db = await database;
    return await db.delete(
      'product_data',
      where: 'product = ? AND workplace_id = ?',
      whereArgs: [productName, workplaceId],
    );
  }

  Future<int> deleteSensor( int sensorId) async {
    final db = await database;
    return await db.delete(
      'product_data',
      where: ' id = ?',
      whereArgs: [sensorId],
    );
  }



  Future<bool> taskExists(Task task) async {
    final db = await database;
    var result = await db.query(
      'work_data',
      where: 'product = ? AND timestamp_created = ?',
      whereArgs: [task.product, task.timestampCreated.toIso8601String()],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert('work_data', task.toMap());
  }

  // Future<List<Task>> getNewTasks(String workplace) async {
  //   final db = await database;
  //   final List<Map<String, dynamic>> maps = await db.query(
  //     'work_data',
  //     where: 'status = ?',
  //     whereArgs: ['NEW'],
  //   );
  //
  //   return List.generate(maps.length, (i) {
  //     return Task.fromMap(maps[i]);
  //   });
  // }
  Future<List<Task>> getNewTasks(String workplace) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'work_data',
      where: 'for_workstation = ?',
      whereArgs: [workplace],
      orderBy:  "id DESC",
      limit: 1,
    );

    if (maps.isNotEmpty) {
      final latestTask = Task.fromMap(maps.first);
      if (latestTask.status == 'NEW') {
        return [latestTask];
      }
    }

    return []; // Return empty list if no NEW task found
  }
  Future<int> updateTask(Task task) async {
    final db = await database;
    return await db.update(
      'work_data',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<bool> productExists(String productName, String workplaceId) async {
    final db = await database;
    var result = await db.query(
      'product_data',
      where: 'product = ? AND workplace_id = ?',
      whereArgs: [productName, workplaceId],
      limit: 1,
    );
    return result.isNotEmpty;
  }


}