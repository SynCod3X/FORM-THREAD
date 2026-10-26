import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/store_service.dart';

const _paper = Color(0xFFF8F6F1);
const _olive = Color(0xFF68715A);
const _muted = Color(0xFF827D73);

class StaffSupportScreen extends StatefulWidget {
  const StaffSupportScreen({
    super.key,
    this.dataSource = const StaffSupportDataSource(),
  });

  final StaffSupportDataSource dataSource;

  @override
  State<StaffSupportScreen> createState() => _StaffSupportScreenState();
}

class StaffSupportDataSource {
  const StaffSupportDataSource();

  Future<List<Map<String, dynamic>>> load() async {
    final profile = await AuthService.loadMyProfile();
    if (profile['role'] != 'staff') throw StateError('Staff access required.');
    return StoreService.loadSupportRequests();
  }

  Future<void> updateStatus(String id, String status) =>
      StoreService.updateSupportRequestStatus(id, status);

  Future<void> sendReply(String id, String reply) =>
      StoreService.replyToSupportRequest(id, reply);
}

class _StaffSupportScreenState extends State<StaffSupportScreen> {
  late Future<List<Map<String, dynamic>>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _requestsFuture = widget.dataSource.load();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _requestsFuture = widget.dataSource.load();
    });
  }

  Future<void> _update(String id, String status) async {
    try {
      await widget.dataSource.updateStatus(id, status);
      if (mounted) _refresh();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update request: $error')),
        );
    }
  }

  Future<void> _reply(Map<String, dynamic> request) async {
    final reply = await showDialog<String>(
      context: context,
      builder: (_) => _StaffReplyDialog(
        initialReply: request['staff_reply'] as String? ?? '',
      ),
    );
    if (reply != null && mounted) {
      try {
        await widget.dataSource.sendReply(request['id'] as String, reply);
        if (mounted) {
          _refresh();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reply saved for the customer.')),
          );
        }
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not send reply: $error')),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(
      backgroundColor: _paper,
      title: const Text('SUPPORT REQUESTS'),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _requestsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load support requests.'),
                      OutlinedButton(
                        onPressed: _refresh,
                        child: const Text('TRY AGAIN'),
                      ),
                    ],
                  ),
                )
              : const Center(child: CircularProgressIndicator(color: _olive));
        }
        final requests = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async {
            _refresh();
            try {
              await _requestsFuture;
            } catch (_) {
              // FutureBuilder shows the load error and the retry action.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: Text('No support requests yet.')),
                ),
              ...requests.map((request) {
                final status = request['status'] as String? ?? 'open';
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request['subject'] as String? ?? '',
                          style: const TextStyle(fontSize: 17),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          request['customer_email'] as String? ?? '',
                          style: const TextStyle(
                            fontFamily: 'Arial',
                            color: _muted,
                          ),
                        ),
                        if (request['order_id'] != null)
                          Text(
                            'Order ${(request['order_id'] as String).split('-').first}',
                            style: const TextStyle(
                              fontFamily: 'Arial',
                              color: _muted,
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(request['message'] as String? ?? ''),
                        if ((request['staff_reply'] as String? ?? '')
                            .isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Reply: ${request['staff_reply']}',
                            style: const TextStyle(
                              fontFamily: 'Arial',
                              color: _olive,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          'Status: ${status.replaceAll('_', ' ')}',
                          style: const TextStyle(
                            fontFamily: 'Arial',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          children:
                              const {
                                    'open': 'Open',
                                    'in_progress': 'In progress',
                                    'resolved': 'Resolved',
                                  }.entries
                                  .where((entry) => entry.key != status)
                                  .map(
                                    (entry) => OutlinedButton(
                                      onPressed: () => _update(
                                        request['id'] as String,
                                        entry.key,
                                      ),
                                      child: Text(
                                        'Mark ${entry.value.toLowerCase()}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                        TextButton.icon(
                          onPressed: () => _reply(request),
                          icon: const Icon(Icons.reply_outlined),
                          label: Text(
                            (request['staff_reply'] as String? ?? '').isEmpty
                                ? 'Reply'
                                : 'Edit reply',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    ),
  );
}

class _StaffReplyDialog extends StatefulWidget {
  const _StaffReplyDialog({required this.initialReply});

  final String initialReply;

  @override
  State<_StaffReplyDialog> createState() => _StaffReplyDialogState();
}

class _StaffReplyDialogState extends State<_StaffReplyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialReply);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reply to customer'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _controller,
        maxLines: 6,
        maxLength: 4000,
        decoration: const InputDecoration(
          labelText: 'Reply',
          border: OutlineInputBorder(),
        ),
        validator: (value) =>
            (value?.trim().isEmpty ?? true) ? 'Enter a reply.' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('CANCEL'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: const Text('SEND'),
      ),
    ],
  );
}
