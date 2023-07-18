import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:yano_web_bundle/yano_web_bundle.dart';

class FacadeScreen extends StatefulWidget {
  final BundleFacade facade;
  final Uri url;
  const FacadeScreen(this.facade, this.url, {super.key});

  @override
  State<StatefulWidget> createState() {
    return FacadeScreenState();
  }
}

class FacadeScreenState extends State<FacadeScreen> {
  final controllerValue = ValueNotifier<WebViewController?>(null);
  final cacheSizeValue = ValueNotifier<int?>(null);
  var progress = 0;
  Bundle? bundle;

  BundleFacade get facade => widget.facade;
  Uri get url => widget.url;

  handleProgress(FetchStatus status) {
    if (mounted) {
      setState(() {
        progress = status.maxLength == 0
            ? 0
            : ((status.current.toDouble() / status.maxLength) * 100).floor();
      });
    }
  }

  fetchCacheSize() {
    cacheSizeValue.value = null;
    facade.getCacheSize().then((size) => cacheSizeValue.value = size);
  }

  clearCache() {
    facade.clearCache().then((_) => fetchCacheSize());
  }

  viewCache() {
    fetchCacheSize();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("View Cache"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ValueListenableBuilder(
                  valueListenable: cacheSizeValue,
                  builder: (_, size, __) {
                    if (size != null) {
                      final kB = (size.toDouble() / 1024).toStringAsFixed(2);
                      return Text("$kB KB");
                    } else {
                      return const Text("Calculating");
                    }
                  },
                ),
                IconButton(
                  onPressed: fetchCacheSize,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              ElevatedButton(
                onPressed: clearCache,
                child: const Text("Clear"),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      facade.fetch(url, onProgress: handleProgress).then((bundle) async {
        this.bundle = bundle;
        await facade.serve(bundle, InternetAddress.loopbackIPv4);
        final url =
            "http://localhost:${facade.getServingPort(bundle)}/index.html";
        controllerValue.value = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadRequest(Uri.parse(url));
      }).catchError((err) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Error"),
              content: Text("Error fetch bundle: $err"),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    facade.cancelFetch(url);
    if (bundle != null) facade.stopServe(bundle!);
    bundle?.close();
    bundle = null;
    controllerValue.dispose();
    cacheSizeValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${ModalRoute.of(context)?.settings.name}")),
      body: Stack(
        children: [
          ValueListenableBuilder(
            valueListenable: controllerValue,
            builder: (_, controller, __) {
              if (controller == null) {
                return Container(
                  color: Colors.white,
                  child: Center(child: Text("$progress %")),
                );
              } else {
                return WebViewWidget(
                  key: ObjectKey(controller),
                  controller: controller,
                );
              }
            },
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: facade.cacheProvider != null
                ? ElevatedButton(
                    onPressed: viewCache,
                    child: const Text("Cache"),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}
