import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RevenueScreen extends StatefulWidget {
  final String classId;
  final String className;

  const RevenueScreen({super.key, required this.classId, required this.className});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  double _total = 0;
  String _currency = 'XOF';
  List<dynamic> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.classRevenue(widget.classId);
      setState(() {
        _total = (res['total'] as num).toDouble();
        _currency = res['currency'];
        _transactions = res['transactions'];
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Revenus — ${widget.className}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Colors.green[50],
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text('Total reçu', style: TextStyle(fontSize: 14, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            '${_total.toStringAsFixed(0)} $_currency',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          const SizedBox(height: 4),
                          Text('${_transactions.length} paiement(s) confirmé(s)', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Aucun paiement pour le moment')),
                    )
                  else
                    ..._transactions.map((t) {
                      final student = t['users'];
                      final name = student != null ? student['full_name'] : 'Élève';
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(name),
                          subtitle: Text(t['confirmed_at']?.toString().substring(0, 16) ?? ''),
                          trailing: Text(
                            '+${t['amount']} ${t['currency']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
