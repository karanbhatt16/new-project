import 'package:flutter/material.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _ChatTile(name: 'Ananya', lastMessage: 'Canteen at 6?', unread: 2),
        _ChatTile(name: 'Sahil', lastMessage: 'Badminton?', unread: 0),
        _ChatTile(name: 'Riya', lastMessage: 'Nice sunset pic!', unread: 1),
        _ChatTile(name: 'Neha', lastMessage: 'Hackathon mixer?', unread: 0),
      ],
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.name, required this.lastMessage, required this.unread});

  final String name;
  final String lastMessage;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: unread > 0
            ? CircleAvatar(
                radius: 12,
                child: Text(
                  unread.toString(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              )
            : null,
        onTap: () {},
      ),
    );
  }
}
