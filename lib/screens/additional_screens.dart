import 'package:flutter/material.dart';

// New Channel Screen
class NewChannelScreen extends StatelessWidget {
  const NewChannelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('નવું ચેનલ')),
      body: const Center(
        child: Text('Channel creation screen - Coming soon'),
      ),
    );
  }
}

// Create Story Screen
class CreateStoryScreen extends StatelessWidget {
  const CreateStoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('સ્ટોરી બનાવો')),
      body: const Center(
        child: Text('Story creation screen - Coming soon'),
      ),
    );
  }
}

// Global Search Screen
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'શોધો...',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
      ),
      body: _searchQuery.isEmpty
          ? _buildSearchSuggestions()
          : _buildSearchResults(),
    );
  }

  Widget _buildSearchSuggestions() {
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'તાજેતરના શોધો',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('વ્યક્તિ અથવા ગ્રુપ શોધો'),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text('મેસેજમાં શોધો'),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return const Center(
      child: Text('Search results will appear here'),
    );
  }
}