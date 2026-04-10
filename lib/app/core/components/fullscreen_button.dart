import 'package:aco_plus/app/core/services/fullscreen_service.dart';
import 'package:flutter/material.dart';

class FullscreenButton extends StatefulWidget {
  final Color? color;
  const FullscreenButton({this.color, super.key});

  @override
  State<FullscreenButton> createState() => _FullscreenButtonState();
}

class _FullscreenButtonState extends State<FullscreenButton> {
  @override
  Widget build(BuildContext context) {
    final isFullscreen = FullscreenService.isFullscreen;
    
    return IconButton(
      tooltip: isFullscreen ? 'Sair da Tela Cheia' : 'Tela Cheia',
      icon: Icon(
        isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
        color: widget.color ?? Colors.white,
        size: 24,
      ),
      onPressed: () {
        setState(() {
          FullscreenService.toggle();
        });
      },
    );
  }
}
