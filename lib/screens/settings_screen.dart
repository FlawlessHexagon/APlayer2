import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sync_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final notifier = ref.read(syncProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Google Drive Sync', style: TextStyle(color: AppColors.beige, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            color: AppColors.purpleAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_sync, color: AppColors.beige, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              syncState.isSignedIn ? 'Signed in as ${syncState.email}' : 'Not Signed In',
                              style: const TextStyle(color: AppColors.offWhite, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Mirror playlists and audio files to cloud',
                              style: const TextStyle(color: AppColors.midGrey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (!syncState.isSignedIn)
                    ElevatedButton.icon(
                      onPressed: () => notifier.signIn(),
                      icon: const Icon(Icons.login),
                      label: const Text('Sign in with Google'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.beige,
                        foregroundColor: AppColors.nearBlack,
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: syncState.state == SyncState.syncing ? null : () => notifier.syncNow(),
                            icon: syncState.state == SyncState.syncing 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.nearBlack, strokeWidth: 2))
                              : const Icon(Icons.sync),
                            label: Text(syncState.state == SyncState.syncing ? 'Syncing...' : 'Sync Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.beige,
                              foregroundColor: AppColors.nearBlack,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () => notifier.signOut(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      syncState.statusText,
                      style: TextStyle(
                        color: syncState.state == SyncState.error ? Colors.redAccent : AppColors.offWhite,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
