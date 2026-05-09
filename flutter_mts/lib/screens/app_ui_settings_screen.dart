import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class AppUISettingsScreen extends StatelessWidget {
  const AppUISettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('앱 설정', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionTitle('화면 테마'),
          _buildSettingsCard(context, [
            _buildThemeOption(
              context, 
              '다크 모드', 
              Icons.dark_mode_outlined, 
              settings.themeMode == ThemeMode.dark,
              () => settings.setThemeMode(ThemeMode.dark),
            ),
            _buildDivider(),
            _buildThemeOption(
              context, 
              '라이트 모드', 
              Icons.light_mode_outlined, 
              settings.themeMode == ThemeMode.light,
              () => settings.setThemeMode(ThemeMode.light),
            ),
            _buildDivider(),
            _buildThemeOption(
              context, 
              '시스템 설정', 
              Icons.settings_suggest_outlined, 
              settings.themeMode == ThemeMode.system,
              () => settings.setThemeMode(ThemeMode.system),
            ),
          ]),
          
          const SizedBox(height: 32),
          _buildSectionTitle('차트 및 색상'),
          _buildSettingsCard(context, [
            _buildOption(
              '차트 색상 테마',
              settings.chartColorMode == ChartColorMode.traditional ? '국내식 (빨강:상승)' : '해외식 (초록:상승)',
              Icons.palette_outlined,
              onTap: () => _showChartColorPicker(context, settings),
            ),
            _buildDivider(),
            _buildSwitchOption(
              '목록 간편 보기',
              '종목 리스트를 더 촘촘하게 표시합니다',
              Icons.view_headline_rounded,
              settings.isCompactMode,
              (val) => settings.toggleCompactMode(),
            ),
          ]),

          const SizedBox(height: 32),
          _buildSectionTitle('기타'),
          _buildSettingsCard(context, [
             _buildOption(
              '폰트 크기',
              settings.fontSizeFactor == 0.8 ? '작게' : (settings.fontSizeFactor == 1.2 ? '크게' : '보통'),
              Icons.text_fields_rounded,
              onTap: () => _showFontSizePicker(context, settings),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildThemeOption(BuildContext context, String title, IconData icon, bool isSelected, VoidCallback onTap) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Icon(icon, color: isSelected ? primaryColor : Colors.grey),
      title: Text(title, style: TextStyle(color: isSelected ? primaryColor : null, fontWeight: isSelected ? FontWeight.bold : null)),
      trailing: isSelected ? Icon(Icons.check_circle, color: primaryColor) : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildOption(String title, String value, IconData icon, {required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title, style: const TextStyle(color: Colors.white70)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: Color(0xFF2D5AF7), fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchOption(String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(title, style: const TextStyle(color: Colors.white70)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF2D5AF7),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.white.withOpacity(0.05), indent: 16, endIndent: 16);
  }

  void _showChartColorPicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).canvasColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('차트 색상 선택', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ListTile(
                title: const Text('국내 표준 (빨강: 상승, 파랑: 하락)'),
                trailing: settings.chartColorMode == ChartColorMode.traditional ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  settings.setChartColorMode(ChartColorMode.traditional);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('해외 표준 (초록: 상승, 빨강: 하락)'),
                trailing: settings.chartColorMode == ChartColorMode.modern ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  settings.setChartColorMode(ChartColorMode.modern);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showFontSizePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).canvasColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('폰트 크기 선택', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildFontSizeTile(context, '작게', 0.8, settings),
              _buildFontSizeTile(context, '보통 (기본)', 1.0, settings),
              _buildFontSizeTile(context, '크게', 1.2, settings),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFontSizeTile(BuildContext context, String label, double factor, SettingsProvider settings) {
    bool isSelected = settings.fontSizeFactor == factor;
    return ListTile(
      title: Text(label),
      trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).primaryColor) : null,
      onTap: () {
        settings.setFontSizeFactor(factor);
        Navigator.pop(context);
      },
    );
  }
}
