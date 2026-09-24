import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LumiFX'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _SectionCard(
            title: 'Scenes',
            subtitle: 'Continuous atmospheres for everyday lighting.',
            icon: Icons.gradient,
          ),
          SizedBox(height: 12),
          _SectionCard(
            title: 'Stories',
            subtitle: 'Narrative effects with movement, surprises and timed events.',
            icon: Icons.auto_awesome,
          ),
          SizedBox(height: 12),
          _SectionCard(
            title: 'Interactive',
            subtitle: 'Lighting that can react to audio and user input.',
            icon: Icons.graphic_eq,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        minVerticalPadding: 20,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
