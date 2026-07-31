import 'package:flutter_riverpod/flutter_riverpod.dart';

extension AsyncValueExt<T> on AsyncValue<T> {
  T getOrThrow() {
    return when(
      data: (data) => data,
      error: (e, st) => throw e,
      loading: () => throw StateError('AsyncValue is still loading'),
    );
  }

  R? mapData<R>(R Function(T data) mapper) {
    return whenOrNull(data: mapper);
  }
}
