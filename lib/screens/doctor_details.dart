import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'staff_details.dart'; // Import the StaffDetailPage

class DoctorDetailsScreen extends StatefulWidget {
  const DoctorDetailsScreen({super.key});

  @override
  DoctorDetailsScreenState createState() => DoctorDetailsScreenState();
}

class DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  final Stream<QuerySnapshot> _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? selectedDepartment;
  String? selectedRole;

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
    return userDocs.where((user) {
      final firstName = (user['firstName'] ?? '').toString().toLowerCase();
      final lastName = (user['lastName'] ?? '').toString().toLowerCase();
      final role = (user['role'] ?? '').toString().toLowerCase();
      final department = (user['department'] ?? '').toString().toLowerCase();

      bool matchesSearch = firstName.contains(_searchQuery) || lastName.contains(_searchQuery);
      bool matchesDepartment = selectedDepartment == null || department == selectedDepartment!.toLowerCase();
      bool matchesRole = selectedRole == null || role == selectedRole!.toLowerCase();

      return matchesSearch && matchesDepartment && matchesRole;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details of Doctors and Nurses'),
      ),
      body: Row(
        children: [
          // Sidebar for filters
          Container(
            width: 200,
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey[200],
            child: Column(
              children: [
                const Text('Select Department', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ...['Cardiology', 'Neurology', 'Radiology', 'Pediatrics'].map((department) {
                  return ListTile(
                    title: Text(department),
                    onTap: () => setState(() => selectedDepartment = department),
                    selected: selectedDepartment == department,
                  );
                }).toList(),
                const Divider(),
                const Text('Select Role', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ...['Doctor', 'Nurse', 'Technologist', 'Admin'].map((role) {
                  return ListTile(
                    title: Text(role),
                    onTap: () => setState(() => selectedRole = role),
                    selected: selectedRole == role,
                  );
                }).toList(),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _usersStream,
                    builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return const Center(child: Text('Error loading data'));
                      }

                      final filteredDocs = _filterUsers(snapshot.data!.docs);

                      if (filteredDocs.isEmpty) {
                        return const Center(child: Text('No results found.'));
                      }

                      return ListView.builder(
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final user = filteredDocs[index];
                          return Card(
                            margin: const EdgeInsets.all(8.0),
                            color: Color(0xFFC8EEF3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 3,
                            child: ListTile(
                              title: Text('${user['firstName']} ${user['lastName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Role: ${user['role']}'),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => StaffDetailPage(user: user),
                                  ),
                                );
                              },
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
}
