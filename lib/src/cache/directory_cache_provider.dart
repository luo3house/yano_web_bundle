import 'dart:convert';
import 'dart:io';

import 'package:yano_web_bundle/src/bundle.dart';

import '../cache.dart';

class DirectoryCacheProvider implements CacheProvider {
  final Directory dir;
  DirectoryCacheProvider(this.dir) {
    dir.create(recursive: true);
  }

  (String header, String bytes) _getCacheFilePaths(Uri bundleKey) {
    final baseName = Uri.encodeComponent(bundleKey.toString());
    return ("${dir.path}/$baseName.json", "${dir.path}/$baseName.dat");
  }

  @override
  Future<void> clearCache() => dir.delete(recursive: true).then((_) {});

  @override
  Future<int> getCacheSize() async {
    await dir.create(recursive: true);
    return dir.list(recursive: true).fold(0, (pre, cur) {
      final stat = cur.statSync();
      return pre + (stat.type == FileSystemEntityType.file ? stat.size : 0);
    });
  }

  @override
  Future<BundleResponse?> loadCache(Uri bundleKey) async {
    final (headerPath, bytesPath) = _getCacheFilePaths(bundleKey);
    final headerFile = File(headerPath), bytesFile = File(bytesPath);
    if (!await headerFile.exists()) {
      return null;
    } else if (!await bytesFile.exists()) {
      return null;
    }
    final header = await headerFile
        .readAsBytes()
        .then((raw) => utf8.decode(raw))
        .then((raw) => jsonDecode(raw) as Map<String, dynamic>)
        .then((json) => Map<String, String>.fromEntries(
            json.entries.map((entry) => MapEntry(entry.key, "${entry.value}"))))
        .catchError((_) => <String, String>{/* ign */});
    final bytes =
        await bytesFile.readAsBytes().then((raw) => List<int>.of(raw));
    return BundleResponse(header, bytes);
  }

  @override
  Future<void> saveCache(Uri bundleKey, BundleResponse bundle) async {
    final (headerPath, bytesPath) = _getCacheFilePaths(bundleKey);
    final headerFile = File(headerPath), bytesFile = File(bytesPath);
    await headerFile.writeAsBytes(
      utf8.encode(jsonEncode(bundle.header)),
      mode: FileMode.writeOnly,
    );
    await bytesFile.writeAsBytes(
      bundle.bytes,
      mode: FileMode.writeOnly,
    );
  }
}
