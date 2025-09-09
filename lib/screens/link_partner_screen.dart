import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lovenest_valley/config/supabase_config.dart';
import 'package:lovenest_valley/services/farm_repository.dart';
import 'package:lovenest_valley/services/couple_link_service.dart';
import 'package:lovenest_valley/main.dart' show FarmLoader; // navigate to loader on success

class LinkPartnerScreen extends StatefulWidget {
  final String? prefillCode;
  const LinkPartnerScreen({super.key, this.prefillCode});

  @override
  State<LinkPartnerScreen> createState() => _LinkPartnerScreenState();
}

class _LinkPartnerScreenState extends State<LinkPartnerScreen> {
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
    if (widget.prefillCode != null && widget.prefillCode!.isNotEmpty) {
      _codeController.text = widget.prefillCode!;
      _lookupInvite(widget.prefillCode!);
    }
    _startCouplePoll();
    
    // Automatically generate an invite code when the page loads
    // so users immediately see a code they can share with their partner
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateInvite();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
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
    if (code.length != 6) return _showSnack('Enter a valid 6-digit code');
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
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
            SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 20, // Account for safe area bottom
              ),
              child: Column(
                children: [
                  // Top Section: Invite your partner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5), // Light purple
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite your partner',
                          style: TextStyle(
                            color: const Color(0xFF6A1B9A), // Dark purple
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Your code:',
                              style: TextStyle(
                                color: const Color(0xFF424242), // Dark grey
                                fontSize: 16,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () async {
                                  if (_activeInvite?['invite_code'] != null) {
                                    final code = _activeInvite!['invite_code'] as String;
                                    await Clipboard.setData(ClipboardData(text: code));
                                    _showSnack('Code copied to clipboard!');
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE1BEE7), // Light purple
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF9C27B0), width: 1),
                                  ),
                                  child: Text(
                                    'Tap to copy',
                                    style: TextStyle(
                                      color: const Color(0xFF6A1B9A), // Dark purple
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      fontFamily: 'monospace',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_activeInvite?['invite_code'] != null) ...[
                          _buildCodeDisplay(_activeInvite!['invite_code'] as String),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () async {
                                final code = _activeInvite!['invite_code'] as String;
                                // final link = 'https://lovenest.app/invite?code=$code';
                                final shareText = 'Join me in Lovenest Valley! Use this invite code: $code';
                                await Share.share(shareText, subject: 'Lovenest Valley Invite');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9C27B0), // Vibrant purple
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Share Invite',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF9C27B0)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Generating your invite code...',
                                  style: TextStyle(
                                    color: const Color(0xFF666666),
                                    fontSize: 16,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 50), // Space for the "or" button
                  
                  // Bottom Section: Enter partner's code
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE4EC), // Light pink
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enter partner\'s code',
                          style: TextStyle(
                            color: const Color(0xFFC2185B), // Dark pink
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Partner\'s 6-digit code',
                          style: TextStyle(
                            color: const Color(0xFF424242), // Dark grey
                            fontSize: 16,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCodeInput(),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _redeeming ? null : _accept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF9C27B0), // Purple
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFFE1BEE7), width: 2),
                              ),
                            ),
                            child: _redeeming
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text(
                                    'Accept Partner\'s Code',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Centered "or" button positioned between the two sections
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE0E0E0), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'or',
                      style: TextStyle(
                        color: const Color(0xFF424242), // Dark grey
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
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

  Widget _buildCodeDisplay(String code) {
    // For 6-digit codes, we don't need hyphens - just display each digit
    final List<String> codeParts = code.split('');
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate box size based on available width
        final availableWidth = constraints.maxWidth;
        final totalBoxes = codeParts.length; // Should be 6
        final totalMargins = (totalBoxes - 1) * 1; // Minimal 1px margin between boxes
        
        // Ensure we don't exceed available width
        final maxBoxWidth = (availableWidth - totalMargins) / totalBoxes;
        
        // Use much smaller minimum size to fit within container
        final boxWidth = maxBoxWidth.clamp(12.0, 35.0); // Much smaller min and max
        final boxHeight = boxWidth * 1.2; // Slightly reduced aspect ratio
        
        // Use minimal margins to prevent overflow
        final actualMargin = boxWidth < 25 ? (boxWidth < 18 ? 0.0 : 0.5) : 2.0;
        
                          return Container(
           width: double.infinity,
           child: Row(
             mainAxisAlignment: MainAxisAlignment.center,
             mainAxisSize: MainAxisSize.min, // Don't expand beyond content
             children: codeParts.map((part) {
               return Container(
                 margin: EdgeInsets.symmetric(horizontal: actualMargin),
                 width: boxWidth,
                 height: boxHeight,
                 decoration: BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: const Color(0xFFE1BEE7), width: 2),
                   boxShadow: [
                     BoxShadow(
                       color: Colors.black.withOpacity(0.1),
                       blurRadius: 2,
                       offset: const Offset(0, 1),
                     ),
                   ],
                 ),
                 child: Center(
                   child: Text(
                     part,
                     style: TextStyle(
                       fontSize: (boxWidth * 0.45).clamp(10.0, 20.0), // Smaller font size for smaller boxes
                       fontWeight: FontWeight.w900,
                       color: const Color(0xFF9C27B0),
                       fontFamily: 'monospace',
                     ),
                     textAlign: TextAlign.center,
                   ),
                 ),
               );
             }).toList(),
           ),
         );
      },
    );
  }

  Widget _buildCodeInput() {
    // Create individual input boxes for 6-digit codes
    final int maxLength = 6;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate box size based on available width
        final availableWidth = constraints.maxWidth;
        final totalBoxes = maxLength; // 6 digits
        final totalMargins = (totalBoxes - 1) * 1; // Minimal 1px margin between boxes
        
        // Ensure we don't exceed available width
        final maxBoxWidth = (availableWidth - totalMargins) / totalBoxes;
        
        // Use much smaller minimum size to fit within container
        final boxWidth = maxBoxWidth.clamp(12.0, 35.0); // Much smaller min and max
        final boxHeight = boxWidth * 1.2; // Slightly reduced aspect ratio
        
        // Use minimal margins to prevent overflow
        final actualMargin = boxWidth < 25 ? (boxWidth < 18 ? 0.0 : 0.5) : 2.0;
        
        final List<Widget> inputBoxes = [];
        
        for (int i = 0; i < maxLength; i++) {
          inputBoxes.add(
            Container(
              margin: EdgeInsets.symmetric(horizontal: actualMargin),
              width: boxWidth,
              height: boxHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF8BBD9), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
                             child: Center(
                 child: Text(
                   _codeController.text.length > i ? _codeController.text[i] : '',
                   style: TextStyle(
                     fontSize: (boxWidth * 0.45).clamp(10.0, 20.0), // Smaller font size for smaller boxes
                     fontWeight: FontWeight.w900,
                     color: const Color(0xFFC2185B),
                     fontFamily: 'monospace',
                   ),
                   textAlign: TextAlign.center,
                 ),
               ),
            ),
          );
        }
        
                          return Stack(
           children: [
             Column(
               children: [
                 Container(
                   width: double.infinity,
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     mainAxisSize: MainAxisSize.min, // Don't expand beyond content
                     children: inputBoxes,
                   ),
                 ),
                 const SizedBox(height: 12),
               ],
             ),
             // Hidden text field for actual input - positioned over the visual boxes
             Positioned.fill(
               child: TextField(
                 controller: _codeController,
                 textCapitalization: TextCapitalization.characters,
                 inputFormatters: [
                   FilteringTextInputFormatter.allow(RegExp(r'[0-9]')), // Only allow digits for 6-digit codes
                   LengthLimitingTextInputFormatter(maxLength),
                 ],
                 onChanged: (v) {
                   // Ensure only digits are entered
                   final digitsOnly = v.replaceAll(RegExp(r'[^0-9]'), '');
                   if (v != digitsOnly) {
                     _codeController.value = _codeController.value.copyWith(
                       text: digitsOnly,
                       selection: TextSelection.collapsed(offset: digitsOnly.length),
                     );
                   }
                   setState(() {}); // Rebuild to show characters in boxes
                 },
                 decoration: const InputDecoration(
                   border: InputBorder.none,
                   counterText: '', // Hide character counter
                 ),
                 style: const TextStyle(
                   color: Colors.transparent, // Make text invisible
                   fontSize: 1, // Minimal size
                 ),
                 cursorColor: Colors.transparent, // Hide cursor
               ),
             ),
           ],
         );
      },
    );
  }
}


