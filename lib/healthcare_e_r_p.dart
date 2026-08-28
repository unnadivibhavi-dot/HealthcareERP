import 'package:mysql1/mysql1.dart';

Future<void> main() async {
  final settings = ConnectionSettings(
    host: 'localhost',
    port: 3306,
    user: 'root',
    // password එක null හෝ හිස් තැබීම වෙනුවට connection එකට අදාළව මෙසේ දෙන්න:
    password: null, 
    db: 'healthcare_erp'
  );

  print('Connecting to database...');

  try {
    final conn = await MySqlConnection.connect(settings);
    print('✅ Successfully connected to the database!\n');

    print('Inserting patient data...');
    
    await conn.query(
      'INSERT INTO patients (id, name, age, contact, blood_group) VALUES (?, ?, ?, ?, ?)',
      ['P001', 'Kamal Perera', 30, '0777654321', 'O+']
    );

    print('✅ "Kamal Perera" data inserted successfully!\n');
    
    await conn.close();

  } catch (e) {
    print('❌ Error occurred: $e');
  }
}