import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lovenest/config/supabase_config.dart';
import 'package:lovenest/services/farm_repository.dart';
import 'package:lovenest/services/couple_link_service.dart';
import 'package:lovenest/main.dart' show FarmLoader; // navigate to loader on success

class LinkPartnerScreen extends StatefulWidget {
  final String? prefillCode;
  const LinkPartnerScreen({super.key, this.prefillCode});

  @override
  State<LinkPartnerScreen> createState() => _LinkPartnerScreenState();
}

class _LinkPartnerScreenState extends State<LinkPartnerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _codeController = TextEditingController();
  final _service = CoupleLinkService();
  Map<String, dynamic>? _activeInvite; // inviter's invite data
  bool _loadingInvite = false;
  bool _creating = false;
  bool _redeeming = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.prefillCode != null && widget.prefillCode!.isNotEmpty) {
      _codeController.text = widget.prefillCode!;
      _lookupInvite(widget.prefillCode!);
      _tabController.index = 1;
    }
    _startCouplePoll();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _tabController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startCouplePoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      final couple = await _service.getCurrentUserCouple();
      if (couple != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FarmLoader()),
        );
      }
    });
  }

  Future<void> _generateInvite() async {
    setState(() => _creating = true);
    try {
      final res = await _service.createInvite();
      setState(() => _activeInvite = res);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _cancelInvite() async {
    try {
      await _service.cancelInvite();
      setState(() => _activeInvite = null);
    } catch (e) {
      _showSnack('Failed to cancel invite');
    }
  }

  Future<void> _lookupInvite(String code) async {
    setState(() => _loadingInvite = true);
    try {
      await _service.getInviteByCode(code);
      // No-op for now; RLS allows prefill but we keep UI simple
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingInvite = false);
    }
  }

  Future<void> _accept() async {
    final code = _codeController.text.trim();
    if (code.length < 6) return _showSnack('Enter a valid code');
    setState(() => _redeeming = true);
    try {
      final coupleId = await _service.redeem(code);
      // After a successful couple creation, connect farms (inviter = user1, invitee = current)
      final client = SupabaseConfig.client;
      final currentUserId = SupabaseConfig.currentUserId;
      if (currentUserId != null) {
        final couple = await client
            .from('couples')
            .select('user1_id, user2_id')
            .eq('id', coupleId)
            .single();
        final inviterId = couple['user1_id'] as String;
        final inviteeId = couple['user2_id'] as String;
        await FarmRepository().connectToPartnerFarm(inviterId: inviterId, inviteeId: inviteeId);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const FarmLoader()),
      );
    } catch (e) {
      _showSnack(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  Future<void> _decline() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    try {
      await _service.decline(code);
      _showSnack('Invite declined');
    } catch (_) {
      _showSnack('Failed to decline');
    }
  }

  Future<void> _unlink() async {
    try {
      await _service.unlink();
      final uid = SupabaseConfig.currentUserId;
      if (uid != null) {
        await FarmRepository().splitFarmForUser(uid);
      }
      _showSnack('Unlinked');
    } catch (_) {
      _showSnack('Failed to unlink');
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('Invalid or expired')) return 'Invalid or expired invite code';
    if (msg.contains('already linked')) return 'You are already linked to a partner';
    if (msg.contains('own invite')) return 'You cannot accept your own invite';
    return 'Something went wrong';
    }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 64,
        title: const Text(
          'Link Your Partner',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Colors.white,
            letterSpacing: 1.0,
            fontFamily: 'monospace',
            shadows: [
              Shadow(offset: Offset(0, 2), blurRadius: 0, color: Colors.black26),
            ],
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFB6C1), // Light pink (matches onboarding)
                Color(0xFFFFC0CB), // Pink
              ],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFC0CB),
                  Color(0xFFFFB6C1),
                ],
              ),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontFamily: 'monospace'),
              indicator: BoxDecoration(
                color: const Color(0xFFE91E63).withOpacity(0.9),
                borderRadius: BorderRadius.zero,
                border: const Border(
                  top: BorderSide(color: Color(0xFFAD1457), width: 2),
                  bottom: BorderSide(color: Color(0xFFAD1457), width: 2),
                ),
              ),
              tabs: const [
                Tab(text: 'Invite partner'),
                Tab(text: 'Have a code?'),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFB6C1), // Light pink (onboarding)
              Color(0xFFFFC0CB), // Pink
            ],
          ),
        ),
        child: Stack(
          children: [
            // subtle vignette
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.08), Colors.transparent, Colors.black.withOpacity(0.08)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6)),
                    ],
                    border: Border.all(color: const Color(0xFFE91E63), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.white.withOpacity(0.85),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildInviteTab(),
                          _buildCodeTab(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteTab() {
    final inviteCode = _activeInvite?['invite_code'] as String?;
    final expiresAt = _activeInvite?['expires_at']?.toString();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generate a code and share with your partner',
            style: TextStyle(
              color: const Color(0xFFE91E63),
              fontWeight: FontWeight.w700,
              fontSize: 18,
              fontFamily: 'monospace',
              shadows: const [Shadow(offset: Offset(0, 1), color: Colors.black26)],
            ),
          ),
          const SizedBox(height: 16),
          if (inviteCode == null) ...[
            SizedBox(
              width: 220,
              height: 44,
              child: ElevatedButton(
                onPressed: _creating ? null : _generateInvite,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFFAD1457), width: 2),
                  ),
                ),
                child: _creating
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Generate Invite'),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE91E63), width: 2),
              ),
              child: Row(
                children: [
                  const Text('Code:', style: TextStyle(color: Color(0xFF4A4A4A), fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  const SizedBox(width: 8),
                  SelectableText(
                    inviteCode,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF4A4A4A), fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 4),
            Text(
              'Expires: ${expiresAt ?? ''}',
              style: const TextStyle(color: Color(0xFF4A4A4A), fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () async {
                      final link = 'https://lovenest.app/invite?code=$inviteCode';
                      await Clipboard.setData(ClipboardData(text: '$link\nCode: $inviteCode'));
                      _showSnack('Invite link copied');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF64DD17),
                      foregroundColor: const Color(0xFF1B5E20),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                      ),
                    ),
                    child: const Text('Share Link'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 40,
                  child: TextButton(
                    onPressed: _cancelInvite,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFFE57373),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFFC62828), width: 2),
                      ),
                    ),
                    child: const Text('Cancel Invite'),
                  ),
                ),
              ],
            ),
          ],
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _unlink,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF90A4AE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFF546E7A), width: 2),
                ),
              ),
              child: const Text('Unlink current partner'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the invite code you received',
            style: TextStyle(
              color: const Color(0xFFE91E63),
              fontWeight: FontWeight.w700,
              fontSize: 18,
              fontFamily: 'monospace',
              shadows: const [Shadow(offset: Offset(0, 1), color: Colors.black26)],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: InputDecoration(
              labelText: 'Invite code',
              hintText: 'ABCDEFGH',
              labelStyle: const TextStyle(color: Color(0xFF4A4A4A), fontFamily: 'monospace'),
              hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontFamily: 'monospace'),
              filled: true,
              fillColor: Colors.white.withOpacity(0.95),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE91E63), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFAD1457), width: 2),
              ),
            ),
            onChanged: (v) {
              final upper = v.toUpperCase();
              if (v != upper) {
                _codeController.value = _codeController.value.copyWith(
                  text: upper,
                  selection: TextSelection.collapsed(offset: upper.length),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _redeeming ? null : _accept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF64DD17),
                    foregroundColor: const Color(0xFF1B5E20),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF2E7D32), width: 2),
                    ),
                  ),
                  child: _redeeming
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Accept'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 44,
                child: TextButton(
                  onPressed: _decline,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFFE57373),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFFC62828), width: 2),
                    ),
                  ),
                  child: const Text('Decline'),
                ),
              ),
            ],
          ),
          if (_loadingInvite) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}


