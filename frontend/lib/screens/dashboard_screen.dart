import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'classroom_screen.dart';
import 'exercises_screen.dart';
import 'class_students_screen.dart';
import 'revenue_screen.dart';
import 'class_detail_screen.dart';
import 'wallet_screen.dart';
import 'notifications_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SchoolClass> _myClasses = [];
  List<SchoolClass> _publicClasses = [];
  bool _loadingMine = true;
  bool _loadingPublic = true;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyClasses();
    _loadPublicClasses();
    _loadNotificationCount();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyClasses() async {
    setState(() => _loadingMine = true);
    final raw = await ApiService.myClasses();
    setState(() {
      _myClasses = raw.map((c) => SchoolClass.fromJson(c)).toList();
      _loadingMine = false;
    });
  }

  Future<void> _loadPublicClasses() async {
    setState(() => _loadingPublic = true);
    try {
      final raw = await ApiService.publicClasses();
      setState(() {
        _publicClasses = raw.map((c) => SchoolClass.fromJson(c)).toList();
      });
    } catch (_) {
      // silencieux
    } finally {
      setState(() => _loadingPublic = false);
    }
  }

  Future<void> _loadNotificationCount() async {
    try {
      final notifs = await ApiService.myNotifications();
      final unread = notifs.where((n) => n['is_read'] != true).length;
      setState(() => _unreadNotifications = unread);
    } catch (_) {}
  }

  // --- Devinette simple du code pays à partir de la langue de l'appareil ---
  static const Map<String, String> _localeToCountryCode = {
    'TG': '+228', 'BJ': '+229', 'CI': '+225', 'SN': '+221', 'ML': '+223',
    'BF': '+226', 'NE': '+227', 'GH': '+233', 'NG': '+234', 'FR': '+33',
    'US': '+1', 'GB': '+44', 'CM': '+237', 'CD': '+243', 'GN': '+224',
  };

  String _guessCountryCode() {
    final country = ui.PlatformDispatcher.instance.locale.countryCode;
    return _localeToCountryCode[country] ?? '+228';
  }

  static const List<String> _subjects = [
    'Mathématiques', 'Physique', 'Chimie', 'Français', 'Anglais', 'Histoire',
    'Géographie', 'SVT', 'Informatique', 'Économie', 'Autre',
  ];

  static const List<String> _currencies = ['XOF', 'EUR', 'USD'];
  static const List<String> _countryCodes = [
    '+228', '+229', '+225', '+221', '+223', '+226', '+227', '+233', '+234',
    '+237', '+243', '+224', '+33', '+1', '+44',
  ];

  void _showCreateOrJoinDialog() {
    final isTeacher = widget.user.isTeacher;
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedSubject = _subjects.first;
    final customSubjectCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0');
    final phoneCtrl = TextEditingController();
    bool isPaid = false;
    bool isPrivate = false;
    String currency = _currencies.first;
    String countryCode = _guessCountryCode();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isTeacher ? 'Créer une classe' : 'Rejoindre une classe (par code)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: isTeacher
                  ? [
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom (ex: Seconde S)')),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Description (visible par tous)'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSubject,
                        isExpanded: true,
                        items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setDialogState(() => selectedSubject = v ?? _subjects.first),
                        decoration: const InputDecoration(labelText: 'Matière'),
                      ),
                      if (selectedSubject == 'Autre') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: customSubjectCtrl,
                          decoration: const InputDecoration(labelText: 'Précise la matière'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Classe privée'),
                        subtitle: const Text('Non visible publiquement, uniquement accessible par code'),
                        value: isPrivate,
                        onChanged: (v) => setDialogState(() => isPrivate = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Classe payante'),
                        subtitle: const Text('Les participants devront payer pour la rejoindre'),
                        value: isPaid,
                        onChanged: (v) => setDialogState(() => isPaid = v),
                      ),
                      if (isPaid) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: priceCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Prix'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: currency,
                              items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) => setDialogState(() => currency = v ?? currency),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Numéro Mobile Money (pour recevoir tes paiements)', style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            DropdownButton<String>(
                              value: countryCode,
                              items: _countryCodes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) => setDialogState(() => countryCode = v ?? countryCode),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(hintText: '90123456'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ]
                  : [
                      TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: "Code d'invitation")),
                      const SizedBox(height: 8),
                      const Text(
                        'Astuce: pour rejoindre une classe publique, utilise plutôt l\'onglet "Découvrir".',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                try {
                  if (isTeacher) {
                    final subject = selectedSubject == 'Autre' && customSubjectCtrl.text.trim().isNotEmpty
                        ? customSubjectCtrl.text.trim()
                        : selectedSubject;
                    final fullPhone = phoneCtrl.text.trim().isNotEmpty ? '$countryCode${phoneCtrl.text.trim()}' : null;
                    await ApiService.createClass(
                      nameCtrl.text,
                      subject,
                      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                      isPrivate: isPrivate,
                      isPaid: isPaid,
                      price: double.tryParse(priceCtrl.text) ?? 0,
                      currency: currency,
                      payoutPhone: isPaid ? fullPhone : null,
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    _loadMyClasses();
                    _loadPublicClasses();
                    messenger.showSnackBar(const SnackBar(content: Text('Classe créée avec succès !')));
                  } else {
                    await ApiService.joinClass(codeCtrl.text.trim().toUpperCase());
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    _loadMyClasses();
                    messenger.showSnackBar(const SnackBar(content: Text('Classe rejointe avec succès !')));
                  }
                } catch (e) {
                  final raw = e.toString().replaceFirst('Exception: ', '');
                  Map<String, dynamic>? paymentInfo;
                  try {
                    final decoded = jsonDecode(raw);
                    if (decoded is Map && decoded.containsKey('class_id')) {
                      paymentInfo = decoded.cast<String, dynamic>();
                    }
                  } catch (_) {}

                  if (paymentInfo != null) {
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    _offerPayment(paymentInfo);
                  } else {
                    messenger.showSnackBar(SnackBar(content: Text(raw)));
                  }
                }
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  void _offerPayment(Map<String, dynamic> info) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Classe payante — ${info['class_name']}'),
        content: Text(
          'Cette classe coûte ${info['price']} ${info['currency']}. '
          'Tu vas être redirigé vers la page de paiement sécurisée LeekPay. '
          'Une fois le paiement effectué, reviens ici et retape le code (ou retente Rejoindre) pour accéder à la classe.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _startPayment(info['class_id']);
            },
            child: const Text('Payer maintenant'),
          ),
        ],
      ),
    );
  }

  Future<void> _startPayment(String classId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final checkout = await ApiService.createCheckout(classId);
      final url = Uri.parse(checkout['checkout_url']);
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) {
        messenger.showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir la page de paiement.")));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur paiement: $e')));
    }
  }

  /// Fiche à 3 boutons pour une classe publique découverte: Rejoindre / Infos / Programmer.
  void _openPublicClassActions(SchoolClass c) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${c.subject} · ${c.teacherName ?? ''}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.login, color: c.isLive ? Colors.green : Colors.grey),
                title: const Text('Rejoindre'),
                subtitle: c.isLive ? const Text('En direct maintenant') : const Text('Pas en direct pour le moment'),
                enabled: c.isLive,
                onTap: c.isLive
                    ? () async {
                        Navigator.pop(sheetContext);
                        try {
                          try {
                            await ApiService.joinClass(c.inviteCode);
                          } catch (joinError) {
                            final joinMsg = joinError.toString();
                            // Si l'erreur est juste "déjà inscrit", on continue normalement
                            // (l'utilisateur fait déjà partie de la classe, rien à bloquer).
                            if (!joinMsg.contains('déjà inscrit') && !joinMsg.contains('propre classe')) {
                              rethrow;
                            }
                          }
                          final sessions = await ApiService.sessionsForClass(c.id);
                          final live = sessions.cast<Map<String, dynamic>?>().firstWhere(
                                (s) => s?['status'] == 'live',
                                orElse: () => null,
                              );
                          if (!mounted) return;
                          if (live != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClassroomScreen(user: widget.user, sessionId: live['id'], title: c.name),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Aucun cours en direct pour l'instant.")),
                            );
                          }
                        } catch (e) {
                          final raw = e.toString().replaceFirst('Exception: ', '');
                          Map<String, dynamic>? paymentInfo;
                          try {
                            final decoded = jsonDecode(raw);
                            if (decoded is Map && decoded.containsKey('class_id')) {
                              paymentInfo = decoded.cast<String, dynamic>();
                            }
                          } catch (_) {}
                          if (!mounted) return;
                          if (paymentInfo != null) {
                            _offerPayment(paymentInfo);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(raw)));
                          }
                        }
                      }
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Voir les infos'),
                subtitle: const Text('Description, programme, prix, messages...'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassDetailScreen(currentUser: widget.user, classId: c.id),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_none),
                title: const Text('Programmer'),
                subtitle: const Text('Être notifié quand cette classe démarre'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  try {
                    await ApiService.setReminder(c.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tu seras notifié au démarrage !')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _myClassCard(SchoolClass c) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.book)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (c.isPaid)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Chip(
                  label: Text('${c.price.toStringAsFixed(0)} ${c.currency}'),
                  backgroundColor: Colors.green[100],
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        subtitle: Text('${c.subject} · Code: ${c.inviteCode}', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.user.isTeacher && c.isPaid)
              IconButton(
                icon: const Icon(Icons.payments_outlined),
                tooltip: 'Revenus',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RevenueScreen(classId: c.id, className: c.name)),
                ),
              ),
            if (widget.user.isTeacher && c.teacherId == widget.user.id)
              IconButton(
                icon: const Icon(Icons.group_outlined),
                tooltip: 'Gérer les élèves',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ClassStudentsScreen(classId: c.id, className: c.name)),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.assignment_outlined),
              tooltip: 'Exercices',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExercisesScreen(user: widget.user, classId: c.id, className: c.name),
                ),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () async {
          try {
            String sessionId;
            final isOwner = c.teacherId == widget.user.id;

            if (isOwner) {
              final sessions = await ApiService.sessionsForClass(c.id);
              final liveSession = sessions.cast<Map<String, dynamic>?>().firstWhere(
                    (s) => s?['status'] == 'live',
                    orElse: () => null,
                  );
              if (liveSession != null) {
                sessionId = liveSession['id'];
              } else {
                final session = await ApiService.createSession(c.id, 'Cours - ${c.name}');
                await ApiService.startSession(session['id']);
                sessionId = session['id'];
              }
            } else {
              final sessions = await ApiService.sessionsForClass(c.id);
              final liveSession = sessions.cast<Map<String, dynamic>?>().firstWhere(
                    (s) => s?['status'] == 'live',
                    orElse: () => null,
                  );
              if (liveSession == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Aucun cours en direct pour l'instant. Attends que l'enseignant démarre.")),
                  );
                }
                return;
              }
              sessionId = liveSession['id'];
            }

            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClassroomScreen(user: widget.user, sessionId: sessionId, title: c.name),
              ),
            );
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
            }
          }
        },
      ),
    );
  }

  Widget _publicClassCard(SchoolClass c) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: c.isLive ? Colors.red[50] : null,
          child: Icon(Icons.book, color: c.isLive ? Colors.red : null),
        ),
        title: Row(
          children: [
            Expanded(child: Text(c.name)),
            if (c.isLive)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Chip(
                  label: Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        subtitle: Text('${c.subject} · ${c.teacherName ?? ''} · ${c.memberCount} participant(s)'),
        trailing: Chip(
          label: Text(c.isPaid ? '${c.price.toStringAsFixed(0)} ${c.currency}' : 'Gratuit'),
          backgroundColor: c.isPaid ? Colors.green[100] : Colors.blue[50],
          visualDensity: VisualDensity.compact,
        ),
        onTap: () => _openPublicClassActions(c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour, ${widget.user.fullName} 👋'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Mes classes'),
            Tab(text: 'Découvrir'),
          ],
        ),
        actions: [
          if (widget.user.isTeacher)
            IconButton(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              tooltip: 'Portefeuille',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
            ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                  _loadNotificationCount();
                },
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('$_unreadNotifications', style: const TextStyle(color: Colors.white, fontSize: 9)),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiService.clearToken();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ---------- Onglet "Mes classes" ----------
          _loadingMine
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadMyClasses,
                  child: _myClasses.isEmpty
                      ? const Center(child: Text('Aucune classe pour le moment'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _myClasses.length,
                          itemBuilder: (context, i) => _myClassCard(_myClasses[i]),
                        ),
                ),
          // ---------- Onglet "Découvrir" (toutes les classes publiques) ----------
          _loadingPublic
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadPublicClasses,
                  child: _publicClasses.isEmpty
                      ? const Center(child: Text('Aucune classe publique pour le moment'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _publicClasses.length,
                          itemBuilder: (context, i) => _publicClassCard(_publicClasses[i]),
                        ),
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateOrJoinDialog,
        child: Icon(widget.user.isTeacher ? Icons.add : Icons.group_add),
      ),
    );
  }
}
