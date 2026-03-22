import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/neon_palette.dart';
import '../widgets/neon_switch.dart';
import '../widgets/hold_to_unblock_button.dart';

class WebsitesSelectionScreen extends StatefulWidget {
  const WebsitesSelectionScreen({super.key});

  @override
  State<WebsitesSelectionScreen> createState() =>
      _WebsitesSelectionScreenState();
}

class _WebsitesSelectionScreenState extends State<WebsitesSelectionScreen> {
  final TextEditingController _customUrlController = TextEditingController();
  Set<String> _blockedWebsites = {};
  List<String> _customUrls = [];
  bool _loading = true;
  String? _loadError;

  // Must NOT mutate this during build() — initialized in initState
  final Set<String> _expandedSections = {};

  static const Map<String, List<WebsiteItem>> _categories = {
    'Social Media': [
      WebsiteItem('Facebook', 'facebook.com', Icons.facebook),
      WebsiteItem('Instagram', 'instagram.com', Icons.camera_alt),
      WebsiteItem('Twitter / X', 'twitter.com', Icons.alternate_email),
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
    // Safe: happens before first build
    _expandedSections.add('Social Media');
    _loadData();
  }

  @override
  void dispose() {
    _customUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final websites = prefs.getStringList('blocked_websites') ?? [];
      final custom = prefs.getStringList('custom_website_urls') ?? [];
      if (!mounted) return;
      setState(() {
        _blockedWebsites = websites.toSet();
        _customUrls = custom;
        if (custom.isNotEmpty) _expandedSections.add('Custom');
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
    final raw = _customUrlController.text.trim();
    if (raw.isEmpty) return;

    if (!raw.contains('.')) {
      _showSnack('Enter a valid domain (e.g. example.com)', isError: true);
      return;
    }

    final cleanUrl = raw
        .replaceAll(RegExp(r'https?://'), '')
        .replaceAll('www.', '');

    if (_customUrls.contains(cleanUrl)) {
      _showSnack('$cleanUrl is already added', isError: true);
      return;
    }

    setState(() {
      _customUrls.add(cleanUrl);
      _expandedSections.add('Custom');
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_website_urls', _customUrls);

    await _toggleWebsite(cleanUrl, true);
    _customUrlController.clear();
    _showSnack('Added & blocked $cleanUrl');
  }

  Future<void> _removeCustomWebsite(String url) async {
    setState(() => _customUrls.remove(url));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_website_urls', _customUrls);
    await _toggleWebsite(url, false);
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: isError
            ? NeonPalette.rose.withValues(alpha: 0.95)
            : const Color(0xFF1A1C26),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.expand(
        child: Center(
          child: CircularProgressIndicator(
            color: NeonPalette.rose,
            strokeWidth: 1.5,
          ),
        ),
      );
    }

    if (_loadError != null) {
      return SizedBox.expand(
        child: Center(
          child: Text(
            _loadError!,
            style: const TextStyle(color: NeonPalette.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    // Build section list: static categories + custom if non-empty
    final allSections = <MapEntry<String, List<WebsiteItem>>>[
      ..._categories.entries,
      if (_customUrls.isNotEmpty)
        MapEntry(
          'Custom',
          _customUrls
              .map((url) => WebsiteItem(_urlToName(url), url, Icons.link))
              .toList(),
        ),
    ];

    return SizedBox.expand(
      child: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: NeonPalette.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: NeonPalette.rose.withValues(alpha: 0.18),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 13,
                  color: NeonPalette.rose.withValues(alpha: 0.70),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Blocked websites cannot be unblocked without holding.',
                    style: TextStyle(color: NeonPalette.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Custom URL input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: NeonPalette.surfaceSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: NeonPalette.border,
                        width: 0.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.link,
                          size: 14,
                          color: NeonPalette.textMuted.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _customUrlController,
                            style: const TextStyle(
                              color: NeonPalette.text,
                              fontSize: 13,
                            ),
                            cursorColor: NeonPalette.rose,
                            decoration: const InputDecoration(
                              hintText: 'example.com',
                              hintStyle: TextStyle(
                                color: NeonPalette.textMuted,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addCustomWebsite,
                  child: Container(
                    height: 46,
                    width: 68,
                    decoration: BoxDecoration(
                      color: NeonPalette.rose.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: NeonPalette.rose.withValues(alpha: 0.30),
                        width: 0.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'ADD',
                      style: TextStyle(
                        color: NeonPalette.rose,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Category sections
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: allSections.length,
              itemBuilder: (context, index) {
                final section = allSections[index];
                return _buildSection(
                  section.key,
                  section.value,
                  isCustom: section.key == 'Custom',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _urlToName(String url) {
    // Capitalize and strip TLD for display
    final parts = url.split('.');
    if (parts.isEmpty) return url;
    final name = parts.first;
    if (name.isEmpty) return url;
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }

  Widget _buildSection(
    String title,
    List<WebsiteItem> websites, {
    bool isCustom = false,
  }) {
    final isExpanded = _expandedSections.contains(title);
    final activeCount =
        websites.where((w) => _blockedWebsites.contains(w.url)).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: NeonPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? NeonPalette.rose.withValues(alpha: 0.20)
              : NeonPalette.border,
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Section header
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                if (isExpanded) {
                  _expandedSections.remove(title);
                } else {
                  _expandedSections.add(title);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: activeCount > 0
                            ? NeonPalette.rose
                            : NeonPalette.border,
                        boxShadow: activeCount > 0
                            ? [
                                BoxShadow(
                                  color:
                                      NeonPalette.rose.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: isExpanded
                              ? NeonPalette.text
                              : NeonPalette.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    if (activeCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: NeonPalette.rose.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: NeonPalette.rose.withValues(alpha: 0.28),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          '$activeCount',
                          style: const TextStyle(
                            color: NeonPalette.rose,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: NeonPalette.textMuted.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),

            if (isExpanded) ...[
              Container(height: 0.5, color: NeonPalette.border),
              ...websites.map(
                (w) => _buildWebsiteItem(w, isCustom: isCustom),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWebsiteItem(WebsiteItem website, {bool isCustom = false}) {
    final isBlocked = _blockedWebsites.contains(website.url);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: NeonPalette.border, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            Icon(
              website.icon,
              size: 15,
              color: isBlocked
                  ? NeonPalette.rose.withValues(alpha: 0.70)
                  : NeonPalette.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    website.name,
                    style: TextStyle(
                      color:
                          isBlocked ? NeonPalette.text : NeonPalette.textMuted,
                      fontSize: 13,
                      fontWeight:
                          isBlocked ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  Text(
                    website.url,
                    style: TextStyle(
                      color: NeonPalette.textMuted.withValues(alpha: 0.5),
                      fontSize: 10,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Action: hold to unblock when blocked, switch to block when not
            if (isBlocked)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HoldToUnblockButton(
                    onUnblocked: () async =>
                        _toggleWebsite(website.url, false),
                  ),
                  if (isCustom) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _removeCustomWebsite(website.url),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: NeonPalette.rose.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: NeonPalette.rose.withValues(alpha: 0.20),
                            width: 0.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close,
                          size: 13,
                          color: NeonPalette.rose.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ],
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NeonSwitch(
                    value: false,
                    activeColor: NeonPalette.rose,
                    onChanged: (_) => _toggleWebsite(website.url, true),
                  ),
                  if (isCustom) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _removeCustomWebsite(website.url),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: NeonPalette.surfaceSoft,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: NeonPalette.border,
                            width: 0.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close,
                          size: 13,
                          color: NeonPalette.textMuted.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          ],
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
