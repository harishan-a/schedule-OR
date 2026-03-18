import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_orscheduler/utils/csv_data_processor.dart';
import 'package:firebase_orscheduler/utils/sample_data_generator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Developer settings screen with tools for testing and sample data manipulation
class DeveloperSettingsScreen extends StatefulWidget {
  const DeveloperSettingsScreen({super.key});

  @override
  State<DeveloperSettingsScreen> createState() =>
      _DeveloperSettingsScreenState();
}

class _DeveloperSettingsScreenState extends State<DeveloperSettingsScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _csvPreviewData;
  int _totalValidRows = 0;
  int _totalErrorRows = 0;
  List<Map<String, dynamic>> _conflicts = [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Tools'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error message if any
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.error),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => _errorMessage = null),
                            color: theme.colorScheme.error,
                          ),
                        ],
                      ),
                    ),

                  // Sample Data Section
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sample Data',
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          const Text(
                            'Generate test data for development and testing purposes.',
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Sample Surgeries'),
                                  onPressed: _addSampleSurgeries,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Clear All Surgeries'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.error,
                                    foregroundColor: theme.colorScheme.onError,
                                  ),
                                  onPressed: _confirmClearSurgeries,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // CSV Import Section
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CSV Data Import',
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          const Text(
                            'Import surgery data from a CSV file with the following columns:',
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              CsvDataProcessor.expectedHeaders.join(', '),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Multi-value fields (nurses, technologists, room) should use pipe (|) as separator.',
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Select CSV File'),
                                  onPressed: _selectCsvFile,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.download),
                                  label: const Text('Download Sample CSV'),
                                  onPressed: _downloadSampleCsv,
                                ),
                              ),
                            ],
                          ),

                          // CSV Preview
                          if (_csvPreviewData != null) ...[
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('CSV Preview',
                                    style: theme.textTheme.titleMedium),
                                Text(
                                  'Valid: $_totalValidRows | Errors: $_totalErrorRows',
                                  style: TextStyle(
                                    color: _totalErrorRows > 0
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildCsvPreview(),

                            // Conflicts section
                            if (_conflicts.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Scheduling Conflicts (${_conflicts.length})',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildConflictsPreview(),
                            ],

                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.save),
                                    label: Text(_conflicts.isNotEmpty
                                        ? 'Import Anyway (${(_csvPreviewData!['data'] as List).length} items)'
                                        : 'Import Data (${(_csvPreviewData!['data'] as List).length} items)'),
                                    onPressed: _importCsvData,
                                    style: _conflicts.isNotEmpty
                                        ? ElevatedButton.styleFrom(
                                            backgroundColor: theme
                                                .colorScheme.errorContainer,
                                            foregroundColor: theme
                                                .colorScheme.onErrorContainer,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => setState(() {
                                    _csvPreviewData = null;
                                    _conflicts = [];
                                  }),
                                  tooltip: 'Cancel import',
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // System Information
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('System Information',
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 16),
                          _buildInfoRow('Flutter Version', '3.22.0'),
                          _buildInfoRow(
                              'Firebase Project', 'flutter-orscheduler'),
                          _buildInfoRow('App Version', '1.0.0'),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reset App Settings'),
                            onPressed: _resetAppSettings,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Builds a system information row
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// Builds a preview of the CSV data
  Widget _buildCsvPreview() {
    if (_csvPreviewData == null) return const SizedBox();

    final headers = _csvPreviewData!['headers'] as List;
    final data = _csvPreviewData!['data'] as List;
    final errors = _csvPreviewData!['errors'] as List;

    // Only show first 5 items for preview
    final previewData = data.take(5).toList();
    final previewErrors = errors.take(5).toList();

    return Column(
      children: [
        // Valid data preview
        if (previewData.isNotEmpty) ...[
          const Text('Valid Rows (Preview):'),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              headingRowColor: MaterialStateProperty.all(
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
              ),
              columns: [
                const DataColumn(label: Text('#')),
                const DataColumn(label: Text('Patient')),
                const DataColumn(label: Text('Surgery')),
                const DataColumn(label: Text('Date/Time')),
                const DataColumn(label: Text('Room')),
                const DataColumn(label: Text('Surgeon')),
              ],
              rows: previewData.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                // Handle different timestamp formats safely
                DateTime startTime;
                if (item['startTime'] is Timestamp) {
                  startTime = (item['startTime'] as Timestamp).toDate();
                } else if (item['startTime'] is DateTime) {
                  startTime = item['startTime'] as DateTime;
                } else {
                  startTime = DateTime.now(); // Fallback
                }

                return DataRow(cells: [
                  DataCell(Text((i + 1).toString())),
                  DataCell(Text(item['patientName'])),
                  DataCell(Text(item['surgeryType'])),
                  DataCell(Text(
                      '${startTime.month}/${startTime.day} ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}')),
                  DataCell(Text((item['room'] as List).join(', '))),
                  DataCell(Text(item['surgeon'])),
                ]);
              }).toList(),
            ),
          ),
        ],

        // Error data preview
        if (previewErrors.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Error Rows (Preview):',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              headingRowColor: MaterialStateProperty.all(
                Theme.of(context).colorScheme.errorContainer.withOpacity(0.4),
              ),
              columns: const [
                DataColumn(label: Text('Row')),
                DataColumn(label: Text('Error')),
              ],
              rows: previewErrors.map((error) {
                return DataRow(cells: [
                  DataCell(Text(error['row'].toString())),
                  DataCell(Text(error['error'])),
                ]);
              }).toList(),
            ),
          ),
          if (errors.length > 5)
            Text(
              '...and ${errors.length - 5} more errors',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ],
    );
  }

  /// Builds a preview of scheduling conflicts
  Widget _buildConflictsPreview() {
    // Show first 5 conflicts
    final previewConflicts = _conflicts.take(5).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 12,
        headingRowColor: MaterialStateProperty.all(
          Theme.of(context).colorScheme.errorContainer.withOpacity(0.4),
        ),
        columns: const [
          DataColumn(label: Text('Patient')),
          DataColumn(label: Text('Time')),
          DataColumn(label: Text('Reason')),
        ],
        rows: previewConflicts.map((conflict) {
          final surgery = conflict['surgery'];
          // Handle different timestamp formats safely
          DateTime startTime;
          if (surgery['startTime'] is Timestamp) {
            startTime = (surgery['startTime'] as Timestamp).toDate();
          } else if (surgery['startTime'] is DateTime) {
            startTime = surgery['startTime'] as DateTime;
          } else {
            startTime = DateTime.now(); // Fallback
          }

          return DataRow(cells: [
            DataCell(Text(surgery['patientName'])),
            DataCell(Text(
                '${startTime.month}/${startTime.day} ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}')),
            DataCell(Text(conflict['reason'])),
          ]);
        }).toList(),
      ),
    );
  }

  /// Add sample surgeries
  Future<void> _addSampleSurgeries() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Show count selector dialog
      final count = await _showCountSelectorDialog();
      if (count == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Add sample surgeries
      await SampleDataGenerator.addSampleSurgeries(count: count);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$count sample surgeries added successfully!')),
        );
      }
    } catch (e) {
      setState(() =>
          _errorMessage = 'Error adding sample surgeries: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Downloads the sample CSV file to the device
  Future<void> _downloadSampleCsv() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load sample CSV from assets
      final data =
          await rootBundle.loadString('assets/samples/sample_surgeries.csv');

      if (data.isEmpty) {
        throw Exception('Sample CSV file is empty');
      }

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/sample_surgeries.csv';
      final file = File(filePath);
      await file.writeAsString(data);

      // Save to downloads directory on native platforms
      // On web, this would trigger a download instead
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sample CSV saved to downloads folder'),
          action: SnackBarAction(
            label: 'OPEN',
            onPressed: () {
              // On mobile, this would open the file
              // On web, this would do nothing as the file is already downloaded
            },
          ),
        ),
      );
    } catch (e) {
      setState(() =>
          _errorMessage = 'Error downloading sample CSV: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Confirm clearing all surgeries
  Future<void> _confirmClearSurgeries() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
            'This will delete ALL surgeries in the database. This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE ALL'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clearAllSurgeries();
    }
  }

  /// Clear all surgeries
  Future<void> _clearAllSurgeries() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await SampleDataGenerator.clearAllSurgeries();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All surgeries deleted successfully')),
        );
      }
    } catch (e) {
      setState(
          () => _errorMessage = 'Error clearing surgeries: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Select and process a CSV file
  Future<void> _selectCsvFile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _csvPreviewData = null;
        _conflicts = [];
      });

      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Read file content
      final fileBytes = result.files.first.bytes;
      if (fileBytes == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not read file. Please try again.';
        });
        return;
      }

      final csvString = utf8.decode(fileBytes);

      // Parse and validate CSV
      final parseResult = await CsvDataProcessor.parseAndValidateCsv(csvString);

      // Check for scheduling conflicts
      List<Map<String, dynamic>> conflicts = [];
      if ((parseResult['data'] as List).isNotEmpty) {
        conflicts = await CsvDataProcessor.checkSchedulingConflicts(
            List<Map<String, dynamic>>.from(parseResult['data']));
      }

      setState(() {
        _csvPreviewData = parseResult;
        _totalValidRows = (parseResult['data'] as List).length;
        _totalErrorRows = (parseResult['errors'] as List).length;
        _conflicts = conflicts;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Error processing CSV: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Import CSV data to Firestore
  Future<void> _importCsvData() async {
    if (_csvPreviewData == null || (_csvPreviewData!['data'] as List).isEmpty) {
      setState(() => _errorMessage = 'No valid data to import');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Confirm if there are conflicts
      if (_conflicts.isNotEmpty) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Scheduling Conflicts'),
            content: Text(
                'There are ${_conflicts.length} scheduling conflicts with existing surgeries. '
                'Importing anyway may cause double-booking issues. Continue?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('IMPORT ANYWAY'),
              ),
            ],
          ),
        );

        if (confirmed != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      // Import data
      final result = await CsvDataProcessor.importSurgeries(
          List<Map<String, dynamic>>.from(_csvPreviewData!['data']));

      // Display results
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Imported ${result['success']} surgeries successfully. '
                '${result['errors'].length > 0 ? '${result['errors'].length} errors.' : ''}'),
          ),
        );

        setState(() {
          _csvPreviewData = null;
          _conflicts = [];
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error importing data: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Reset app settings
  Future<void> _resetAppSettings() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App settings reset successfully')),
        );
      }
    } catch (e) {
      setState(
          () => _errorMessage = 'Error resetting settings: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Shows a dialog to select the count of surgeries to add
  Future<int?> _showCountSelectorDialog() async {
    return showDialog<int>(
      context: context,
      builder: (context) {
        int selectedCount = 20;

        return AlertDialog(
          title: const Text('Add Sample Surgeries'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select the number of sample surgeries to add:'),
                  const SizedBox(height: 16),
                  Slider(
                    value: selectedCount.toDouble(),
                    min: 5,
                    max: 100,
                    divisions: 19,
                    label: selectedCount.toString(),
                    onChanged: (value) {
                      setState(() {
                        selectedCount = value.round();
                      });
                    },
                  ),
                  Text(
                    '$selectedCount surgeries',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, selectedCount),
              child: const Text('ADD'),
            ),
          ],
        );
      },
    );
  }
}
