import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/store_service.dart';

const _paper = Color(0xFFF8F6F1);
const _olive = Color(0xFF68715A);
const _muted = Color(0xFF827D73);

class CustomerSupportScreen extends StatefulWidget {
  const CustomerSupportScreen({super.key, this.orderId});

  final String? orderId;

  @override
  State<CustomerSupportScreen> createState() => _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends State<CustomerSupportScreen> {
  late Future<List<Map<String, dynamic>>> _requestsFuture;
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;
  RealtimeChannel? _requestChannel;

  @override
  void initState() {
    super.initState();
    _requestsFuture = StoreService.loadMySupportRequests();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _requestChannel = Supabase.instance.client
          .channel('support-$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'support_requests',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'customer_id',
              value: userId,
            ),
            callback: (_) {
              if (mounted) _refresh();
            },
          )
          .subscribe();
    }
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _requestsFuture = StoreService.loadMySupportRequests();
    });
  }

  @override
  void dispose() {
    if (_requestChannel != null)
      Supabase.instance.client.removeChannel(_requestChannel!);
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _sending) return;
    setState(() => _sending = true);
    try {
      await StoreService.submitSupportRequest(
        subject: _subject.text,
        message: _message.text,
        orderId: widget.orderId,
      );
      if (!mounted) return;
      _subject.clear();
      _message.clear();
      _refresh();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your request was sent to staff.')),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send request: $error')),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(
      backgroundColor: _paper,
      title: const Text('HELP & SUPPORT'),
    ),
    body: RefreshIndicator(
      onRefresh: () async {
        _refresh();
        try {
          await _requestsFuture;
        } catch (_) {}
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          const Text('How can we help?', style: TextStyle(fontSize: 23)),
          const SizedBox(height: 6),
          const Text(
            'Send a message to the shop team. You can check its status here.',
            style: TextStyle(fontFamily: 'Arial', color: _muted),
          ),
          if (widget.orderId != null) ...[
            const SizedBox(height: 8),
            Text(
              'About order ${widget.orderId!.split('-').first}',
              style: const TextStyle(fontFamily: 'Arial', color: _olive),
            ),
          ],
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _subject,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Enter a subject.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _message,
                  maxLines: 5,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Enter your message.'
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('SEND REQUEST'),
          ),
          const SizedBox(height: 30),
          const Text('Your requests', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 10),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _requestsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return snapshot.hasError
                    ? OutlinedButton(
                        onPressed: _refresh,
                        child: const Text('Could not load requests. Retry'),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: _olive),
                      );
              }
              final requests = snapshot.data!;
              if (requests.isEmpty)
                return const Text(
                  'No support requests yet.',
                  style: TextStyle(fontFamily: 'Arial', color: _muted),
                );
              return Column(
                children: requests
                    .map(
                      (request) => Card(
                        color: Colors.white,
                        elevation: 0,
                        child: ListTile(
                          title: Text(request['subject'] as String? ?? ''),
                          subtitle: Text(
                            '${request['message'] ?? ''}\nStatus: ${(request['status'] as String? ?? 'open').replaceAll('_', ' ')}${(request['staff_reply'] as String? ?? '').isEmpty ? '' : '\nStaff reply: ${request['staff_reply']}'}',
                            maxLines: 10,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    ),
  );
}
