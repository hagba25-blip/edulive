import 'package:flutter/material.dart';
import '../services/api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _wallet;
  List<dynamic> _withdrawals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final wallet = await ApiService.getWallet();
      final withdrawals = await ApiService.myWithdrawals();
      setState(() {
        _wallet = wallet;
        _withdrawals = withdrawals;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openWithdrawDialog() {
    final amountCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final cardCtrl = TextEditingController();
    String method = 'mobile_money';
    final messenger = ScaffoldMessenger.of(context);
    final balance = (_wallet?['balance'] as num?)?.toDouble() ?? 0;
    final currency = _wallet?['currency'] ?? 'XOF';
    final feeRate = (_wallet?['fee_rate'] as num?)?.toDouble() ?? 0.17;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final amount = double.tryParse(amountCtrl.text) ?? 0;
          final fee = amount * feeRate;
          final net = amount - fee;

          return AlertDialog(
            title: const Text('Demander un retrait'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Solde disponible: ${balance.toStringAsFixed(0)} $currency'),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'mobile_money', label: Text('Mobile Money'), icon: Icon(Icons.smartphone)),
                      ButtonSegment(value: 'card', label: Text('Carte bancaire'), icon: Icon(Icons.credit_card)),
                    ],
                    selected: {method},
                    onSelectionChanged: (s) => setDialogState(() => method = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Montant à retirer ($currency)'),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  if (method == 'mobile_money')
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Numéro mobile money (ex: +228XXXXXXXX)'),
                    )
                  else
                    TextField(
                      controller: cardCtrl,
                      decoration: const InputDecoration(labelText: 'Infos carte bancaire'),
                    ),
                  const SizedBox(height: 12),
                  if (amount > 0)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Frais plateforme (${(feeRate * 100).toStringAsFixed(0)}%): ${fee.toStringAsFixed(0)} $currency'),
                          Text(
                            'Vous recevrez: ${net.toStringAsFixed(0)} $currency',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
              FilledButton(
                onPressed: () async {
                  try {
                    final res = await ApiService.requestWithdrawal(
                      method: method,
                      amount: amount,
                      phone: method == 'mobile_money' ? phoneCtrl.text.trim() : null,
                      cardInfo: method == 'card' ? cardCtrl.text.trim() : null,
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    messenger.showSnackBar(SnackBar(content: Text(res['message'])));
                    _load();
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
                  }
                },
                child: const Text('Confirmer'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon portefeuille')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Colors.indigo[50],
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text('Solde disponible', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            '${(_wallet?['balance'] as num?)?.toStringAsFixed(0) ?? 0} ${_wallet?['currency'] ?? 'XOF'}',
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _openWithdrawDialog,
                            icon: const Icon(Icons.account_balance_wallet_outlined),
                            label: const Text('Retirer'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(children: [
                        Text('${(_wallet?['total_revenue'] as num?)?.toStringAsFixed(0) ?? 0}'),
                        const Text('Total encaissé', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                      Column(children: [
                        Text('${(_wallet?['total_withdrawn'] as num?)?.toStringAsFixed(0) ?? 0}'),
                        const Text('Total retiré', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ]),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text('Historique des retraits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (_withdrawals.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Aucun retrait pour le moment'),
                    )
                  else
                    ..._withdrawals.map((w) => Card(
                          child: ListTile(
                            leading: Icon(
                              w['method'] == 'mobile_money' ? Icons.smartphone : Icons.credit_card,
                            ),
                            title: Text('${w['amount']} ${w['currency']}'),
                            subtitle: Text('Net reçu: ${w['net_amount']} ${w['currency']} · ${w['status']}'),
                            trailing: Icon(
                              w['status'] == 'completed'
                                  ? Icons.check_circle
                                  : w['status'] == 'failed'
                                      ? Icons.cancel
                                      : Icons.hourglass_top,
                              color: w['status'] == 'completed'
                                  ? Colors.green
                                  : w['status'] == 'failed'
                                      ? Colors.red
                                      : Colors.orange,
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
