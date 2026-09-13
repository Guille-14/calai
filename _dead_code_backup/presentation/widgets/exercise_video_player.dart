import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Widget reproductor de videos de ejercicios con controles básicos
class ExerciseVideoPlayer extends StatefulWidget {
  final String videoUrl; // URL de YouTube (puede ser link completo o ID)
  final String exerciseName;
  final bool autoPlay;
  final VoidCallback? onVideoEnd;

  const ExerciseVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.exerciseName,
    this.autoPlay = false,
    this.onVideoEnd,
  });

  @override
  State<ExerciseVideoPlayer> createState() => _ExerciseVideoPlayerState();
}

class _ExerciseVideoPlayerState extends State<ExerciseVideoPlayer> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    final videoId = _extractVideoId(widget.videoUrl);
    
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: widget.autoPlay,
        mute: false,
        useHybridComposition: true,
      ),
    )..addListener(_onPlayerStateChange);
  }

  String _extractVideoId(String url) {
    // Handle full YouTube URLs
    RegExp regExp = RegExp(
      r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)',
      caseSensitive: false,
      multiLine: true,
    );
    
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }
    
    // Assume it's already a video ID
    return url;
  }

  void _onPlayerStateChange() {
    if (_controller.value.playerState == PlayerState.ended && widget.onVideoEnd != null) {
      widget.onVideoEnd!();
    }
  }

  @override
  void didUpdateWidget(ExerciseVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller.load(_extractVideoId(widget.videoUrl));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF34C759).withValues(alpha: 0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: const Color(0xFF34C759),
          progressColors: const ProgressBarColors(
            playedColor: Color(0xFF34C759),
            handleColor: Color(0xFF34C759),
            bufferedColor: Colors.white30,
            backgroundColor: Colors.white10,
          ),
          onReady: () {
            setState(() => _isPlayerReady = true);
          },
        ),
      ),
    );
  }
}

/// Widget para mostrar tarjeta con instrucciones e información del ejercicio
class ExerciseInstructionCard extends StatelessWidget {
  final String name;
  final String description;
  final List<String> tips;
  final String muscleGroup;
  final String difficulty;
  final String equipment;

  const ExerciseInstructionCard({
    super.key,
    required this.name,
    required this.description,
    required this.tips,
    required this.muscleGroup,
    required this.difficulty,
    required this.equipment,
  });

  Color _getDifficultyColor() {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return const Color(0xFF34C759); // Green
      case 'intermediate':
        return const Color(0xFFFF9500); // Orange
      case 'advanced':
        return const Color(0xFFFF453A); // Red
      default:
        return Colors.grey;
    }
  }

  String _getDifficultyLabel() {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return 'Principiante';
      case 'intermediate':
        return 'Intermedio';
      case 'advanced':
        return 'Avanzado';
      default:
        return difficulty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con dificultad
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      muscleGroup.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF34C759),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getDifficultyColor().withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getDifficultyColor().withValues(alpha: 0.3)),
                ),
                child: Text(
                  _getDifficultyLabel(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getDifficultyColor(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Descripción
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 16),

          // Equipment
          if (equipment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  const Icon(Icons.fitness_center, color: Color(0xFF34C759), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    equipment,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

          // Tips/Consejos
          if (tips.isNotEmpty) ...[
            const Text(
              '💡 Consejos:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ...tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2, right: 8),
                    child: Icon(Icons.check_circle, color: Color(0xFF34C759), size: 16),
                  ),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}
