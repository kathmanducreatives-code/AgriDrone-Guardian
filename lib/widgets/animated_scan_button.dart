import 'package:flutter/material.dart';

class AnimatedScanButton extends StatefulWidget {
  final bool isScanning;
  final VoidCallback onPressed;

  const AnimatedScanButton(
      {super.key, required this.isScanning, required this.onPressed});

  @override
  State<AnimatedScanButton> createState() => _AnimatedScanButtonState();
}

class _AnimatedScanButtonState extends State<AnimatedScanButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _pulse = Tween<double>(begin: 1.0, end: 1.5)
        .chain(CurveTween(curve: Curves.easeOut))
        .animate(_ctrl);
    if (widget.isScanning) _ctrl.repeat(reverse: false);
  }

  @override
  void didUpdateWidget(AnimatedScanButton old) {
    super.didUpdateWidget(old);
    if (widget.isScanning && !old.isScanning) {
      _ctrl.repeat(reverse: false);
    } else if (!widget.isScanning && old.isScanning) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.isScanning ? const Color(0xFFFB923C) : const Color(0xFF4ADE80);

    return GestureDetector(
      onTap: widget.isScanning ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.isScanning)
                Transform.scale(
                  scale: _pulse.value,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFFB923C).withOpacity(
                              (1 - (_pulse.value - 1) / 0.5).clamp(0.0, 1.0)),
                          width: 2),
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.isScanning
                        ? [const Color(0xFFFB923C), const Color(0xFFEA7A1A)]
                        : [const Color(0xFF4ADE80), const Color(0xFF22C55E)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RotationTransition(
                      turns: _ctrl,
                      child: Icon(
                        widget.isScanning
                            ? Icons.radar
                            : Icons.track_changes_rounded,
                        color: const Color(0xFF0A0F0D),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.isScanning ? 'SCANNING...' : 'TRIGGER SCAN',
                      style: const TextStyle(
                        color: Color(0xFF0A0F0D),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
