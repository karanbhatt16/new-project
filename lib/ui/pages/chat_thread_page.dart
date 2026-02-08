import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../auth/app_user.dart';
import '../../call/voice_call_controller.dart';
import '../../chat/firestore_chat_controller.dart';
import '../../chat/e2ee_chat_controller.dart';
import '../../chat/firestore_chat_models.dart' show FirestoreChatThread, FirestoreMessage, CallMessageStatus, MessageStatus;
import '../../notifications/firestore_notifications_controller.dart';
import '../../posts/cloudinary_uploader.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../widgets/async_action.dart';
import 'reaction_row.dart';
import 'swipe_to_reply.dart';
import 'voice_call_page.dart';

class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.currentUser,
    required this.otherUser,
    required this.thread,
    required this.chat,
    required this.e2eeChat,
    required this.social,
    required this.notifications,
    required this.callController,
    this.isMatchChat = false,
  });

  final AppUser currentUser;
  final AppUser otherUser;
  final FirestoreChatThread thread;
  final FirestoreChatController chat;
  final E2eeChatController e2eeChat;
  final FirestoreSocialGraphController social;
  final FirestoreNotificationsController notifications;
  final VoiceCallController callController;
  final bool isMatchChat;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final hour12 = (h % 12 == 0) ? 12 : (h % 12);
    final ampm = h >= 12 ? 'PM' : 'AM';
    return '$hour12:$m $ampm';
  }

  /// Build tick marks widget based on message status
  /// - Single grey tick: sent
  /// - Double grey tick: delivered
  /// - Double blue tick: read
  Widget _buildMessageTicks(MessageStatus status, ThemeData theme) {
    const double iconSize = 14;
    final Color greyColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    const Color blueColor = Color(0xFF34B7F1); // WhatsApp blue

    switch (status) {
      case MessageStatus.sending:
        return Icon(
          Icons.access_time,
          size: iconSize,
          color: greyColor,
        );
      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: iconSize,
          color: greyColor,
        );
      case MessageStatus.delivered:
        return SizedBox(
          width: iconSize + 4,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                child: Icon(Icons.check, size: iconSize, color: greyColor),
              ),
              Positioned(
                left: 5,
                child: Icon(Icons.check, size: iconSize, color: greyColor),
              ),
            ],
          ),
        );
      case MessageStatus.read:
        return SizedBox(
          width: iconSize + 4,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                child: Icon(Icons.check, size: iconSize, color: blueColor),
              ),
              Positioned(
                left: 5,
                child: Icon(Icons.check, size: iconSize, color: blueColor),
              ),
            ],
          ),
        );
    }
  }

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showEmojiPicker = false;

  FirestoreMessage? _replyTo;

  /// Get display text for a message.
  /// Messages are already decrypted by the stream, so this is now simple.
  String _getDisplayText(FirestoreMessage m) {
    // Check deleted status first
    if (m.isDeletedFor(widget.currentUser.uid)) {
      return 'This message was deleted';
    }
    if (m.deletedForEveryone) {
      return 'This message was deleted';
    }

    // For call and voice messages, use the sync display
    if (m.isCallMessage || m.isVoiceMessage) {
      return widget.chat.displayText(m, forUid: widget.currentUser.uid);
    }

    // Messages are already decrypted by the stream
    if (m.text != null) {
      return m.text!;
    }

    // If still encrypted (decryption failed), show placeholder
    if (m.ciphertextB64 != null) {
      return '[Encrypted message]';
    }

    return '[Unsupported message]';
  }

  // Selection mode state
  bool _selectionMode = false;
  final Set<String> _selectedMessageIds = {};
  
  // For showing reaction picker above message
  final Map<String, GlobalKey> _messageKeys = {};
  OverlayEntry? _reactionOverlay;
  bool _showingFullEmojiPicker = false;

  // Voice recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  int _recordingDurationSeconds = 0;
  String? _recordingPath;

  // Voice message playback
  final Map<String, AudioPlayer> _audioPlayers = {};
  final Map<String, bool> _isPlaying = {};
  final Map<String, Duration> _playerPositions = {};
  final Map<String, Duration> _playerDurations = {};

  // Cloudinary uploader for voice messages
  final CloudinaryUploader _cloudinary = CloudinaryUploader(
    cloudName: 'dlouee0os',
    unsignedUploadPreset: 'vibeu_posts',
  );

  @override
  void initState() {
    super.initState();
    // Mark messages and notifications as read when chat is opened
    _markMessagesAsRead();
  }

  Future<void> _markMessagesAsRead() async {
    // First mark messages as delivered (grey double tick)
    await widget.chat.markMessagesAsDelivered(
      threadId: widget.thread.id,
      myUid: widget.currentUser.uid,
    );
    // Then mark as read (blue double tick)
    await widget.chat.markThreadAsRead(
      threadId: widget.thread.id,
      myUid: widget.currentUser.uid,
    );
    // Also mark notifications as read
    await widget.notifications.markMessageNotificationsRead(
      uid: widget.currentUser.uid,
      threadId: widget.thread.id,
    );
  }

  @override
  void dispose() {
    _removeReactionOverlay();
    _controller.dispose();
    _focusNode.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    for (final player in _audioPlayers.values) {
      player.dispose();
    }
    super.dispose();
  }
  
  void _removeReactionOverlay() {
    _reactionOverlay?.remove();
    _reactionOverlay = null;
  }
  
  GlobalKey _getMessageKey(String messageId) {
    return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
    setState(() => _showEmojiPicker = !_showEmojiPicker);
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji.emoji,
    );
    final newCursorPosition = selection.start + emoji.emoji.length;
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: newCursorPosition);
  }

  /// Determines if a date separator should be shown before this message.
  /// Shows separator for first message of each day.
  bool _shouldShowDateSeparator({
    required List<FirestoreMessage> messages,
    required int currentIndex,
  }) {
    if (currentIndex == 0) return true; // Always show for first message
    
    final currentMsg = messages[currentIndex];
    final previousMsg = messages[currentIndex - 1];
    
    final currentDate = DateTime(
      currentMsg.sentAt.year,
      currentMsg.sentAt.month,
      currentMsg.sentAt.day,
    );
    final previousDate = DateTime(
      previousMsg.sentAt.year,
      previousMsg.sentAt.month,
      previousMsg.sentAt.day,
    );
    
    return currentDate != previousDate;
  }

  /// Formats the date for the separator (Today, Yesterday, Monday, or full date).
  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(messageDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      // Show day name (Monday, Tuesday, etc.)
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days[date.weekday - 1];
    } else {
      // Show full date
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  /// Builds the date separator widget.
  Widget _buildDateSeparator(DateTime date, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _formatDateSeparator(date),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: widget.social.friendsStream(uid: widget.currentUser.uid),
      builder: (context, snap) {
        final friends = snap.data;
        if (friends == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final areFriends = friends.contains(widget.otherUser.uid);
        final isMatch = widget.isMatchChat;
        final canChat = areFriends || isMatch;

        final theme = Theme.of(context);
        final love = theme.colorScheme.secondary;
        final loveSoft = love.withValues(alpha: 0.14);

        return Scaffold(
          appBar: AppBar(
            leading: _selectionMode
                ? IconButton(
                    onPressed: _exitSelectionMode,
                    icon: const Icon(Icons.close),
                  )
                : null,
            title: _selectionMode
                ? Text('${_selectedMessageIds.length} selected')
                : Row(
                    children: [
                      if (isMatch) ...[
                        Icon(Icons.favorite, color: love),
                        const SizedBox(width: 8),
                      ],
                      Text(widget.otherUser.username),
                    ],
                  ),
            actions: [
              if (_selectionMode) ...[
                // Show reaction button only when exactly one message is selected
                if (_selectedMessageIds.length == 1)
                  IconButton(
                    onPressed: () => _showReactionPicker(_selectedMessageIds.first),
                    icon: const Icon(Icons.emoji_emotions_outlined),
                    tooltip: 'React',
                  ),
                IconButton(
                  onPressed: _selectedMessageIds.isNotEmpty
                      ? () => _showDeleteDialog(context)
                      : null,
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete',
                ),
              ] else if (canChat)
                IconButton(
                  onPressed: () => _startVoiceCall(context),
                  icon: const Icon(Icons.call),
                  tooltip: 'Voice Call',
                ),
            ],
          ),
          body: DecoratedBox(
            decoration: isMatch
                ? BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [loveSoft, theme.colorScheme.surface],
                    ),
                  )
                : const BoxDecoration(),
            child: Column(
              children: [
                if (!canChat)
                  MaterialBanner(
                    content: const Text('You can only chat with friends. Send/accept a friend request first.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                Expanded(
                  child: StreamBuilder<List<FirestoreMessage>>(
                    stream: widget.e2eeChat.decryptedMessagesStream(
                      threadId: widget.thread.id,
                      otherUid: widget.otherUser.uid,
                    ),
                    builder: (context, snap) {
                      final messages = snap.data;
                      if (messages == null) {
                        // Skeleton loading for chat messages
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          reverse: true,
                          itemCount: 8,
                          itemBuilder: (context, index) {
                            final isMe = index % 3 != 0;
                            return _ChatBubbleSkeletonInline(isMe: isMe);
                          },
                        );
                      }

                      // Filter out messages deleted "for me" (but keep "deleted for everyone" to show placeholder)
                      final visibleMessages = messages.where((m) {
                        // If deleted for everyone, show it (with "This message was deleted")
                        if (m.deletedForEveryone) return true;
                        // If deleted only for this user, hide it completely
                        if (m.deletedForUsers.contains(widget.currentUser.uid)) return false;
                        return true;
                      }).toList();

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        reverse: true,
                        cacheExtent: 500, // Cache more items for smoother scrolling
                        itemCount: visibleMessages.length,
                        itemBuilder: (context, index) {
                          final m = visibleMessages[visibleMessages.length - 1 - index];
                          
                          // Check if we need to show a date separator
                          final showDateSeparator = _shouldShowDateSeparator(
                            messages: visibleMessages,
                            currentIndex: visibleMessages.length - 1 - index,
                          );
                          final isMe = m.fromUid == widget.currentUser.uid;
                          final isDeleted = m.deletedForEveryone; // Only show "deleted" for everyone
                          final text = _getDisplayText(m);
                          final isSelected = _selectedMessageIds.contains(m.id);
                          
                          // WhatsApp-like colors: outgoing slightly tinted, incoming neutral.
                          final myBubble = isMatch
                              ? theme.colorScheme.secondary.withValues(alpha: 0.22)
                              : theme.colorScheme.primary.withValues(alpha: 0.12);
                          final otherBubble = isMatch
                              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.70)
                              : theme.colorScheme.surfaceContainerHighest;

                          // Special rendering for call messages (if not deleted)
                          if (m.isCallMessage && !isDeleted) {
                            return GestureDetector(
                              onTap: _selectionMode
                                  ? () => _toggleMessageSelection(m.id)
                                  : null,
                              onLongPress: () => _enterSelectionMode(m.id),
                              child: Container(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                child: _buildCallMessageBubble(
                                  context: context,
                                  message: m,
                                  isMe: isMe,
                                  theme: theme,
                                ),
                              ),
                            );
                          }

                          // Special rendering for voice messages (if not deleted)
                          if (m.isVoiceMessage && !isDeleted) {
                            return Column(
                              children: [
                                if (showDateSeparator)
                                  _buildDateSeparator(m.sentAt, theme),
                                GestureDetector(
                                  onTap: _selectionMode
                                      ? () => _toggleMessageSelection(m.id)
                                      : null,
                                  onLongPress: () => _enterSelectionMode(m.id),
                                  child: Container(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                        : Colors.transparent,
                                    child: _buildVoiceMessageBubble(
                                      context: context,
                                      message: m,
                                      isMe: isMe,
                                      theme: theme,
                                      isMatch: isMatch,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          // Add extra bottom padding if message has reactions (for the overlapping badge)
                          final hasReactions = m.reactions.isNotEmpty && !isDeleted;
                          
                          return Column(
                            children: [
                              // Date separator (shown above the first message of each day)
                              if (showDateSeparator)
                                _buildDateSeparator(m.sentAt, theme),
                              
                              Padding(
                                padding: EdgeInsets.only(bottom: hasReactions ? 22 : 4),
                                child: SwipeToReply(
                              replyFromRight: isMe,
                              onReply: isDeleted ? () {} : () => setState(() => _replyTo = m),
                              child: GestureDetector(
                                onTap: _selectionMode
                                    ? () => _toggleMessageSelection(m.id)
                                    : null,
                                onLongPress: isDeleted
                                    ? null
                                    : () => _enterSelectionMode(m.id),
                                child: Container(
                                  key: _getMessageKey(m.id),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  color: isSelected
                                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                      : Colors.transparent,
                                  child: Row(
                                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Flexible(
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            // Message bubble
                                            Container(
                                              constraints: BoxConstraints(
                                                maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDeleted
                                                    ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                                                    : (isMe ? myBubble : otherBubble),
                                                borderRadius: BorderRadius.only(
                                                  topLeft: const Radius.circular(18),
                                                  topRight: const Radius.circular(18),
                                                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                                                  bottomRight: Radius.circular(isMe ? 4 : 18),
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.only(
                                                  topLeft: const Radius.circular(18),
                                                  topRight: const Radius.circular(18),
                                                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                                                  bottomRight: Radius.circular(isMe ? 4 : 18),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    // Reply preview
                                                    if (m.replyToText != null && !isDeleted)
                                                      Container(
                                                        width: double.infinity,
                                                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                                                        decoration: BoxDecoration(
                                                          color: isMe 
                                                              ? theme.colorScheme.primary.withValues(alpha: 0.08)
                                                              : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                                                          border: Border(
                                                            left: BorderSide(
                                                              color: isMe 
                                                                  ? theme.colorScheme.primary
                                                                  : theme.colorScheme.secondary,
                                                              width: 4,
                                                            ),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          m.replyToText!,
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: theme.textTheme.bodySmall?.copyWith(
                                                            color: theme.colorScheme.onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ),
                                                    // Message content with timestamp
                                                    Padding(
                                                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        crossAxisAlignment: CrossAxisAlignment.end,
                                                        children: [
                                                          // Message text
                                                          Flexible(
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                if (isDeleted)
                                                                  Padding(
                                                                    padding: const EdgeInsets.only(right: 4),
                                                                    child: Icon(
                                                                      Icons.block,
                                                                      size: 16,
                                                                      color: theme.colorScheme.onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                Flexible(
                                                                  child: Text(
                                                                    text,
                                                                    style: isDeleted
                                                                        ? theme.textTheme.bodyLarge?.copyWith(
                                                                            fontStyle: FontStyle.italic,
                                                                            color: theme.colorScheme.onSurfaceVariant,
                                                                          )
                                                                        : theme.textTheme.bodyLarge,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          // Timestamp and tick marks
                                                          const SizedBox(width: 8),
                                                          Padding(
                                                            padding: const EdgeInsets.only(bottom: 0),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Text(
                                                                  _formatTime(m.sentAt),
                                                                  style: theme.textTheme.labelSmall?.copyWith(
                                                                    fontSize: 11,
                                                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                                                  ),
                                                                ),
                                                                // Show tick marks only for messages sent by current user
                                                                if (isMe && !isDeleted) ...[
                                                                  const SizedBox(width: 3),
                                                                  _buildMessageTicks(m.status, theme),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // WhatsApp-style reaction badge
                                            if (hasReactions)
                                              Positioned(
                                                bottom: -18,
                                                // Place on left side for both sender and receiver
                                                left: 12,
                                                child: ReactionRow(
                                                  reactions: m.reactions,
                                                  myUid: widget.currentUser.uid,
                                                  isMe: isMe,
                                                  onToggle: (emoji) => widget.chat.toggleReaction(
                                                    threadId: widget.thread.id,
                                                    messageId: m.id,
                                                    emoji: emoji,
                                                    uid: widget.currentUser.uid,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_replyTo != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Replying',
                                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _getDisplayText(_replyTo!),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setState(() => _replyTo = null),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                        if (_isRecording)
                          // Recording UI
                          Row(
                            children: [
                              IconButton(
                                onPressed: _cancelRecording,
                                icon: const Icon(Icons.delete_outline),
                                color: theme.colorScheme.error,
                                tooltip: 'Cancel',
                              ),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.mic,
                                        color: theme.colorScheme.error,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatRecordingDuration(_recordingDurationSeconds),
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          color: theme.colorScheme.error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Recording...',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: _stopAndSendRecording,
                                icon: const Icon(Icons.send),
                                style: IconButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          )
                        else
                          // Normal input UI
                          Row(
                            children: [
                              IconButton(
                                onPressed: canChat ? _toggleEmojiPicker : null,
                                icon: Icon(
                                  _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  enabled: canChat,
                                  decoration: const InputDecoration(
                                    hintText: 'Message…',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: canChat ? (_) => _send() : null,
                                  onTap: () {
                                    if (_showEmojiPicker) {
                                      setState(() => _showEmojiPicker = false);
                                    }
                                  },
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Show mic button when text is empty, send button when text exists
                              if (_controller.text.trim().isEmpty)
                                IconButton.filled(
                                  onPressed: canChat ? _startRecording : null,
                                  icon: const Icon(Icons.mic),
                                )
                              else
                                IconButton.filled(
                                  onPressed: canChat ? _send : null,
                                  icon: const Icon(Icons.send),
                                ),
                            ],
                          ),
                        if (_showEmojiPicker)
                          Container(
                            height: 300,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: EmojiPicker(
                                onEmojiSelected: _onEmojiSelected,
                                config: Config(
                                  height: 300,
                                  checkPlatformCompatibility: true,
                                  emojiViewConfig: EmojiViewConfig(
                                    emojiSizeMax: 28 * (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.30 : 1.0),
                                    verticalSpacing: 0,
                                    horizontalSpacing: 0,
                                    gridPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    recentsLimit: 28,
                                    backgroundColor: theme.colorScheme.surface,
                                    noRecents: Text(
                                      'No Recents',
                                      style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                    buttonMode: ButtonMode.MATERIAL,
                                  ),
                                  viewOrderConfig: const ViewOrderConfig(
                                    top: EmojiPickerItem.categoryBar,
                                    middle: EmojiPickerItem.emojiView,
                                    bottom: EmojiPickerItem.searchBar,
                                  ),
                                  skinToneConfig: SkinToneConfig(
                                    enabled: true,
                                    dialogBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                                    indicatorColor: theme.colorScheme.primary,
                                  ),
                                  categoryViewConfig: CategoryViewConfig(
                                    initCategory: Category.SMILEYS,
                                    backgroundColor: theme.colorScheme.surface,
                                    dividerColor: theme.colorScheme.outlineVariant,
                                    indicatorColor: theme.colorScheme.primary,
                                    iconColor: theme.colorScheme.onSurfaceVariant,
                                    iconColorSelected: theme.colorScheme.primary,
                                    categoryIcons: const CategoryIcons(),
                                  ),
                                  bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
                                  searchViewConfig: SearchViewConfig(
                                    backgroundColor: theme.colorScheme.surface,
                                    buttonIconColor: theme.colorScheme.primary,
                                    hintText: 'Search emoji...',
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await runAsyncAction(context, () async {
      // Use E2EE encrypted sending
      await widget.e2eeChat.sendEncryptedMessage(
        threadId: widget.thread.id,
        fromUid: widget.currentUser.uid,
        fromEmail: widget.currentUser.email,
        toUid: widget.otherUser.uid,
        toEmail: widget.otherUser.email,
        text: text,
        replyToMessageId: _replyTo?.id,
        replyToFromUid: _replyTo?.fromUid,
        replyToText: _replyTo == null ? null : widget.chat.displayText(_replyTo!),
      );
      _controller.clear();
      setState(() {
        _replyTo = null;
      });
    });
  }

  // Voice recording methods
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );
        
        setState(() {
          _isRecording = true;
          _recordingStartTime = DateTime.now();
          _recordingDurationSeconds = 0;
          _recordingPath = path;
        });
        
        // Start timer to update duration
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDurationSeconds = DateTime.now().difference(_recordingStartTime!).inSeconds;
          });
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required for voice messages')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    await _audioRecorder.stop();
    
    // Delete the recorded file
    if (_recordingPath != null) {
      try {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
    
    setState(() {
      _isRecording = false;
      _recordingStartTime = null;
      _recordingDurationSeconds = 0;
      _recordingPath = null;
    });
  }

  Future<void> _stopAndSendRecording() async {
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop();
    
    if (path == null || _recordingDurationSeconds < 1) {
      // Too short, cancel
      await _cancelRecording();
      return;
    }

    final duration = _recordingDurationSeconds;
    
    setState(() {
      _isRecording = false;
      _recordingStartTime = null;
      _recordingDurationSeconds = 0;
      _recordingPath = null;
    });

    // Upload and send
    await runAsyncAction(context, () async {
      final file = File(path);
      final bytes = await file.readAsBytes();
      
      // Upload to Cloudinary
      final upload = await _cloudinary.uploadAudioBytes(
        bytes: bytes,
        filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
        folder: 'voice_messages',
      );
      
      // Send encrypted voice message
      await widget.e2eeChat.sendEncryptedVoiceMessage(
        threadId: widget.thread.id,
        fromUid: widget.currentUser.uid,
        toUid: widget.otherUser.uid,
        voiceUrl: upload.secureUrl,
        durationSeconds: duration,
        replyToMessageId: _replyTo?.id,
        replyToFromUid: _replyTo?.fromUid,
        replyToText: _replyTo == null ? null : widget.chat.displayText(_replyTo!),
      );
      
      // Clean up temp file
      try {
        await file.delete();
      } catch (_) {}
      
      setState(() {
        _replyTo = null;
      });
    });
  }

  String _formatRecordingDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // Voice playback methods
  AudioPlayer _getPlayer(String messageId) {
    return _audioPlayers.putIfAbsent(messageId, () {
      final player = AudioPlayer();
      player.onPlayerComplete.listen((_) {
        setState(() {
          _isPlaying[messageId] = false;
          _playerPositions[messageId] = Duration.zero;
        });
      });
      player.onPositionChanged.listen((pos) {
        setState(() {
          _playerPositions[messageId] = pos;
        });
      });
      player.onDurationChanged.listen((dur) {
        setState(() {
          _playerDurations[messageId] = dur;
        });
      });
      return player;
    });
  }

  Future<void> _togglePlayback(String messageId, String url) async {
    final player = _getPlayer(messageId);
    final playing = _isPlaying[messageId] ?? false;
    
    if (playing) {
      await player.pause();
      setState(() => _isPlaying[messageId] = false);
    } else {
      // Stop other players
      for (final entry in _audioPlayers.entries) {
        if (entry.key != messageId && (_isPlaying[entry.key] ?? false)) {
          await entry.value.pause();
          _isPlaying[entry.key] = false;
        }
      }
      
      await player.play(UrlSource(url));
      setState(() => _isPlaying[messageId] = true);
    }
  }

  Widget _buildVoiceMessageBubble({
    required BuildContext context,
    required FirestoreMessage message,
    required bool isMe,
    required ThemeData theme,
    required bool isMatch,
  }) {
    final playing = _isPlaying[message.id] ?? false;
    final position = _playerPositions[message.id] ?? Duration.zero;
    final duration = _playerDurations[message.id] ?? 
        Duration(seconds: message.voiceDurationSeconds ?? 0);
    
    final progress = duration.inMilliseconds > 0 
        ? position.inMilliseconds / duration.inMilliseconds 
        : 0.0;

    final myBubble = isMatch
        ? theme.colorScheme.secondary.withValues(alpha: 0.22)
        : theme.colorScheme.primary.withValues(alpha: 0.12);
    final otherBubble = isMatch
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.70)
        : theme.colorScheme.surfaceContainerHighest;

    String formatDuration(Duration d) {
      final m = d.inMinutes;
      final s = d.inSeconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.75,
              minWidth: 200,
            ),
            decoration: BoxDecoration(
              color: isMe ? myBubble : otherBubble,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Play/Pause button
                IconButton(
                  onPressed: message.voiceUrl != null
                      ? () => _togglePlayback(message.id, message.voiceUrl!)
                      : null,
                  icon: Icon(
                    playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    size: 40,
                    color: isMe 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.secondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                // Waveform / progress
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(
                            isMe ? theme.colorScheme.primary : theme.colorScheme.secondary,
                          ),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Duration
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            playing ? formatDuration(position) : formatDuration(duration),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTime(message.sentAt),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                ),
                              ),
                              // Show tick marks only for messages sent by current user
                              if (isMe) ...[
                                const SizedBox(width: 3),
                                _buildMessageTicks(message.status, theme),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Mic icon indicator
                Icon(
                  Icons.mic,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startVoiceCall(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VoiceCallPage(
          currentUser: widget.currentUser,
          otherUser: widget.otherUser,
          callController: widget.callController,
        ),
      ),
    );
  }

  void _enterSelectionMode(String messageId) {
    setState(() {
      _selectionMode = true;
      _selectedMessageIds.add(messageId);
    });
    // Show reaction picker for single message selection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showReactionPickerAboveMessage(messageId);
    });
  }

  void _showReactionPickerAboveMessage(String messageId) {
    _removeReactionOverlay();
    
    final messageKey = _messageKeys[messageId];
    if (messageKey == null || messageKey.currentContext == null) return;
    
    final RenderBox renderBox = messageKey.currentContext!.findRenderObject() as RenderBox;
    final Offset messagePosition = renderBox.localToGlobal(Offset.zero);
    final Size messageSize = renderBox.size;
    final Size screenSize = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    
    // Quick reactions - 6 emojis like WhatsApp
    final quickReactions = ['❤️', '😂', '😮', '😢', '😡', '👍'];
    
    _reactionOverlay = OverlayEntry(
      builder: (context) {
        // Calculate position - show above the message
        const pickerHeight = 56.0;
        const pickerWidth = 280.0;
        
        double top = messagePosition.dy - pickerHeight - 8;
        // If not enough space above, show below
        if (top < MediaQuery.of(context).padding.top + kToolbarHeight) {
          top = messagePosition.dy + messageSize.height + 8;
        }
        
        // Center horizontally relative to message, but keep within screen
        double left = messagePosition.dx + (messageSize.width - pickerWidth) / 2;
        left = left.clamp(16.0, screenSize.width - pickerWidth - 16);
        
        return Stack(
          children: [
            // No full-screen dismiss layer - taps on messages will dismiss via _toggleMessageSelection
            // Taps on empty areas of the screen won't dismiss (user must tap a message or X button)
            // Reaction picker
            Positioned(
              top: top,
              left: left,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final emoji in quickReactions)
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            _removeReactionOverlay();
                            widget.chat.toggleReaction(
                              threadId: widget.thread.id,
                              messageId: messageId,
                              emoji: emoji,
                              uid: widget.currentUser.uid,
                            );
                            _exitSelectionMode();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(emoji, style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                      Container(
                        width: 1,
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: theme.colorScheme.outlineVariant,
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          _removeReactionOverlay();
                          _showingFullEmojiPicker = true;
                          setState(() {});
                          _showFullEmojiPickerInline(messageId);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.add_circle_outline, size: 24, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    
    Overlay.of(context).insert(_reactionOverlay!);
  }

  void _showFullEmojiPickerInline(String messageId) {
    final theme = Theme.of(context);
    
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.45,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    Navigator.of(ctx).pop();
                    widget.chat.toggleReaction(
                      threadId: widget.thread.id,
                      messageId: messageId,
                      emoji: emoji.emoji,
                      uid: widget.currentUser.uid,
                    );
                    _showingFullEmojiPicker = false;
                    _exitSelectionMode();
                  },
                  config: Config(
                    height: 300,
                    checkPlatformCompatibility: true,
                    emojiViewConfig: EmojiViewConfig(
                      emojiSizeMax: 28 * (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.30 : 1.0),
                      verticalSpacing: 0,
                      horizontalSpacing: 0,
                      gridPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      recentsLimit: 28,
                      backgroundColor: theme.colorScheme.surface,
                      noRecents: Text(
                        'No Recents',
                        style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      buttonMode: ButtonMode.MATERIAL,
                    ),
                    viewOrderConfig: const ViewOrderConfig(
                      top: EmojiPickerItem.categoryBar,
                      middle: EmojiPickerItem.emojiView,
                      bottom: EmojiPickerItem.searchBar,
                    ),
                    skinToneConfig: SkinToneConfig(
                      enabled: true,
                      dialogBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                      indicatorColor: theme.colorScheme.primary,
                    ),
                    categoryViewConfig: CategoryViewConfig(
                      initCategory: Category.SMILEYS,
                      backgroundColor: theme.colorScheme.surface,
                      dividerColor: theme.colorScheme.outlineVariant,
                      indicatorColor: theme.colorScheme.primary,
                      iconColor: theme.colorScheme.onSurfaceVariant,
                      iconColorSelected: theme.colorScheme.primary,
                      categoryIcons: const CategoryIcons(),
                    ),
                    bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
                    searchViewConfig: SearchViewConfig(
                      backgroundColor: theme.colorScheme.surface,
                      buttonIconColor: theme.colorScheme.primary,
                      hintText: 'Search emoji...',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _showingFullEmojiPicker = false;
      _exitSelectionMode();
    });
  }
  
  void _showReactionPicker(String messageId) {
    // Called from app bar button - show above the message if possible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showReactionPickerAboveMessage(messageId);
    });
  }

  void _exitSelectionMode() {
    _removeReactionOverlay();
    setState(() {
      _selectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _toggleMessageSelection(String messageId) {
    // Dismiss reaction picker when selecting more messages
    _removeReactionOverlay();
    
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) {
          _selectionMode = false;
        } else if (_selectedMessageIds.length == 1) {
          // Back to single selection - show reaction picker again
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showReactionPickerAboveMessage(_selectedMessageIds.first);
          });
        }
      } else {
        _selectedMessageIds.add(messageId);
        // More than one selected - reaction picker already dismissed above
      }
    });
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final count = _selectedMessageIds.length;
    
    // Check if any selected message can be deleted for everyone (sent by current user)
    final messagesStream = widget.chat.messagesStream(threadId: widget.thread.id);
    final messages = await messagesStream.first;
    final selectedMessages = messages.where((m) => _selectedMessageIds.contains(m.id)).toList();
    final canDeleteForEveryone = selectedMessages.any((m) => m.fromUid == widget.currentUser.uid);
    final allMine = selectedMessages.every((m) => m.fromUid == widget.currentUser.uid);

    if (!mounted) return;

    final ctx = context;
    await showModalBottomSheet<void>(
      context: ctx,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Delete $count message${count > 1 ? 's' : ''}?',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // Delete for me option
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete for me'),
                  subtitle: const Text('This message will be deleted from your device only'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _deleteForMe();
                  },
                ),

                // Delete for everyone option (only if user sent any selected message)
                if (canDeleteForEveryone)
                  ListTile(
                    leading: const Icon(Icons.delete_forever),
                    title: const Text('Delete for everyone'),
                    subtitle: Text(
                      allMine
                          ? 'This message will be deleted for all participants'
                          : 'Only your messages will be deleted for everyone',
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _deleteForEveryone();
                    },
                  ),

                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteForMe() async {
    final messageIds = _selectedMessageIds.toList();
    _exitSelectionMode();

    await runAsyncAction(context, () async {
      await widget.chat.deleteMessagesForMe(
        threadId: widget.thread.id,
        messageIds: messageIds,
        uid: widget.currentUser.uid,
      );
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${messageIds.length} message${messageIds.length > 1 ? 's' : ''} deleted'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteForEveryone() async {
    final messageIds = _selectedMessageIds.toList();
    _exitSelectionMode();

    await runAsyncAction(context, () async {
      final deletedCount = await widget.chat.deleteMessagesForEveryone(
        threadId: widget.thread.id,
        messageIds: messageIds,
        senderUid: widget.currentUser.uid,
      );

      if (mounted) {
        final skipped = messageIds.length - deletedCount;
        String message = '$deletedCount message${deletedCount > 1 ? 's' : ''} deleted for everyone';
        if (skipped > 0) {
          message += ' ($skipped skipped - not your messages)';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  /// Builds a WhatsApp-style call message bubble with appropriate icons.
  Widget _buildCallMessageBubble({
    required BuildContext context,
    required FirestoreMessage message,
    required bool isMe,
    required ThemeData theme,
  }) {
    // Determine call icon and color based on status and direction
    IconData callIcon;
    Color iconColor;
    String statusText;

    final isOutgoing = message.fromUid == widget.currentUser.uid;
    
    switch (message.callStatus) {
      case CallMessageStatus.completed:
        callIcon = isOutgoing ? Icons.call_made : Icons.call_received;
        iconColor = Colors.green;
        statusText = 'Voice call · ${message.formattedCallDuration ?? '0:00'}';
        break;
      case CallMessageStatus.missed:
        callIcon = Icons.call_missed;
        iconColor = Colors.red;
        statusText = isOutgoing ? 'No answer' : 'Missed voice call';
        break;
      case CallMessageStatus.declined:
        callIcon = Icons.call_end;
        iconColor = Colors.red;
        statusText = isOutgoing ? 'Call declined' : 'Declined voice call';
        break;
      case CallMessageStatus.cancelled:
        callIcon = Icons.call_end;
        iconColor = Colors.orange;
        statusText = 'Cancelled call';
        break;
      default:
        callIcon = Icons.call;
        iconColor = theme.colorScheme.primary;
        statusText = 'Voice call';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Call icon with background
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  callIcon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Call info
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      statusText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(message.sentAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Call back button (for missed/declined calls)
              if (message.callStatus == CallMessageStatus.missed ||
                  message.callStatus == CallMessageStatus.declined)
                IconButton(
                  onPressed: () => _startVoiceCall(context),
                  icon: Icon(
                    Icons.call,
                    color: theme.colorScheme.primary,
                  ),
                  tooltip: 'Call back',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline skeleton for chat bubbles - optimized for performance
class _ChatBubbleSkeletonInline extends StatelessWidget {
  const _ChatBubbleSkeletonInline({this.isMe = false});

  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = isMe ? 180.0 : 220.0;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 60 : 0,
          right: isMe ? 0 : 60,
          bottom: 8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? (isMe ? const Color(0xFF2A2A2A) : const Color(0xFF1E1E1E))
              : (isMe ? const Color(0xFFE3E3E3) : const Color(0xFFF0F0F0)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: width,
              height: 12,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD0D0D0),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: width * 0.6,
              height: 12,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD0D0D0),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
