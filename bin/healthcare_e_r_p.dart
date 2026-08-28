import 'dart:io';
import 'package:mysql1/mysql1.dart';

Future<void> main() async {
  final settings = ConnectionSettings(
    host: 'localhost',
    port: 3306,
    user: 'root',
    db: 'healthcare_erp'
  );

  try {
    final conn = await MySqlConnection.connect(settings);
    print('✅ Database Connected!\n');

    while (true) {
      print('=== Healthcare ERP System ===');
      print('1. Add New Patient');
      print('2. View All Patients');
      print('3. Exit');
      stdout.write('Select an option (1-3): ');
      
      String? choice = stdin.readLineSync();

      if (choice == '1') {
        stdout.write('Enter Patient ID (e.g., P002): ');
        String? id = stdin.readLineSync();
        
        stdout.write('Enter Name: ');
        String? name = stdin.readLineSync();
        
        stdout.write('Enter Age: ');
        int? age = int.tryParse(stdin.readLineSync() ?? '0');
        
        stdout.write('Enter Contact: ');
        String? contact = stdin.readLineSync();
        
        stdout.write('Enter Blood Group: ');
        String? bloodGroup = stdin.readLineSync();

        try {
          await conn.query(
            'INSERT INTO patients (id, name, age, contact, blood_group) VALUES (?, ?, ?, ?, ?)',
            [id, name, age, contact, bloodGroup]
          );
          print('\n✅ Patient Added Successfully!\n');
        } catch (e) {
          print('\n❌ Error inserting data: $e\n');
        }

      } else if (choice == '2') {
        print('\n--- Patient Records ---');
        var results = await conn.query('SELECT id, name, age, contact, blood_group FROM patients');
        for (var row in results) {
          print('ID: ${row[0]} | Name: ${row[1]} | Age: ${row[2]} | Contact: ${row[3]} | Blood Group: ${row[4]}');
        }
        print('-----------------------\n');

      } else if (choice == '3') {
        print('Exiting the system...');
        await conn.close();
        break;

      } else {
        print('\n❌ Invalid option! Please try again.\n');
      }
    }
  } catch (e) {
    print('❌ Connection Error: $e');
  }
}