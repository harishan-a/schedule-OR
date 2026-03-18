import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

/// A standalone patient lookup screen that directly queries Firestore
class PatientLookupScreen extends StatefulWidget {
  const PatientLookupScreen({super.key});

  @override
  State<PatientLookupScreen> createState() => _PatientLookupScreenState();
}

class _PatientLookupScreenState extends State<PatientLookupScreen> {
  // Form state
  final patientNameController = TextEditingController();
  var isSearching = false;
  var hasSearched = false;
  var searchResults = <Map<String, dynamic>>[];
  var errorMessage = '';
  var selectedSurgery = <String, dynamic>{};
  var showDetails = false;

  @override
  void dispose() {
    patientNameController.dispose();
    super.dispose();
  }

  // Search for patient surgeries
  Future<void> searchPatient() async {
    final patientName = patientNameController.text.trim();
    if (patientName.isEmpty) return;

    setState(() {
      isSearching = true;
      hasSearched = true;
      searchResults = [];
      errorMessage = '';
    });

    try {
      print('PUBLIC LOOKUP: Searching for patient: $patientName');

      // Use a direct collection get and then filter in memory
      final snapshot =
          await FirebaseFirestore.instance.collection('surgeries').get();

      print('PUBLIC LOOKUP: Got ${snapshot.docs.length} surgeries');

      // Manual filtering for patient name
      final matches = snapshot.docs.where((doc) {
        final data = doc.data();
        return data.containsKey('patientName') &&
            data['patientName'] == patientName;
      }).toList();

      print(
          'PUBLIC LOOKUP: Found ${matches.length} matches for "$patientName"');

      final results = matches
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();

      setState(() {
        searchResults = results;
        isSearching = false;
      });
    } catch (error) {
      print('PUBLIC LOOKUP ERROR: ${error.toString()}');
      setState(() {
        isSearching = false;
        errorMessage = 'Error: ${error.toString()}';
      });
    }
  }

  // View surgery details
  void viewSurgeryDetails(Map<String, dynamic> surgery) {
    setState(() {
      selectedSurgery = surgery;
      showDetails = true;
    });
  }

  // Back to search
  void backToSearch() {
    setState(() {
      showDetails = false;
      selectedSurgery = {};
    });
  }

