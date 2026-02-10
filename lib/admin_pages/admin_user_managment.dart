import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gas_on_go/theme/app_theme.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<Map<String, dynamic>> allUsers = [];
  bool isLoading = true;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    setState(() => isLoading = true);

    final snapshot = await FirebaseFirestore.instance.collection('users').get();

    //to add the doc id to the data since this the id is its name
    final userList = snapshot.docs.map((doc) {
      //get the data we are going to reshape it
      var data = doc.data(); // Get the document's data (as a Map)
      data['docId'] = doc.id; // here is a new index and its new value
      return data;
    }).toList(); //turn it to a list []

    setState(() {
      allUsers = userList;
      isLoading = false;
    });
  }

  List<Map<String, dynamic>> get displayedUsers {
    final query = searchController.text.toLowerCase();
    if (query.isEmpty) return allUsers;
    return allUsers.where((user) {
      final name = (user['name'] ?? '').toLowerCase();
      final email = (user['email'] ?? '').toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  Future<void> editUser(Map<String, dynamic> user) async {
    final nameController = TextEditingController(text: user['name']);
    final emailController = TextEditingController(text: user['email']);
    final roleController = TextEditingController(text: user['role']);

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email')),
            TextField(
                controller: roleController,
                decoration: const InputDecoration(labelText: 'Role')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );

    if (updated == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user['docId'])
          .update({
        'name': nameController.text,
        'email': emailController.text,
        'role': roleController.text,
      });
      fetchUsers();
    }
  }

  Future<void> deleteUser(String docId) async {
    await FirebaseFirestore.instance.collection('users').doc(docId).delete();
    fetchUsers();
  }

  void viewDetails(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user['name'] ?? ''),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${user['docId']}'),
            Text('Email: ${user['email'] ?? 'N/A'}'),
            Text('Role: ${user['role'] ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'))
        ],
      ),
    );
  }

  Future<void> addUser() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final roleController = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email')),
            TextField(
                controller: roleController,
                decoration: const InputDecoration(labelText: 'Role')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add')),
        ],
      ),
    );

    if (created == true) {
      await FirebaseFirestore.instance.collection('users').add({
        'name': nameController.text,
        'email': emailController.text,
        'role': roleController.text,
      });
      fetchUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management',
            style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon:
                          Icon(Icons.search, color: AppTheme.primaryColor),
                      hintText: 'Search by name or email...',
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayedUsers.isEmpty
                    ? Center(
                        child: Text('No users found',
                            style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.builder(
                        itemCount: displayedUsers.length,
                        itemBuilder: (context, index) {
                          final user = displayedUsers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor,
                                child: Text(
                                  (user['name'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                '${user['name']} (ID: ${user['docId']})',
                                style: const TextStyle(
                                    color: AppTheme.textPrimary),
                              ),
                              subtitle: Text(
                                '${user['email'] ?? ''}\nRole: ${user['role'] ?? ''}',
                                style: const TextStyle(
                                    color: AppTheme.textSecondary),
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'view':
                                      viewDetails(user);
                                      break;
                                    case 'edit':
                                      await editUser(user);
                                      break;
                                    case 'remove':
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title:
                                              const Text('Confirm Remove User'),
                                          content: Text(
                                              'Are you sure you want to remove ${user['name']}?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context)
                                                      .pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.of(context)
                                                      .pop(true),
                                              child: const Text('Remove User'),
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        await deleteUser(user['docId']);
                                      }
                                      break;
                                  }
                                },
                                itemBuilder: (BuildContext context) => const [
                                  PopupMenuItem(
                                      value: 'view',
                                      child: Text('View Details')),
                                  PopupMenuItem(
                                      value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(
                                      value: 'remove',
                                      child: Text('Remove User')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addUser,
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
