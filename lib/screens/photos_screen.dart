import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_providers.dart';
import '../models/drone_log.dart';
import '../widgets/glass_card.dart';

class PhotosScreen extends ConsumerStatefulWidget {
  const PhotosScreen({super.key});

  @override
  ConsumerState<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends ConsumerState<PhotosScreen> {
  static const _bg = Color(0xFF0A0F0D);
  static const _green = Color(0xFF4ADE80);
  static const _textPrimary = Color(0xFFE8F5E9);
  static const _textSecondary = Color(0xFF86A98E);

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(droneLogsProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text('Mission Photos',
            style: GoogleFonts.syne(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: _textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _green),
            onPressed: () =>
                ref.read(droneLogsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _green)),
        error: (e, _) => _ErrorView(
          error: e.toString(),
          onRetry: () =>
              ref.read(droneLogsProvider.notifier).refresh(),
        ),
        data: (logs) {
          if (logs.isEmpty) return const _EmptyView();
          return _LogList(logs: logs);
        },
      ),
    );
  }
}

// ─── Group + list ──────────────────────────────────────────────────────────────

class _LogList extends StatelessWidget {
  final List<DroneLog> logs;
  const _LogList({required this.logs});

  Map<String, List<DroneLog>> _group(List<DroneLog> logs) {
    final map = <String, List<DroneLog>>{};
    for (final l in logs) {
      (map[l.sessionId] ??= []).add(l);
    }
    // Sort sessions newest-first by first entry's capturedAt
    final sorted = map.entries.toList()
      ..sort((a, b) {
        final ta = a.value.first.capturedAt;
        final tb = b.value.first.capturedAt;
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });
    return {for (final e in sorted) e.key: e.value};
  }

  @override
  Widget build(BuildContext context) {
    final groups = _group(logs);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: groups.entries.map((entry) {
        final sessionId = entry.key;
        final items = entry.value;
        final shortId = sessionId.length >= 8
            ? sessionId.substring(0, 8)
            : sessionId;
        final firstTs = items.first.formattedTime;

        return _SessionGroup(
          sessionShort: shortId,
          timestamp: firstTs,
          logs: items,
        );
      }).toList(),
    );
  }
}

// ─── Session group ────────────────────────────────────────────────────────────

class _SessionGroup extends StatelessWidget {
  final String sessionShort;
  final String timestamp;
  final List<DroneLog> logs;
  const _SessionGroup({
    required this.sessionShort,
    required this.timestamp,
    required this.logs,
  });

  static const _green = Color(0xFF4ADE80);
  static const _textPrimary = Color(0xFFE8F5E9);
  static const _textSecondary = Color(0xFF86A98E);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: GlassCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            initiallyExpanded: true,
            title: Row(
              children: [
                const Icon(Icons.folder_outlined, color: _green, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session $sessionShort…',
                        style: GoogleFonts.syne(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _textPrimary),
                      ),
                      Text(
                        timestamp,
                        style: GoogleFonts.dmMono(
                            fontSize: 10, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${logs.length} photo${logs.length == 1 ? '' : 's'}',
                    style: GoogleFonts.dmMono(
                        fontSize: 10, color: _green, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
            children: logs.map((l) => _PhotoRow(log: l)).toList(),
          ),
        ),
      ),
    );
  }
}

// ─── Photo row ────────────────────────────────────────────────────────────────

class _PhotoRow extends StatelessWidget {
  final DroneLog log;
  const _PhotoRow({required this.log});

  static const _green = Color(0xFF4ADE80);
  static const _textPrimary = Color(0xFFE8F5E9);
  static const _textSecondary = Color(0xFF86A98E);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: log.hasImage
          ? () => _showFullImage(context, log.imageUrl)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: log.hasImage
                  ? Image.network(
                      log.imageUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.formattedTime,
                    style: GoogleFonts.dmMono(
                        fontSize: 12,
                        color: _textPrimary,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    _gpsIcon(log.gpsValid),
                    const SizedBox(width: 4),
                    Text(
                      log.gpsValid
                          ? '${log.lat.toStringAsFixed(5)}, ${log.lng.toStringAsFixed(5)}'
                          : 'No GPS fix',
                      style: GoogleFonts.dmMono(
                          fontSize: 10, color: _textSecondary),
                    ),
                  ]),
                  if (log.altitudeM != null)
                    Text(
                      'Alt ${log.altitudeM!.toStringAsFixed(1)} m',
                      style: GoogleFonts.dmMono(
                          fontSize: 10, color: _textSecondary),
                    ),
                ],
              ),
            ),
            if (log.hasImage)
              const Icon(Icons.open_in_full_rounded,
                  color: _green, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_not_supported_outlined,
          color: Color(0xFF4A6B51), size: 26),
    );
  }

  Widget _gpsIcon(bool valid) => Icon(
        valid ? Icons.gps_fixed : Icons.gps_off,
        size: 12,
        color: valid ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
      );

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty / error states ─────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined,
              color: const Color(0xFF86A98E).withOpacity(0.4), size: 64),
          const SizedBox(height: 12),
          Text('No photos yet',
              style: GoogleFonts.syne(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: const Color(0xFF86A98E))),
          const SizedBox(height: 6),
          Text('Start a session and capture images from the drone',
              style: GoogleFonts.instrumentSans(
                  fontSize: 13, color: const Color(0xFF4A6B51))),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: Color(0xFFF87171), size: 48),
            const SizedBox(height: 12),
            Text('Could not load photos',
                style: GoogleFonts.syne(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: const Color(0xFFE8F5E9))),
            const SizedBox(height: 6),
            Text(error,
                style: GoogleFonts.instrumentSans(
                    fontSize: 12, color: const Color(0xFF86A98E)),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ADE80).withOpacity(0.15),
                foregroundColor: const Color(0xFF4ADE80),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
