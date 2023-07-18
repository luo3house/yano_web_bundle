import 'dart:io';

import 'package:yano_web_bundle/src/bundle.dart';

import '../fetch.dart';

class HttpFetcher extends StreamableFetcher {
  static final schemeRE = RegExp("^https?");

  final client = HttpClient();

  @override
  Future<BundleResponse> fetch(Uri bundleKey) {
    return client.getUrl(bundleKey).then((req) => req.close()).then((rsp) {
      var current = 0;
      final maxLength = rsp.contentLength;
      final headers = <String, String>{};
      rsp.headers.forEach((name, values) => headers[name] = values.join(', '));
      return rsp.fold(<int>[], (pre, cur) {
        pre.addAll(cur);
        current += cur.length;
        statusEventsController.add(FetchStatus(bundleKey, current, maxLength));
        return pre;
      }).then((bytes) => BundleResponse(headers, bytes));
    });
  }
}
