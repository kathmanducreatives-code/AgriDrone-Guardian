import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/app_providers.dart';
import '../models/drone_models.dart';
import '../widgets/glass_card.dart';
import '../widgets/pulsing_dot.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key});

  String _urgency(String disease) {
    final d = disease.toLowerCase();
    if (d.contains('blast') || d.contains('blight')) return 'HIGH';
    if (d.contains('spot') || d.contains('rust')) return 'MEDIUM';
    return 'LOW';
  }

  Color _urgencyColor(String u) {
    if (u == 'HIGH') return const Color(0xFFF87171);
    if (u == 'MEDIUM') return const Color(0xFFFB923C);
    return const Color(0xFF4ADE80);
  }

  Map<String, String> _treatment(String disease) {
    final d = disease.toLowerCase().replaceAll('_', ' ');
    if (d.contains('brown spot')) {
      return {
        'action':
            'Apply Propiconazole fungicide. Remove infected leaves. Keep field drainage optimal.',
        'icon': 'leaf',
      };
    }
    if (d.contains('blast')) {
      return {
        'action':
            'Apply Tricyclazole at first sign. Increase silica content in soil. Avoid excessive nitrogen.',
        'icon': 'warning',
      };
    }
    if (d.contains('blight')) {
      return {
        'action':
            'Apply Copper-based fungicide. Destroy infected plant residues. Improve air circulation.',
        'icon': 'warning',
      };
    }
    if (d.contains('healthy')) {
      return {
        'action': 'Crop looks healthy. Continue standard monitoring every 48h.',
        'icon': 'check',
      };
    }
    return {
      'action':
          'Consult local agronomist. Collect samples for lab analysis. Monitor spread.',
      'icon': 'search',
    };
  }

  Color _sevColor(double conf, bool isHealthy) {
    if (isHealthy) return const Color(0xFF4ADE80);
    if (conf < 0.4) return const Color(0xFFF87171);
    if (conf < 0.7) return const Color(0xFFFB923C);
    return const Color(0xFF4ADE80);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestAsync = ref.watch(latestDetectionProvider);
    final historyAsync = ref.watch(detectionHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F0D),
        elevation: 0,
        title: Text('Detection Report',
            style: GoogleFonts.syne(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: const Color(0xFFE8F5E9))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Card
            latestAsync.when(
              data: (d) => _buildHeroCard(context, d),
              loading: () => _shimmer(200),
              error: (_, __) => _buildEmptyState(context),
            ),
            const SizedBox(height: 24),

            // Treatment Card
            latestAsync.when(
              data: (d) {
                if (d.disease == 'Unknown' || d.confidence == 0)
                  return const SizedBox.shrink();
                return _buildTreatmentCard(context, d);
              },
              loading: () => _shimmer(120),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 28),

            // History
            _sectionLabel('SCAN HISTORY'),
            const SizedBox(height: 10),
            historyAsync.when(
              data: (list) {
                if (list.isEmpty) return _buildEmptyState(context);
                return Column(
                  children: List.generate(
                    list.length,
                    (i) => TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 300 + i * 60),
                      curve: Curves.easeOut,
                      builder: (_, v, child) =>
                          Opacity(opacity: v, child: child),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildHistoryItem(context, list[i]),
                      ),
                    ),
                  ),
                );
              },
              loading: () => _shimmer(80),
              error: (_, __) => _buildEmptyState(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, Detection d) {
    final isHealthy = d.disease.toLowerCase() == 'healthy';
    final isUnknown = d.disease == 'Unknown' || d.confidence == 0;
    final sev = _sevColor(d.confidence, isHealthy);
    final urgency = isUnknown ? 'LOW' : _urgency(d.disease);
    final formattedDisease = d.disease.replaceAll('_', ' ');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            sev.withOpacity(0.18),
            const Color(0xFF111A14),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: sev.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: sev.withOpacity(0.12),
              blurRadius: 30,
              offset: const Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          _sectionLabel('LATEST RESULT'),
          const SizedBox(height: 16),
          Text(
            isUnknown ? 'Awaiting Scan...' : formattedDisease,
            textAlign: TextAlign.center,
            style: GoogleFonts.syne(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: isUnknown ? const Color(0xFF4A6B51) : const Color(0xFFE8F5E9),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 18),
          if (!isUnknown) ...[
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: d.confidence),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (_, v, __) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${(v * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.dmMono(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: sev)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: d.confidence),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (_, v, __) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: v,
                  backgroundColor: Colors.black.withOpacity(0.35),
                  valueColor: AlwaysStoppedAnimation<Color>(sev),
                  minHeight: 10,
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: sev.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sev.withOpacity(0.35)),
            ),
            child: Text(
              isUnknown ? 'NO DATA' : urgency,
              style: GoogleFonts.dmMono(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                  color: sev),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentCard(BuildContext context, Detection d) {
    final info = _treatment(d.disease);
    final urgency = _urgency(d.disease);
    final urgencyColor = _urgencyColor(urgency);
    final iconData = info['icon'] == 'warning'
        ? Icons.warning_amber_rounded
        : info['icon'] == 'check'
            ? Icons.check_circle_outline_rounded
            : info['icon'] == 'search'
                ? Icons.search_rounded
                : Icons.eco_rounded;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('RECOMMENDED ACTION'),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: urgencyColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: urgencyColor.withOpacity(0.4)),
                ),
                child: Text('$urgency URGENCY',
                    style: GoogleFonts.dmMono(
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w500,
                        color: urgencyColor)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData,
                    color: const Color(0xFF4ADE80), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(info['action'] ?? '',
                    style: GoogleFonts.instrumentSans(
                        fontSize: 14,
                        color: const Color(0xFF86A98E),
                        height: 1.6)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, Detection d) {
    final isHealthy = d.disease.toLowerCase() == 'healthy';
    final sev = _sevColor(d.confidence, isHealthy);
    final formatted = d.disease.replaceAll('_', ' ');

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A2A1E), Color(0xFF111A14)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF4ADE80).withOpacity(0.1)),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: sev,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formatted,
                                style: GoogleFonts.syne(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE8F5E9))),
                            const SizedBox(height: 4),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(d.crop.toUpperCase(),
                                    style: GoogleFonts.dmMono(
                                        fontSize: 9,
                                        color: const Color(0xFF86A98E))),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: sev.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: sev.withOpacity(0.3)),
                            ),
                            child: Text(
                                '${(d.confidence * 100).toStringAsFixed(0)}%',
                                style: GoogleFonts.dmMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: sev)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            d.timestamp > 0
                                ? DateFormat('MMM dd · HH:mm').format(
                                    DateTime.fromMillisecondsSinceEpoch(
                                        d.timestamp))
                                : '—',
                            style: GoogleFonts.dmMono(
                                fontSize: 10,
                                color: const Color(0xFF4A6B51)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.track_changes_rounded,
              color: const Color(0xFF4A6B51).withOpacity(0.5), size: 52),
          const SizedBox(height: 16),
          Text('No detections yet',
              style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4A6B51))),
          const SizedBox(height: 8),
          Text('Trigger a scan to begin detection',
              style: GoogleFonts.instrumentSans(
                  fontSize: 13, color: const Color(0xFF4A6B51))),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(t,
      style: GoogleFonts.dmMono(
          fontSize: 10,
          letterSpacing: 2.5,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF4A6B51)));

  Widget _shimmer(double h) => Container(
      height: h,
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF1A2A1E), Color(0xFF1F3224)]),
          borderRadius: BorderRadius.circular(18)));
}
