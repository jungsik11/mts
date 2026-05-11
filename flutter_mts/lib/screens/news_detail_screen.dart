import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class NewsDetailScreen extends StatefulWidget {
  final String url;
  final String title;

  const NewsDetailScreen({super.key, required this.url, required this.title});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;
  Timer? _loadingTimeout;

  @override
  void initState() {
    super.initState();
    _initController();
    _startTimeout();
  }

  void _initController() {
    final cleanUrl = widget.url.trim();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F111A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _progress = progress / 100.0;
              });
            }
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            _loadingTimeout?.cancel();
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            debugPrint('WebView Error: ${error.description}');
            // Even on error, we might want to hide the loader to show the error page
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(cleanUrl));
  }

  void _startTimeout() {
    // 10초 후에도 로딩이 안 끝나면 강제로 로딩바 제거
    _loadingTimeout = Timer(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    super.dispose();
  }

  Future<void> _launchInBrowser() async {
    final Uri url = Uri.parse(widget.url.trim());
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('브라우저를 열 수 없습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF0F111A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser, size: 22),
            tooltip: '브라우저에서 열기',
            onPressed: _launchInBrowser,
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: Colors.transparent,
                color: const Color(0xFF2D5AF7),
                minHeight: 3,
              ),
            ),
          if (_isLoading && _progress == 0)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF2D5AF7)),
            ),
        ],
      ),
    );
  }
}
