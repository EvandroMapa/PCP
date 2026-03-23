import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class RowSeparated extends StatelessWidget {
  final List<Widget> children;
  final Widget? gap;
  final MainAxisAlignment mainAxisAlignment;

  const RowSeparated({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.gap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      children: _addSeparators(children, gap ?? Gap(8)),
    );
  }

  List<Widget> _addSeparators(List<Widget> children, Widget gap) {
    if (children.isEmpty) return [];

    final List<Widget> separatedChildren = [];
    for (int i = 0; i < children.length; i++) {
      separatedChildren.add(children[i]);
      if (i < children.length - 1) {
        separatedChildren.add(gap);
      }
    }
    return separatedChildren;
  }
}
