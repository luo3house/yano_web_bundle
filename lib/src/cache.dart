import 'bundle.dart';
import 'fetch.dart';

abstract class CacheProvider {
  /// check if a bundle key is available to store & load
  Future<bool> test(Uri bundleKey);

  /// load a cache as [Fetcher.fetch] does, null if no cache retrieved
  Future<BundleResponse?> loadCache(Uri bundleKey);

  /// throwing is ignored
  Future<void> saveCache(Uri bundleKey, BundleResponse bundle);

  Future<int> getCacheSize();
  Future<void> clearCache();
}

// abstract class CachedFetcher extends StreamableFetcher {
//   CacheProvider get cacheProvider;

//   Fetcher get fetcher;

//   @override
//   Future<bool> test(Uri bundleKey) async =>
//       await fetcher.test(bundleKey) && await cacheProvider.testCache(bundleKey);

//   @override
//   Future<BundleResponse> fetch(Uri bundleKey) async {
//     if (await test(bundleKey)) return cacheProvider.loadCache(bundleKey);
//     return fetch(bundleKey).then((rsp) async {
//       await cacheProvider.saveCache(bundleKey, rsp).catchError((_) {});
//       return rsp;
//     });
//   }
// }
