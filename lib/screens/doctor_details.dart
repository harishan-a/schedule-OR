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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details of Doctors and Nurses'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userDocs = snapshot.data?.docs;    // If we have data, build a list

          if (userDocs == null || userDocs.isEmpty) {
            return const Center(child: Text('No doctors or nurses found.'));
          }

          return ListView.builder(
            itemCount: userDocs.length,
            itemBuilder: (context, index) {
              final user = userDocs[index];
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
    );
  }
}

// seperate doctors and nurses and other roles based on their roles
// search bar
// filter
