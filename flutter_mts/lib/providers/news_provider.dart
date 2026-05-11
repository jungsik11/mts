import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NewsArticle {
  final String title;
  final String description;
  final String link;
  final String pubDate;
  final String? imageUrl;

  NewsArticle({
    required this.title,
    required this.description,
    required this.link,
    required this.pubDate,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'link': link,
    'pubDate': pubDate,
    'imageUrl': imageUrl,
  };

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
    title: json['title'],
    description: json['description'],
    link: json['link'],
    pubDate: json['pubDate'],
    imageUrl: json['imageUrl'],
  );
}

class NewsProvider with ChangeNotifier {
  List<NewsArticle> _articles = [];
  List<NewsArticle> get articles => _articles;
  
  List<NewsArticle> _savedArticles = [];
  List<NewsArticle> get savedArticles => _savedArticles;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _showSavedOnly = false;
  bool get showSavedOnly => _showSavedOnly;

  final String _rssUrl = 'https://www.yna.co.kr/rss/economy.xml';

  NewsProvider() {
    _loadSavedArticles();
    fetchNews();
    Timer.periodic(const Duration(minutes: 5), (_) => fetchNews());
  }

  // 관심 뉴스 토글
  void toggleSaveArticle(NewsArticle article) {
    final index = _savedArticles.indexWhere((a) => a.link == article.link);
    if (index >= 0) {
      _savedArticles.removeAt(index);
    } else {
      _savedArticles.add(article);
    }
    _saveArticlesToPrefs();
    notifyListeners();
  }

  bool isSaved(String link) {
    return _savedArticles.any((a) => a.link == link);
  }

  void toggleShowSavedOnly() {
    _showSavedOnly = !_showSavedOnly;
    notifyListeners();
  }

  List<NewsArticle> get displayedArticles => _showSavedOnly ? _savedArticles : _articles;

  Future<void> _loadSavedArticles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('saved_news');
    if (savedData != null) {
      final List<dynamic> decoded = jsonDecode(savedData);
      _savedArticles = decoded.map((item) => NewsArticle.fromJson(item)).toList();
      notifyListeners();
    }
  }

  Future<void> _saveArticlesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_savedArticles.map((a) => a.toJson()).toList());
    await prefs.setString('saved_news', encoded);
  }

  List<NewsArticle> getArticlesForTicker(String ticker, String name) {
    final cleanTicker = ticker.split('_')[0].toLowerCase();
    final cleanName = name.toLowerCase();
    
    return _articles.where((article) {
      final title = article.title.toLowerCase();
      final desc = article.description.toLowerCase();
      return title.contains(cleanTicker) || title.contains(cleanName) || 
             desc.contains(cleanTicker) || desc.contains(cleanName);
    }).toList();
  }

  Future<void> fetchNews() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(_rssUrl));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');

        _articles = items.map((node) {
          final title = node.findElements('title').first.innerText;
          final link = node.findElements('link').first.innerText;
          final description = node.findElements('description').first.innerText;
          final pubDate = node.findElements('pubDate').first.innerText;
          
          return NewsArticle(
            title: _cleanTitle(title),
            description: _cleanDescription(description),
            link: link,
            pubDate: _formatDate(pubDate),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching news: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _cleanTitle(String title) {
    return title.replaceAll('<![CDATA[', '').replaceAll(']]>', '').trim();
  }

  String _cleanDescription(String desc) {
    String clean = desc.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '');
    clean = clean.replaceAll('<![CDATA[', '').replaceAll(']]>', '').trim();
    if (clean.length > 100) return '${clean.substring(0, 100)}...';
    return clean;
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split(' ');
      if (parts.length >= 5) {
        final time = parts[4].substring(0, 5);
        return time;
      }
    } catch (_) {}
    return dateStr;
  }
}
