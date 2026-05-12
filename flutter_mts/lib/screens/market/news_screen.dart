import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/news_provider.dart';
import '../../providers/settings_provider.dart';
import 'news_detail_screen.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final newsProvider = Provider.of<NewsProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);

    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        title: const Text('투자 인사이트', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(newsProvider.showSavedOnly ? Icons.bookmark : Icons.bookmark_border, 
              color: newsProvider.showSavedOnly ? settings.upColor : Colors.white),
            tooltip: '저장한 기사 보기',
            onPressed: () => newsProvider.toggleShowSavedOnly(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => newsProvider.fetchNews(),
          ),
        ],
      ),
      body: newsProvider.isLoading && newsProvider.displayedArticles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => newsProvider.fetchNews(),
              child: newsProvider.showSavedOnly && newsProvider.savedArticles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bookmark_border, size: 64, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 16),
                          const Text('저장된 기사가 없습니다.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: newsProvider.displayedArticles.length,
                      itemBuilder: (context, index) {
                        final article = newsProvider.displayedArticles[index];
                        return _buildNewsCard(context, article, primaryColor, newsProvider);
                      },
                    ),
            ),
    );
  }

  Widget _buildNewsCard(BuildContext context, NewsArticle article, Color primaryColor, NewsProvider newsProvider) {
    final isSaved = newsProvider.isSaved(article.link);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () => _viewNewsDetail(context, article),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '경제/금융',
                      style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    article.pubDate,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: isSaved ? primaryColor : Colors.grey,
                      size: 20,
                    ),
                    onPressed: () => newsProvider.toggleSaveArticle(article),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                article.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                article.description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '더 보기',
                    style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Icon(Icons.chevron_right, color: primaryColor, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewNewsDetail(BuildContext context, NewsArticle article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsDetailScreen(url: article.link, title: article.title),
      ),
    );
  }
}
