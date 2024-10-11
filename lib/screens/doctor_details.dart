import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorDetailsScreen extends StatefulWidget {
  const DoctorDetailsScreen({super.key});

  @override
  DoctorDetailsScreenState createState() => DoctorDetailsScreenState();
}

class DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  final Stream<QuerySnapshot> _usersStream = FirebaseFirestore.instance            // Listens to real-time updates from the 'users'
      .collection('users')
      .snapshots();

  final TextEditingController _searchController = TextEditingController();         // For search bar
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {                                            // Initializes the search bar
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();                      // Updates _searchQuery whenever the text changes and converts text to lowercase
      });
    });
  }

  List<DocumentSnapshot> _filterUsers(List<DocumentSnapshot> userDocs) {          //Takes a list of users and filters them based on the search query.
    if (_searchQuery.isEmpty) {
      return userDocs;                                                            // Returns the full list of users if empty
    } else {
      return userDocs.where((user) {                                              // Retrieves user info and filters users based on their roles and name
        final firstName = (user['firstName'] ?? '').toString().toLowerCase();
        final lastName = (user['lastName'] ?? '').toString().toLowerCase();
        final role = (user['role'] ?? '').toString().toLowerCase();
        return firstName.contains(_searchQuery) ||
            lastName.contains(_searchQuery) ||
            role.contains(_searchQuery);                                         // Returns true if any of the user's fields contain the search query and
      }).toList();                                                               // coverts result back to list

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
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueAccent),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _usersStream,                                               // Updates whenever the data in the 'users' collection changes
              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {    // Holds the current state of the stream
                if (snapshot.hasError) {
                  return Center(child: Text('Something went wrong'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userDocs = snapshot.data?.docs;                              // Retrieves users

                if (userDocs == null || userDocs.isEmpty) {
                  return const Center(child: Text('No doctors or nurses found.'));
                }

                final filteredDocs = _filterUsers(userDocs);                      // Filter users list based on search query

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('No results found.'));
                }

                return ListView.builder(                                          // Defines how to build each item
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
                      color: Colors.blue[100], // Set the card color here
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
    _searchController.dispose();                                                  // Disposes of _searchController to avoid memory leaks
    super.dispose();
  }
}
