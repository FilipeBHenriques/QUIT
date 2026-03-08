import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/neon_palette.dart';
import '../widgets/neon_button.dart';
import '../widgets/neon_card.dart';
import '../widgets/neon_switch.dart';

class WebsitesSelectionScreen extends StatefulWidget {
  const WebsitesSelectionScreen({super.key});

  @override
  State<WebsitesSelectionScreen> createState() =>
      _WebsitesSelectionScreenState();
}

class _WebsitesSelectionScreenState extends State<WebsitesSelectionScreen> {
  final TextEditingController _customUrlController = TextEditingController();
  Set<String> _blockedWebsites = {};
  bool _loading = true;
  String? _loadError;
  final Set<String> _expandedSections = <String>{};

  final Map<String, List<WebsiteItem>> _categories = {
    'Social Media': [
      WebsiteItem('Facebook', 'facebook.com', Icons.facebook),
      WebsiteItem('Instagram', 'instagram.com', Icons.camera_alt),
      WebsiteItem('Twitter/X', 'twitter.com', Icons.alternate_email),
      WebsiteItem('TikTok', 'tiktok.com', Icons.music_note),
      WebsiteItem('Snapchat', 'snapchat.com', Icons.snapchat),
      WebsiteItem('Reddit', 'reddit.com', Icons.reddit),
      WebsiteItem('LinkedIn', 'linkedin.com', Icons.work),
    ],
    'Streaming': [
      WebsiteItem('YouTube', 'youtube.com', Icons.play_circle),
      WebsiteItem('Netflix', 'netflix.com', Icons.tv),
      WebsiteItem('Twitch', 'twitch.tv', Icons.videogame_asset),
      WebsiteItem('Disney+', 'disneyplus.com', Icons.movie),
    ],
    'Adult Content': [
      WebsiteItem('Adult Sites Filter', '*.xxx', Icons.block),
      WebsiteItem('Pornhub', 'pornhub.com', Icons.block),
      WebsiteItem('xVideos', 'xvideos.com', Icons.block),
      WebsiteItem('xHamster', 'xhamster.com', Icons.block),
      WebsiteItem('OnlyFans', 'onlyfans.com', Icons.block),
    ],
    'Gambling': [
      WebsiteItem('Bet365', 'bet365.com', Icons.casino),
      WebsiteItem('PokerStars', 'pokerstars.com', Icons.casino),
      WebsiteItem('DraftKings', 'draftkings.com', Icons.casino),
      WebsiteItem('FanDuel', 'fanduel.com', Icons.casino),
    ],
    'Gaming': [
      WebsiteItem('Steam', 'steampowered.com', Icons.games),
      WebsiteItem('Epic Games', 'epicgames.com', Icons.games),
      WebsiteItem('Roblox', 'roblox.com', Icons.games),
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadBlockedWebsites();
  }

  @override
  void dispose() {
    _customUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadBlockedWebsites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('blocked_websites') ?? [];
      if (!mounted) return;
      setState(() {
        _blockedWebsites = list.toSet();
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Failed to load websites';
      });
    }
  }

  Future<void> _syncBlockedWebsites() async {
    const platform = MethodChannel('com.quit.app/monitoring');
    await platform.invokeMethod('updateBlockedWebsites', {
      'blockedWebsites': _blockedWebsites.toList(),
    });
  }

  Future<void> _toggleWebsite(String url, bool blocked) async {
    setState(() {
      if (blocked) {
        _blockedWebsites.add(url);
      } else {
        _blockedWebsites.remove(url);
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocked_websites', _blockedWebsites.toList());
    await _syncBlockedWebsites();
  }

  Future<void> _addCustomWebsite() async {
    final url = _customUrlController.text.trim();
    if (url.isEmpty) return;

    if (!url.contains('.')) {
      _showSnack('Please enter a valid domain (example.com)', isError: true);
      return;
    }

    final cleanUrl = url
        .replaceAll(RegExp(r'https?://'), '')
        .replaceAll('www.', '');

    await _toggleWebsite(cleanUrl, true);
    _customUrlController.clear();
    _showSnack('Blocked $cleanUrl');
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? NeonPalette.rose : const Color(0xFFEF4444),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.expand(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return SizedBox.expand(
        child: Center(
          child: Text(
            _loadError!,
            style: const TextStyle(color: NeonPalette.text),
          ),
        ),
      );
    }

    final sections = _categories.entries.toList();
    if (_expandedSections.isEmpty && sections.isNotEmpty) {
      _expandedSections.add(sections.first.key);
    }

    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(gradient: NeonPalette.pageGlow),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: NeonCard(
                glowColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.all(14),
                child: const Text(
                  'Websites are blocked instantly when selected.',
                  style: TextStyle(color: NeonPalette.textMuted, fontSize: 12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF374151)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _customUrlController,
                        style: const TextStyle(color: NeonPalette.text),
                        cursorColor: const Color(0xFFEF4444),
                        decoration: const InputDecoration(
                          hintText: 'example.com',
                          hintStyle: TextStyle(color: NeonPalette.textMuted),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 84,
                    child: NeonButton(
                      onPressed: _addCustomWebsite,
                      text: 'Add',
                      color: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      borderRadius: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: sections.length,
                itemBuilder: (context, index) {
                  final section = sections[index];
                  return _buildSection(section.key, section.value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<WebsiteItem> websites) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeonCard(
        glowColor: const Color(0xFFEF4444),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey<String>('website_section_$title'),
            iconColor: NeonPalette.textMuted,
            collapsedIconColor: NeonPalette.textMuted,
            initiallyExpanded: _expandedSections.contains(title),
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  _expandedSections.add(title);
                } else {
                  _expandedSections.remove(title);
                }
              });
            },
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            childrenPadding: EdgeInsets.zero,
            title: Text(
              title,
              style: const TextStyle(
                color: NeonPalette.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            children: websites.map((website) {
              final isBlocked = _blockedWebsites.contains(website.url);
              return ListTile(
                dense: true,
                leading: Icon(
                  website.icon,
                  color: NeonPalette.textMuted,
                  size: 18,
                ),
                title: Text(
                  website.name,
                  style: const TextStyle(
                    color: NeonPalette.text,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  website.url,
                  style: const TextStyle(
                    color: NeonPalette.textMuted,
                    fontSize: 11,
                  ),
                ),
                trailing: NeonSwitch(
                  value: isBlocked,
                  activeColor: const Color(0xFFEF4444),
                  onChanged: (value) => _toggleWebsite(website.url, value),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class WebsiteItem {
  final String name;
  final String url;
  final IconData icon;

  const WebsiteItem(this.name, this.url, this.icon);
}
