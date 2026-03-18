#!/usr/bin/env node
// =============================================================================
// Firebase Emulator Seed Script
// =============================================================================
// Seeds the local Firebase emulators with test data for development.
//
// Usage:
//   node scripts/seed.js           # Seed with default data
//   node scripts/seed.js --reset   # Clear emulators then seed
//
// Default test credentials:
//   Email:    doctor@test.com    Password: password123    Role: Doctor
//   Email:    nurse@test.com     Password: password123    Role: Nurse
//   Email:    tech@test.com      Password: password123    Role: Technologist
//   Email:    admin@test.com     Password: password123    Role: Admin
// =============================================================================

const http = require('http');

const CONFIG = {
  authHost: 'localhost',
  authPort: 9099,
  firestoreHost: 'localhost',
  firestorePort: 8181,
  projectId: 'flutter-orscheduler',
};

// ---------------------------------------------------------------------------
// HTTP helpers
// ---------------------------------------------------------------------------

function httpRequest(host, port, method, path, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const opts = {
      hostname: host,
      port,
      path,
      method,
      headers: { 'Content-Type': 'application/json', ...headers },
    };
    const req = http.request(opts, (res) => {
      let data = '';
      res.on('data', (c) => (data += c));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, data });
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(typeof body === 'string' ? body : JSON.stringify(body));
    req.end();
  });
}

// ---------------------------------------------------------------------------
// Auth helpers
// ---------------------------------------------------------------------------

async function signUp(email, password, displayName) {
  const res = await httpRequest(
    CONFIG.authHost,
    CONFIG.authPort,
    'POST',
    '/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key',
    { email, password, displayName, returnSecureToken: true }
  );
  if (res.status < 400) return res.data;

  // If user exists, sign in instead
  if (res.data?.error?.message === 'EMAIL_EXISTS') {
    const signInRes = await httpRequest(
      CONFIG.authHost,
      CONFIG.authPort,
      'POST',
      '/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key',
      { email, password, returnSecureToken: true }
    );
    if (signInRes.status < 400) return signInRes.data;
    throw new Error(`Sign-in failed for ${email}: ${JSON.stringify(signInRes.data)}`);
  }
  throw new Error(`Sign-up failed for ${email}: ${JSON.stringify(res.data)}`);
}

async function clearAuth() {
  await httpRequest(
    CONFIG.authHost,
    CONFIG.authPort,
    'DELETE',
    `/emulator/v1/projects/${CONFIG.projectId}/accounts`,
    null
  );
}

// ---------------------------------------------------------------------------
// Firestore helpers
// ---------------------------------------------------------------------------

function toVal(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'number')
    return Number.isInteger(v)
      ? { integerValue: String(v) }
      : { doubleValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v))
    return { arrayValue: { values: v.map(toVal) } };
  if (typeof v === 'object') {
    const fields = {};
    for (const [k, val] of Object.entries(v)) fields[k] = toVal(val);
    return { mapValue: { fields } };
  }
  return { stringValue: String(v) };
}

async function putDoc(collection, docId, data, token) {
  const fields = {};
  for (const [k, v] of Object.entries(data)) fields[k] = toVal(v);
  const path = `/v1/projects/${CONFIG.projectId}/databases/(default)/documents/${collection}/${docId}`;
  const res = await httpRequest(
    CONFIG.firestoreHost,
    CONFIG.firestorePort,
    'PATCH',
    path,
    { fields },
    token ? { Authorization: `Bearer ${token}` } : {}
  );
  if (res.status >= 400)
    console.error(`  FAIL ${collection}/${docId} (${res.status})`);
  else console.log(`  OK   ${collection}/${docId}`);
}

async function clearFirestore() {
  await httpRequest(
    CONFIG.firestoreHost,
    CONFIG.firestorePort,
    'DELETE',
    `/emulator/v1/projects/${CONFIG.projectId}/databases/(default)/documents`,
    null
  );
}

// ---------------------------------------------------------------------------
// Seed data definitions
// ---------------------------------------------------------------------------

const USERS = [
  {
    email: 'doctor@test.com',
    password: 'password123',
    displayName: 'Dr. Sarah Patel',
    profile: {
      firstName: 'Sarah',
      lastName: 'Patel',
      role: 'Doctor',
      department: 'Cardiology',
      phoneNumber: '+1 (555) 100-0001',
      profileImageUrl: '',
      selectedDefaultAvatar: '',
    },
  },
  {
    email: 'nurse@test.com',
    password: 'password123',
    displayName: 'Maya Johnson',
    profile: {
      firstName: 'Maya',
      lastName: 'Johnson',
      role: 'Nurse',
      department: 'Surgery',
      phoneNumber: '+1 (555) 100-0002',
      profileImageUrl: '',
      selectedDefaultAvatar: '',
    },
  },
  {
    email: 'tech@test.com',
    password: 'password123',
    displayName: 'Alex Rivera',
    profile: {
      firstName: 'Alex',
      lastName: 'Rivera',
      role: 'Technologist',
      department: 'Surgery',
      phoneNumber: '+1 (555) 100-0003',
      profileImageUrl: '',
      selectedDefaultAvatar: '',
    },
  },
  {
    email: 'admin@test.com',
    password: 'password123',
    displayName: 'Jane Admin',
    profile: {
      firstName: 'Jane',
      lastName: 'Admin',
      role: 'Admin',
      department: 'Operations',
      phoneNumber: '+1 (555) 100-0004',
      profileImageUrl: '',
      selectedDefaultAvatar: '',
    },
  },
];

