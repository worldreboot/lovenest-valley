import 'package:flutter/material.dart';
import 'package:lovenest_valley/services/debug_log_service.dart';

/// Debug overlay widget that displays logs and errors
/// Useful for TestFlight builds where console logs aren't accessible
class DebugLogOverlay extends StatefulWidget {
  final Widget child;
  
  const DebugLogOverlay({
    super.key,
    required this.child,
  });

  @override
  State<DebugLogOverlay> createState() => _DebugLogOverlayState();
}

class _DebugLogOverlayState extends State<DebugLogOverlay> {
  bool _isVisible = false;
  final DebugLogService _logService = DebugLogService();
  
  @override
  void initState() {
    super.initState();
    _logService.addListener(_onLogUpdate);
  }
  
  @override
  void dispose() {
    _logService.removeListener(_onLogUpdate);
    super.dispose();
  }
  
  void _onLogUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Toggle button - tap top-right corner to show/hide
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isVisible = !_isVisible;
              });
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isVisible ? Colors.red : Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isVisible ? Icons.close : Icons.bug_report,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        // Debug panel
        if (_isVisible)
          Positioned.fill(
            child: Container(
              color: Colors.black87,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black,
                    child: Row(
                      children: [
                        const Text(
                          'Debug Logs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _isVisible = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  // Last error section
                  if (_logService.lastError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Colors.red.shade900,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LAST ERROR:',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _logService.lastError!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_logService.lastErrorTime != null)
                            Text(
                              'Time: ${_logService.lastErrorTime!.toString().substring(11, 19)}',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  // Logs list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _logService.logs.length,
                      itemBuilder: (context, index) {
                        final log = _logService.logs[index];
                        Color logColor;
                        switch (log.level) {
                          case LogLevel.info:
                            logColor = Colors.grey.shade300;
                            break;
                          case LogLevel.warning:
                            logColor = Colors.orange.shade300;
                            break;
                          case LogLevel.error:
                            logColor = Colors.red.shade300;
                            break;
                        }
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: log.level == LogLevel.error
                                ? Colors.red.shade900.withOpacity(0.3)
                                : Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: logColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  log.levelString,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log.message,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    Text(
                                      log.timestamp.toString().substring(11, 19),
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Footer with actions
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.black,
                    child: Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('Clear'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                          onPressed: () {
                            _logService.clearLogs();
                          },
                        ),
                        const Spacer(),
                        Text(
                          '${_logService.logs.length} logs',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

