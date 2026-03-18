enum UserRole {
  doctor('Doctor'),
  nurse('Nurse'),
  technologist('Technologist'),
  admin('Admin');

  const UserRole(this.displayName);
  final String displayName;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
        return UserRole.doctor;
      case 'nurse':
        return UserRole.nurse;
      case 'technologist':
        return UserRole.technologist;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.doctor;
    }
  }
}