function buildSurgeries(doctorUid) {
  const now = new Date();
  const day = (offset) => {
    const d = new Date(now);
    d.setDate(d.getDate() + offset);
    return d;
  };
  const at = (offset, h, m = 0) => {
    const d = day(offset);
    d.setHours(h, m, 0, 0);
    return d;
  };

  return [
    {
      id: 'surg-001',
      data: {
        patientName: 'John Smith',
        patientId: 'MRN100001',
        patientAge: 45,
        patientGender: 'Male',
        surgeryType: 'Cardiac Surgery',
        doctorId: doctorUid,
        surgeon: 'Dr. Sarah Patel',
        dateTime: at(1, 9),
        startTime: at(1, 9),
        endTime: at(1, 11),
        roomId: 'OperatingRoom1',
        room: ['OperatingRoom1'],
        duration: 120,
        status: 'Scheduled',
        type: 'Cardiac Surgery',
        notes: 'Patient has penicillin allergy. NPO after midnight.',
        nurses: ['Maya Johnson'],
        technologists: ['Alex Rivera'],
        prepTimeMinutes: 30,
        cleanupTimeMinutes: 30,
        requiredEquipment: [],
        equipmentRequirements: [],
        customTimeFrames: {},
        customTimeBlocks: [],
      },
    },
    {
      id: 'surg-002',
      data: {
        patientName: 'Maria Garcia',
        patientId: 'MRN100002',
        patientAge: 62,
        patientGender: 'Female',
        surgeryType: 'Orthopedic Surgery',
        doctorId: doctorUid,
        surgeon: 'Dr. Sarah Patel',
        dateTime: at(3, 14),
        startTime: at(3, 14),
        endTime: at(3, 16, 30),
        roomId: 'OperatingRoom2',
        room: ['OperatingRoom2'],
        duration: 150,
        status: 'Scheduled',
        type: 'Orthopedic Surgery',
        notes: 'Hip replacement — right side. Pre-op labs required.',
        nurses: ['Maya Johnson'],
        technologists: ['Alex Rivera'],
        prepTimeMinutes: 45,
        cleanupTimeMinutes: 30,
        requiredEquipment: [],
        equipmentRequirements: [],
        customTimeFrames: {},
        customTimeBlocks: [],
      },
    },
    {
      id: 'surg-003',
      data: {
        patientName: 'Robert Chen',
        patientId: 'MRN100003',
        patientAge: 38,
        patientGender: 'Male',
        surgeryType: 'General Surgery',
        doctorId: doctorUid,
        surgeon: 'Dr. Sarah Patel',
        dateTime: at(-2, 10),
        startTime: at(-2, 10),
        endTime: at(-2, 11, 30),
        roomId: 'OperatingRoom3',
        room: ['OperatingRoom3'],
        duration: 90,
        status: 'Completed',
        type: 'General Surgery',
        notes: 'Appendectomy — completed successfully.',
        nurses: ['Maya Johnson'],
        technologists: ['Alex Rivera'],
        prepTimeMinutes: 20,
        cleanupTimeMinutes: 20,
        requiredEquipment: [],
        equipmentRequirements: [],
        customTimeFrames: {},
        customTimeBlocks: [],
      },
    },
    {
      id: 'surg-004',
      data: {
        patientName: 'Emily Park',
        patientId: 'MRN100004',
        patientAge: 29,
        patientGender: 'Female',
        surgeryType: 'Neurosurgery',
        doctorId: doctorUid,
        surgeon: 'Dr. Sarah Patel',
        dateTime: at(-5, 8),
        startTime: at(-5, 8),
        endTime: at(-5, 11),
        roomId: 'OperatingRoom4',
        room: ['OperatingRoom4'],
        duration: 180,
        status: 'Cancelled',
        type: 'Neurosurgery',
        notes: 'Cancelled — patient requested postponement.',
        nurses: ['Maya Johnson'],
        technologists: ['Alex Rivera'],
        prepTimeMinutes: 60,
        cleanupTimeMinutes: 30,
        requiredEquipment: [],
        equipmentRequirements: [],
        customTimeFrames: {},
        customTimeBlocks: [],
      },
    },
    {
      id: 'surg-005',
      data: {
        patientName: 'David Williams',
        patientId: 'MRN100005',
        patientAge: 55,
        patientGender: 'Male',
        surgeryType: 'Plastic Surgery',
        doctorId: doctorUid,
        surgeon: 'Dr. Sarah Patel',
        dateTime: at(0, 14),
        startTime: at(0, 14),
        endTime: at(0, 16),
        roomId: 'OperatingRoom5',
        room: ['OperatingRoom5'],
        duration: 120,
        status: 'In Progress',
        type: 'Plastic Surgery',
        notes: 'Reconstructive procedure following trauma.',
        nurses: ['Maya Johnson'],
        technologists: ['Alex Rivera'],
        prepTimeMinutes: 30,
        cleanupTimeMinutes: 30,
        requiredEquipment: [],
        equipmentRequirements: [],
        customTimeFrames: {},
        customTimeBlocks: [],
      },
    },
  ];
}

