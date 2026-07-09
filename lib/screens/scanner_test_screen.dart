import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/scanner_provider.dart';
import '../providers/database_provider.dart';

class ScannerTestScreen extends ConsumerStatefulWidget {
  const ScannerTestScreen({super.key});

  @override
  ConsumerState<ScannerTestScreen> createState() => _ScannerTestScreenState();
}

class _ScannerTestScreenState extends ConsumerState<ScannerTestScreen> {
  int _totalTracks = 0;

  @override
  void initState() {
    super.initState();
    _fetchTotal();
  }

  Future<void> _fetchTotal() async {
    final repo = ref.read(databaseRepositoryProvider);
    final tracks = await repo.getAllTracks();
    if (mounted) {
      setState(() {
        _totalTracks = tracks.length;
      });
    }
  }

  Future<void> _startScan() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      final scanner = ref.read(libraryScannerProvider);
      await scanner.scanDirectory(selectedDirectory);
      await _fetchTotal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanner = ref.watch(libraryScannerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Scanner Validation')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _startScan,
              child: const Text('Select Folder & Scan'),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: StreamBuilder<String>(
                stream: scanner.progressStream,
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? 'Awaiting scan...',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Total Tracks in DB: $_totalTracks',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
