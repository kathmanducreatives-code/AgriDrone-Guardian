import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_providers.dart';
import '../models/photo_model.dart';
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
    final photosAsync = ref.watch(photosProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text('Mission Photos',
            style: GoogleFonts.syne(fontWeight: FontWeight.w800, fontSize: 18, color: _textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _green),
            onPressed: () => ref.read(photosProvider.notifier).load(),
          ),
        ],
      ),
      body: photosAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _green),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, color: Color(0xFFF87171), size: 48),
                const SizedBox(height: 12),
                Text('Could not load photos',
                    style: GoogleFonts.syne(
                        fontWeight: FontWeight.w700, fontSize: 16, color: _textPrimary)),
                const SizedBox(height: 6),
                Text(e.toString(),
                    style: GoogleFonts.instrumentSans(fontSize: 12, color: _textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.read(photosProvider.notifier).load(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green.withOpacity(0.15),
                    foregroundColor: _green,
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (photos) {
          if (photos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library_outlined,
                      color: _textSecondary.withOpacity(0.4), size: 64),
                  const SizedBox(height: 12),
                  Text('No photos yet',
                      style: GoogleFonts.syne(
                          fontWeight: FontWeight.w700, fontSize: 16, color: _textSecondary)),
                  const SizedBox(height: 6),
                  Text('Start a mission to capture photos',
                      style:
                          GoogleFonts.instrumentSans(fontSize: 13, color: _textSecondary)),
                ],
              ),
            );
          }
          return _PhotosList(photos: photos);
        },
      ),
    );
  }
}

class _PhotosList extends StatelessWidget {
  final List<PhotoModel> photos;

  const _PhotosList({required this.photos});

  static const _textPrimary = Color(0xFFE8F5E9);
  static const _textSecondary = Color(0xFF86A98E);
  static const _green = Color(0xFF4ADE80);

  /// Group photos by storageFolder. Photos without a folder go into a "" bucket.
  Map<String, List<PhotoModel>> _group(List<PhotoModel> photos) {
    final map = <String, List<PhotoModel>>{};
    for (final p in photos) {
      final key = p.storageFolder ?? '';
      (map[key] ??= []).add(p);
    }
    // Sort buckets newest-first (folder names start with mission_YYYYMMDD_HHMMSS)
    final sorted = map.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return {for (final e in sorted) e.key: e.value};
  }

  @override
  Widget build(BuildContext context) {
    final groups = _group(photos);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      children: groups.entries.map((entry) {
        final folder = entry.key;
        final items = entry.value;
        final title = folder.isEmpty ? 'Ungrouped Photos' : PhotoModel.folderLabel(folder);

        return _MissionGroup(
          title: title,
          subtitle: folder.isEmpty ? null : folder,
          photos: items,
        );
      }).toList(),
    );
  }
}

class _MissionGroup extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<PhotoModel> photos;

  const _MissionGroup({
    required this.title,
    this.subtitle,
    required this.photos,
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
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_outlined, color: _green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.syne(
                            fontWeight: FontWeight.w700, fontSize: 14, color: _textPrimary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${photos.length} photo${photos.length == 1 ? '' : 's'}',
                        style: GoogleFonts.dmMono(
                            fontSize: 10, color: _green, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 26),
                    child: Text(
                      subtitle!,
                      style: GoogleFonts.dmMono(
                          fontSize: 10, color: _textSecondary, letterSpacing: 0.3),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            children: photos.map((photo) => _PhotoRow(photo: photo)).toList(),
          ),
        ),
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  final PhotoModel photo;

  const _PhotoRow({required this.photo});

  static const _green = Color(0xFF4ADE80);
  static const _orange = Color(0xFFFB923C);
  static const _red = Color(0xFFF87171);
  static const _textPrimary = Color(0xFFE8F5E9);
  static const _textSecondary = Color(0xFF86A98E);

  Color _severityColor(String? severity) {
    switch (severity) {
      case 'severe': return _red;
      case 'moderate': return _orange;
      case 'mild': return const Color(0xFFFBBF24);
      default: return _green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disease = photo.primaryDetection?['disease'] as String?;
    final severity = photo.highestSeverity;
    final hasDetection = photo.detectionCount > 0 && disease != null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          // Preview thumbnail or placeholder
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: photo.previewUrl != null
                ? Image.network(
                    photo.previewUrl!,
                    width: 56,
                    height: 56,
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
                  'Frame ${photo.patchIndex + 1}  ·  ${photo.imageId}',
                  style: GoogleFonts.dmMono(
                      fontSize: 12, color: _textPrimary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                if (hasDetection)
                  Text(
                    '${disease!}  ·  ${photo.detectionCount} detection${photo.detectionCount == 1 ? '' : 's'}',
                    style: GoogleFonts.instrumentSans(
                        fontSize: 12, color: _severityColor(severity)),
                  )
                else
                  Text(
                    photo.analysisStatus == 'completed' ? 'No disease detected' : photo.analysisStatus,
                    style: GoogleFonts.instrumentSans(fontSize: 12, color: _textSecondary),
                  ),
                if (photo.capturedAt != null)
                  Text(
                    _formatTimestamp(photo.capturedAt!),
                    style: GoogleFonts.dmMono(fontSize: 10, color: _textSecondary.withOpacity(0.6)),
                  ),
              ],
            ),
          ),
          if (severity != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _severityColor(severity).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                severity.toUpperCase(),
                style: GoogleFonts.dmMono(
                    fontSize: 9, color: _severityColor(severity), letterSpacing: 1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2A1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_not_supported_outlined,
          color: Color(0xFF4A6B51), size: 24),
    );
  }

  String _formatTimestamp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} '
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
