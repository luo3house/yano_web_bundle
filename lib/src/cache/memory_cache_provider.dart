import 'package:yano_web_bundle/src/bundle.dart';

import '../cache.dart';

class MemoryCacheProvider implements CacheProvider {
  final Map<Uri, BundleResponse> store = {};
  @override
  Future<void> clearCache() async {
    store.clear();
  }

  @override
  Future<int> getCacheSize() async {
    final size = store.values.fold(0, (pre, cur) => pre + cur.bytes.length);
    return size;
  }

  @override
  Future<BundleResponse?> loadCache(Uri bundleKey) async {
    return store[bundleKey];
  }

  @override
  Future<void> saveCache(Uri bundleKey, BundleResponse bundle) async {
    store[bundleKey] = bundle;
  }
}
