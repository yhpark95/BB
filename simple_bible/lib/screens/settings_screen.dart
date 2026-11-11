import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../app_version.dart';
import '../widgets/donation_sheet.dart';
import '../widgets/reader_bar.dart';

/// Settings kept deliberately short: text size, text weight, screen theme.
/// Anything that could be discovered by using the reader itself is not here.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Text('설정',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _sectionHeader(context, '글자'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: FontSizeStepper(),
              ),
              const SizedBox(height: 8),
              Consumer<SettingsService>(
                builder: (context, settings, _) => SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  value: settings.boldText,
                  onChanged: settings.setBoldText,
                  title: const Text('글자를 굵게',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                  subtitle: const Text('글자가 흐릿하게 보일 때 켜세요'),
                ),
              ),

              const Divider(height: 32),
              _sectionHeader(context, '간격'),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: SpacingSteppers(),
              ),
              _sectionHeader(context, '화면'),
              Consumer<SettingsService>(
                builder: (context, settings, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<ThemeMode>(
                        style: SegmentedButton.styleFrom(
                          minimumSize: const Size(0, 56),
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('밝게'),
                            icon: Icon(Icons.light_mode),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('어둡게'),
                            icon: Icon(Icons.dark_mode),
                          ),
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('자동'),
                            icon: Icon(Icons.brightness_auto),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (selection) =>
                            settings.setThemeMode(selection.first),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '"자동"은 휴대폰 설정을 따라가요',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 32),
              _sectionHeader(context, '번역본'),
              Consumer<SettingsService>(
                builder: (context, settings, _) => ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: const Icon(Icons.translate, size: 28),
                  title: const Text('읽을 번역본 고르기',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                  subtitle: Text(_translationSummary(settings)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showTranslationSheet(context),
                ),
              ),

              const Divider(height: 32),
              _sectionHeader(context, '이 앱에 대하여'),
              const ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Icon(Icons.info_outline, size: 26),
                title: Text('버전', style: TextStyle(fontSize: 16)),
                // Hardcoded, and it sat at 1.0.0 while the builds went to
                // 1.6 — which made "which build is on the phone?" an
                // unanswerable question during testing.
                subtitle: Text(kAppVersion),
              ),
              const ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Icon(Icons.book, size: 26),
                title: Text('실려 있는 번역본', style: TextStyle(fontSize: 16)),
                subtitle: Text(
                    '개역한글 (한국어) · KJV (영어) · Louis Segond 1910 (프랑스어)'),
              ),

              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: const Icon(Icons.favorite_border, size: 26),
                title: const Text('개발자 후원하기',
                    style: TextStyle(fontSize: 16)),
                subtitle: const Text('마음이 있을 때만, 안 해도 괜찮아요'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDonationSheet(context),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.privacy_tip_outlined,
                          size: 32,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '광고 없음 · 로그인 없음',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '인터넷 없이도 읽을 수 있어요.\n'
                          '읽던 곳과 북마크는 이 휴대폰에 저장돼요.\n'
                          "휴대폰을 바꿀 땐 북마크 화면의 '옮기기'를 쓰세요.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _translationSummary(SettingsService settings) {
    const names = {2: '개역한글', 1: 'KJV', 3: 'Louis Segond'};
    return settings.selectedTranslationIds
        .map((id) => names[id] ?? '$id')
        .join(' + ');
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
