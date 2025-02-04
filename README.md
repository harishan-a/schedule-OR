# OR Scheduler - Operating Room Management System

## Table of Contents
1. [Introduction](#introduction)
   - [Problem Statement](#problem-statement)
   - [Solution Overview](#solution-overview)
2. [Project Context](#project-context)
   - [Academic Details](#academic-details)
   - [Development Team](#development-team)
3. [Project Structure](#project-structure)
   - [Root Directory Structure](#root-directory-structure)
   - [Source Code Organization](#source-code-organization-lib)
   - [Feature Module Structure](#feature-module-structure)
4. [Setup Instructions](#setup-instructions)
   - [Prerequisites](#prerequisites)
   - [Environment Setup](#environment-setup)
   - [Firebase Setup](#firebase-setup)
   - [Running the Application](#running-the-application)
5. [Firebase Integration](#firebase-integration)
   - [Core Firebase Services](#core-firebase-services)
   - [Security Rules](#security-rules)
6. [Dependencies](#dependencies)
   - [Key Dependencies](#key-dependencies)
7. [Usage Guide](#usage-guide)
   - [Running the Application](#running-the-application-1)
   - [Development Environment](#development-environment)
8. [Additional Resources](#additional-resources)

## Introduction

The Operating Room (OR) Scheduler is a comprehensive mobile application developed to streamline and optimize the management of operating room resources in healthcare facilities. This project addresses critical challenges in healthcare operations, including resource allocation, staff scheduling, and real-time communication among medical personnel.

### Problem Statement
Healthcare facilities often face significant challenges in operating room management:
- Inefficient resource allocation leading to underutilized operating rooms
- Communication gaps between surgical teams and support staff
- Manual scheduling processes prone to errors and conflicts
- Difficulty in tracking real-time status updates and changes
- Complex compliance requirements with healthcare privacy regulations

### Solution Overview
Our application provides a modern solution that enables:
- Real-time scheduling and resource management
- Automated conflict detection and resolution
- Instant notifications and status updates
- Secure data handling

## Project Context
This application is our final year capstone engineering project at Carleton University.

### Academic Details
- **Course**: SYSC4907 - Engineering Project
- **Institution**: Carleton University, Ottawa, Canada
- **Academic Year**: 2024-2025
- **Project Supervisor**: Professor Lynn Marshall

### Development Team
**Group #20**
- **Nikita Sara Vijay** (101195009)

- **Faiaz Ahsan** (101120268)

- **Keya Patel** (101191689)

- **Evan Baldwin** (101222276)

- **Harishan Amutheesan** (101154757)



## Project Structure

The OR Scheduler follows a feature-first architecture pattern, organizing code by feature rather than by type. This approach improves maintainability, testability, and scalability of the application.

### Root Directory Structure
```
or-scheduler/
├── android/          # Android platform-specific code
├── ios/             # iOS platform-specific code
├── web/             # Web platform configuration and assets
├── linux/           # Linux platform configuration
├── macos/           # macOS platform configuration
├── windows/         # Windows platform configuration
├── assets/          # Application assets (images, fonts, etc.)
│   └── images/      # Image assets including logos and icons
├── lib/             # Main Dart source code
├── test/            # Application tests
└── UML Diagrams/    # Architecture and design documentation
```

### Source Code Organization (`lib/`)
```
lib/
├── config/                 # Application configuration
│   └── firebase_options.dart   # Firebase platform configurations
├── core/                  # Core utilities and constants
│   ├── constants/         # Application-wide constants
│   └── theme/            # Base theme configurations
├── features/             # Feature modules
│   ├── auth/            # Authentication feature
│   ├── doctor/          # Doctor management
│   ├── home/            # Home screen and dashboard
│   ├── profile/         # User profile management
│   ├── schedule/        # Scheduling system
│   ├── settings/        # Application settings
│   └── surgery/         # Surgery management
└── shared/              # Shared components and utilities
    ├── models/          # Shared data models
    ├── theme/           # Theme configuration
    ├── utils/           # Utility functions
    └── widgets/         # Reusable widgets
```

### Feature Module Structure
Each feature module follows a consistent organization:

#### Authentication (`features/auth/`)
```
auth/
└── screens/
    └── auth.dart        # Authentication screen implementation
```

#### Doctor Management (`features/doctor/`)
```
doctor/
└── screens/
    ├── doctor_details.dart    # Doctor details view
    ├── doctor_page.dart       # Main doctor listing
    ├── filter_screen.dart     # Doctor filtering options
    └── staff_details.dart     # Staff member details
```

#### Home Dashboard (`features/home/`)
```
home/
├── models/
│   ├── surgery_summary.dart   # Surgery summary data model
│   └── user_stats.dart        # User statistics model
├── screens/
│   └── home.dart             # Home screen implementation
├── services/
│   └── home_service.dart     # Home screen business logic
└── widgets/
    ├── activity_card.dart    # Activity display widget
    ├── announcement_card.dart # Announcements widget
    └── stat_card.dart        # Statistics display widget
```

#### Schedule Management (`features/schedule/`)
```
schedule/
├── models/
│   └── surgery.dart          # Surgery data model
├── screens/
│   ├── schedule.dart         # Main schedule screen
│   ├── schedule_view_*.dart  # Various schedule views
│   ├── resource_check.dart   # Resource availability
│   └── surgery_details.dart  # Surgery details view
├── services/
│   └── resource_check_service.dart  # Resource management logic
└── widgets/
    ├── list_view_content.dart      # List view implementation
    ├── month_view_content.dart     # Month view implementation
    └── week_view_content.dart      # Week view implementation
```

#### Surgery Management (`features/surgery/`)
```
surgery/
├── screens/
│   ├── add_surgery.dart      # Surgery creation screen
│   ├── surgery_details.dart  # Surgery details view
│   └── surgery_log.dart      # Surgery history log
└── widgets/
    └── surgery_list.dart     # Surgery listing widget
```

### Shared Components (`shared/`)
```
shared/
├── models/                # Shared data models
├── theme/
│   └── app_theme.dart    # Application theme configuration
├── utils/
│   └── formatters.dart   # Data formatting utilities
└── widgets/
    ├── custom_navigation_bar.dart  # Navigation bar component
    └── splash.dart                 # Splash screen widget
```

### Configuration Files
```
Root/
├── .firebaserc              # Firebase project configuration
├── firebase.json            # Firebase hosting configuration
├── firestore.indexes.json   # Firestore index definitions
├── firestore.rules          # Firestore security rules
├── pubspec.yaml             # Dart dependencies and assets
└── analysis_options.yaml    # Dart analyzer configuration
```


## Setup Instructions

### Prerequisites

Before setting up the OR Scheduler, ensure you have the following installed:

#### Required Software
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.16.0 or higher)
- [Dart SDK](https://dart.dev/get-dart) (version 3.2.0 or higher)
- [Git](https://git-scm.com/downloads) for version control
- [Firebase CLI](https://firebase.google.com/docs/cli#install_the_firebase_cli) for Firebase configuration

#### IDE Setup
We recommend using either:
- [Visual Studio Code](https://code.visualstudio.com/) with the following extensions:
  - Flutter extension
  - Dart extension
  - Firebase extension
- [Android Studio](https://developer.android.com/studio) with the Flutter plugin

#### Platform-specific Requirements
- **Android Development:**
  - Android Studio
  - Android SDK
  - Android Emulator or physical device
- **iOS Development:**
  - macOS computer
  - Xcode (latest version)
  - CocoaPods
  - iOS Simulator or physical device

### Environment Setup

1. **Clone the Repository**
   ```bash
   git clone https://github.com/harishan-a/schedule-OR
   cd or-scheduler
   ```

2. **Install Flutter Dependencies**
   ```bash
   # Get all dependencies listed in pubspec.yaml
   flutter pub get
   
   # Run Flutter doctor to verify setup
   flutter doctor
   ```

3. **IDE Configuration**
   - Open the project in your IDE
   - Ensure Flutter and Dart plugins are installed
   - Configure Flutter SDK path
   - Set up code formatting and analysis options

### Firebase Setup

1. **Create Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project named "OR-Scheduler"
   - Enable required services (Authentication, Firestore, Cloud Messaging)

2. **Configure Firebase in the App**
   ```bash
   # Install Firebase CLI if not already installed
   npm install -g firebase-tools
   
   # Login to Firebase
   firebase login
   
   # Initialize Firebase in the project
   firebase init
   ```

3. **Set Up Firebase Configuration**
   - Copy the generated Firebase configuration from the Firebase Console
   - Update `lib/config/firebase_options.dart` with your configuration
   - For security, use environment variables for sensitive values:
     ```dart
     // Example using environment variables
     apiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
     ```

4. **Configure Firestore**
   - Deploy security rules:
     ```bash
     firebase deploy --only firestore:rules
     ```
   - Deploy indexes:
     ```bash
     firebase deploy --only firestore:indexes
     ```

5. **Firebase Security Rules**
   The project includes predefined security rules in `firestore.rules`:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // Add your security rules here
     }
   }
   ```

6. **Firebase Indexes**
   Deploy the required indexes defined in `firestore.indexes.json`:
   ```json
   {
     "indexes": [
       {
         "collectionGroup": "surgeries",
         "queryScope": "COLLECTION",
         "fields": [
           { "fieldPath": "status", "order": "ASCENDING" },
           { "fieldPath": "startTime", "order": "ASCENDING" }
         ]
       }
     ]
   }
   ```


### Running the Application

#### Development Mode
```bash
# Run with debug mode
flutter run

# Run with specific device
flutter run -d <device-id>

# Run with release mode
flutter run --release
```

#### Building for Production
```bash
# Build Android APK
flutter build apk --release

# Build iOS IPA (on macOS)
flutter build ios --release

# Build Web
flutter build web --release
```

#### Running Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage
```

#### Core Firebase Services

1. **Cloud Firestore**
   - Real-time database for surgery and resource management
   - Collection structure:
     ```
     firestore/
     ├── surgeries/           # Surgery records
     ├── doctors/             # Doctor profiles
     ├── schedules/           # Operating room schedules
     ├── resources/           # Equipment and room data
     └── users/               # User profiles and preferences
     ```
   - Indexing configuration (`firestore.indexes.json`):
     ```json
     {
       "indexes": [
         {
           "collectionGroup": "surgeries",
           "queryScope": "COLLECTION",
           "fields": [
             { "fieldPath": "status", "order": "ASCENDING" },
             { "fieldPath": "startTime", "order": "ASCENDING" }
           ]
         }
       ]
     }
     ```

2. **Firebase Authentication**
   - Multi-role user authentication (doctors, staff, administrators)
   - Security rules integration:
     ```javascript
     match /users/{userId} {
       allow read: if request.auth.uid == userId;
       allow write: if request.auth.uid == userId 
         && request.resource.data.role in ['doctor', 'staff', 'admin'];
     }
     ```

3. **Cloud Messaging (FCM)**
   - Real-time notifications for:
     - Schedule changes
     - Emergency surgeries
     - Resource availability updates
   - Topic-based messaging for role-specific notifications

4. **Security Rules**
   - PHIPA-compliant access controls
   - Role-based permissions
   - Data validation rules
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // Global functions
       function isAuthenticated() {
         return request.auth != null;
       }
       
       function hasRole(role) {
         return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == role;
       }
       
       // Surgery collection rules
       match /surgeries/{surgeryId} {
         allow read: if isAuthenticated();
         allow write: if hasRole('admin') || hasRole('doctor');
       }
     }
   }
   ```

#### Key Dependencies

```yaml
dependencies:
  # State Management
  provider: ^6.0.0
  
  # Firebase Integration
  firebase_core: ^2.24.0
  cloud_firestore: ^4.13.3
  firebase_auth: ^4.15.0
  firebase_messaging: ^14.7.6
  
  # UI Components
  flutter_calendar_view: ^1.0.0
  flutter_local_notifications: ^16.2.0
  
  # Utilities
  intl: ^0.18.1
  shared_preferences: ^2.2.2
```


## Usage Guide

### Running the Application

#### Development Environment
1. **Start the App**
   ```bash
   # Run in debug mode with hot reload
   flutter run

   # Run on a specific device
   flutter run -d <device-id>

   # List available devices
   flutter devices
   ```

2. **Hot Reload & Restart**
   - Press `r` in terminal for hot reload
   - Press `R` for hot restart
   - Press `q` to quit

3. **Build Modes**
   ```bash
   # Debug mode (default)
   flutter run

   # Profile mode (performance testing)
   flutter run --profile

   # Release mode (production testing)
   flutter run --release
   ```

## Additional Resources
- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Flutter Setup Guide](https://firebase.google.com/docs/flutter/setup)
- [Flutter Testing Guide](https://flutter.dev/docs/testing)
- [Firebase Security Rules Guide](https://firebase.google.com/docs/rules)
