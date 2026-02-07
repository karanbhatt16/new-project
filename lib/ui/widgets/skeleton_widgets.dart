import 'package:flutter/material.dart';

/// Shimmer effect widget for skeleton loading
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.centerRight,
              colors: isDark
                  ? [
                      const Color(0xFF2A2A2A),
                      const Color(0xFF3D3D3D),
                      const Color(0xFF2A2A2A),
                    ]
                  : [
                      const Color(0xFFE8E8E8),
                      const Color(0xFFF5F5F5),
                      const Color(0xFFE8E8E8),
                    ],
              stops: [
                0.0,
                _controller.value,
                1.0,
              ],
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

/// Base skeleton box with rounded corners
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.isCircle = false,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }
}

/// Skeleton for a post card - improved design
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Shimmer(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const SkeletonBox(width: 32, height: 32, isCircle: true),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBox(width: 120, height: 12, borderRadius: 6),
                      SizedBox(height: 4),
                      SkeletonBox(width: 80, height: 10, borderRadius: 5),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Image placeholder
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: SkeletonBox(borderRadius: 14),
                ),
              ),
              const SizedBox(height: 12),
              // Caption lines
              const SkeletonBox(width: double.infinity, height: 12, borderRadius: 6),
              const SizedBox(height: 6),
              const SkeletonBox(width: 200, height: 12, borderRadius: 6),
              const SizedBox(height: 12),
              // Action row
              Row(
                children: const [
                  SkeletonBox(width: 28, height: 28, isCircle: true),
                  SizedBox(width: 6),
                  SkeletonBox(width: 24, height: 12, borderRadius: 6),
                  SizedBox(width: 16),
                  SkeletonBox(width: 28, height: 28, isCircle: true),
                  SizedBox(width: 6),
                  SkeletonBox(width: 24, height: 12, borderRadius: 6),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for a conversation/chat list item
class ConversationTileSkeleton extends StatelessWidget {
  const ConversationTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Shimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SkeletonBox(width: 52, height: 52, isCircle: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 140, height: 14, borderRadius: 7),
                  SizedBox(height: 6),
                  SkeletonBox(width: 200, height: 12, borderRadius: 6),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                SkeletonBox(width: 40, height: 10, borderRadius: 5),
                SizedBox(height: 6),
                SkeletonBox(width: 20, height: 20, isCircle: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a comment item
class CommentSkeleton extends StatelessWidget {
  const CommentSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 36, height: 36, isCircle: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      SkeletonBox(width: 80, height: 12, borderRadius: 6),
                      SizedBox(width: 8),
                      SkeletonBox(width: 50, height: 10, borderRadius: 5),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const SkeletonBox(width: double.infinity, height: 12, borderRadius: 6),
                  const SizedBox(height: 4),
                  const SkeletonBox(width: 150, height: 12, borderRadius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a chat message bubble
class ChatBubbleSkeleton extends StatelessWidget {
  const ChatBubbleSkeleton({
    super.key,
    this.isMe = false,
    this.width = 200,
  });

  final bool isMe;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Shimmer(
      child: Align(
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
                : (isMe ? const Color(0xFFE8E8E8) : const Color(0xFFF0F0F0)),
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
              SkeletonBox(width: width, height: 12, borderRadius: 6),
              const SizedBox(height: 4),
              SkeletonBox(width: width * 0.6, height: 12, borderRadius: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for a user profile card
class UserCardSkeleton extends StatelessWidget {
  const UserCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Shimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SkeletonBox(width: 56, height: 56, isCircle: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 120, height: 16, borderRadius: 8),
                  SizedBox(height: 6),
                  SkeletonBox(width: 180, height: 12, borderRadius: 6),
                ],
              ),
            ),
            const SkeletonBox(width: 36, height: 36, borderRadius: 10),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for notifications list item
class NotificationSkeleton extends StatelessWidget {
  const NotificationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Shimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const SkeletonBox(width: 44, height: 44, isCircle: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: double.infinity, height: 12, borderRadius: 6),
                  SizedBox(height: 6),
                  SkeletonBox(width: 100, height: 10, borderRadius: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A list of skeleton items with optional count
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    required this.itemBuilder,
    this.itemCount = 5,
    this.padding,
  });

  final Widget Function(BuildContext context, int index) itemBuilder;
  final int itemCount;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
