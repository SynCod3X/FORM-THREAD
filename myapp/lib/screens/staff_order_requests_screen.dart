import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/store_service.dart';

class StaffOrderRequestsScreen extends StatefulWidget {
  const StaffOrderRequestsScreen({super.key});

  @override
  State<StaffOrderRequestsScreen> createState() =>
      _StaffOrderRequestsScreenState();
}

class _StaffOrderRequestsScreenState extends State<StaffOrderRequestsScreen> {
  late Future<List<Map<String, dynamic>>> _requests;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _requests = future;
    });
    try {
      await future;
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final profile = await AuthService.loadMyProfile();
    if (profile['role'] != 'staff') throw StateError('Staff access required.');
    return StoreService.loadOrderRequests();
  }

  Future<void> _decide(Map<String, dynamic> request, String status) async {
    final note = TextEditingController(
      text: request['staff_note'] as String? ?? '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '${status == 'completed'
              ? 'Mark return received'
              : status == 'approved'
              ? 'Approve'
              : 'Reject'} ${request['type']}?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(request['reason'] as String? ?? ''),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Message to customer (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CLOSE'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(status.toUpperCase()),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await StoreService.decideOrderRequest(
          request['id'] as String,
          request['status'] as String,
          status,
          note.text,
        );
        if (mounted) _refresh();
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update request: $error')),
          );
      }
    }
    note.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ORDER REQUESTS')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _requests,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton(
              onPressed: _refresh,
              child: const Text('Could not load requests. Retry'),
            ),
          );
        }
        final requests = snapshot.data ?? [];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No order requests yet.')),
                ),
              ...requests.map(
                (request) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${request['type']} · ${request['status']}',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order ${(request['order_id'] as String? ?? '').split('-').first}',
                        ),
                        const SizedBox(height: 8),
                        Text(request['reason'] as String? ?? ''),
                        if ((request['staff_note'] as String? ?? '').isNotEmpty)
                          Text('Staff: ${request['staff_note']}'),
                        if (request['status'] == 'pending')
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _decide(request, 'rejected'),
                                child: const Text('REJECT'),
                              ),
                              FilledButton(
                                onPressed: () => _decide(request, 'approved'),
                                child: const Text('APPROVE'),
                              ),
                            ],
                          ),
                        if (request['type'] == 'return' &&
                            request['status'] == 'approved')
                          FilledButton(
                            onPressed: () => _decide(request, 'completed'),
                            child: const Text('MARK RETURN RECEIVED'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
