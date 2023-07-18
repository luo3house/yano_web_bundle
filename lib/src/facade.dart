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

  final Map<Uri, (StreamSubscription, Function(BundleResponse raw))>
      _fetchCallbacks = {};

  Future<Bundle> fetch(
    Uri key, {
    Function(FetchStatus status)? onProgress,
  }) async {
    if (_fetchCallbacks[key] != null) {
      throw AlreadyFetchingError(key);
    }
    BundleResponse? rawBundle = await cacheProvider?.loadCache(key);
    final completer = Completer<Bundle>();
    onFetchCallback(BundleResponse raw) {
      cacheProvider?.saveCache(key, raw).catchError((_) {});
      if (decoder == null) {
        if (raw is Bundle) {
          completer.complete(raw as Bundle);
        } else {
          completer.completeError(NoDecoderAvailableError(key));
        }
        return;
      } else {
        decoder!
            .decode(raw)
            .then((bundle) => completer.complete(bundle))
            .catchError((err) => completer.completeError(err));
      }
    }

    final sub =
        fetcher.statusEvents().listen((stat) => onProgress?.call((stat)));

    if (rawBundle != null) {
      onFetchCallback(rawBundle);
    } else {
      _fetchCallbacks[key] = (sub, onFetchCallback);
      fetcher.fetch(key).then((raw) {
        final cb = _fetchCallbacks[key];
        _fetchCallbacks.remove(key);
        cb?.$1.cancel();
        cb?.$2.call(raw);
      });
    }
    return completer.future;
  }

  cancelFetch(Uri key) {
    final cb = _fetchCallbacks[key];
    cb?.$1.cancel();
    _fetchCallbacks.remove(key);
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
