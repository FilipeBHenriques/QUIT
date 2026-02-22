import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quit/usage_timer.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/hold_to_unblock_button.dart';
import '../widgets/neon_button.dart';
import '../widgets/neon_card.dart';
import '../widgets/neon_switch.dart';
import '../widgets/neon_text_field.dart';
import '../theme/neon_palette.dart';

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

  UsageTimer? _usageTimer;
  Timer? _pollTimer;

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
    _initializeTimer();
    _loadBlockedWebsites();

    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_usageTimer != null) {
        await _usageTimer!.reload();

        if (_usageTimer!.shouldReset()) {
          await _usageTimer!.resetTimer();
          await _syncVpnState();
        }

        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _customUrlController.dispose();
    super.dispose();
  }

  Future<void> _initializeTimer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _usageTimer = UsageTimer(prefs);
    await _usageTimer!.checkAndResetIfNeeded();
  }

  Future<void> _loadBlockedWebsites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('blocked_websites') ?? [];
    setState(() {
      _blockedWebsites = list.toSet();
      _loading = false;
    });
  }

  Future<void> _syncVpnState() async {
    try {
      const platform = MethodChannel('com.quit.app/monitoring');
      await platform.invokeMethod('updateBlockedWebsites', {
        'blockedWebsites': _blockedWebsites.toList(),
      });
    } catch (e) {
      print('⚠️ Sync error: $e');
    }
  }

  Future<void> _toggleWebsite(String url, bool blocked) async {
    setState(() {
      if (blocked) {
        _blockedWebsites.add(url);
      } else {
        _blockedWebsites.remove(url);
      }
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocked_websites', _blockedWebsites.toList());

    await _syncVpnState();
  }

  Future<void> _addCustomWebsite() async {
    final url = _customUrlController.text.trim();
    if (url.isEmpty) return;

    if (!url.contains('.')) {
      _showError('Please enter a valid domain (e.g., example.com)');
      return;
    }

    final cleanUrl = url
        .replaceAll(RegExp(r'https?://'), '')
        .replaceAll('www.', '');

    await _toggleWebsite(cleanUrl, true);
    _customUrlController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Blocked $cleanUrl'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: NeonPalette.rose),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      decoration: BoxDecoration(gradient: NeonPalette.pageGlow),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: NeonCard(
              glowColor: NeonPalette.rose,
              padding: const EdgeInsets.all(16),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: NeonPalette.rose),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Strict Blocking Active',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: NeonPalette.text,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Websites are blocked after timer runs out.',
                          style: TextStyle(
                            fontSize: 12,
                            color: NeonPalette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: NeonCard(
              glowColor: const Color(0xFFEF4444),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Custom Website',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: NeonPalette.text,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: NeonTextField(
                          controller: _customUrlController,
                          placeholder: 'example.com',
                          leading: const Icon(
                            Icons.language_rounded,
                            color: NeonPalette.textMuted,
                          ),
                          onChanged: (_) {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      NeonButton(
                        onPressed: _addCustomWebsite,
                        text: 'Add',
                        color: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: ListView.separated(
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final category = _categories.keys.elementAt(index);
                final websites = _categories[category]!;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: NeonPalette.border),
                    borderRadius: BorderRadius.circular(12),
                    color: NeonPalette.surface,
                  ),
                  child: ExpansionTile(
                    collapsedIconColor: NeonPalette.textMuted,
                    iconColor: const Color(0xFFEF4444),
                    title: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: NeonPalette.text,
                      ),
                    ),
                    children: websites.map((website) {
                      final isBlocked = _blockedWebsites.contains(website.url);

                      return Column(
                        children: [
                          const Divider(height: 1, color: NeonPalette.border),
                          ListTile(
                            leading: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: NeonPalette.surfaceSoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                website.icon,
                                size: 16,
                                color: NeonPalette.text,
                              ),
                            ),
                            title: Text(
                              website.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: NeonPalette.text,
                              ),
                            ),
                            subtitle: Text(
                              website.url,
                              style: const TextStyle(
                                color: NeonPalette.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            trailing: isBlocked
                                ? HoldToUnblockButton(
                                    onUnblocked: () async {
                                      await _toggleWebsite(website.url, false);
                                    },
                                  )
                                : NeonSwitch(
                                    value: isBlocked,
                                    onChanged: (value) {
                                      _toggleWebsite(website.url, value);
                                    },
                                    activeColor: const Color(0xFFEF4444),
                                  ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class WebsiteItem {
  final String name;
  final String url;
  final IconData icon;

  WebsiteItem(this.name, this.url, this.icon);
}
