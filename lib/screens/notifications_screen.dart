import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../api/firebase_api.dart';
import '../constants.dart';
import 'login_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String _apiToken = '';

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _setupFCMListeners();
  }

  StreamSubscription<RemoteMessage>? _messageSubscription;

  void _setupFCMListeners() {
    // SYNC: Pag may pumasok na notification habang gamit ang app (Foreground),
    // automatic magre-refresh ang listahan.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (mounted) {
        // Trigger a background fetch
        _fetchNotifications().then((_) {
          // Force UI to rebuild once fetch is done
          if (mounted) setState(() {});
        });
      }
    });

    // LISTEN to taps on notifications (from Background or Terminated states handled by FirebaseApi)
    _messageSubscription = FirebaseApi.onMessageTapped.stream.listen((RemoteMessage message) {
      if (!mounted) return;
      
      // Parse the same way we do in the list
      final notifData = message.data;
      final String id = message.messageId ?? message.hashCode.toString();
      
      // We don't have created_at in standard push payload directly, 
      // but you can show the document details safely.
      _showDocumentDetails(notifData, id, null);
    });

    // Siguraduhin na updated ang token sa server
    FirebaseApi.syncToken();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    _apiToken = prefs.getString('api_token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/unread'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $_apiToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _notifications = data['data'];
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        _logout();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/$id/read'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $_apiToken',
        },
      );
      if (response.statusCode == 200) {
        setState(() => _notifications.removeWhere((n) => n['id'] == id));
      }
    } catch (e) {
      // Handle error gracefully if needed
    }
  }

  Future<void> _showLogoutConfirmation() async {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFECACA), width: 1),
                ),
                child: const Center(
                  child: Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 26),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Confirm Sign Out',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to log out of Document Management System? You will need to sign in again to receive push alerts.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Log Out',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
    try {
      await http.post(Uri.parse('$baseUrl/logout'), headers: {'Accept': 'application/json', 'Authorization': 'Bearer $_apiToken'});
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  // Parses timestamps like "2024-10-10T12:00:00Z"
  String _formatDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final parsed = DateTime.parse(dateStr).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final ampm = parsed.hour >= 12 ? 'PM' : 'AM';
      var hour = parsed.hour > 12 ? parsed.hour - 12 : parsed.hour;
      if (hour == 0) hour = 12;
      var minute = parsed.minute.toString().padLeft(2, '0');
      return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year} | $hour:$minute $ampm';
    } catch (e) {
      return dateStr;
    }
  }

  // Formats ugly snake_case keys into Title Case words
  String _formatKey(String key) {
    return key.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // Refetches detailed Document Data
  Future<Map<String, dynamic>?> _fetchDocumentDetails(String? docId) async {
    if (docId == null) return null;
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/documents/$docId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $_apiToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
    }
    return null;
  }

  // Opens a beautiful bottom sheet that parses out the document details
  void _showDocumentDetails(Map<String, dynamic> notifData, String notifId, String? createdAt) async {
    // Show loading dialog immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: const CircularProgressIndicator(color: primaryYellow)
        )
      )
    );

    // Call API for extra Document ID details if present
    final documentId = notifData['document_id']?.toString();
    final detailedDoc = await _fetchDocumentDetails(documentId);

    // Close loading indicator
    if (mounted) Navigator.pop(context);

    if (!mounted) return;

    // Use our fetched Details if it exists, otherwise fallback to standard notif data
    final displayData = detailedDoc ?? notifData;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85, 
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull Bar handle
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryYellow.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.description_outlined, color: primaryRed, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayData['document_number'] ?? 'Document Update',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayData['title'] ?? displayData['subject'] ?? notifData['title'] ?? 'New Notification',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),
                        if (createdAt != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                _formatDateString(detailedDoc != null ? detailedDoc['created_at'] : createdAt),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              const Divider(thickness: 1, height: 1),
              const SizedBox(height: 20),
              
              // Details Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Highlighting the main message (always use notif message for context)
                      if (notifData['message'] != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            notifData['message'],
                            style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      const Text(
                        'Document Information',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 12),
                      
                      // Dynamically Map the other displayData entries
                      ...displayData.entries
                        .where((e) => e.key != 'title' && e.key != 'message' && e.key != 'id' && e.key != 'document_id' && e.key != 'created_at' && e.value != null && e.value.toString().isNotEmpty)
                        .map((entry) {
                          // Special styling for status tags
                          Widget valueWidget = Text(
                            entry.value.toString(),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 14),
                          );

                          if (entry.key == 'status') {
                             valueWidget = Align(
                               alignment: Alignment.centerLeft,
                               child: Text(
                                 entry.value.toString().toUpperCase(),
                                 style: const TextStyle(
                                   color: Colors.black87,
                                   fontWeight: FontWeight.bold,
                                   fontSize: 14,
                                 ),
                               ),
                             );
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 140,
                                  child: Text(
                                    _formatKey(entry.key),
                                    style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500, fontSize: 14),
                                  ),
                                ),
                                Expanded(child: valueWidget),
                              ],
                            ),
                          );
                      }),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close bottomsheet
                        _markAsRead(notifId);   // Read Action
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Mark as Read', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            expandedHeight: 125.0,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: primaryDark,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 18, right: 20),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'NOTIFICATIONS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 18,
                    ),
                  ),
                  if (_notifications.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: accentSky.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentSky.withOpacity(0.45), width: 1),
                      ),
                      child: Text(
                        '${_notifications.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryDark, Color(0xFF1E1B4B), primaryIndigoDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Icon(
                        Icons.mark_email_read_rounded,
                        size: 190,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  tooltip: 'Refresh',
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _fetchNotifications();
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                  tooltip: 'Logout',
                  onPressed: _showLogoutConfirmation,
                ),
              ),
            ],
          ),
          // Loading State
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: primaryIndigo),
              ),
            )
          // Empty State
          else if (_notifications.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: primaryIndigo.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_rounded,
                        size: 64,
                        color: primaryIndigo,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'All Caught Up!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'No new document notifications at this time.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          // List
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final notif = _notifications[index];
                    final notifData = notif['data'] != null && notif['data'] is Map
                        ? Map<String, dynamic>.from(notif['data'])
                        : <String, dynamic>{};

                    final id = notif['id']?.toString() ?? '';
                    final createdAt = notif['created_at']?.toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showDocumentDetails(notifData, id, createdAt),
                            splashColor: primaryIndigo.withOpacity(0.08),
                            highlightColor: Colors.transparent,
                            child: Padding(
                              padding: const EdgeInsets.all(18.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Leading Icon Badge
                                  Container(
                                    height: 48,
                                    width: 48,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFC7D2FE), width: 1),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.description_rounded,
                                        color: primaryIndigoDark,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Body
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notifData['title'] ?? 'System Notification',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: Color(0xFF0F172A),
                                            letterSpacing: -0.2,
                                            height: 1.25,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          notifData['message'] ?? 'Tap to view document timeline and details',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        // Footer with timestamp
                                        if (createdAt != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.schedule_rounded,
                                                  size: 13,
                                                  color: Color(0xFF64748B),
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  _formatDateString(createdAt),
                                                  style: const TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Trailing chevron
                                  const Padding(
                                    padding: EdgeInsets.only(top: 14.0, left: 6.0),
                                    child: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Color(0xFFCBD5E1),
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _notifications.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
