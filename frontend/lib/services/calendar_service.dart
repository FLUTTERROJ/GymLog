import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';

/// Non-sensitive connection status -- the refresh token itself is never
/// readable by the client (see the `google_calendar_connections` RLS in the
/// backend migration), only through the `get_calendar_connection_status` RPC.
class CalendarConnectionStatus {
  const CalendarConnectionStatus({
    required this.connected,
    this.googleEmail,
    this.connectedAt,
  });

  final bool connected;
  final String? googleEmail;
  final DateTime? connectedAt;

  static const disconnected = CalendarConnectionStatus(connected: false);

  factory CalendarConnectionStatus.fromMap(Map<String, dynamic> map) =>
      CalendarConnectionStatus(
        connected: map['connected'] as bool? ?? false,
        googleEmail: map['google_email'] as String?,
        connectedAt: map['connected_at'] == null
            ? null
            : DateTime.parse(map['connected_at'] as String),
      );
}

/// A parsed session from tomorrow's calendar, as returned by the
/// `calendar-preview` Edge Function.
class PreviewSession {
  const PreviewSession({
    required this.eventId,
    required this.title,
    required this.start,
    required this.names,
    required this.paidStatus,
    required this.location,
  });

  final String eventId;
  final String title;
  final DateTime start;
  final List<String> names;
  final String paidStatus;
  final String location;

  factory PreviewSession.fromMap(Map<String, dynamic> map) => PreviewSession(
        eventId: map['eventId'] as String,
        title: map['title'] as String,
        start: DateTime.parse(map['start'] as String).toLocal(),
        names: (map['names'] as List).cast<String>(),
        paidStatus: map['paidStatus'] as String,
        location: map['location'] as String,
      );
}

/// A name detected in the calendar, alongside whether it's already mapped.
class PreviewName {
  const PreviewName({
    required this.name,
    required this.mapped,
    this.traineeId,
    this.traineeLabel,
  });

  final String name;
  final bool mapped;
  final String? traineeId;
  final String? traineeLabel;

  factory PreviewName.fromMap(Map<String, dynamic> map) => PreviewName(
        name: map['name'] as String,
        mapped: map['mapped'] as bool? ?? false,
        traineeId: map['traineeId'] as String?,
        traineeLabel: map['traineeLabel'] as String?,
      );
}

class CalendarPreview {
  const CalendarPreview({
    required this.connected,
    required this.sessions,
    required this.names,
  });

  final bool connected;
  final List<PreviewSession> sessions;
  final List<PreviewName> names;

  static const empty = CalendarPreview(connected: false, sessions: [], names: []);

