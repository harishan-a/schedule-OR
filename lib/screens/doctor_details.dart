import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorDetailsScreen extends StatefulWidget {
  const DoctorDetailsScreen({super.key});

  @override
  DoctorDetailsScreenState createState() => DoctorDetailsScreenState();
}

class DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  final Stream<QuerySnapshot> _usersStream = FirebaseFirestore.instance         // Listens to real-time updates from the 'users'
      .collection('users')
      .snapshots();

  final TextEditingController _searchController = TextEditingController();      // For search bar
  String _searchQuery = '';
  String? selectedDepartment;
  String? selectedRole;

  final Map<String, List<String>> departments = {
    'Cardiology': ['Doctor', 'Nurse', 'Technologist', 'Admin'],
    'Neurology': ['Doctor', 'Nurse', 'Technologist', 'Admin'],
    'Pediatrics': ['Doctor', 'Nurse', 'Technologist', 'Admin'],
    'Radiology': ['Doctor', 'Nurse', 'Technologist', 'Admin'],
  };

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
    return userDocs.where((user) {                                                // Retrieves user info and filters users based on their roles and name
      final firstName = (user['firstName'] ?? '').toString().toLowerCase();
      final lastName = (user['lastName'] ?? '').toString().toLowerCase();
      final role = (user['role'] ?? '').toString().toLowerCase();
      final department = (user['department'] ?? '').toString().toLowerCase();

      // Apply search query
      bool matchesSearch = firstName.contains(_searchQuery) ||
          lastName.contains(_searchQuery) ||
          role.contains(_searchQuery);                                            // Checks if any of the user's fields contain the search query

      // Apply department and role filtering
      bool matchesDepartment = selectedDepartment == null ||
          department == selectedDepartment!.toLowerCase();
      bool matchesRole = selectedRole == null ||
          role == selectedRole!.toLowerCase(); // Ensure exact match

      return matchesSearch && matchesDepartment && matchesRole;                   // Returns true and converts it to list if department, search, and role matches
    }).toList();
  }

  void _onDepartmentSelected(String department) {
    setState(() {
      selectedDepartment = department.toLowerCase();
      selectedRole = null; // Reset role when department changes
    });
  }

  void _onRoleSelected(String role) {
    setState(() {
      selectedRole = role.toLowerCase(); // Match singular form
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details of Doctors and Nurses'),
      ),
      body: Row(
        children: [
          // Sidebar for Department and Role selection
          Container(
            width: 200,
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey[200],
            child: Column(
              children: [
                Text('Select Department', style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.bold)),
                ...departments.keys.map((department) {
                  return ListTile(
                    title: Text(department),
                    onTap: () => _onDepartmentSelected(department),
                    selected: selectedDepartment == department.toLowerCase(),
                  );
                }).toList(),
                Divider(),
                Text('Select Role', style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.bold)),
                ...['Doctor', 'Nurse', 'Technologist', 'Admin'].map((role) {
                  return ListTile(
                    title: Text(role),
                    onTap: () => _onRoleSelected(role),
                    selected: selectedRole == role.toLowerCase(),
                  );
                }).toList(),
              ],
            ),
          ),
          Expanded(
            child: Column(
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
                    stream: _usersStream,                                         // Updates whenever the data in the 'users' collection changes
                    builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {    // Holds the current state of the stream
                      if (snapshot.hasError) {
                        return Center(child: Text('Something went wrong'));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final userDocs = snapshot.data?.docs;                       // Retrieves users

                      if (userDocs == null || userDocs.isEmpty) {
                        return const Center(child: Text('No doctors or nurses found.'));
                      }

                      final filteredDocs = _filterUsers(userDocs);                 // Filter users list based on search query

                      if (filteredDocs.isEmpty) {
                        return const Center(child: Text('No results found.'));
                      }

                      return ListView.builder(                                   // Defines how to build each item
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
                            color: Colors.blue[100],
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
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {                                                                 // Disposes of _searchController to avoid memory leaks
    _searchController.dispose();
    super.dispose();
  }
}
