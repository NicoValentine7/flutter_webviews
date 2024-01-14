import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }

  runApp(const ProviderScope(child: MaterialApp(home: App())));
}

final webViewProvider =
    StateNotifierProvider<WebViewStateNotifier, WebViewState>(
        (ref) => WebViewStateNotifier());

class WebViewStateNotifier extends StateNotifier<WebViewState> {
  InAppWebViewController? webViewController;
  WebViewStateNotifier() : super(const WebViewState());

  void setWebViewController(InAppWebViewController controller) {
    webViewController = controller;
  }

  void updateUrl(String url) {
    state = state.copyWith(url: url);
  }

  void updateProgress(double progress) {
    state = state.copyWith(progress: progress);
  }
}

@immutable
class WebViewState {
  final String url;
  final double progress;

  const WebViewState(
      {this.url = 'https://www.google.com', this.progress = 0.0});

  WebViewState copyWith({
    String? url,
    double? progress,
  }) {
    return WebViewState(
      url: url ?? this.url,
      progress: progress ?? this.progress,
    );
  }
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final webViewState = ref.watch(webViewProvider);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            UrlInputField(webViewState: webViewState, ref: ref),
            WebViewContainer(webViewState: webViewState, ref: ref),
          ],
        ),
      ),
    );
  }
}

class UrlInputField extends StatelessWidget {
  final WebViewState webViewState;
  final WidgetRef ref;

  UrlInputField({required this.webViewState, required this.ref});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(prefixIcon: Icon(Icons.search)),
      controller: TextEditingController(text: webViewState.url),
      keyboardType: TextInputType.url,
      onSubmitted: (value) {
        var url = Uri.parse(value);
        if (url.scheme.isEmpty) {
          url = Uri.parse("https://www.google.com/search?q=$value");
        }
        ref.read(webViewProvider.notifier).updateUrl(url.toString());
        ref.read(webViewProvider.notifier).webViewController?.loadUrl(
              urlRequest: URLRequest(url: WebUri(url.toString())),
            );
      },
    );
  }
}

class WebViewContainer extends StatelessWidget {
  final WebViewState webViewState;
  final WidgetRef ref;

  WebViewContainer({required this.webViewState, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(webViewState.url)),
            onWebViewCreated: (controller) async {
              ref
                  .read(webViewProvider.notifier)
                  .setWebViewController(controller);
              var url = await controller.getUrl();
              ref.read(webViewProvider.notifier).updateUrl(url.toString());
            },
            onLoadStart: (controller, url) async {
              var url = await controller.getUrl();
              ref.read(webViewProvider.notifier).updateUrl(url.toString());
            },
            onProgressChanged: (controller, progress) {
              ref.read(webViewProvider.notifier).updateProgress(progress / 100);
            },
            onUpdateVisitedHistory: (controller, url, androidIsReload) {
              ref.read(webViewProvider.notifier).updateUrl(url.toString());
            },
          ),
          webViewState.progress < 1.0
              ? LinearProgressIndicator(value: webViewState.progress)
              : Container(),
        ],
      ),
    );
  }
}

