import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:yano_web_bundle/yano_web_bundle.dart';
import 'package:path_provider/path_provider.dart';

final kMemoryFacade = BundleFacade.memory({
  "index.html": utf8.encode("""
  <!DOCTYPE HTML>
  <html><head><script src="/index.js"></script></head<</html>
  """),
  "index.js": utf8.encode("window.onload = function() {alert('Hello World')}"),
});

final kZipAssetFacade = () {
  final fetcher = Fetcher.withFunction((bundleKey) => rootBundle
      .load(bundleKey.path)
      .then((dat) => BundleResponse({}, List.from(dat.buffer.asUint8List()))));
  final decoder = ZipBundleDecoder();
  return BundleFacade(fetcher, decoder);
}();

final kZipHttpFacade = () {
  final fetcher = HttpFetcher();
  final decoder = ZipBundleDecoder();
  return BundleFacade(fetcher, decoder);
}();

final kCachedZipHttpFacade = () async {
  final fetcher = HttpFetcher();
  final decoder = ZipBundleDecoder();
  final cacheProvider = DirectoryCacheProvider(await getTemporaryDirectory());
  return BundleFacade(fetcher, decoder, cacheProvider);
}();
