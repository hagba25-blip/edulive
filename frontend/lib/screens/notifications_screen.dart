import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.myNotifications();
      setState(() => _notifications = res);
      await ApiService.markAllNotificationsRead();
    } catch (_) {
      // silencieux
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _notifications.isEmpty
                  ? const Center(child: Text('Aucune notification pour le moment'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _notifications.length,
                      itemBuilder: (context, i) {
                        final n = _notifications[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.notifications_active, color: Colors.indigo),
                            title: Text(n['title'] ?? ''),
                            subtitle: Text(n['body'] ?? ''),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
