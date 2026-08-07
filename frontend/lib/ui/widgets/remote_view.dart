// RemoteView — the shared loading/error/empty/retry state machine every
// data-backed screen used to re-implement by hand. Loads a single
// Future<T>, exposes that state to a [builder], and reloads via its
// GlobalKey<RemoteViewState<T>> when filters or pagination change.
// The interface is the whole loading contract: screens become declarative.
import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';

class RemoteView<T> extends StatefulWidget {
  const RemoteView({
    super.key,
    required this.load,
    required this.builder,
    this.isEmpty,
    this.emptyMessage,
    this.emptyIcon,
    this.onData,
  });

  /// Loads the data. Called on init and every [RemoteViewState.reload].
  final Future<T> Function() load;

  /// Renders the loaded data.
  final Widget Function(BuildContext context, T data) builder;

  /// Optional predicate deciding whether loaded data counts as "empty".
  final bool Function(T data)? isEmpty;

  /// Text shown for the empty state (with [emptyIcon]).
  final String? emptyMessage;
  final IconData? emptyIcon;

  /// Fired with each freshly loaded value so the screen can stash
  /// out-of-band info (e.g. a pagination cursor).
  final void Function(T data)? onData;

  @override
  State<RemoteView<T>> createState() => RemoteViewState<T>();
}

class RemoteViewState<T> extends State<RemoteView<T>> {
  T? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.load();
      if (!mounted) return;
      widget.onData?.call(data);
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    }
    if (_error != null && _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: reload, child: Text(context.t('common.retry'))),
            ],
          ),
        ),
      );
    }
    final data = _data as T;
    if (widget.isEmpty?.call(data) ?? false) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.emptyIcon ?? Icons.inbox_outlined,
                color: AppColors.textMuted, size: 44),
            const SizedBox(height: 12),
            Text(widget.emptyMessage ?? context.t('common.empty')),
          ],
        ),
      );
    }
    return widget.builder(context, data);
  }
}
