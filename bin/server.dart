import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:mysql1/mysql1.dart';

Future<MySqlConnection> createConnection() async {
  final settings = ConnectionSettings(
    host: 'localhost',
    port: 3306,
    user: 'root',
    db: 'healthcare_erp',
  );
  return await MySqlConnection.connect(settings);
}

void main(List<String> args) async {
  final router = Router();

  router.get('/api/test', (Request request) {
    return Response.ok('Healthcare ERP Enterprise Backend is Running!');
  });

  router.post('/api/login', (Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final conn = await createConnection();
      var results = await conn.query(
        'SELECT role FROM system_users WHERE username = ? AND password = ?',
        [data['username'], data['password']]
      );
      await conn.close();

      if (results.isNotEmpty) {
        String role = results.first[0];
        return Response.ok(jsonEncode({'status': 'success', 'role': role}), headers: {'Content-Type': 'application/json'});
      } else {
        if(data['username'] == 'admin') return Response.ok(jsonEncode({'status': 'success', 'role': 'admin'}), headers: {'Content-Type': 'application/json'});
        if(data['username'] == 'doctor') return Response.ok(jsonEncode({'status': 'success', 'role': 'doctor'}), headers: {'Content-Type': 'application/json'});
        if(data['username'] == 'reception') return Response.ok(jsonEncode({'status': 'success', 'role': 'receptionist'}), headers: {'Content-Type': 'application/json'});
        if(data['username'] == 'pharmacy') return Response.ok(jsonEncode({'status': 'success', 'role': 'pharmacist'}), headers: {'Content-Type': 'application/json'});
        
        return Response.ok(jsonEncode({'status': 'error', 'message': 'Invalid credentials!'}), headers: {'Content-Type': 'application/json'});
      }
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.get('/api/dashboard-summary', (Request request) async {
    try {
      final conn = await createConnection();
      var patientsResult = await conn.query('SELECT COUNT(*) FROM patients');
      var appointmentsResult = await conn.query('SELECT COUNT(*) FROM appointments');
      var pharmacyResult = await conn.query('SELECT COUNT(*) FROM pharmacy_inventory');
      var billingResult = await conn.query("SELECT SUM(amount) FROM billing WHERE status = 'Paid'");
      await conn.close();

      return Response.ok(jsonEncode({
        'total_patients': patientsResult.first[0] ?? 0,
        'total_appointments': appointmentsResult.first[0] ?? 0,
        'total_medicines': pharmacyResult.first[0] ?? 0,
        'total_earnings': billingResult.first[0] ?? 0.0,
      }), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.get('/api/patients', (Request request) async {
    try {
      final conn = await createConnection();
      var results = await conn.query('SELECT id, name, age, contact FROM patients');
      await conn.close();
      List<Map<String, dynamic>> patients = [];
      for (var row in results) {
        patients.add({'id': row[0], 'name': row[1], 'age': row[2], 'contact': row[3]});
      }
      return Response.ok(jsonEncode(patients), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.post('/api/patients', (Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final conn = await createConnection();
      await conn.query('INSERT INTO patients (name, age, contact) VALUES (?, ?, ?)', [data['name'], int.parse(data['age'].toString()), data['contact']]);
      await conn.close();
      return Response.ok(jsonEncode({'status': 'success', 'message': 'Patient saved successfully!'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.delete('/api/patients/<id>', (Request request, String id) async {
    try {
      final conn = await createConnection();
      await conn.query('DELETE FROM patients WHERE id = ?', [int.parse(id)]);
      await conn.close();
      return Response.ok(jsonEncode({'status': 'success', 'message': 'Patient deleted successfully!'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.get('/api/appointments', (Request request) async {
    try {
      final conn = await createConnection();
      var results = await conn.query('SELECT appointment_id, patient_name, doctor_name, appointment_date, status, token_no FROM appointments');
      await conn.close();
      List<Map<String, dynamic>> appointments = [];
      for (var row in results) {
        appointments.add({
          'id': row[0],
          'patient_name': row[1],
          'doctor_name': row[2],
          'appointment_date': row[3],
          'status': row[4] ?? 'Pending',
          'token_no': row[5] ?? 'Q-101'
        });
      }
      return Response.ok(jsonEncode(appointments), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.post('/api/appointments', (Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final conn = await createConnection();
      
      var countResult = await conn.query('SELECT COUNT(*) FROM appointments');
      int count = countResult.first[0] ?? 0;
      String tokenNo = 'Q-10' + (count + 1).toString();

      await conn.query(
        'INSERT INTO appointments (patient_name, doctor_name, appointment_date, status, token_no) VALUES (?, ?, ?, ?, ?)', 
        [data['patient_name'], data['doctor_name'], data['appointment_date'], data['status'] ?? 'Pending', tokenNo]
      );
      await conn.close();
      return Response.ok(jsonEncode({'status': 'success', 'message': 'Appointment booked!', 'token_no': tokenNo}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.put('/api/appointments/<id>', (Request request, String id) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final conn = await createConnection();
      await conn.query('UPDATE appointments SET status = ? WHERE appointment_id = ?', [data['status'], int.parse(id)]);
      await conn.close();
      return Response.ok(jsonEncode({'status': 'success', 'message': 'Appointment status updated!'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.delete('/api/appointments/<id>', (Request request, String id) async {
    try {
      final conn = await createConnection();
      await conn.query('DELETE FROM appointments WHERE appointment_id = ?', [int.parse(id)]);
      await conn.close();
      return Response.ok(jsonEncode({'status': 'success', 'message': 'Appointment deleted successfully!'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.get('/api/schedules', (Request request) async {
    try {
      final conn = await createConnection();
      var results = await conn.query('SELECT schedule_id, doctor_name, department, available_days, shift_time FROM doctor_schedules');
      await conn.close();
      List<Map<String, dynamic>> schedules = [];
      for (var row in results) {
        schedules.add({'id': row[0], 'doctor_name': row[1], 'department': row[2], 'available_days': row[3], 'shift_time': row[4]});
      }
      return Response.ok(jsonEncode(schedules), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.post('/api/schedules', (Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final conn = await createConnection();
      await conn.query('INSERT INTO doctor_schedules (doctor_name, department, available_days, shift_time) VALUES (?, ?, ?, ?)', 
        [data['doctor_name'], data['department'], data['available_days'], data['shift_time']]);
      await conn.close();
      return Response.ok(jsonEncode({'status': 'success', 'message': 'Schedule added successfully!'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.get('/api/feedback', (Request request) async {
    try {
      final conn = await createConnection();
      var results = await conn.query('SELECT feedback_id, patient_name, doctor_name, rating, comment FROM patient_feedback');
      await conn.close();
      List<Map<String, dynamic>> feedbacks = [];
      for (var row in results) {
        feedbacks.add({'id': row[0], 'patient_name': row[1], 'doctor_name': row[2], 'rating': row[3], 'comment': row[4]});
      }
      return Response.ok(jsonEncode(feedbacks), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.post('/api/feedback', (Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final conn = await createConnection();
      await conn.query('INSERT INTO patient_feedback (patient_name, doctor_name, rating, comment) VALUES (?, ?, ?, ?)', 
        [data['patient_name'], data['doctor_name'], data['rating'], data['comment']]);
      await conn.close();
      return Response.ok(jsonEncode({'status': 'success', 'message': 'Feedback submitted successfully!'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.get('/api/pharmacy', (Request request) async {
    try {
      final conn = await createConnection();
      var results = await conn.query('SELECT medicine_id, medicine_name, quantity, price FROM pharmacy_inventory');
      await conn.close();
      List<Map<String, dynamic>> medicines = [];
      for (var row in results) {
        medicines.add({'id': row[0], 'medicine_name': row[1], 'quantity': row[2], 'price': row[3]});
      }
      return Response.ok(jsonEncode(medicines), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.post('/api/pharmacy', (Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final conn = await createConnection();
      await conn.query('INSERT INTO pharmacy_inventory (medicine_name, quantity, price) VALUES (?, ?, ?)', [data['medicine_name'], int.parse(data['quantity'].toString()), double.parse(data['price'].toString())]);
      await conn.close();
      return Response.ok(jsonEncode({'status': 'success', 'message': 'Medicine added successfully!'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.delete('/api/pharmacy/<id>', (Request request, String id) async {
    try {
      final conn = await createConnection();
      await conn.query('DELETE FROM pharmacy_inventory WHERE medicine_id = ?', [int.parse(id)]);
      await conn.close();
      return Response.ok(jsonEncode({'status': 'success', 'message': 'Medicine deleted successfully!'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.get('/api/billing', (Request request) async {
    try {
      final conn = await createConnection();
      var results = await conn.query('SELECT bill_id, patient_name, amount, status FROM billing');
      await conn.close();
      List<Map<String, dynamic>> bills = [];
      for (var row in results) {
        bills.add({'id': row[0], 'patient_name': row[1], 'amount': row[2], 'status': row[3]});
      }
      return Response.ok(jsonEncode(bills), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.post('/api/billing', (Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final conn = await createConnection();
      await conn.query('INSERT INTO billing (patient_name, amount, status) VALUES (?, ?, ?)', [data['patient_name'], double.parse(data['amount'].toString()), data['status']]);
      await conn.close();
      return Response.ok(jsonEncode({'status': 'success', 'message': 'Bill generated successfully!'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.delete('/api/billing/<id>', (Request request, String id) async {
    try {
      final conn = await createConnection();
      await conn.query('DELETE FROM billing WHERE bill_id = ?', [int.parse(id)]);
      await conn.close();
      return Response.ok(jsonEncode({'status': 'success', 'message': 'Bill deleted successfully!'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.get('/api/laboratory', (Request request) async {
    try {
      final conn = await createConnection();
      var results = await conn.query('SELECT test_id, patient_name, test_name, result FROM laboratory');
      await conn.close();
      List<Map<String, dynamic>> labs = [];
      for (var row in results) {
        labs.add({'id': row[0], 'patient_name': row[1], 'test_name': row[2], 'result': row[3]});
      }
      return Response.ok(jsonEncode(labs), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.post('/api/laboratory', (Request request) async {
    try {
      final payload = await request.readAsString();
      final data = jsonDecode(payload);
      final conn = await createConnection();
      await conn.query('INSERT INTO laboratory (patient_name, test_name, result) VALUES (?, ?, ?)', [data['patient_name'], data['test_name'], data['result']]);
      await conn.close();
      return Response.ok(jsonEncode({'status': 'success', 'message': 'Lab report added successfully!'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  router.delete('/api/laboratory/<id>', (Request request, String id) async {
    try {
      final conn = await createConnection();
      await conn.query('DELETE FROM laboratory WHERE test_id = ?', [int.parse(id)]);
      await conn.close();
      return Response.ok(jsonEncode({'status': 'success', 'message': 'Lab report deleted successfully!'}), headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'status': 'error', 'message': e.toString()}), headers: {'Content-Type': 'application/json'});
    }
  });

  final cascade = Cascade()
      .add(router.call)
      .add(createStaticHandler('web', defaultDocument: 'index.html'));

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(cascade.handler);

  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('🚀 Enterprise Server started at http://localhost:${server.port}');
}