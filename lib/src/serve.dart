import 'dart:async';
import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'bundle.dart';

class BundleServeController {
  // match = leading, trailing spaces & quotes
  static final trimEdgeQuoteRE = RegExp("""^\\s*["']?|["']\\s*\$""");

  final Bundle bundle;
  BundleServeController(this.bundle);

  String eTag(DateTime lastModified, int contentLen) {
    return "${lastModified.millisecondsSinceEpoch}-$contentLen";
  }

  Map<String, String> documentHeader((String, DateTime, int) stat) {
    final m = <String, String>{
      HttpHeaders.dateHeader: formatHttpDate(DateTime.now()),
      HttpHeaders.contentLengthHeader: "${stat.$3}",
      HttpHeaders.etagHeader: eTag(stat.$2, stat.$3),
      HttpHeaders.lastModifiedHeader: formatHttpDate(stat.$2),
      HttpHeaders.serverHeader: "yano",
    };
    final contentType = lookupMimeType(stat.$1);
    if (contentType != null) m[HttpHeaders.contentTypeHeader] = contentType;

    return m;
  }

  Future<int?> handlePreCondition(Uri href, Map<String, String> header) async {
    final rpath = href.path.replaceAll(kBundleTrimLeadingSlashRE, "");
    final contentLength = await bundle.fileSize(rpath);
    final lastModified = await bundle.fileModified(rpath);
    final etag = eTag(lastModified, contentLength);
    String? value;

    // if-none-match: "etag1", "etag2", ...
    if ((value = header[HttpHeaders.ifNoneMatchHeader]) != null) {
      if (value!
          .split(",")
          .map((e) => e.replaceAll(trimEdgeQuoteRE, ""))
          .contains(etag)) {
        return HttpStatus.notModified;
      }
    }

    // if-modified-since
    if ((value = header[HttpHeaders.ifModifiedSinceHeader]) != null) {
      if (lastModified.isBefore(parseHttpDate(value!))) {
        return HttpStatus.notModified;
      }
    }

    return null;
  }

  Future<void> handleHEAD(
    Uri href,
    Map<String, String> header,
    Function(int code) writeStatus,
    Function(String k, String v) writeHeader,
  ) async {
    final rpath = href.path.replaceAll(kBundleTrimLeadingSlashRE, "");
    final lastModified = await bundle.fileModified(rpath);
    final contentLength = await bundle.fileSize(rpath);
    writeStatus(await handlePreCondition(href, header) ?? HttpStatus.ok);
    documentHeader((rpath, lastModified, contentLength)).forEach((key, value) {
      writeHeader(key, value);
    });
  }

  Future<void> handleGET(
    Uri href,
    Map<String, String> header,
    Function(int code) writeStatus,
    Function(String k, String v) writeHeader,
    StreamConsumer<List<int>> body,
  ) async {
    final rpath = href.path.replaceAll(kBundleTrimLeadingSlashRE, "");
    await handleHEAD(href, header, writeStatus, writeHeader);
    return bundle.openStream(rpath).then((stream) => stream.pipe(body));
  }
}
