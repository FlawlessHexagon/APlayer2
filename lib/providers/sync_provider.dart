import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';

enum SyncState { idle, syncing, error, success }

class SyncStateModel {
  final SyncState state;
  final String statusText;
  final bool isSignedIn;
  final String? email;

  SyncStateModel({
    required this.state,
    required this.statusText,
    required this.isSignedIn,
    this.email,
  });

  SyncStateModel copyWith({
    SyncState? state,
    String? statusText,
    bool? isSignedIn,
    String? email,
  }) {
    return SyncStateModel(
      state: state ?? this.state,
      statusText: statusText ?? this.statusText,
      isSignedIn: isSignedIn ?? this.isSignedIn,
      email: email ?? this.email,
    );
  }
}

class SyncNotifier extends Notifier<SyncStateModel> {
  @override
  SyncStateModel build() {
    // Initial sync with SyncService state
    final service = ref.watch(syncServiceProvider);
    return SyncStateModel(
      state: SyncState.idle,
      statusText: 'Ready to sync',
      isSignedIn: service.isSignedIn,
      email: service.userEmail,
    );
  }

  Future<void> signIn() async {
    final service = ref.read(syncServiceProvider);
    try {
      await service.signIn();
      state = state.copyWith(isSignedIn: service.isSignedIn, email: service.userEmail);
    } catch (e) {
      state = state.copyWith(state: SyncState.error, statusText: 'Sign in failed: $e');
    }
  }

  Future<void> signOut() async {
    final service = ref.read(syncServiceProvider);
    await service.signOut();
    state = state.copyWith(isSignedIn: false, email: null, state: SyncState.idle, statusText: 'Signed out');
  }

  Future<void> syncNow() async {
    final service = ref.read(syncServiceProvider);
    if (!service.isSignedIn) return;

    state = state.copyWith(state: SyncState.syncing, statusText: 'Starting sync...');
    
    try {
      await service.performSync((progress) {
        // Update UI progress securely on the main thread
        state = state.copyWith(statusText: progress);
      });
      state = state.copyWith(state: SyncState.success, statusText: 'Sync Complete!');
      
      // Revert to idle after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (state.state == SyncState.success) {
          state = state.copyWith(state: SyncState.idle, statusText: 'Ready to sync');
        }
      });
    } catch (e) {
      state = state.copyWith(state: SyncState.error, statusText: 'Sync Error: $e');
    }
  }
}

final syncProvider = NotifierProvider<SyncNotifier, SyncStateModel>(() => SyncNotifier());