const EQUIPMENT = [
  { id: 'eq-001', name: 'Surgical Microscope', category: 'Optical', locationId: 'storage-a', isAvailable: true, specifications: {} },
  { id: 'eq-002', name: 'Anesthesia Machine', category: 'Critical', locationId: 'or-2', isAvailable: true, specifications: {} },
  { id: 'eq-003', name: 'Patient Monitor', category: 'Monitoring', locationId: 'or-1', isAvailable: true, specifications: {} },
  { id: 'eq-004', name: 'Electrosurgical Unit', category: 'Surgical', locationId: 'or-3', isAvailable: true, specifications: {} },
  { id: 'eq-005', name: 'Defibrillator', category: 'Critical', locationId: 'emergency', isAvailable: true, specifications: {} },
  { id: 'eq-006', name: 'Ventilator', category: 'Critical', locationId: 'icu', isAvailable: false, specifications: {} },
  { id: 'eq-007', name: 'Infusion Pump', category: 'Medication', locationId: 'or-2', isAvailable: true, specifications: {} },
  { id: 'eq-008', name: 'Surgical Lights', category: 'General', locationId: 'or-4', isAvailable: true, specifications: {} },
  { id: 'eq-009', name: 'Ultrasound Scanner', category: 'Imaging', locationId: 'radiology', isAvailable: true, specifications: {} },
  { id: 'eq-010', name: 'Suction Machine', category: 'General', locationId: 'storage-b', isAvailable: true, specifications: {} },
];

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  const shouldReset = process.argv.includes('--reset');

  console.log('');
  console.log('  OR Scheduler — Firebase Emulator Seed');
  console.log('  =====================================');
  console.log('');

  // Check emulators are running
  try {
    await httpRequest(CONFIG.authHost, CONFIG.authPort, 'GET', '/', null);
  } catch {
    console.error('  ERROR: Firebase emulators are not running.');
    console.error('  Start them with: make emulators');
    console.error('');
    process.exit(1);
  }

  if (shouldReset) {
    console.log('  [reset] Clearing all emulator data...');
    await clearAuth();
    await clearFirestore();
    console.log('  [reset] Done.\n');
  }

  // 1. Create auth users and collect UIDs/tokens
  console.log('  [1/4] Auth users');
  const authResults = {};
  for (const u of USERS) {
    try {
      const result = await signUp(u.email, u.password, u.displayName);
      authResults[u.email] = result;
      console.log(`  OK   ${u.email} (${u.profile.role}) uid=${result.localId}`);
    } catch (e) {
      console.error(`  FAIL ${u.email}: ${e.message}`);
    }
  }

  const primaryUser = authResults['doctor@test.com'];
  if (!primaryUser) {
    console.error('\n  Cannot continue without primary user.\n');
    process.exit(1);
  }

  // 2. Create user profiles
  console.log('\n  [2/4] User profiles');
  for (const u of USERS) {
    const auth = authResults[u.email];
    if (!auth) continue;
    await putDoc(
      'users',
      auth.localId,
      { ...u.profile, email: u.email },
      auth.idToken
    );
  }

  // 3. Create surgeries
  console.log('\n  [3/4] Surgeries');
  const surgeries = buildSurgeries(primaryUser.localId);
  for (const s of surgeries) {
    await putDoc('surgeries', s.id, s.data, primaryUser.idToken);
  }

  // 4. Create equipment
  console.log('\n  [4/4] Equipment');
  for (const eq of EQUIPMENT) {
    const { id, ...data } = eq;
    await putDoc('equipment', id, data, primaryUser.idToken);
  }

  console.log('');
  console.log('  =====================================');
  console.log('  Seed complete!');
  console.log('');
  console.log('  Login credentials:');
  console.log('    Doctor:       doctor@test.com / password123');
  console.log('    Nurse:        nurse@test.com  / password123');
  console.log('    Technologist: tech@test.com   / password123');
  console.log('    Admin:        admin@test.com  / password123');
  console.log('');
  console.log('  Emulator UI: http://localhost:4000');
  console.log('');
}

main().catch((e) => {
  console.error('Seed failed:', e);
  process.exit(1);
});
