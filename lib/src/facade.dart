import 'dart:async';
import 'dart:io';

import 'bundle.dart';
import 'cache.dart';
import 'fetch.dart';
import 'serve.dart';
import 'errors.dart';

class BundleFacade with BundleServer {
  static BundleFacade memory(Map<String, List<int>> files) {
    final fetcher = Fetcher.withFunction((_) async => MemoryBundle(files));
    return BundleFacade(fetcher);
  }

  final Fetcher fetcher;
  final CacheProvider? cacheProvider;
  final BundleDecoder? decoder;
  BundleFacade(this.fetcher, [this.decoder, this.cacheProvider]);

  final _fetchSubs = <Uri, StreamSubscription>{};

  Future<Bundle> fetch(
    Uri key, {
    Function(FetchStatus status)? onProgress,
  }) async {
    BundleResponse? rawBundle = await cacheProvider?.loadCache(key);
    // final completer = Completer<Bundle>();

    _fetchSubs[key] = fetcher.statusEvents().listen((stat) {
      if (stat.bundleKey == key) onProgress?.call((stat));
    });

    final fetching = rawBundle != null //
        ? Future.value(rawBundle)
        : fetcher.fetch(key);

    return fetching.then((raw) {
      cacheProvider?.saveCache(key, raw).catchError((_) {});
      if (decoder == null) {
        if (raw is Bundle) {
          return raw as Bundle;
        } else {
          throw NoDecoderAvailableError(key);
        }
      } else {
        return decoder!.decode(raw);
      }
    });
  }

  cancelFetch(Uri key) {
    fetcher.cancelFetch(key);
    _fetchSubs.remove(key)?.cancel();
  }

  Future<int> getCacheSize() async => await cacheProvider?.getCacheSize() ?? 0;

  Future<void> clearCache() async => cacheProvider?.clearCache();
}

mixin class BundleServer {
  final Map<Bundle, (int, HttpServer)> _servers = {};

  Future<void> serve(Bundle bundle, [InternetAddress? addr, int? port]) async {
    final exist = _servers[bundle];
    if (exist != null) {
      final (port, server) = exist;
      throw AlreadyServingError("${server.address.address}:$port");
    }
    final server =
        await HttpServer.bind(addr ?? InternetAddress.loopbackIPv4, port ?? 0);
    final serverPort = server.port;
    _servers[bundle] = (serverPort, server);
    server.autoCompress = true;

    final controller = BundleServeController(bundle);

    server.forEach((req) async {
      final header = <String, String>{};
      req.headers.forEach((name, values) => header[name] = values.join(";"));
      final rsp = req.response;
      final method = req.method.toLowerCase();
      try {
        if (method == 'head') {
          return await controller.handleHEAD(
            req.uri,
            header,
            (code) => rsp.statusCode = code,
            (k, v) => rsp.headers.set(k, v),
          );
        } else if (method == 'get') {
          return await controller.handleGET(
            req.uri,
            header,
            (code) => rsp.statusCode = code,
            (k, v) => rsp.headers.set(k, v),
            rsp,
          );
        } else {
          return Future.value();
        }
      } on FileNotFoundError {
        rsp.statusCode = HttpStatus.notFound;
      } catch (e) {
        rsp.statusCode = HttpStatus.internalServerError;
      } finally {
        rsp.close();
      }
    });
  }

  int? getServingPort(Bundle bundle) => _servers[bundle]?.$1;

  Future<void> stopServe(Bundle bundle) async {
    _servers[bundle]?.$2.close(force: true);
    _servers.remove(bundle);
  }
}
