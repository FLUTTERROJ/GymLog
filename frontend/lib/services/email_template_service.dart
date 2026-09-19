import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailTemplate {
  const EmailTemplate({
    required this.id,
    required this.location,
    required this.paidStatus,
    required this.subject,
    required this.body,
  });

  final String id;
  final String location;
  final String paidStatus;
  final String subject;
  final String body;

  factory EmailTemplate.fromMap(Map<String, dynamic> map) => EmailTemplate(
        id: map['id'] as String,
        location: map['location'] as String,
        paidStatus: map['paid_status'] as String,
        subject: map['subject'] as String,
        body: map['body'] as String,
      );
}

class EmailTemplateService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  List<EmailTemplate> templates = const [];
  bool loading = false;

  String get _trainerId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      final rows = await _client
          .from('email_templates')
          .select('id, location, paid_status, subject, body')
          .eq('trainer_id', _trainerId)
          .order('location')
          .order('paid_status');
      templates = (rows as List)
          .map((row) => EmailTemplate.fromMap(
              Map<String, dynamic>.from(row as Map),))
          .toList();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> save({
    String? existingId,
    required String location,
    required String paidStatus,
    required String subject,
    required String body,
  }) async {
    final values = {
      'trainer_id': _trainerId,
      'location': location.trim(),
      'paid_status': paidStatus,
      'subject': subject.trim(),
      'body': body.trim(),
    };
    if (existingId != null) {
      await _client.from('email_templates').update(values).eq('id', existingId);
    } else {
      await _client.from('email_templates').upsert(
        values,
        onConflict: 'trainer_id,location,paid_status',
      );
    }
    await load();
  }

  Future<void> remove(EmailTemplate template) async {
    await _client.from('email_templates').delete().eq('id', template.id);
    await load();
  }

  void clear() {
    templates = const [];
    notifyListeners();
  }
}
