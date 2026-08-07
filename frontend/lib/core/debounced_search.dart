// DebouncedSearch — a self-contained debounced text controller for search
// fields. Screens used to hand-roll a TextEditingController + Timer pair;
// this folds the timer + listener lifecycle into one disposable object.
import 'dart:async';
import 'package:flutter/material.dart';

class DebouncedSearch {
  DebouncedSearch({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;
  final TextEditingController controller = TextEditingController();
  Timer? _timer;

  /// Called after the user stops typing for [delay].
  void Function()? onQuery;

  void attach() {
    controller.addListener(_schedule);
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(delay, () => onQuery?.call());
  }

  String get query => controller.text.trim();

  void dispose() {
    _timer?.cancel();
    controller.dispose();
  }
}
