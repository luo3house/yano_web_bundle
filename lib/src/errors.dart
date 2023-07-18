class FileNotFoundError extends Error {
  final String path;
  FileNotFoundError(this.path);
  @override
  String toString() => "file $path not found";
}

class NoDecoderAvailableError extends Error {
  final Uri key;
  NoDecoderAvailableError(this.key);
  @override
  String toString() => "no available decoder for bundle: $key";
}

class AlreadyFetchingError extends Error {
  final Uri key;
  AlreadyFetchingError(this.key);
  @override
  String toString() => "bundle is already fetching, cancel it first: $key";
}

class AlreadyServingError extends Error {
  final String addrport;
  AlreadyServingError(this.addrport);
  @override
  String toString() => "already serving this bundle at: $addrport";
}
