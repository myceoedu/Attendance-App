class AppUser {
  final String id;
  final String username;
  final String name;
  final String email;
  final String role; // 'admin' or 'employee'
  final String? phone;
  final DateTime createdAt;
  final DateTime? employmentStartDate;
  final double? annualLeaveEntitlementOverride;

  final String? address;
  final String? maritalStatus;
  final DateTime? dateOfBirth;
  final String? icNumber;
  final String? jobTitle;
  final String? department;
  final String? employeeCode;
  final String? epfNumber;
  final String? socsoNumber;
  final String? bankName;
  final String? bankAccountNumber;
  final String? educationLevel;
  final String? educationInstitution;
  final String? emergencyContactName;
  final String? emergencyContactRelationship;
  final String? emergencyContactPhone;

  AppUser({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    required this.createdAt,
    this.employmentStartDate,
    this.annualLeaveEntitlementOverride,
    this.address,
    this.maritalStatus,
    this.dateOfBirth,
    this.icNumber,
    this.jobTitle,
    this.department,
    this.employeeCode,
    this.epfNumber,
    this.socsoNumber,
    this.bankName,
    this.bankAccountNumber,
    this.educationLevel,
    this.educationInstitution,
    this.emergencyContactName,
    this.emergencyContactRelationship,
    this.emergencyContactPhone,
  });

  bool get isAdmin => role == 'admin';
  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final emp = map['employment_start_date'];
    final overrideRaw = map['annual_leave_entitlement_override'];
    final dob = map['date_of_birth'];
    return AppUser(
      id: map['id'] as String,
      username: map['username'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'employee',
      phone: map['phone'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      employmentStartDate: emp is String ? DateTime.tryParse(emp) : null,
      annualLeaveEntitlementOverride: overrideRaw == null
          ? null
          : (overrideRaw is num
              ? overrideRaw.toDouble()
              : double.tryParse('$overrideRaw')),
      address: map['address'] as String?,
      maritalStatus: map['marital_status'] as String?,
      dateOfBirth: _parseDate(dob),
      icNumber: map['ic_number'] as String?,
      jobTitle: map['job_title'] as String?,
      department: map['department'] as String?,
      employeeCode: map['employee_code'] as String?,
      epfNumber: map['epf_number'] as String?,
      socsoNumber: map['socso_number'] as String?,
      bankName: map['bank_name'] as String?,
      bankAccountNumber: map['bank_account_number'] as String?,
      educationLevel: map['education_level'] as String?,
      educationInstitution: map['education_institution'] as String?,
      emergencyContactName: map['emergency_contact_name'] as String?,
      emergencyContactRelationship:
          map['emergency_contact_relationship'] as String?,
      emergencyContactPhone: map['emergency_contact_phone'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'created_at': createdAt.toIso8601String(),
      if (employmentStartDate != null)
        'employment_start_date': '${employmentStartDate!.year}-'
            '${employmentStartDate!.month.toString().padLeft(2, '0')}-'
            '${employmentStartDate!.day.toString().padLeft(2, '0')}',
      if (annualLeaveEntitlementOverride != null)
        'annual_leave_entitlement_override': annualLeaveEntitlementOverride,
      'address': address,
      'marital_status': maritalStatus,
      if (dateOfBirth != null)
        'date_of_birth': '${dateOfBirth!.year}-'
            '${dateOfBirth!.month.toString().padLeft(2, '0')}-'
            '${dateOfBirth!.day.toString().padLeft(2, '0')}',
      'ic_number': icNumber,
      'job_title': jobTitle,
      'department': department,
      'employee_code': employeeCode,
      'epf_number': epfNumber,
      'socso_number': socsoNumber,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'education_level': educationLevel,
      'education_institution': educationInstitution,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_relationship': emergencyContactRelationship,
      'emergency_contact_phone': emergencyContactPhone,
    };
  }
}