  // Share surgery details
  Future<void> shareSurgeryDetails() async {
    if (selectedSurgery.isEmpty) return;

    // Add debug logging
    print('SHARING SURGERY: Room raw value: ${selectedSurgery['room']}');
    print('SHARING SURGERY: Room formatted: ${getRoomName(selectedSurgery)}');

    final surgeryInfo = '''
Surgery Information:
Patient: ${selectedSurgery['patientName']}
Date: ${formatDate(selectedSurgery['dateTime'])}
Time: ${formatTime(selectedSurgery['startTime'])}
Room: ${getRoomName(selectedSurgery)}
Surgeon: ${selectedSurgery['surgeon'] ?? 'Not assigned'}
Surgery Type: ${selectedSurgery['surgeryType'] ?? 'Not specified'}
''';

    try {
      await Share.share(surgeryInfo,
          subject: 'Surgery Information for ${selectedSurgery['patientName']}');
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Surgery Lookup'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2E7D32),
              Color(0xFF1B5E20),
              Colors.white,
            ],
            stops: [0.0, 0.2, 0.3],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: MediaQuery.of(context).size.width > 600
                    ? 600
                    : MediaQuery.of(context).size.width * 0.9,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: showDetails
                      ? buildSurgeryDetailsView(theme)
                      : buildSearchView(theme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build the search form
  Widget buildSearchView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          'Patient Surgery Lookup',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2E7D32),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Info text
        const Text(
          'Enter the exact name of the patient to find upcoming surgery information.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 24),

        // Patient name field
        TextField(
          controller: patientNameController,
          autofocus: true,
          showCursor: true,
          cursorColor: const Color(0xFF2E7D32),
          decoration: InputDecoration(
            labelText: 'Patient Full Name',
            hintText: 'e.g. Louis Griffin',
            prefixIcon:
                const Icon(Icons.person_search, color: Color(0xFF2E7D32)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey[200],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.never,
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                patientNameController.clear();
              },
            ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => searchPatient(),
        ),
        const SizedBox(height: 24),

        // Search button
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: isSearching ? null : searchPatient,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              disabledBackgroundColor: const Color(0xFF2E7D32).withOpacity(0.5),
            ),
            child: isSearching
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Search',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),

        // Error message
        if (errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Results
        if (hasSearched && errorMessage.isEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            margin: const EdgeInsets.only(top: 24),
            child: searchResults.isEmpty
                ? Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No surgery scheduled for this patient',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final surgery = searchResults[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            surgery['patientName'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Date: ${formatDate(surgery['dateTime']) ?? 'Unscheduled'}\n'
                            'Surgery Type: ${surgery['surgeryType'] ?? 'Not specified'}\n'
                            'Room: ${getRoomName(surgery)}\n'
                            'Surgeon: ${surgery['surgeon'] ?? 'Not assigned'}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            color: Color(0xFF2E7D32),
                            size: 16,
                          ),
                          onTap: () => viewSurgeryDetails(surgery),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }

  // Build the surgery details view
  Widget buildSurgeryDetailsView(ThemeData theme) {
    // Log the surgery data to help troubleshoot
    print('PATIENT VIEW: Surgery data: ${selectedSurgery.toString()}');
    print('PATIENT VIEW: Room value: ${selectedSurgery['room']}');
    print(
        'PATIENT VIEW: Calculated room name: ${getRoomName(selectedSurgery)}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with back button
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: backToSearch,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: 24,
              color: const Color(0xFF2E7D32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Surgery Information',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Surgery details card
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade50,
                Colors.blue.shade100,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient info
              const Text(
                'Patient',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                selectedSurgery['patientName'] ?? 'Not Available',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 32),

              // Date and time
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatDate(selectedSurgery['dateTime']) ??
                              'Not Scheduled',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Time',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatTime(selectedSurgery['startTime']) ??
                              'Not Specified',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Surgeon and room
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Surgeon',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedSurgery['surgeon'] ?? 'Not Assigned',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Room',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          getRoomName(selectedSurgery),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Surgery Type
              const SizedBox(height: 20),
              const Text(
                'Surgery Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                selectedSurgery['surgeryType'] ?? 'Not Specified',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Notes
              if (selectedSurgery['notes'] != null &&
                  selectedSurgery['notes'].toString().isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedSurgery['notes'],
                  style: const TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Share button
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.share, size: 20),
              label: const Text(
                'Share Surgery Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: shareSurgeryDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Helper functions
String? formatDate(dynamic timestamp) {
  if (timestamp == null) return null;

  if (timestamp is Timestamp) {
    final dateTime = timestamp.toDate();
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  } else if (timestamp is String) {
    return timestamp;
  }

  return null;
}

String? formatTime(dynamic dateTime) {
  if (dateTime == null) return null;

  if (dateTime is Timestamp) {
    final dt = dateTime.toDate();
    final hour = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
            ? 12
            : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  } else if (dateTime is String) {
    return dateTime;
  }

  return null;
}

// Helper function to get room name
String getRoomName(Map<String, dynamic> surgery) {
  // According to the database screenshot, the room is directly stored as a string like "OperatingRoom1"
  if (surgery['room'] is String) {
    return surgery['room'];
  }
  // If room is stored as a map with a numeric key like "0"
  else if (surgery['room'] is Map && surgery['room'].containsKey('0')) {
    return surgery['room']['0'] ?? 'Not Assigned';
  }
  // If room is stored in the roomNumber field
  else if (surgery['roomNumber'] != null) {
    return surgery['roomNumber'];
  }
  // In the screenshot, we can see it's stored directly as a value with key "room"
  else if (surgery.containsKey('room')) {
    var roomValue = surgery['room'];
    if (roomValue is List && roomValue.isNotEmpty) {
      return roomValue[0] ?? 'Not Assigned';
    }
  }

  return 'Not Assigned';
}
