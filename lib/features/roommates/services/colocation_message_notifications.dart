import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../providers/roommates_providers.dart';
import '../roommates_routes.dart';

/// Indique si l'écran de discussion de la colocation est affiché.
///
/// Simple objet mutable (pas un état réactif) : l'écran le met à jour dans
/// `initState` / `dispose` sans reconstruire quoi que ce soit.
class ColocationChatPresence {
  bool isOpen = false;
}

final colocationChatPresenceProvider = Provider<ColocationChatPresence>(
  (_) => ColocationChatPresence(),
);

/// Nombre de messages de colocataires reçus depuis la dernière ouverture de la discussion
/// (pastille rouge sur l'icône de discussion). Remis à zéro à l'ouverture de la discussion
/// et au changement de compte ; non conservé après la fermeture de l'application.
class ColocationUnreadNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void add(int count) {
    if (count > 0) state += count;
  }

  void clear() {
    if (state != 0) state = 0;
  }
}

final colocationUnreadCountProvider = NotifierProvider<ColocationUnreadNotifier, int>(
  ColocationUnreadNotifier.new,
);

/// Notifications système (barre de notifications du téléphone) pour les nouveaux
/// messages de la colocation.
///
/// Fonctionnement : tant que l'application tourne (premier plan ou arrière-plan récent),
/// le serveur est interrogé toutes les [pollInterval] ; chaque message reçu d'un autre
/// colocataire déclenche une notification, sauf si la discussion est déjà affichée à l'écran.
/// Une fois l'application complètement fermée, aucune notification n'est reçue.
class ColocationMessageNotifier with WidgetsBindingObserver {
  ColocationMessageNotifier(this._ref);

  static const pollInterval = Duration(seconds: 15);
  static const _notificationId = 6001;
  static const _channelId = 'colocation_messages';
  static const _channelName = 'Messages de la colocation';

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Timer? _timer;
  bool _pluginReady = false;
  bool _polling = false;
  bool _appInForeground = true;

  /// Utilisateur et colocation suivis : un changement de compte remet le suivi à zéro.
  String? _watchedKey;

  /// Horodatage du dernier message déjà connu (rien n'est notifié avant).
  DateTime? _lastSeen;

  static bool get _platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void start() {
    if (_timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initPlugin());
    _timer = Timer.periodic(pollInterval, (_) => unawaited(_poll()));
    unawaited(_poll());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    if (_appInForeground) unawaited(_poll());
  }

  Future<void> _initPlugin() async {
    if (!_platformSupported) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (_) => _openChat(),
      );
      // Android 13+ : demande l'autorisation d'afficher des notifications (une seule fois).
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _pluginReady = true;
    } catch (e) {
      debugPrint('[colocation] Notifications indisponibles : $e');
    }
  }

  void _openChat() {
    final context = AppNavigator.rootKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).push(RoommatesRoutes.chat);
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final user = _ref.read(currentUserProvider);
      final hasAccess = _ref.read(subscriptionProvider).hasFeature(AppFeature.roommates);
      final colocation = _ref.read(colocationProvider);
      if (user == null || !hasAccess || colocation == null) {
        if (_watchedKey != null) _ref.read(colocationUnreadCountProvider.notifier).clear();
        _watchedKey = null;
        _lastSeen = null;
        return;
      }

      final key = '${user.id}/${colocation.id}';
      if (key != _watchedKey) {
        _watchedKey = key;
        _lastSeen = null;
        _ref.read(colocationUnreadCountProvider.notifier).clear();
      }

      final since = _lastSeen;
      final items = await _ref.read(strapiClientProvider).getList(
        '/colocation-messages',
        queryParameters: {if (since != null) 'since': since.toUtc().toIso8601String()},
      );
      if (_watchedKey != key) return;

      final messages = items
          .map(_IncomingMessage.fromJson)
          .where((m) => since == null || m.timestamp.isAfter(since))
          .toList();
      if (messages.isEmpty) {
        _lastSeen ??= DateTime.now().toUtc();
        return;
      }
      _lastSeen = messages.map((m) => m.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);

      // Premier chargement : on mémorise l'existant sans notifier.
      if (since == null) return;

      final fromOthers = messages.where((m) => !m.isMe).toList();
      if (fromOthers.isEmpty) return;

      // La discussion ouverte se met déjà à jour : on actualise sans notifier.
      final chatVisible = _ref.read(colocationChatPresenceProvider).isOpen && _appInForeground;
      _ref.invalidate(colocationMessagesProvider);
      if (chatVisible) return;

      _ref.read(colocationUnreadCountProvider.notifier).add(fromOthers.length);
      await _show(fromOthers, colocation.name);
    } catch (_) {
      // Hors-ligne, serveur endormi, plus de colocation… : nouvel essai au prochain passage.
    } finally {
      _polling = false;
    }
  }

  Future<void> _show(List<_IncomingMessage> messages, String colocationName) async {
    if (!_pluginReady) return;
    final last = messages.last;
    final title = messages.length == 1 ? last.senderName : colocationName;
    final body = messages.length == 1
        ? last.text
        : '${messages.length} nouveaux messages · ${last.senderName} : ${last.text}';

    await _plugin.show(
      _notificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Nouveaux messages de vos colocataires',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: RoommatesRoutes.chat,
    );
  }
}

class _IncomingMessage {
  const _IncomingMessage({
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isMe,
  });

  factory _IncomingMessage.fromJson(Map<String, dynamic> json) => _IncomingMessage(
    senderName: (json['senderName'] ?? 'Colocataire').toString(),
    text: (json['text'] ?? '').toString(),
    timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString())?.toUtc() ??
        DateTime.now().toUtc(),
    isMe: json['isMe'] == true,
  );

  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;
}

/// Démarre la surveillance des messages dès sa première lecture et l'arrête à la fermeture.
final colocationMessageNotifierProvider = Provider<ColocationMessageNotifier>((ref) {
  final notifier = ColocationMessageNotifier(ref)..start();
  ref.onDispose(notifier.dispose);
  return notifier;
});
