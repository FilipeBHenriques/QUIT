import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:quit/usage_timer.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
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
          print('🔄 Reset detected');
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

    print('📋 Loaded ${_blockedWebsites.length} blocked websites');
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

    print('${blocked ? '🚫 Blocked' : '✅ Unblocked'}: $url');
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
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = shadcn.Theme.of(context); // Use Shadcn theme

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // BLOCKING INFO ALERT (Custom styled container)
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.1),
            border: Border.all(color: const Color(0xFFEF4444)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning, color: Color(0xFFEF4444)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Strict Blocking Active',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    Text(
                      'Websites are blocked after timer runs out.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // CUSTOM URL INPUT CARD
        shadcn.Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Custom Website',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customUrlController,
                        decoration: const InputDecoration(
                          hintText: 'example.com',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addCustomWebsite(),
                        style: TextStyle(color: theme.colorScheme.foreground),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // FIX: Replaced Shadcn PrimaryButton invalid prop with Material ElevatedButton
                    ElevatedButton(
                      onPressed: _addCustomWebsite,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // CATEGORIES
        Expanded(
          child: ListView.separated(
            itemCount: _categories.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final category = _categories.keys.elementAt(index);
              final websites = _categories[category]!;

              // Using ExpansionTile with shadcn styling concepts
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ExpansionTile(
                  title: Text(
                    category,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.foreground,
                    ),
                  ),
                  children: websites.map((website) {
                    final isBlocked = _blockedWebsites.contains(website.url);

                    return Column(
                      children: [
                        const Divider(height: 1),
                        ListTile(
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.muted,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              website.icon,
                              size: 16,
                              color: theme.colorScheme.foreground,
                            ),
                          ),
                          title: Text(
                            website.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            website.url,
                            style: TextStyle(
                              color: theme.colorScheme.mutedForeground,
                              fontSize: 11,
                            ),
                          ),
                          trailing: isBlocked
                              ? HoldToUnblockButton(
                                  onUnblocked: () async {
                                    await _toggleWebsite(website.url, false);
                                  },
                                )
                              : Switch(
                                  value: isBlocked,
                                  onChanged: (value) {
                                    _toggleWebsite(website.url, value);
                                  },
                                  activeThumbColor: const Color(0xFFEF4444),
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
    );
  }
}

class WebsiteItem {
  final String name;
  final String url;
  final IconData icon;

  WebsiteItem(this.name, this.url, this.icon);
}
