import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorDetailsScreen extends StatefulWidget {
  const DoctorDetailsScreen({Key? key}) : super(key: key);

  @override
  _DoctorDetailsScreenState createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  final Stream<QuerySnapshot> _usersStream = FirebaseFirestore.instance
      .collection('users')
      .snapshots();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  List<DocumentSnapshot> _filterUsers(List<DocumentSnapshot> userDocs) {
    if (_searchQuery.isEmpty) {
      return userDocs;
    } else {
      return userDocs.where((user) {
        final firstName = (user['firstName'] ?? '').toString().toLowerCase();
        final lastName = (user['lastName'] ?? '').toString().toLowerCase();
        final role = (user['role'] ?? '').toString().toLowerCase();
        return firstName.contains(_searchQuery) ||
            lastName.contains(_searchQuery) ||
            role.contains(_searchQuery);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details of Doctors and Nurses'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _usersStream,
              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Something went wrong'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userDocs = snapshot.data?.docs;

                if (userDocs == null || userDocs.isEmpty) {
                  return const Center(child: Text('No doctors or nurses found.'));
                }

                final filteredDocs = _filterUsers(userDocs);

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('No results found.'));
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final user = filteredDocs[index];
                    final firstName = user['firstName'] ?? 'N/A';
                    final lastName = user['lastName'] ?? 'N/A';
                    final role = user['role'] ?? 'N/A';
                    final department = user['department'] ?? 'N/A';
                    final email = user['email'] ?? 'N/A';
                    final phoneNumber = user['phoneNumber'] ?? 'N/A';

                    return Card(
                      margin: const EdgeInsets.all(10),
                      elevation: 5,
                      child: ListTile(
                        title: Text('$firstName $lastName'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Role: $role'),
                            Text('Department: $department'),
                            Text('Email: $email'),
                            Text('Phone: $phoneNumber'),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
