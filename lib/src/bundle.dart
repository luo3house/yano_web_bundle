import 'errors.dart';

// match = leading slash
final kBundleTrimLeadingSlashRE = RegExp("^/");

abstract class BundleDecoder {
  Future<Bundle> decode(BundleResponse raw);

  static withFunction(Future<Bundle> Function(BundleResponse raw) decode) =>
      BundleDecoderImpl(decode);
}

class BundleDecoderImpl implements BundleDecoder {
  final Future<Bundle> Function(BundleResponse raw) item1;
  const BundleDecoderImpl(this.item1);

  @override
  Future<Bundle> decode(BundleResponse raw) => item1(raw);
}

class BundleResponse {
  final Map<String, String> header;
  final List<int> bytes;
  const BundleResponse(this.header, this.bytes);
}

abstract class Bundle {
  Map<String, String> get header;

  /// list bundle files, in relative paths
  ///
  /// e.g. `index.html`, `assets/logo.png`
  Future<List<String>> fileList();

  /// get size of a file
  ///
  /// throws [FileNotFoundError]
  Future<int> fileSize(String rpath);

  /// get modified time of a file
  ///
  /// throws [FileNotFoundError]
  Future<DateTime> fileModified(String rpath);

  /// open read stream for a file
  ///
  /// throws [FileNotFoundError]
  Future<Stream<List<int>>> openStream(String rpath);

  /// close bundle, release resource
  void close();
}

class BundleImpl implements Bundle {
  @override
  final Map<String, String> header;
  final Future<List<String>> Function() fileListIMPL;
  final Future<int> Function(String rpath) fileSizeIMPL;
  final Future<DateTime> Function(String rpath) fileModifiedIMPL;
  final Future<Stream<List<int>>> Function(String rpath) openStreamIMPL;
  final void Function() closeIMPL;

  BundleImpl(
    this.header,
    this.fileListIMPL,
    this.fileSizeIMPL,
    this.fileModifiedIMPL,
    this.openStreamIMPL,
    this.closeIMPL,
  );

  @override
  Future<List<String>> fileList() => fileListIMPL();

  @override
  Future<int> fileSize(String rpath) => fileSizeIMPL(rpath);

  @override
  Future<DateTime> fileModified(String rpath) => fileModifiedIMPL(rpath);
  @override
  Future<Stream<List<int>>> openStream(String rpath) => openStreamIMPL(rpath);

  @override
  void close() => closeIMPL();
}

class MemoryBundle implements Bundle, BundleResponse {
  final Map<String, List<int>> files;
  final _created = DateTime.now();

  MemoryBundle(this.files);

  List<int> _fileBytesOrThrow(String rpath) {
    if (!files.containsKey(rpath)) {
      throw FileNotFoundError(rpath);
    }
    return files[rpath]!;
  }

  @override
  void close() {}

  @override
  Future<List<String>> fileList() async => List.from(files.keys);

  @override
  Future<DateTime> fileModified(String rpath) async => _created;

  @override
  Future<int> fileSize(String rpath) async => _fileBytesOrThrow(rpath).length;

  @override
  Map<String, String> get header => {};

  @override
  Future<Stream<List<int>>> openStream(String rpath) async =>
      Stream.fromIterable([_fileBytesOrThrow(rpath)]);

  @override
  List<int> get bytes => [];
}
