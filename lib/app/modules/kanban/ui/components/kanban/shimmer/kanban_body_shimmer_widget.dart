import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/kanban/kanban_background_widget.dart';
import 'package:flutter/material.dart';

class KanbanBodyShimmerWidget extends StatefulWidget {
  const KanbanBodyShimmerWidget({super.key});

  @override
  State<KanbanBodyShimmerWidget> createState() =>
      _KanbanBodyShimmerWidgetState();
}

class _KanbanBodyShimmerWidgetState extends State<KanbanBodyShimmerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KanbanBackgroundWidget(
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryMain.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Carregando Kanban...',
                style: AppCss.mediumRegular.copyWith(
                  fontSize: 14,
                  color: AppColors.neutralMedium,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
