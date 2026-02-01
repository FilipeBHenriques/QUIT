import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _vpnActive = false;
  bool _instantBlockMode = true;

  UsageTimer? _usageTimer;
  int _dailyLimitMinutes = 0;
  Timer? _pollTimer;

  final Map<String, List<WebsiteItem>> _categories = {
    'Social Media': [
      WebsiteItem('Facebook', 'facebook.com', Icons.facebook),
      WebsiteItem('Instagram', 'instagram.com', Icons.photo_camera),
      WebsiteItem('Twitter/X', 'twitter.com', Icons.tag),
      WebsiteItem('TikTok', 'tiktok.com', Icons.video_library),
      WebsiteItem('Snapchat', 'snapchat.com', Icons.camera_alt),
      WebsiteItem('Reddit', 'reddit.com', Icons.forum),
      WebsiteItem('LinkedIn', 'linkedin.com', Icons.business),
    ],
    'Streaming': [
      WebsiteItem('YouTube', 'youtube.com', Icons.play_circle),
      WebsiteItem('Netflix', 'netflix.com', Icons.live_tv),
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
      WebsiteItem('DraftKings', 'draftkings.com', Icons.sports),
      WebsiteItem('FanDuel', 'fanduel.com', Icons.sports),
    ],
    'Gaming': [
      WebsiteItem('Steam', 'steampowered.com', Icons.gamepad),
      WebsiteItem('Epic Games', 'epicgames.com', Icons.videogame_asset),
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
    if (mounted) {
      setState(() {
        _dailyLimitMinutes = (_usageTimer!.dailyLimitSeconds / 60).round();
      });
    }
  }

  Future<void> _loadBlockedWebsites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('blocked_websites') ?? [];
    final instantBlock = prefs.getBool('instant_block_websites') ?? true;

    setState(() {
      _blockedWebsites = list.toSet();
      _instantBlockMode = instantBlock;
      _loading = false;
    });

    // Check if VPN is already running (it should be from app launch)
    // If not, start it now
    print('📋 Loaded ${_blockedWebsites.length} blocked websites');
  }

  Future<void> _syncVpnState() async {
    // Determine if VPN should be running
    bool shouldRunVpn = false;

    if (_blockedWebsites.isEmpty) {
      shouldRunVpn = false;
    } else if (_instantBlockMode) {
      shouldRunVpn = true;
    } else if (_usageTimer != null) {
      // Timer mode: only run if no timer OR time ran out
      shouldRunVpn =
          _dailyLimitMinutes == 0 || _usageTimer!.remainingSeconds <= 0;
    }

    // Update MonitoringService
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

    print(
      '${blocked ? '🚫 Blocked' : '✅ Unblocked'}: $url (instant: $_instantBlockMode, vpn: $_vpnActive)',
    );
  }

  Future<void> _toggleInstantBlockMode(bool instant) async {
    setState(() {
      _instantBlockMode = instant;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('instant_block_websites', instant);

    await _syncVpnState();

    print('🔄 Instant block mode: ${instant ? "ON" : "OFF"}');
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
          content: Text('Added $cleanUrl to blocked list'),
          backgroundColor: Colors.redAccent,
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // VPN STATUS INDICATOR
        if (_vpnActive)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.green[900],
            child: Row(
              children: [
                const Icon(Icons.vpn_lock, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Website blocking active (${_blockedWebsites.length} sites)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // BLOCKING MODE SWITCH
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[900],
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Blocking Mode',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _instantBlockMode
                          ? 'Block immediately when selected'
                          : 'Block only when timer runs out',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _instantBlockMode,
                onChanged: _toggleInstantBlockMode,
                activeColor: Colors.redAccent,
                inactiveThumbColor: Colors.white,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white24),

        // CUSTOM URL INPUT
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[900],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Custom Website',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customUrlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'example.com',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: Colors.grey[850],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _addCustomWebsite(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _addCustomWebsite,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white24),

        // CATEGORIES
        Expanded(
          child: ListView.builder(
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories.keys.elementAt(index);
              final websites = _categories[category]!;

              return ExpansionTile(
                title: Text(
                  category,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                iconColor: Colors.white,
                collapsedIconColor: Colors.white70,
                children: websites.map((website) {
                  final isBlocked = _blockedWebsites.contains(website.url);

                  return ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(website.icon, color: Colors.white, size: 28),
                    ),
                    title: Text(
                      website.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      website.url,
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
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
                            activeColor: Colors.redAccent,
                            inactiveThumbColor: Colors.white,
                          ),
                  );
                }).toList(),
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
