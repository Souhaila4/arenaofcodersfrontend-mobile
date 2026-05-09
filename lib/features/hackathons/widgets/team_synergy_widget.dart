import 'dart:math';
import 'package:flutter/material.dart';
import 'package:arena/core/models/synergy_model.dart';
import 'package:arena/core/services/api_service.dart';

/// Displays the AI Team Synergy radar chart + advice.
/// Call with the equipeId and it handles loading/display.
class TeamSynergyWidget extends StatefulWidget {
  final String equipeId;
  final bool isLeader;
  const TeamSynergyWidget({
    super.key, 
    required this.equipeId,
    this.isLeader = false,
  });

  @override
  State<TeamSynergyWidget> createState() => _TeamSynergyWidgetState();
}

class _TeamSynergyWidgetState extends State<TeamSynergyWidget>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  TeamSynergy? _synergy;
  bool _loading = true;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _animProgress;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animProgress = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _loadSynergy();
  }

  Future<void> _loadSynergy() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _api.getTeamSynergy(widget.equipeId);
      if (mounted) {
        setState(() {
          _synergy = TeamSynergy.fromJson(data);
          _loading = false;
        });
        _animController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withAlpha(60),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Synergy Agent',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Analyse IA des compétences',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              if (_synergy != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _scoreColor(_synergy!.synergyScore).withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _scoreColor(_synergy!.synergyScore).withAlpha(80),
                    ),
                  ),
                  child: Text(
                    '${_synergy!.synergyScore}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _scoreColor(_synergy!.synergyScore),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // Content
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF8B5CF6),
                      strokeWidth: 2,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Analyse en cours...',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else if (_error != null)
            Center(
              child: Text(
                'Erreur : $_error',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            )
          else if (_synergy != null) ...[
            // Radar Chart
            Center(
              child: AnimatedBuilder(
                animation: _animProgress,
                builder: (context, child) {
                  return SizedBox(
                    width: 260,
                    height: 260,
                    child: CustomPaint(
                      painter: _RadarChartPainter(
                        axes: _synergy!.axes,
                        progress: _animProgress.value,
                        isDark: isDark,
                        targetAxis: _synergy!.targetAxis,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            // Hackathon Demands
            if (_synergy!.targetTheme != null || _synergy!.targetAxis != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.withAlpha(20) : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withAlpha(60)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🎯 Objectif du Hackathon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blue.shade400)),
                    const SizedBox(height: 4),
                    if (_synergy!.targetTheme != null)
                      Text('• Thème : ${_synergy!.targetTheme}', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : Colors.black87)),
                    if (_synergy!.targetAxis != null)
                      Text('• Spécialité attendue : ${_synergy!.targetAxis}', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : Colors.black87)),
                  ],
                ),
              ),
              
            // AI Advice Box (Only for leader)
            if (widget.isLeader)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF8B5CF6).withAlpha(15)
                      : const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withAlpha(40),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🤖', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _synergy!.advice,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: Text(
                  'L\'IA conseille votre Leader sur les recrutements 🤖',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            
            // Section: Compétences actuelles
            Text('✅ Compétences actuelles', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : Colors.black87)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _synergy!.axes.where((a) => a.score > 0).map((axis) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _axisColor(axis.name).withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _axisColor(axis.name).withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_axisIcon(axis.name), size: 14, color: _axisColor(axis.name)),
                      const SizedBox(width: 6),
                      Text(
                        '${axis.name} ${axis.score}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _axisColor(axis.name),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 12),
            
            // Section: Ce qu'il manque
            if (_synergy!.axes.any((a) => a.score == 0)) ...[
              Text('⚠️ Compétences manquantes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade400)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _synergy!.axes.where((a) => a.score == 0).map((axis) {
                final isTarget = axis.name == _synergy!.targetAxis;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isTarget ? Colors.red.withAlpha(20) : Colors.grey.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isTarget ? Colors.red.withAlpha(60) : Colors.grey.withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_axisIcon(axis.name), size: 14, color: isTarget ? Colors.red : Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        isTarget ? '${axis.name} (Requis !)' : axis.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isTarget ? Colors.red : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 70) return const Color(0xFF22C55E);
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  Color _axisColor(String name) {
    switch (name) {
      case 'Frontend': return const Color(0xFF3B82F6);
      case 'Backend': return const Color(0xFF10B981);
      case 'AI / Data': return const Color(0xFF8B5CF6);
      case 'Mobile': return const Color(0xFFF59E0B);
      case 'DevOps': return const Color(0xFFEF4444);
      case 'Design': return const Color(0xFFEC4899);
      default: return Colors.grey;
    }
  }

  IconData _axisIcon(String name) {
    switch (name) {
      case 'Frontend': return Icons.web;
      case 'Backend': return Icons.dns;
      case 'AI / Data': return Icons.psychology;
      case 'Mobile': return Icons.phone_android;
      case 'DevOps': return Icons.cloud;
      case 'Design': return Icons.palette;
      default: return Icons.code;
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// RADAR CHART CUSTOM PAINTER
// ─────────────────────────────────────────────────────────────────

class _RadarChartPainter extends CustomPainter {
  final List<SynergyAxis> axes;
  final double progress;
  final bool isDark;
  final String? targetAxis;

  _RadarChartPainter({
    required this.axes,
    required this.progress,
    required this.isDark,
    this.targetAxis,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 30;
    final n = axes.length;
    if (n == 0) return;

    final angleStep = (2 * pi) / n;
    // Offset by -pi/2 so first axis is at top
    const startAngle = -pi / 2;

    // Draw grid rings (4 levels: 25%, 50%, 75%, 100%)
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withAlpha(15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int level = 1; level <= 4; level++) {
      final r = radius * level / 4;
      final path = Path();
      for (int i = 0; i <= n; i++) {
        final angle = startAngle + angleStep * (i % n);
        final x = center.dx + r * cos(angle);
        final y = center.dy + r * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, gridPaint);
    }

    // Draw axis lines
    final axisPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withAlpha(20)
      ..strokeWidth = 1;

    for (int i = 0; i < n; i++) {
      final angle = startAngle + angleStep * i;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawLine(center, Offset(x, y), axisPaint);
    }

    // Draw filled data polygon
    final dataPath = Path();
    final dataPaint = Paint()
      ..style = PaintingStyle.fill;

    // Gradient-like fill with purple
    dataPaint.color = const Color(0xFF8B5CF6).withAlpha(40);

    final strokePaint = Paint()
      ..color = const Color(0xFF8B5CF6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (int i = 0; i <= n; i++) {
      final idx = i % n;
      final score = axes[idx].score / 100.0 * progress;
      final r = radius * score;
      final angle = startAngle + angleStep * idx;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }

    canvas.drawPath(dataPath, dataPaint);
    canvas.drawPath(dataPath, strokePaint);

    // Draw data points (circles)
    final dotPaint = Paint()
      ..color = const Color(0xFF8B5CF6)
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < n; i++) {
      final score = axes[i].score / 100.0 * progress;
      final r = radius * score;
      final angle = startAngle + angleStep * i;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      canvas.drawCircle(Offset(x, y), 5, dotPaint);
      canvas.drawCircle(Offset(x, y), 5, dotBorderPaint);
    }

    // Draw labels
    for (int i = 0; i < n; i++) {
      final angle = startAngle + angleStep * i;
      final labelRadius = radius + 22;
      final x = center.dx + labelRadius * cos(angle);
      final y = center.dy + labelRadius * sin(angle);

      final isTarget = axes[i].name == targetAxis;
      final labelText = isTarget ? '🎯 ${axes[i].name}\n${(axes[i].score * progress).round()}%' : '${axes[i].name}\n${(axes[i].score * progress).round()}%';
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
            fontSize: isTarget ? 11 : 10,
            fontWeight: isTarget ? FontWeight.bold : FontWeight.w600,
            color: isTarget 
                ? (isDark ? Colors.blue.shade300 : Colors.blue.shade700) 
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            height: 1.3,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.axes != axes;
  }
}
