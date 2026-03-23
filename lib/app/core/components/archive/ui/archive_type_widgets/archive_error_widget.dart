import 'package:aco_plus/app/core/components/archive/archive_model.dart';
import 'package:aco_plus/app/core/components/archive/archive_type.dart';
import 'package:flutter/material.dart';

class ArchiveErrorWidget extends StatelessWidget {
  final ArchiveModel archive;
  const ArchiveErrorWidget(this.archive, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Icon(archive.type.icon, size: 40, color: Colors.grey[400]),
      ),
    );
  }
}
