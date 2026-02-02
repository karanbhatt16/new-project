import 'package:flutter/material.dart';

class CampusPage extends StatelessWidget {
  const CampusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _SectionTitle('Groups'),
        SizedBox(height: 12),
        _GroupCard(name: 'CSE Batch 2027', members: '324 members'),
        _GroupCard(name: 'Photography Club', members: '88 members'),
        _GroupCard(name: 'Badminton Gang', members: '41 members'),
        SizedBox(height: 20),
        _SectionTitle('Events'),
        SizedBox(height: 12),
        _EventCard(title: 'Cultural Night', meta: 'Fri • Auditorium'),
        _EventCard(title: 'Hackathon mixer', meta: 'Sat • LT-2'),
        _EventCard(title: 'Open Mic', meta: 'Sun • Lawn'),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.name, required this.members});

  final String name;
  final String members;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.groups)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(members),
        trailing: FilledButton.tonal(
          onPressed: null,
          child: const Text('Join'),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.title, required this.meta});

  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.event)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(meta),
        trailing: FilledButton.tonal(
          onPressed: null,
          child: const Text('RSVP'),
        ),
      ),
    );
  }
}
