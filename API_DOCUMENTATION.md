# Attendance System — REST API Specification

A multi-tenant attendance management API built for Flutter Web (Admin Panel) and Flutter Android (Teacher Mobile App).

- **Base URL**: `http://<your-host>:8080` (Local Dev: `http://localhost:8080` / `10.0.2.2:8080` for Android Emulator)
- **Content-Type**: `application/json`
- **Response Format**: Standard Envelope `{ "data": ..., "error": ..., "meta": ... }`

---

## Standard Response Envelope

All API endpoints return JSON wrapped in a standard envelope:

### Success Response (`200 OK`, `201 Created`)
```json
{
  "data": { ... },
  "meta": {
    "page": 1,
    "page_size": 20,
    "total": 45,
    "total_pages": 3
  }
}
```

### Error Response (`400`, `401`, `403`, `404`, `409`, `500`)
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "validation failed",
    "details": [
      {
        "field": "Email",
        "issue": "required"
      }
    ]
  }
}
```

---

## Authorization Header

For protected endpoints (`/api/v1/...`), attach the Access Token received from `/auth/login`:
```http
Authorization: Bearer <access_token>
```

---

## 1. Authentication Endpoints

### 1.1 Login User
Log in an Admin or Teacher into a specific school.

- **Method & Path**: `POST /api/v1/auth/login`
- **Access**: Public
- **Request Body**:
```json
{
  "school_code": "demo-school",
  "email": "priya@demo-school.edu",
  "password": "Teacher@1234"
}
```
- **Response `200 OK`**:
```json
{
  "data": {
    "access_token": "eyJhbGciOiJIUzI1Ni...",
    "refresh_token": "c3VwZXJzZWNyZXR...",
    "expires_in_seconds": 900,
    "user": {
      "id": "a0000000-0000-0000-0000-000000000021",
      "school_id": "a0000000-0000-0000-0000-000000000001",
      "role": "teacher",
      "full_name": "Priya Sharma",
      "email": "priya@demo-school.edu",
      "phone": "+1-555-0100",
      "is_active": true
    }
  }
}
```

---

### 1.2 Refresh Token
Exchange a valid refresh token for a fresh access token.

- **Method & Path**: `POST /api/v1/auth/refresh`
- **Access**: Public
- **Request Body**:
```json
{
  "refresh_token": "c3VwZXJzZWNyZXR..."
}
```
- **Response `200 OK`**:
```json
{
  "data": {
    "access_token": "eyJhbGciOiJIUzI1Ni...",
    "refresh_token": "new_c3VwZXJzZWNyZXR...",
    "expires_in_seconds": 900
  }
}
```

---

### 1.3 Logout
Revoke the refresh token on logout.

- **Method & Path**: `POST /api/v1/auth/logout`
- **Access**: Authenticated (Bearer Token)
- **Request Body**:
```json
{
  "refresh_token": "c3VwZXJzZWNyZXR..."
}
```
- **Response `204 No Content`**

---

### 1.4 Get Profile (`/me`)
Get current authenticated user info.

- **Method & Path**: `GET /api/v1/me`
- **Access**: Authenticated
- **Response `200 OK`**:
```json
{
  "data": {
    "id": "a0000000-0000-0000-0000-000000000021",
    "school_id": "a0000000-0000-0000-0000-000000000001",
    "role": "teacher",
    "full_name": "Priya Sharma",
    "email": "priya@demo-school.edu",
    "phone": "+1-555-0100",
    "is_active": true
  }
}
```

---

## 2. Admin API Endpoints (Flutter Web Client)

---

### 2.1 Classes Management

#### List Classes
- **Method & Path**: `GET /api/v1/classes?page=1&page_size=20`
- **Access**: Admin Only
- **Response `200 OK`**:
```json
{
  "data": [
    {
      "id": "a0000000-0000-0000-0000-000000000040",
      "school_id": "a0000000-0000-0000-0000-000000000001",
      "academic_year_id": "a0000000-0000-0000-0000-000000000010",
      "grade_level": 10,
      "section": "A",
      "created_at": "2026-07-23T03:18:51Z"
    }
  ],
  "meta": { "page": 1, "page_size": 20, "total": 1, "total_pages": 1 }
}
```

#### Create Class
- **Method & Path**: `POST /api/v1/classes`
- **Access**: Admin Only
- **Request Body**:
```json
{
  "academic_year_id": "a0000000-0000-0000-0000-000000000010",
  "grade_level": 10,
  "section": "B"
}
```

#### Delete Class
- **Method & Path**: `DELETE /api/v1/classes/{id}`
- **Access**: Admin Only
- **Response `204 No Content`**

---

### 2.2 Teachers Management

#### List Teachers
- **Method & Path**: `GET /api/v1/teachers?page=1&page_size=20`
- **Access**: Admin Only
- **Response `200 OK`**: List of teacher users.

#### Create Teacher Account
- **Method & Path**: `POST /api/v1/teachers`
- **Access**: Admin Only
- **Request Body**:
```json
{
  "full_name": "Jane Smith",
  "email": "jsmith@demo-school.edu",
  "phone": "+1-555-0199",
  "password": "TeacherPass123!"
}
```

#### Update Teacher Profile
- **Method & Path**: `PUT /api/v1/teachers/{id}`
- **Access**: Admin Only
- **Request Body**:
```json
{
  "full_name": "Jane Smith-Doe",
  "phone": "+1-555-0200"
}
```

#### Deactivate Teacher
- **Method & Path**: `PATCH /api/v1/teachers/{id}/deactivate`
- **Access**: Admin Only
- **Response `204 No Content`**

#### Reactivate Teacher
- **Method & Path**: `PATCH /api/v1/teachers/{id}/activate`
- **Access**: Admin Only
- **Response `204 No Content`**

#### Delete Teacher
- **Method & Path**: `DELETE /api/v1/teachers/{id}`
- **Access**: Admin Only
- **Response `204 No Content`**

#### Reset Teacher Password
- **Method & Path**: `POST /api/v1/teachers/{id}/reset-password`
- **Access**: Admin Only
- **Request Body**:
```json
{
  "new_password": "NewTeacherPassword123!"
}
```

---

### 2.3 Students Management

#### List Students (Filtered by Class / Search)
- **Method & Path**: `GET /api/v1/students?class_id=<uuid>&search=Aarav&page=1&page_size=20`
- **Access**: Admin Only
- **Response `200 OK`**:
```json
{
  "data": [
    {
      "id": "b1000000-0000-0000-0000-000000000001",
      "school_id": "a0000000-0000-0000-0000-000000000001",
      "class_id": "a0000000-0000-0000-0000-000000000040",
      "admission_number": "ADM001",
      "roll_number": "01",
      "full_name": "Aarav Patel",
      "gender": "M",
      "dob": "2010-05-15",
      "guardian_name": "Sanjay Patel",
      "guardian_phone": "+1-555-9988",
      "is_active": true,
      "created_at": "2026-07-23T03:18:51Z"
    }
  ]
}
```

#### Create Student
- **Method & Path**: `POST /api/v1/students`
- **Access**: Admin Only
- **Request Body**:
```json
{
  "class_id": "a0000000-0000-0000-0000-000000000040",
  "admission_number": "ADM010",
  "roll_number": "10",
  "full_name": "Rahul Verma",
  "gender": "M",
  "dob": "2010-08-20",
  "guardian_name": "Sunil Verma",
  "guardian_phone": "+1-555-3344"
}
```

#### Bulk Import Students via CSV
- **Method & Path**: `POST /api/v1/students/bulk-import`
- **Access**: Admin Only
- **Content-Type**: `multipart/form-data` (`file` field with CSV file)
- **CSV Header Format**: `class_id,admission_number,roll_number,full_name,gender`

---

## 3. Attendance & Teacher Mobile API (Android Client)

---

### 3.1 Get Class Student Roster
Get all active students in a specific class for marking attendance.

- **Method & Path**: `GET /api/v1/classes/{class_id}/students?page=1&page_size=100`
- **Access**: Admin & Teacher
- **Response `200 OK`**: List of student objects enrolled in the class.

---

### 3.2 Create or Fetch Attendance Session
Idempotent endpoint: Returns an existing open/closed session or creates a new one for specified `class_id`, `session_date`, and `period_number`.

- **Method & Path**: `POST /api/v1/attendance/sessions`
- **Access**: Admin & Teacher
- **Request Body**:
```json
{
  "class_id": "a0000000-0000-0000-0000-000000000040",
  "session_date": "2026-07-23",
  "period_number": 1
}
```
- **Response `201 Created` / `200 OK`**:
```json
{
  "data": {
    "id": "c1000000-0000-0000-0000-000000000001",
    "school_id": "a0000000-0000-0000-0000-000000000001",
    "class_id": "a0000000-0000-0000-0000-000000000040",
    "teacher_id": "a0000000-0000-0000-0000-000000000021",
    "session_date": "2026-07-23T00:00:00Z",
    "period_number": 1,
    "status": "open",
    "created_at": "2026-07-23T03:30:00Z"
  }
}
```

---

### 3.3 Get Session with Roster & Existing Marks
Retrieve session status along with pre-filled student marks (if already submitted).

- **Method & Path**: `GET /api/v1/attendance/sessions/{session_id}`
- **Access**: Admin & Teacher
- **Response `200 OK`**:
```json
{
  "data": {
    "session": {
      "id": "c1000000-0000-0000-0000-000000000001",
      "status": "open",
      "session_date": "2026-07-23T00:00:00Z",
      "period_number": 1
    },
    "roster": [
      {
        "student_id": "b1000000-0000-0000-0000-000000000001",
        "full_name": "Aarav Patel",
        "roll_number": "01",
        "status": "present",
        "remarks": null
      },
      {
        "student_id": "b1000000-0000-0000-0000-000000000002",
        "full_name": "Diya Sharma",
        "roll_number": "02",
        "status": "absent",
        "remarks": "Sick leave"
      }
    ]
  }
}
```

---

### 3.4 Bulk Mark Attendance
Submit attendance status for multiple students in a session.

- **Method & Path**: `POST /api/v1/attendance/sessions/{session_id}/mark`
- **Access**: Admin & Teacher
- **Status Values**: `"present"`, `"absent"`, `"late"`, `"excused"`
- **Request Body**:
```json
{
  "marks": [
    { "student_id": "b1000000-0000-0000-0000-000000000001", "status": "present" },
    { "student_id": "b1000000-0000-0000-0000-000000000002", "status": "absent", "remarks": "Sick leave" },
    { "student_id": "b1000000-0000-0000-0000-000000000003", "status": "late" }
  ]
}
```
- **Response `200 OK`**: `{ "data": { "message": "attendance marked" } }`

---

### 3.5 Single Student Status Update
Update a single student's attendance record (writes an entry into `attendance_audit_log`).

- **Method & Path**: `PATCH /api/v1/attendance/sessions/{session_id}/mark/{student_id}`
- **Access**: Admin & Teacher
- **Request Body**:
```json
{
  "status": "excused",
  "remarks": "Medical note provided"
}
```

---

### 3.6 Close Session
Lock an attendance session after marking complete.

- **Method & Path**: `POST /api/v1/attendance/sessions/{session_id}/close`
- **Access**: Admin & Teacher
- **Response `204 No Content`**

---

### 3.7 Reopen Session
Re-open a closed session for corrections.

- **Method & Path**: `POST /api/v1/attendance/sessions/{session_id}/reopen`
- **Access**: Admin Only
- **Response `200 OK`**

---

## 4. Analytics & Reports Endpoints

---

### 4.1 Class Attendance Summary
Get overall present, absent, late counts & percentages for a class across a date range.

- **Method & Path**: `GET /api/v1/analytics/class/{class_id}/summary?from=2026-07-01&to=2026-07-31`
- **Access**: Admin & Teacher
- **Response `200 OK`**:
```json
{
  "data": {
    "class_id": "a0000000-0000-0000-0000-000000000040",
    "total_sessions": 20,
    "total_records": 500,
    "present": 450,
    "absent": 30,
    "late": 15,
    "excused": 5,
    "attendance_percentage": 90.0
  }
}
```

---

### 4.2 Class Defaulters List
Identify students below a minimum attendance percentage threshold (e.g. `< 75%`).

- **Method & Path**: `GET /api/v1/analytics/class/{class_id}/defaulters?threshold=75`
- **Access**: Admin & Teacher
- **Response `200 OK`**: List of student defaulter objects with attendance percentage.

---

### 4.3 Export Reports (CSV / PDF)

#### Export Class Attendance (CSV / PDF)
- **Method & Path**: `GET /api/v1/reports/class/{class_id}/export?format=pdf` (or `format=csv`)
- **Access**: Admin Only
- **Response**: Binary stream (`application/pdf` or `text/csv`) download.

#### Export Student Attendance Report
- **Method & Path**: `GET /api/v1/reports/student/{student_id}/export?format=pdf`
- **Access**: Admin Only
- **Response**: Binary PDF download.
