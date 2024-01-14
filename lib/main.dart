import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_indicator/loading_indicator.dart';

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
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  UrlInputField({super.key, required this.webViewState, required this.ref}) {
    _controller.text = webViewState.url;
    _focusNode.addListener(_clearText);
  }

  void _clearText() {
    if (_focusNode.hasFocus) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(prefixIcon: Icon(Icons.search)),
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.url,
      onSubmitted: _handleSubmitted,
    );
  }

  void _handleSubmitted(String value) {
    var url = Uri.parse(value);
    if (_isValidUrl(url)) {
      _loadUrl(url.toString());
    } else {
      _searchGoogle(value);
    }
  }

  bool _isValidUrl(Uri url) {
    return url.scheme.isNotEmpty && url.host.isNotEmpty;
  }

  void _loadUrl(String url) {
    ref.read(webViewProvider.notifier).updateUrl(url);
    ref.read(webViewProvider.notifier).webViewController?.loadUrl(
          urlRequest: URLRequest(url: WebUri(url)),
        );
  }

  void _searchGoogle(String query) {
    var searchUrl =
        'https://www.google.com/search?q=${Uri.encodeComponent(query)}';
    _loadUrl(searchUrl);
  }
}

class WebViewContainer extends StatelessWidget {
  final WebViewState webViewState;
  final WidgetRef ref;

  const WebViewContainer(
      {super.key, required this.webViewState, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onHorizontalDragEnd: (DragEndDetails details) {
          if (details.primaryVelocity! > 0) {
            _goBack();
          } else if (details.primaryVelocity! < 0) {
            _goForward();
          }
        },
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(webViewState.url)),
              onWebViewCreated: _handleWebViewCreated,
              onLoadStart: _handleLoadStart,
              onProgressChanged: _handleProgressChanged,
              onUpdateVisitedHistory: _handleUpdateVisitedHistory,
            ),
            _buildProgressIndicator(),
          ],
        ),
      ),
    );
  }

  void _goBack() async {
    if (await ref
            .read(webViewProvider.notifier)
            .webViewController
            ?.canGoBack() ??
        false) {
      ref.read(webViewProvider.notifier).webViewController?.goBack();
    }
  }

  void _goForward() async {
    if (await ref
            .read(webViewProvider.notifier)
            .webViewController
            ?.canGoForward() ??
        false) {
      ref.read(webViewProvider.notifier).webViewController?.goForward();
    }
  }

  void _handleWebViewCreated(InAppWebViewController controller) async {
    ref.read(webViewProvider.notifier).setWebViewController(controller);
    var url = await controller.getUrl();
    ref.read(webViewProvider.notifier).updateUrl(url.toString());
  }

  void _handleLoadStart(InAppWebViewController controller, WebUri? url) async {
    var url = await controller.getUrl();
    ref.read(webViewProvider.notifier).updateUrl(url.toString());
  }

  void _handleProgressChanged(InAppWebViewController controller, int progress) {
    ref.read(webViewProvider.notifier).updateProgress(progress / 100);
  }

  void _handleUpdateVisitedHistory(
      InAppWebViewController controller, WebUri? url, bool? androidIsReload) {
    ref.read(webViewProvider.notifier).updateUrl(url.toString());
  }

  Widget _buildProgressIndicator() {
    return Center(
      child: SizedBox(
        width: 200, // ここで幅を設定します
        height: 200, // ここで高さを設定します
        child: webViewState.progress < 1.0
            ? const LoadingIndicator(
                indicatorType: Indicator.pacman,

                /// Optional, The color collections
                strokeWidth: 6,

                /// Optional, lineを含むウィジェットにのみ適用されます。
                // backgroundColor: Colors.black,

                /// Optional, Background of the widget
                pathBackgroundColor: Colors.black

                /// Optional, strokeの背景色
                )
            : Container(),
      ),
    );
  }
}
