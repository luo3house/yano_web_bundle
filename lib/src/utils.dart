T? tryCatch<T>(T Function() fn, {T Function(Object e)? orElse}) {
  try {
    return fn();
  } catch (e) {
    return orElse?.call(e);
  }
}
