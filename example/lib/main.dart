import 'package:example/facade_screen.dart';
import 'package:example/facades.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.blueGrey,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
    ),
    routes: {
      "/": (context) => const BundleListScreen(),
      "/memory": (context) => FacadeScreen(kMemoryFacade, Uri.base),
      "/zip-asset": (context) => FacadeScreen(kZipAssetFacade, Uri.base),
      "/zip-http": (context) => FacadeScreen(
          kZipHttpFacade, Uri.parse("http://10.0.2.2:3000/dist.zip")),
    },
  ));
}

class BundleListScreen extends StatelessWidget {
  static final facadeRoutes = {
    "Memory": "/memory",
    "Zip Assets": "/zip-asset",
    "Zip Http Dist": "/zip-http",
  };

  const BundleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Yet Another Web Bundle")),
      body: GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 1,
        children: List.of(
          facadeRoutes.entries.map((e) {
            final label = e.key, to = e.value;
            return InkWell(
              onTap: () => Navigator.of(context).pushNamed(to),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.widgets),
                  const SizedBox(height: 5),
                  Text(label),
                ]),
              ),
            );
          }),
        ),
      ),
    );
  }
}
