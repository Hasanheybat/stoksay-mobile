import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/sync_service.dart';

class ConnectivityState {
  final bool online;
  final int bekleyenSync;

  const ConnectivityState({this.online = true, this.bekleyenSync = 0});

  ConnectivityState copyWith({bool? online, int? bekleyenSync}) {
    return ConnectivityState(
      online: online ?? this.online,
      bekleyenSync: bekleyenSync ?? this.bekleyenSync,
    );
  }
}

class ConnectivityNotifier extends Notifier<ConnectivityState> {
  StreamSubscription? _sub;

  @override
  ConnectivityState build() {
    ref.onDispose(() => _sub?.cancel());
    _init();
    return const ConnectivityState();
  }

  void _init() {
    Connectivity().checkConnectivity().then((results) {
      state = state.copyWith(online: !results.contains(ConnectivityResult.none));
      _updateBekleyen();
    });

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      final wasOffline = !state.online;
      state = state.copyWith(online: online);
      if (online && wasOffline) {
        SyncService.kuyruguGonder().then((_) => _updateBekleyen());
      }
    });
  }

  Future<void> _updateBekleyen() async {
    final count = await SyncService.bekleyenSayisi();
    state = state.copyWith(bekleyenSync: count);
  }

  Future<void> bekleyenGuncelle() async {
    await _updateBekleyen();
  }
}

final connectivityProvider = NotifierProvider<ConnectivityNotifier, ConnectivityState>(ConnectivityNotifier.new);
