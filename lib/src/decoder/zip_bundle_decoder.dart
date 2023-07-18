import 'package:archive/archive_io.dart';
import 'package:yano_web_bundle/src/errors.dart';

import '../bundle.dart';

class ZipBundleDecoder extends BundleDecoder {
  @override
  Future<Bundle> decode(BundleResponse raw) async {
    final zipAr = ZipDecoder().decodeBytes(raw.bytes);
    final files = Map<String, (int, ArchiveFile)>.fromEntries(
      List.generate(zipAr.files.length, (i) => (i, zipAr.files[i]))
          .where((tuple) => tuple.$2.isFile)
          .map((tuple) => MapEntry(tuple.$2.name, (tuple.$1, tuple.$2))),
    );
    (int, ArchiveFile) findFileOrThrow(String rpath) {
      final target = files[rpath];
      if (target == null) throw FileNotFoundError(rpath);
      return target;
    }

    return BundleImpl(
      raw.header,
      () async => files.values.map((file) => file.$2.name).toList(),
      (rpath) async => zipAr.fileSize(findFileOrThrow(rpath).$1),
      (rpath) async => DateTime.fromMillisecondsSinceEpoch(
          findFileOrThrow(rpath).$2.lastModTime * 1000),
      (rpath) async => Stream.fromFuture(
        Future.sync(() => zipAr.fileData(findFileOrThrow(rpath).$1)),
      ),
      () => files.clear(),
    );
  }
}
