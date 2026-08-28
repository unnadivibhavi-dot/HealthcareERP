import 'dart:io';
import 'package:mysql1/mysql1.dart';

// 1. Patient Class (දත්ත ආකෘතිය)
class Patient {
  String id, name, contact, bloodGroup;
  int age;
  Patient(this.id, this.name, this.age, this.contact, this.bloodGroup);
}

// 2. Database Helper Class (දත්ත සමුදාය හැසිරවීම)
class DatabaseHelper {
  late MySqlConnection conn;

  Future<void> connect() async {
    final settings = ConnectionSettings(
        host: 'localhost', port: 3306, user: 'root', db: 'healthcare_erp');
    conn = await MySqlConnection.connect(settings);
    print('✅ Database Connected!\n');
  }

  Future<void> addPatient(Patient p) async {
    try {
      await conn.query(
          'INSERT INTO patients (id, name, age, contact, blood_group) VALUES (?, ?, ?, ?, ?)',
          [p.id, p.name, p.age, p.contact, p.bloodGroup]);
      print('\n✅ Patient Added Successfully!\n');
    } catch (e) {
      print('\n❌ Error inserting data: $e\n');
    }
  }

  Future<void> viewPatients() async {
    print('\n--- Patient Records ---');
    var results = await conn.query('SELECT * FROM patients');
    for (var row in results) {
      print('ID: ${row[0]} | Name: ${row[1]} | Age: ${row[2]} | Contact: ${row[3]} | Blood: ${row[4]}');
    }
    print('-----------------------\n');
  }

  Future<void> updatePatient(String id, int age, String contact) async {
    try {
      await conn.query('UPDATE patients SET age = ?, contact = ? WHERE id = ?', [age, contact, id]);
      print('\n✅ Patient Updated Successfully!\n');
    } catch (e) {
      print('\n❌ Error updating data: $e\n');
    }
  }

  Future<void> deletePatient(String id) async {
    try {
      await conn.query('DELETE FROM patients WHERE id = ?', [id]);
      print('\n✅ Patient Deleted Successfully!\n');
    } catch (e) {
      print('\n❌ Error deleting data: $e\n');
    }
  }

  Future<void> close() async => await conn.close();
}

// 3. Main Function (පද්ධතිය ක්‍රියාත්මක කිරීම)
Future<void> main() async {
  var db = DatabaseHelper();
  await db.connect();

  while (true) {
    print('=== Healthcare ERP System (OOP Version) ===');
    print('1. Add Patient  |  2. View Patients  |  3. Update  |  4. Delete  |  5. Exit');
    stdout.write('Select an option: ');
    String? choice = stdin.readLineSync();

    if (choice == '1') {
      stdout.write('Enter ID: '); String id = stdin.readLineSync() ?? '';
      stdout.write('Enter Name: '); String name = stdin.readLineSync() ?? '';
      stdout.write('Enter Age: '); int age = int.tryParse(stdin.readLineSync() ?? '0') ?? 0;
      stdout.write('Enter Contact: '); String contact = stdin.readLineSync() ?? '';
      stdout.write('Enter Blood Group: '); String bg = stdin.readLineSync() ?? '';
      await db.addPatient(Patient(id, name, age, contact, bg));
    } else if (choice == '2') {
      await db.viewPatients();
    } else if (choice == '3') {
      stdout.write('Enter ID to Update: '); String id = stdin.readLineSync() ?? '';
      stdout.write('Enter New Age: '); int age = int.tryParse(stdin.readLineSync() ?? '0') ?? 0;
      stdout.write('Enter New Contact: '); String contact = stdin.readLineSync() ?? '';
      await db.updatePatient(id, age, contact);
    } else if (choice == '4') {
      stdout.write('Enter ID to Delete: '); String id = stdin.readLineSync() ?? '';
      await db.deletePatient(id);
    } else if (choice == '5') {
      print('Exiting...');
      await db.close();
      break;
    } else {
      print('\n❌ Invalid option!\n');
    }
  }
}