  factory CalendarPreview.fromMap(Map<String, dynamic> map) => CalendarPreview(
        connected: map['connected'] as bool? ?? false,
        sessions: ((map['sessions'] as List?) ?? const [])
            .map((e) => PreviewSession.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        names: ((map['names'] as List?) ?? const [])
            .map((e) => PreviewName.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// An already-saved calendar-name -> trainee mapping.
class CalendarMapping {
  const CalendarMapping({
    required this.id,
    required this.calendarName,
    required this.traineeId,
    this.traineeLabel,
  });

  final String id;
  final String calendarName;
  final String traineeId;
  final String? traineeLabel;

  factory CalendarMapping.fromMap(Map<String, dynamic> map) {
    final trainee = map['trainee'];
    return CalendarMapping(
      id: map['id'] as String,
      calendarName: map['calendar_name'] as String,
      traineeId: map['trainee_id'] as String,
      traineeLabel: trainee is Map
          ? ((trainee['username'] ?? trainee['full_name']) as String?)
          : null,
    );
  }
}

class CalendarService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  StreamSubscription<AuthState>? _linkSub;

  CalendarConnectionStatus status = CalendarConnectionStatus.disconnected;
  bool loadingStatus = false;

  List<CalendarMapping> mappings = const [];
  bool loadingMappings = false;

  CalendarPreview preview = CalendarPreview.empty;
  bool loadingPreview = false;
  String? previewError;

  bool _connecting = false;
  bool get connecting => _connecting;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  Future<void> loadStatus() async {
    loadingStatus = true;
    notifyListeners();
    try {
      final rows = await _client.rpc('get_calendar_connection_status');
      final row = (rows as List).isEmpty
          ? <String, dynamic>{'connected': false}
          : Map<String, dynamic>.from(rows.first as Map);
      status = CalendarConnectionStatus.fromMap(row);
    } catch (error) {
      debugPrint('CalendarService.loadStatus: $error');
    } finally {
      loadingStatus = false;
      notifyListeners();
    }
  }

  /// Opens Google's consent screen to grant read-only Calendar access on top
  /// of however the trainer already signed in -- this links a permission, it
  /// doesn't change their login method, so `linkIdentity` (not
  /// `signInWithOAuth`) is the right call here.
  ///
  /// Supabase does not persist `session.providerRefreshToken` across app
  /// restarts -- it's only present on the auth-state event fired right after
  /// this redirect completes. This listens for that one moment and pushes it
  /// straight into `google_calendar_connections`; if that write is missed,
  /// the token is gone and the trainer has to reconnect.
  Future<void> connect() async {
    _connecting = true;
    notifyListeners();

    final completer = Completer<void>();
    _linkSub?.cancel();
    _linkSub = _client.auth.onAuthStateChange.listen((state) async {
      final refreshToken = state.session?.providerRefreshToken;
      if (refreshToken == null) return;

      try {
        await _client.from('google_calendar_connections').upsert({
          'trainer_id': _uid,
          'refresh_token': refreshToken,
          'google_email': state.session?.user.email,
        });
        await loadStatus();
      } catch (error) {
        debugPrint('CalendarService: failed to store refresh token: $error');
      } finally {
        if (!completer.isCompleted) completer.complete();
      }
    });

    try {
      await _client.auth.linkIdentity(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : Env.authRedirectUrl,
        scopes: 'https://www.googleapis.com/auth/calendar.readonly',
        queryParams: const {'access_type': 'offline', 'prompt': 'consent'},
      );
      // The browser round-trip finishes asynchronously; give the listener a
      // window to catch the resulting auth-state event before giving up.
      await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {},
      );
    } finally {
      await _linkSub?.cancel();
      _linkSub = null;
      _connecting = false;
      notifyListeners();
    }
  }

  /// Removes the app's stored access -- the Google account may still show
  /// GymLog under "linked apps" until revoked there too, but calendar-sync
  /// stops using it immediately either way.
  Future<void> disconnect() async {
    await _client.from('google_calendar_connections').delete().eq('trainer_id', _uid);
    status = CalendarConnectionStatus.disconnected;
    notifyListeners();
  }

  Future<void> loadMappings() async {
    loadingMappings = true;
    notifyListeners();
    try {
      final rows = await _client
          .from('calendar_name_mappings')
          .select(
            'id, calendar_name, trainee_id, trainee:profiles!calendar_name_mappings_trainee_id_fkey(username, full_name)',
          )
          .eq('trainer_id', _uid)
          .order('calendar_name');
      mappings = (rows as List)
          .map((row) => CalendarMapping.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (error) {
      debugPrint('CalendarService.loadMappings: $error');
    } finally {
      loadingMappings = false;
      notifyListeners();
    }
  }

  Future<void> saveMapping({
    required String calendarName,
    required String traineeId,
  }) async {
    await _client.from('calendar_name_mappings').upsert(
      {
        'trainer_id': _uid,
        'calendar_name': calendarName.trim(),
        'trainee_id': traineeId,
      },
      onConflict: 'trainer_id,calendar_name_normalized',
    );
    await Future.wait([loadMappings(), fetchPreview()]);
  }

  Future<void> removeMapping(String mappingId) async {
    await _client.from('calendar_name_mappings').delete().eq('id', mappingId);
    await Future.wait([loadMappings(), fetchPreview()]);
  }

  Future<void> fetchPreview() async {
    loadingPreview = true;
    previewError = null;
    notifyListeners();
    try {
      final response = await _client.functions.invoke('calendar-preview');
      preview = CalendarPreview.fromMap(Map<String, dynamic>.from(response.data as Map));
    } catch (error) {
      previewError = "Couldn't read your calendar. Try again in a moment.";
      debugPrint('CalendarService.fetchPreview: $error');
    } finally {
      loadingPreview = false;
      notifyListeners();
    }
  }

  void clear() {
    status = CalendarConnectionStatus.disconnected;
    mappings = const [];
    preview = CalendarPreview.empty;
    notifyListeners();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }
}
