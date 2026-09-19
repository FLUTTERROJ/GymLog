import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/auth_service.dart' show describeError;
import '../../services/email_template_service.dart';

class EmailTemplatesScreen extends StatefulWidget {
  const EmailTemplatesScreen({super.key});

  @override
  State<EmailTemplatesScreen> createState() => _EmailTemplatesScreenState();
}

class _EmailTemplatesScreenState extends State<EmailTemplatesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<EmailTemplateService>().load(),
    );
  }

  Future<void> _edit([EmailTemplate? existing]) async {
    final location = TextEditingController(text: existing?.location ?? '');
    final subject = TextEditingController(text: existing?.subject ?? '');
    final body = TextEditingController(text: existing?.body ?? '');
    var paidStatus = existing?.paidStatus ?? 'Paid';

    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          constraints: const BoxConstraints(maxWidth: 560),
          title: Text(existing == null ? 'New email template' : 'Edit template'),
          content: SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: location,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: paidStatus,
                    decoration:
                        const InputDecoration(labelText: 'Session type'),
                    items: const [
                      DropdownMenuItem(value: 'Paid', child: Text('Paid')),
                      DropdownMenuItem(
                        value: 'Unpaid',
                        child: Text('Unpaid'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => paidStatus = value ?? paidStatus),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subject,
                    decoration:
                        const InputDecoration(labelText: 'Email subject'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: body,
                    maxLines: 7,
                    decoration: const InputDecoration(
                      labelText: 'Email body',
                      hintText:
                          'Hi {traineeName}, your session is tomorrow at {sessionTime}.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Placeholders: {traineeName}, {sessionTime}, '
                    '{location}, {paidStatus}',
                    softWrap: true,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (location.text.trim().isEmpty ||
                    subject.text.trim().isEmpty ||
                    body.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop(paidStatus);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;
    try {
      await context.read<EmailTemplateService>().save(
            existingId: existing?.id,
            location: location.text,
            paidStatus: result,
            subject: subject.text,
            body: body.text,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(error))));
      }
    } finally {
      location.dispose();
      subject.dispose();
      body.dispose();
    }
  }

  Future<void> _remove(EmailTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text(
          '${template.location} · ${template.paidStatus} will use the default email again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<EmailTemplateService>().remove(template);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<EmailTemplateService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Email templates')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('New template'),
      ),
      body: service.loading && service.templates.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: service.load,
              child: service.templates.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(32),
                      children: const [
                        Icon(Icons.mail_outline, size: 56),
                        SizedBox(height: 16),
                        Text(
                          'No custom templates yet',
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create one for a location and choose whether the session is paid or unpaid.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                      itemCount: service.templates.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final template = service.templates[index];
                        return Panel(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(template.location),
                            subtitle: Text(
                              '${template.paidStatus} · ${template.subject}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _edit(template),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _remove(template),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
