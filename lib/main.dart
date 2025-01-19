import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:shimmer/shimmer.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SearchAppsScreen(),
    );
  }
}

class SearchAppsScreen extends StatefulWidget {
  const SearchAppsScreen({super.key});

  @override
  State<SearchAppsScreen> createState() => _SearchAppsScreenState();
}

class _SearchAppsScreenState extends State<SearchAppsScreen>
    with WidgetsBindingObserver {
  late FocusNode focusNode;
  late List<AppInfo> searchResults;
  late TextEditingController controller;
  Completer<bool> completer = Completer<bool>();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    focusNode = FocusNode();
    controller = TextEditingController();
    // TODO: workaround: autoFocus doesn't show keyboard when app started.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), focusNode.requestFocus);
    });
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  // TODO: workaround: InstalledApps.startApp() future ignores confirmation dialog, and returns results before app is actually opened
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      completer.complete(true);
    } else if (state == AppLifecycleState.resumed) {
      completer = Completer<bool>();
      setState(() {});
    }
  }

  void closeApp() {
    FlutterExitApp.exitApp();
  }

  @override
  Widget build(BuildContext context) {
    const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
        mainAxisSpacing: 7,
        crossAxisSpacing: 7,
        mainAxisExtent: 70,
        crossAxisCount: 5);
    return SafeArea(
      child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: IconButton(
                      color: Colors.white70,
                      alignment: Alignment.centerRight,
                      icon: const Icon(Icons.close),
                      onPressed: closeApp,
                    ),
                  )
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SearchBar(
                    controller: controller,
                    trailing: [
                      IconButton(
                          onPressed: () {
                            controller.text = '';
                          },
                          icon: const Icon(Icons.remove_circle_outline))
                    ],
                    constraints:
                        const BoxConstraints(maxHeight: 50, minHeight: 50),
                    shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                    //onChanged: (_) => setState(() {}),
                    leading: const Icon(Icons.search),
                    focusNode: focusNode,
                    hintText: 'Название приложения..'),
              ),
              const SizedBox(
                height: 5,
              ),
              Expanded(
                child: FutureBuilder(
                    future: InstalledApps.getInstalledApps(true, true),
                    builder: (context, snapshot) {
                      final apps = snapshot.data;
                      if (apps == null) {
                        return const ShimmerGrid(gridDelegate: gridDelegate);
                      }
                      return ValueListenableBuilder(
                          valueListenable: controller,
                          builder: (context, value, _) {
                            return AppList(
                              appResumeCompleter: completer,
                              gridDelegate: gridDelegate,
                              initialApps: apps,
                              searchQuery: value.text,
                            );
                          });
                    }),
              )
            ],
          )),
    );
  }
}

class AppList extends StatefulWidget {
  final List<AppInfo> initialApps;
  final String searchQuery;
  final Completer<bool> appResumeCompleter;
  final SliverGridDelegateWithFixedCrossAxisCount gridDelegate;
  const AppList({
    super.key,
    required this.initialApps,
    required this.appResumeCompleter,
    required this.searchQuery,
    required this.gridDelegate,
  });

  @override
  State<AppList> createState() => _AppListState();
}

class _AppListState extends State<AppList> {
  late List<AppInfo> _apps;

  @override
  void initState() {
    _apps = widget.initialApps;
    super.initState();
  }

  void onPressApp(AppInfo app) async {
    final result = await InstalledApps.startApp(app.packageName);
    if (result ?? false) {
      await widget.appResumeCompleter.future;
      FlutterExitApp.exitApp();
    }
  }

  void onLongPressApp(AppInfo app) async {
    final result = await InstalledApps.uninstallApp(app.packageName);
    if (result ?? false) {
      setState(() {
        _apps.remove(app);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = widget.searchQuery.isEmpty
        ? _apps
        : _apps
            .where((info) => info.name
                .toLowerCase()
                .contains(widget.searchQuery.toLowerCase()))
            .toList();
    return GridView.builder(
        cacheExtent: 2000,
        padding: const EdgeInsets.all(15.0),
        gridDelegate: widget.gridDelegate,
        itemCount: searchResults.length,
        itemBuilder: (item, index) {
          final app = searchResults[index];
          final icon = app.icon;
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 5,
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                  child: GestureDetector(
                onTapUp: (_) => onPressApp(app),
                onLongPressUp: () => onLongPressApp(app),
                child: Column(
                  children: [
                    if (icon != null)
                      Container(
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(5)),
                          padding: const EdgeInsets.all(5),
                          height: 50,
                          width: 50,
                          child: Image.memory(icon)),
                    Text(
                      app.name,
                      style: const TextStyle(
                          color: Color.fromARGB(208, 255, 255, 255)),
                      overflow: TextOverflow.ellipsis,
                    )
                  ],
                ),
              )),
            ),
          );
        });
  }
}

class ShimmerWidget extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const ShimmerWidget(
      {super.key,
      required this.width,
      required this.height,
      required this.radius});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Shimmer.fromColors(
          baseColor: const Color.fromARGB(255, 106, 104, 104),
          highlightColor: const Color.fromARGB(255, 132, 128, 128),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: const Color.fromARGB(
                  255, 132, 128, 128), // Optional: Set a background color
            ),
          )),
    );
  }
}

class ShimmerGrid extends StatelessWidget {
  final SliverGridDelegateWithFixedCrossAxisCount gridDelegate;
  const ShimmerGrid({super.key, required this.gridDelegate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
          padding: const EdgeInsets.symmetric(vertical: 20),
          gridDelegate: gridDelegate,
          itemCount: 100,
          itemBuilder: (item, index) {
            return const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShimmerWidget(width: 50, height: 50, radius: 5),
                SizedBox(
                  height: 5,
                ),
                ShimmerWidget(width: 70, height: 10, radius: 5),
              ],
            );
          }),
    );
  }
}
