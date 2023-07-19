import 'dart:io';

import 'package:http_parser/http_parser.dart';

import 'bundle.dart';
import 'fetch.dart';
import 'utils.dart';

abstract class CacheProvider {
  /// load a cache as [Fetcher.fetch] does, null if no cache retrieved
  Future<BundleResponse?> loadCache(Uri bundleKey);

  /// throwing is ignored
  Future<void> saveCache(Uri bundleKey, BundleResponse bundle);

  Future<int> getCacheSize();

  Future<void> clearCache();
}

class HeaderRespectCacheProviderDecorator implements CacheProvider {
  HeaderRespectCacheProviderDecorator(this.parent);

  final CacheProvider parent;

  @override
  Future<void> clearCache() => parent.clearCache();

  @override
  Future<int> getCacheSize() => parent.getCacheSize();

  @override
  Future<BundleResponse?> loadCache(Uri bundleKey) async {
    final bundle = await parent.loadCache(bundleKey);
    if (bundle != null && HttpCacheHelper.isFresh(bundle.header)) {
      return bundle;
    } else {
      return null;
    }
  }

  @override
  Future<void> saveCache(Uri bundleKey, BundleResponse bundle) async {
    final header = HttpCacheHelper.shouldCache(bundle.header);
    if (header != null) {
      return parent.saveCache(bundleKey, BundleResponse(header, bundle.bytes));
    }
  }
}

class HttpCacheHelper {
  HttpCacheHelper._();

  static const xYanoCacheMaxAgeHeader = "x-yano-cache-max-age";

  static String? readPropertyValue(
      Map<String, String> header, String key, Pattern prefix) {
    return header[key]
        ?.split(";")
        .map((e) => e.trim())
        .where((e) => prefix.matchAsPrefix(e) != null)
        .map((e) => e.replaceFirst(prefix, ""))
        .firstOrNull;
  }

  static bool isFresh(Map<String, String> header) {
    final now = DateTime.now();
    final date = tryCatch(
      () => parseHttpDate(header[HttpHeaders.dateHeader]!),
    );

    final xMaxAge = tryCatch(() {
      return int.tryParse(header[xYanoCacheMaxAgeHeader]!);
    });
    if (xMaxAge != null &&
        date != null &&
        date.add(Duration(seconds: xMaxAge)).isAfter(now)) {
      return true;
    }

    final age = tryCatch(() {
      return int.tryParse(header[HttpHeaders.ageHeader]!);
    });
    final maxAge = tryCatch(() {
      return int.tryParse(readPropertyValue(
          header, HttpHeaders.cacheControlHeader, "max-age=")!);
    });

    // Age + max-age
    if (date != null && maxAge != null) {
      return date.add(Duration(seconds: maxAge - (age ?? 0))).isAfter(now);
    }

    return false;
  }

  static Map<String, String>? shouldCache(Map<String, String> header) {
    header = Map.from(header);

    final noCache =
        readPropertyValue(header, HttpHeaders.cacheControlHeader, "no-cache") !=
            null;
    final noStore =
        readPropertyValue(header, HttpHeaders.cacheControlHeader, "no-store") !=
            null;

    if (noCache || noStore) return null;

    final date = tryCatch(
      () => parseHttpDate(header[HttpHeaders.dateHeader]!),
    );

    // Date + max-age -> max-age
    final maxAge = tryCatch(() {
      return int.tryParse(readPropertyValue(
          header, HttpHeaders.cacheControlHeader, "max-age=")!);
    });
    if (maxAge == 0) {
      return null;
    } else if (maxAge != null && maxAge > 0) {
      return header..[xYanoCacheMaxAgeHeader] = "$maxAge";
    }

    // Date + LastModified -> 0.1x Diff
    final lastModified = tryCatch(
      () => parseHttpDate(header[HttpHeaders.lastModifiedHeader]!),
    );
    final minDiff = Duration(minutes: 1);
    if (lastModified != null &&
        date != null &&
        date.subtract(minDiff).isAfter(lastModified)) {
      final xMaxAge = (date.difference(lastModified).inSeconds * 0.1).floor();
      return header..[xYanoCacheMaxAgeHeader] = "$xMaxAge";
    }

    return null;
  }
}
