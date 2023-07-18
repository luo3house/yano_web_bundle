import 'dart:async';

import 'bundle.dart';

abstract class Fetcher {
  Future<BundleResponse> fetch(Uri bundleKey);
  Stream<FetchStatus> statusEvents();

  static withFunction(Future<BundleResponse> Function(Uri bundleKey) fn) =>
      FetcherImpl(fn);
}

class FetchStatus {
  final Uri bundleKey;
  final int current;
  final int maxLength;
  FetchStatus(this.bundleKey, this.current, this.maxLength);
}

class FetcherImpl extends StreamableFetcher {
  Future<BundleResponse> Function(Uri bundleKey) fetchImpl;
  FetcherImpl(this.fetchImpl);

  @override
  Future<BundleResponse> fetch(Uri bundleKey) {
    statusEventsController.add(FetchStatus(bundleKey, 0, 1));
    return fetchImpl(bundleKey).then((rsp) {
      statusEventsController
          .add(FetchStatus(bundleKey, rsp.bytes.length, rsp.bytes.length));
      return rsp;
    });
  }
}

abstract class StreamableFetcher extends Fetcher {
  final _statusEventsController = StreamController<FetchStatus>.broadcast();

  // protected
  StreamController<FetchStatus> get statusEventsController =>
      _statusEventsController;

  @override
  Stream<FetchStatus> statusEvents() {
    return _statusEventsController.stream;
  }
}
