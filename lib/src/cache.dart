import 'bundle.dart';
import 'fetch.dart';

abstract class CacheProvider {
  /// load a cache as [Fetcher.fetch] does, null if no cache retrieved
  Future<BundleResponse?> loadCache(Uri bundleKey);

  /// throwing is ignored
  Future<void> saveCache(Uri bundleKey, BundleResponse bundle);

  Future<int> getCacheSize();

  Future<void> clearCache();
}
