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
  var progress = 0;
  Bundle? bundle;

  BundleFacade get facade => widget.facade;
  Uri get url => widget.url;

  handleProgress(FetchStatus status) {
    setState(() {
      progress = ((status.current.toDouble() / status.maxLength) * 100).floor();
    });
  }

  close() {
    facade.cancelFetch(url);
    if (bundle != null) facade.stopServe(bundle!);
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
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Error"),
            content: Text("Error fetch bundle: $err"),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${ModalRoute.of(context)?.settings.name}")),
      body: ValueListenableBuilder(
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
    );
  }
}
