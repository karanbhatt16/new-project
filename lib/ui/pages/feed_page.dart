import 'package:flutter/material.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _StoriesRow(),
        SizedBox(height: 16),
        _PostCard(
          author: 'Ananya • CSE',
          time: '2h',
          caption: 'Coffee at the canteen after labs? ☕',
        ),
        SizedBox(height: 12),
        _PostCard(
          author: 'Sahil • Mechanical',
          time: '5h',
          caption: 'Gym session done. Who’s up for badminton later?',
        ),
        SizedBox(height: 12),
        _PostCard(
          author: 'Riya • IT',
          time: '1d',
          caption: 'Golden hour on campus hits different.',
        ),
      ],
    );
  }
}

class _StoriesRow extends StatelessWidget {
  const _StoriesRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const [
          _StoryBubble(label: 'Your story', isAdd: true),
          _StoryBubble(label: 'Ananya'),
          _StoryBubble(label: 'Sahil'),
          _StoryBubble(label: 'Riya'),
          _StoryBubble(label: 'Kunal'),
          _StoryBubble(label: 'Neha'),
        ],
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({required this.label, this.isAdd = false});

  final String label;
  final bool isAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 32,
                child: Icon(isAdd ? Icons.add : Icons.person),
              ),
              if (!isAdd)
                const Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 10,
                    child: Icon(Icons.circle, size: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 72,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.author, required this.time, required this.caption});

  final String author;
  final String time;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        time,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(onPressed: null, icon: const Icon(Icons.more_horiz)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(Icons.image_outlined, size: 48),
              ),
            ),
            const SizedBox(height: 12),
            Text(caption),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(onPressed: null, icon: const Icon(Icons.favorite_border)),
                IconButton(onPressed: null, icon: const Icon(Icons.mode_comment_outlined)),
                IconButton(onPressed: null, icon: const Icon(Icons.send_outlined)),
                const Spacer(),
                IconButton(onPressed: null, icon: const Icon(Icons.bookmark_border)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
