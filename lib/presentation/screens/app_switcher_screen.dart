import 'package:flutter/material.dart';
import 'normal_mode_navigator.dart';
import 'symmetry_navigator.dart';

class AppSwitcherScreen extends StatefulWidget {
  const AppSwitcherScreen({super.key});

  @override
  State<AppSwitcherScreen> createState() => _AppSwitcherScreenState();
}

class _AppSwitcherScreenState extends State<AppSwitcherScreen> {
  bool _isSymmetryMode = false;

  @override
  Widget build(BuildContext context) {
    if (_isSymmetryMode) {
      return SymmetryNavigator(
        onExitSymmetry: () => setState(() => _isSymmetryMode = false),
      );
    }
    return NormalModeNavigator(
      onEnterSymmetry: () => setState(() => _isSymmetryMode = true),
    );
  }
}
