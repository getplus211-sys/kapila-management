import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../utils/validation_utils.dart';
import '../utils/error_handler.dart';
import '../utils/app_constants.dart';

class ScheduleMessageScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String? initialMessage;

  const ScheduleMessageScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    this.initialMessage,
  });

  @override
  State<ScheduleMessageScreen> createState() => _ScheduleMessageScreenState();
}

class _ScheduleMessageScreenState extends State<ScheduleMessageScreen> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  bool _isSaving = false;
  List<Map<String, dynamic>> _scheduledMessages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      _messageController.text = widget.initialMessage!;
    }
    _loadScheduledMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadScheduledMessages() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

    final response = await _supabase
    .from('ngm_scheduled_messages')
    .select()
    .eq('chat_id', widget.chatId)
    .eq('sender_id', userId)
    .eq('is_sent', false)
    .order('scheduled_for', ascending: true);

      if (mounted) {
        setState(() {
          _scheduledMessages = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showError(context, ErrorHandler.handleError(e));
      }
    }
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (time != null && mounted) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _scheduleMessage() async {
    final message = _messageController.text.trim();
    
    if (!ValidationUtils.isValidMessage(message)) {
      ErrorHandler.showError(
        context,
        AppError('Please enter a valid message'),
      );
      return;
    }

    if (_selectedDateTime.isBefore(DateTime.now())) {
      ErrorHandler.showError(
        context,
        AppError('Please select a future date and time'),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw AppError('User not authenticated');

      await _supabase.from('ngm_scheduled_messages').insert({
      'chat_id': widget.chatId,
      'sender_id': userId,
      'user_id': userId,
      'content': ValidationUtils.sanitizeInput(message),
      'message_content': ValidationUtils.sanitizeInput(message),
      'message_type': 'text',
      'scheduled_time': _selectedDateTime.toIso8601String(),
      'scheduled_for': _selectedDateTime.toIso8601String(),
      'is_sent': false,
      'created_at': DateTime.now().toIso8601String(),
     });

      if (mounted) {
        _messageController.clear();
        ErrorHandler.showSuccess(context, 'Message scheduled successfully');
        await _loadScheduledMessages();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, ErrorHandler.handleError(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteScheduledMessage(String messageId) async {
    try {
      await _supabase
          .from('ngm_scheduled_messages')
            .delete().eq('schedule_id', messageId);

      if (mounted) {
        ErrorHandler.showSuccess(context, 'Scheduled message deleted');
        await _loadScheduledMessages();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, ErrorHandler.handleError(e));
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inDays == 0) {
      return 'Today at ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Tomorrow at ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Message'),
        backgroundColor: const Color(0xFFFF6F00),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Schedule new message section
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To: ${widget.chatName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Enter your message',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  maxLength: 5000,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _selectDateTime,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Schedule for',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDateTime(_selectedDateTime),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _scheduleMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6F00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Schedule Message'),
                  ),
                ),
              ],
            ),
          ),
          
          // Scheduled messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _scheduledMessages.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No scheduled messages',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _scheduledMessages.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final msg = _scheduledMessages[index];
                              final scheduledTime = DateTime.parse(
                                  msg['scheduled_time'] ?? msg['scheduled_for'],
                              );
                          
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFFF6F00),
                                child: Icon(
                                  Icons.schedule,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                msg['content'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _formatDateTime(scheduledTime),
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Message'),
                                      content: const Text(
                                        'Are you sure you want to delete this scheduled message?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    _deleteScheduledMessage(msg['message_id']);
                                  }
                                },
                              ),
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