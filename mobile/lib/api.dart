import 'dart:convert';

import 'package:http/http.dart' as http;

class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.vendor,
    required this.type,
    required this.rawText,
    required this.timestamp,
  });

  final int id;
  final double amount;
  final String vendor;
  final String type;
  final String rawText;
  final DateTime timestamp;

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as int,
      amount: (json['amount'] as num).toDouble(),
      vendor: json['vendor'] as String,
      type: json['type'] as String,
      rawText: json['raw_text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String).toLocal(),
    );
  }

  bool get isDebit => type.toLowerCase() == 'debit';
}

class ExpensesPayload {
  const ExpensesPayload({required this.dailyTotal, required this.expenses});

  final double dailyTotal;
  final List<Expense> expenses;

  factory ExpensesPayload.fromJson(Map<String, dynamic> json) {
    final items = (json['expenses'] as List<dynamic>? ?? [])
        .map((item) => Expense.fromJson(item as Map<String, dynamic>))
        .toList();
    return ExpensesPayload(
      dailyTotal: (json['daily_total'] as num?)?.toDouble() ?? 0,
      expenses: items,
    );
  }
}

class PocketGuardApi {
  Future<ExpensesPayload> fetchExpenses(String host) async {
    final uri = Uri.parse('http://$host:8000/api/expenses');
    final response = await http.get(uri).timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) {
      throw Exception('Server returned ${response.statusCode}');
    }
    return ExpensesPayload.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
