# Technical Design Specification: Document Request Portal

**Version:** 2.0  
**Author:** Systems Integration Team  
**Date:** November 2024  
**Platform:** Salesforce / Experience Cloud

---

## 1. Executive Summary

This specification defines a **configurable, object-agnostic** secure document collection system. Administrators can request additional documentation from external recipients, with files uploaded via an Experience Cloud Guest User portal. The system implements a two-phase review workflow before documents are committed to target records.

The solution is designed to work with **any sObject** through a configuration layer, eliminating the need for code changes when enabling new objects.

### 1.1 Key Requirements

- Configurable to work with any standard or custom sObject
- Administrators initiate document requests from any configured source record
- Secure GUID-based token URLs with configurable expiration window (default 7 days)
- Guest User file upload via Experience Cloud (no authentication required)
- Configurable file size limits and allowed file types per use case
- Two-phase review: Administrator reviews uploads before committing to target record
- No sensitive record information exposed to Guest User—only request metadata displayed

### 1.2 Configuration-Driven Design

| Aspect                     | Configurable Via                    |
| -------------------------- | ----------------------------------- |
| Enabled Objects            | Custom Metadata Type                |
| Recipient Email Field Path | Custom Metadata Type                |
| Recipient Name Field Path  | Custom Metadata Type                |
| Token Expiration Days      | Custom Metadata Type (with default) |
| Max File Size              | Custom Metadata Type (with default) |
| Allowed File Types         | Custom Metadata Type (with default) |

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SALESFORCE INTERNAL                                │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │ Document_Request_Config__mdt (Custom Metadata)                         │ │
│  │ - Defines which objects support document requests                      │ │
│  │ - Configures field paths for recipient email/name                      │ │
│  │ - Sets validation rules (file size, types, expiration)                 │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                    │                                         │
│                         Configuration drives                                 │
│                                    ▼                                         │
│  ┌──────────────┐     ┌─────────────────────┐     ┌─────────────────────┐   │
│  │ Any Source   │────▶│ Document_Request__c │────▶│ Task (Review)       │   │
│  │ sObject      │     │ - GUID Token        │     │ - Assigned to Owner │   │
│  │ (Configured) │     │ - Expiration        │     │ - Links to Request  │   │
│  └──────────────┘     │ - Status            │     └─────────────────────┘   │
│                       │ - Request Details   │                               │
│                       └─────────────────────┘                               │
│                                │                                             │
│                                │ Files linked via                            │
│                                │ ContentDocumentLink                         │
│                                ▼                                             │
│                       ┌─────────────────────┐                               │
│                       │ ContentVersion      │                               │
│                       │ - Staged files      │                               │
│                       │ - Review status     │                               │
│                       └─────────────────────┘                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                │
                    Email with Secure URL
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        EXPERIENCE CLOUD (Guest User)                         │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ Document Upload Portal                                               │    │
│  │ - Token validation                                                   │    │
│  │ - Request metadata display (Request #, Date, Instructions)          │    │
│  │ - File upload (configurable limits)                                  │    │
│  │ - Success confirmation                                               │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Configuration Framework

### 3.1 Custom Metadata Type: Document_Request_Config\_\_mdt

**Purpose:** Define which objects support document requests and how to retrieve recipient information from each object.

| Field API Name                    | Field Type | Description                                                                        |
| --------------------------------- | ---------- | ---------------------------------------------------------------------------------- |
| `MasterLabel`                     | Text       | Friendly name (e.g., "Case Document Request")                                      |
| `DeveloperName`                   | Text       | Unique identifier                                                                  |
| `Source_Object_API_Name__c`       | Text(80)   | API name of the source object (e.g., "Case", "Custom_Object\_\_c")                 |
| `Is_Active__c`                    | Checkbox   | Enable/disable this configuration                                                  |
| `Recipient_Email_Field_Path__c`   | Text(255)  | Field path to recipient email (supports relationships, e.g., "Contact\_\_r.Email") |
| `Recipient_Name_Field_Path__c`    | Text(255)  | Field path to recipient name (e.g., "Contact\_\_r.Name")                           |
| `Recipient_Contact_Field_Path__c` | Text(255)  | Optional: Field path to Contact lookup for linking                                 |
| `Default_Expiration_Days__c`      | Number     | Token expiration in days (default: 7)                                              |
| `Max_File_Size_MB__c`             | Number     | Maximum file size in MB (default: 5)                                               |
| `Max_Files_Per_Upload__c`         | Number     | Maximum files per upload session (default: 10)                                     |
| `Allowed_File_Extensions__c`      | Text(500)  | Comma-separated list (e.g., "pdf,jpg,png,docx")                                    |
| `Quick_Action_Label__c`           | Text(80)   | Label for the quick action button                                                  |
| `Email_Template_Name__c`          | Text(80)   | Developer name of email template to use                                            |

### 3.2 Configuration Examples

**Example 1: Case Object**

```
MasterLabel: Case Document Request
Source_Object_API_Name__c: Case
Recipient_Email_Field_Path__c: Contact.Email
Recipient_Name_Field_Path__c: Contact.Name
Recipient_Contact_Field_Path__c: ContactId
Default_Expiration_Days__c: 7
Max_File_Size_MB__c: 5
Allowed_File_Extensions__c: pdf,jpg,jpeg,png,doc,docx
Quick_Action_Label__c: Request Document
```

**Example 2: Custom Application Object**

```
MasterLabel: Application Document Request
Source_Object_API_Name__c: Application__c
Recipient_Email_Field_Path__c: Applicant__r.Email
Recipient_Name_Field_Path__c: Applicant__r.Name
Recipient_Contact_Field_Path__c: Applicant__c
Default_Expiration_Days__c: 14
Max_File_Size_MB__c: 10
Allowed_File_Extensions__c: pdf,jpg,jpeg,png
Quick_Action_Label__c: Request Applicant Documents
```

**Example 3: Multi-Level Relationship**

```
MasterLabel: Asset Document Request
Source_Object_API_Name__c: Asset__c
Recipient_Email_Field_Path__c: Application__r.Primary_Contact__r.Email
Recipient_Name_Field_Path__c: Application__r.Primary_Contact__r.Name
Recipient_Contact_Field_Path__c: Application__r.Primary_Contact__c
Default_Expiration_Days__c: 7
Max_File_Size_MB__c: 5
Allowed_File_Extensions__c: pdf,jpg,jpeg,png,xls,xlsx
Quick_Action_Label__c: Request Asset Documentation
```

### 3.3 Configuration Service Requirements

The Apex configuration service must:

1. **Cache configurations** — Use Platform Cache or static variables to avoid repeated SOQL
2. **Validate field paths** — At runtime, verify that configured field paths exist and are accessible
3. **Support relationship traversal** — Parse dot-notation field paths (up to 5 levels per Salesforce limits)
4. **Provide defaults** — Fall back to system defaults when optional configuration fields are null
5. **Throw descriptive errors** — When misconfigured, provide clear error messages indicating the problem

### 3.4 Default Values (When Not Configured)

| Setting              | Default Value                             |
| -------------------- | ----------------------------------------- |
| Expiration Days      | 7                                         |
| Max File Size        | 5 MB                                      |
| Max Files Per Upload | 10                                        |
| Allowed Extensions   | pdf, jpg, jpeg, png, doc, docx, xls, xlsx |

---

## 4. Reference Architecture — Metadata Types

This section defines the Salesforce metadata types that the implementation agent should use when building this solution. All components should follow Salesforce DX project structure and be deployable via source format.

### 4.1 Metadata Inventory

| Category                 | Metadata Type            | Components                                                                                                                                                           | Notes                                                            |
| ------------------------ | ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **Configuration**        | CustomMetadata           | Document_Request_Config\_\_mdt                                                                                                                                       | Object configuration records                                     |
| **Data Model**           | CustomObject             | Document_Request\_\_c                                                                                                                                                | Full object definition with fields, validation rules, list views |
|                          | CustomField              | ContentVersion.Upload_Source**c, ContentVersion.Review_Status**c, ContentVersion.Reviewed_By**c, ContentVersion.Review_Date**c, ContentVersion.Rejection_Reason\_\_c | Fields on standard object                                        |
| **Apex**                 | ApexClass                | DocumentRequestConfigService, DocumentRequestService, GuestDocumentUploadService, DocumentRequestTriggerHandler, ExpireDocumentRequestsBatch                         | Plus corresponding test classes                                  |
|                          | ApexTrigger              | DocumentRequestTrigger                                                                                                                                               | Before update on Document_Request\_\_c                           |
| **Lightning Components** | LightningComponentBundle | documentRequestQuickAction, guestDocumentUpload, documentReviewPanel                                                                                                 | LWC format only (no Aura)                                        |
| **Actions**              | QuickAction              | (Dynamically created per configured object)                                                                                                                          | Screen action type, linked to LWC                                |
| **Layouts & Views**      | ListView                 | Document_Request**c.Pending_Review, Document_Request**c.My_Requests, Document_Request\_\_c.All_Requests                                                              | Administrator queue views                                        |
|                          | FlexiPage                | Document_Request\_\_c_Record_Page                                                                                                                                    | Lightning record page with review panel                          |
| **Email**                | EmailTemplate            | Document_Request_Notification (default), plus custom templates per config                                                                                            | Lightning or Visualforce template                                |
| **Security**             | PermissionSet            | Document_Request_Admin, Document_Request_Guest                                                                                                                       | Admin permissions and Guest controller access                    |
|                          | SharingRules             | Document_Request\_\_c sharing                                                                                                                                        | Owner-based or criteria-based sharing                            |
| **Experience Cloud**     | ExperienceBundle         | (Existing site)                                                                                                                                                      | Add page to existing community                                   |

### 4.2 Project Structure

```
force-app/
└── main/
    └── default/
        ├── classes/
        │   ├── DocumentRequestConfigService.cls
        │   ├── DocumentRequestConfigService.cls-meta.xml
        │   ├── DocumentRequestConfigServiceTest.cls
        │   ├── DocumentRequestService.cls
        │   ├── DocumentRequestService.cls-meta.xml
        │   ├── DocumentRequestServiceTest.cls
        │   ├── GuestDocumentUploadService.cls
        │   ├── GuestDocumentUploadService.cls-meta.xml
        │   ├── GuestDocumentUploadServiceTest.cls
        │   ├── DocumentRequestTriggerHandler.cls
        │   ├── DocumentRequestTriggerHandler.cls-meta.xml
        │   ├── ExpireDocumentRequestsBatch.cls
        │   ├── ExpireDocumentRequestsBatch.cls-meta.xml
        │   └── ExpireDocumentRequestsBatchTest.cls
        ├── triggers/
        │   ├── DocumentRequestTrigger.trigger
        │   └── DocumentRequestTrigger.trigger-meta.xml
        ├── objects/
        │   ├── Document_Request__c/
        │   │   ├── Document_Request__c.object-meta.xml
        │   │   ├── fields/
        │   │   │   ├── Request_Token__c.field-meta.xml
        │   │   │   ├── Token_Expiration__c.field-meta.xml
        │   │   │   ├── Status__c.field-meta.xml
        │   │   │   └── ... (all custom fields)
        │   │   ├── listViews/
        │   │   │   ├── Pending_Review.listView-meta.xml
        │   │   │   ├── My_Requests.listView-meta.xml
        │   │   │   └── All_Requests.listView-meta.xml
        │   │   └── validationRules/
        │   │       └── (as needed)
        │   ├── Document_Request_Config__mdt/
        │   │   ├── Document_Request_Config__mdt.object-meta.xml
        │   │   └── fields/
        │   │       ├── Source_Object_API_Name__c.field-meta.xml
        │   │       ├── Recipient_Email_Field_Path__c.field-meta.xml
        │   │       ├── Recipient_Name_Field_Path__c.field-meta.xml
        │   │       └── ... (all config fields)
        │   └── ContentVersion/
        │       └── fields/
        │           ├── Upload_Source__c.field-meta.xml
        │           ├── Review_Status__c.field-meta.xml
        │           ├── Reviewed_By__c.field-meta.xml
        │           ├── Review_Date__c.field-meta.xml
        │           └── Rejection_Reason__c.field-meta.xml
        ├── lwc/
        │   ├── documentRequestQuickAction/
        │   │   ├── documentRequestQuickAction.html
        │   │   ├── documentRequestQuickAction.js
        │   │   ├── documentRequestQuickAction.js-meta.xml
        │   │   └── documentRequestQuickAction.css
        │   ├── guestDocumentUpload/
        │   │   ├── guestDocumentUpload.html
        │   │   ├── guestDocumentUpload.js
        │   │   ├── guestDocumentUpload.js-meta.xml
        │   │   └── guestDocumentUpload.css
        │   └── documentReviewPanel/
        │       ├── documentReviewPanel.html
        │       ├── documentReviewPanel.js
        │       ├── documentReviewPanel.js-meta.xml
        │       └── documentReviewPanel.css
        ├── customMetadata/
        │   └── Document_Request_Config/
        │       └── (sample configuration records)
        ├── email/
        │   └── Document_Requests/
        │       ├── Document_Request_Notification.email-meta.xml
        │       └── Document_Request_Notification.email
        ├── permissionsets/
        │   ├── Document_Request_Admin.permissionset-meta.xml
        │   └── Document_Request_Guest.permissionset-meta.xml
        └── flexipages/
            └── Document_Request__c_Record_Page.flexipage-meta.xml
```

### 4.3 API Versions & Standards

| Standard          | Requirement                                                             |
| ----------------- | ----------------------------------------------------------------------- |
| API Version       | 59.0 or latest stable                                                   |
| LWC               | ES6+ modules, no Aura wrapper                                           |
| Apex              | Bulkified, governor-limit aware                                         |
| Test Coverage     | Minimum 90% per class                                                   |
| Naming Convention | PascalCase for classes, camelCase for LWC, snake_case for custom fields |

### 4.4 Dependencies & Assumptions

**Platform Features Required:**

- Experience Cloud (Community) license
- Salesforce Files (ContentVersion/ContentDocument)
- Email Deliverability enabled
- Custom Metadata Types

**Agent Implementation Notes:**

- Do not create Aura components; use LWC exclusively
- Use `@AuraEnabled` methods for LWC-to-Apex communication
- Use `wire` adapters where cacheable data is appropriate
- Guest User controller must use `without sharing` with explicit security checks
- All DML operations should be bulkified even if initially single-record
- Configuration service should be mockable for unit tests

---

## 5. Data Model

### 5.1 Document_Request\_\_c (Custom Object)

**Purpose:** Tracks document requests, stores secure token, links uploaded files to eventual target record.

| Field API Name              | Field Type      | Description                                                            |
| --------------------------- | --------------- | ---------------------------------------------------------------------- |
| `Name`                      | Auto Number     | Request number (e.g., "REQ-{00000}")                                   |
| `Request_Token__c`          | Text(36)        | UUID/GUID for secure URL access (External ID, Unique)                  |
| `Token_Expiration__c`       | DateTime        | Token expiry timestamp                                                 |
| `Status__c`                 | Picklist        | Draft, Sent, Files_Received, Under_Review, Approved, Rejected, Expired |
| `Request_Instructions__c`   | Long Text Area  | Administrator's instructions to the recipient                          |
| `Source_Object_API_Name__c` | Text(80)        | API name of the source object                                          |
| `Source_Record_Id__c`       | Text(18)        | ID of the source record                                                |
| `Recipient_Contact__c`      | Lookup(Contact) | Contact record for the recipient (optional)                            |
| `Recipient_Email__c`        | Email           | Email address for the request                                          |
| `Recipient_Name__c`         | Text(255)       | Recipient name (denormalized for display)                              |
| `Requested_By__c`           | Lookup(User)    | User who created the request                                           |
| `Request_Date__c`           | DateTime        | When the request was created                                           |
| `Files_Received_Date__c`    | DateTime        | When first file was uploaded                                           |
| `Review_Completed_Date__c`  | DateTime        | When administrator completed review                                    |
| `Review_Notes__c`           | Long Text Area  | Administrator's notes during review                                    |
| `File_Count__c`             | Number          | Count of files uploaded                                                |
| `Config_Developer_Name__c`  | Text(80)        | Reference to the configuration used                                    |

**Indexes:**

- `Request_Token__c` (External ID, Unique) — Critical for Guest User lookup performance
- `Source_Record_Id__c` — For querying requests by source record

**Sharing:**

- OWD: Private
- Sharing Rule: Share with administrator queue/role based on `Requested_By__c`

### 5.2 ContentVersion / ContentDocumentLink Strategy

Files uploaded by Guest User are linked to `Document_Request__c` via `ContentDocumentLink`. This approach:

- Keeps files associated with the request during review phase
- Allows administrator to approve/reject individual files
- Upon approval, administrator commits files to source record by creating additional `ContentDocumentLink` records

**Custom Fields on ContentVersion:**

| Field API Name        | Field Type   | Description                         |
| --------------------- | ------------ | ----------------------------------- |
| `Upload_Source__c`    | Picklist     | Portal_Upload, Internal, Migration  |
| `Review_Status__c`    | Picklist     | Pending_Review, Approved, Rejected  |
| `Reviewed_By__c`      | Lookup(User) | Administrator who reviewed the file |
| `Review_Date__c`      | DateTime     | When reviewed                       |
| `Rejection_Reason__c` | Text(255)    | Reason if rejected                  |

### 5.3 Task (Standard Object Usage)

Review tasks are assigned to the requesting user upon file upload completion.

| Field          | Value Strategy                                          |
| -------------- | ------------------------------------------------------- |
| `Subject`      | Include Request Name for identification                 |
| `WhatId`       | Document_Request\_\_c Id                                |
| `OwnerId`      | Document_Request**c.Requested_By**c                     |
| `Status`       | Open                                                    |
| `Priority`     | Normal                                                  |
| `ActivityDate` | Request Date + 3 business days                          |
| `Description`  | Include link to review, file count, recipient reference |

---

## 6. Security Design

### 6.1 Token Design Requirements

**Token Generation:**

- Use `Crypto.generateAesKey(128)` for cryptographic randomness
- Format as standard UUID pattern (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
- Store in `Request_Token__c` field (External ID, Unique, Case-Insensitive)

**Token Validation Rules (must ALL pass):**

1. Token exists in `Document_Request__c.Request_Token__c`
2. `Token_Expiration__c` > NOW()
3. `Status__c` NOT IN ('Approved', 'Rejected', 'Expired')

**Token URL Structure:**

```
https://{community-domain}/document-upload?token={GUID}
```

### 6.2 Guest User Security Model

**Critical Design Constraint:** All Guest User operations MUST run through `without sharing` Apex controllers that perform explicit token validation. No direct object access is granted to the Guest User profile.

**Guest User Profile Permissions:**

| Object                | Access        | Implementation Notes                                       |
| --------------------- | ------------- | ---------------------------------------------------------- |
| Document_Request\_\_c | None directly | Access only via Apex controller with token validation      |
| ContentVersion        | Create only   | Controlled via Apex; files linked to Document_Request\_\_c |
| ContentDocumentLink   | Create only   | Limited to linking to Document_Request\_\_c                |

### 6.3 Data Exposure Rules

**NEVER expose to Guest User (hard requirements):**

- Source record information (any data from the source object)
- Source Record ID or any internal Salesforce IDs
- Sensitive data of any kind
- Full Contact details
- Token expiration exact timestamp
- Configuration details

**Safe to expose to Guest User:**

- Request Number (auto-number, e.g., "REQ-00042")
- Request Date (formatted date only)
- Request Instructions (administrator's message to recipient)
- Upload status (success/failure messages)
- General token validity status (valid vs. expired/invalid)

---

## 7. Component Specifications

### 7.1 LWC: documentRequestQuickAction

**Location:** Any configured source object record page (Quick Action)  
**Actor:** Administrator  
**Purpose:** Create document request and trigger email to recipient

#### Functional Requirements

**On Load Behavior:**

1. Retrieve `recordId` and `objectApiName` from page context
2. Query `Document_Request_Config__mdt` for matching configuration
3. If no active configuration exists, display informative error message
4. If configuration exists, dynamically retrieve recipient information using configured field paths

**Input Fields:**
| Field | Type | Validation | Notes |
|-------|------|------------|-------|
| Request Instructions | Textarea | Required, Max 4000 chars | What the administrator needs from recipient |
| Internal Notes | Textarea | Optional | Not sent to recipient, stored on request |
| Expiration Days | Number | Optional, 1-30 | Override default from configuration |

**Dynamic Display:**

- Show recipient name and email (retrieved via configuration)
- Show configured file type restrictions
- Show configured file size limit

**Actions:**
| Action | Behavior |
|--------|----------|
| Preview Email | Show modal with email preview before sending |
| Submit | Validate form, create Document_Request\_\_c, trigger email, show confirmation |
| Cancel | Close modal without action |

**Configuration Error Handling:**

- If configuration not found: "Document requests are not enabled for this object type."
- If recipient email field path invalid: "Unable to retrieve recipient email. Please contact your administrator."
- If recipient email is blank: "No email address found for the recipient on this record."

---

### 7.2 LWC: guestDocumentUpload

**Location:** Experience Cloud Page (Guest Accessible)  
**Actor:** Recipient (Guest User)  
**Purpose:** Validate token and allow secure file uploads

#### URL Contract

```
/document-upload?token={GUID}
```

Component must extract token from URL query parameter on load.

#### UI State Machine

| State       | Trigger                 | Display                                           |
| ----------- | ----------------------- | ------------------------------------------------- |
| `loading`   | Initial load            | Spinner while validating token                    |
| `invalid`   | Token fails validation  | Error message, contact support info, no upload UI |
| `valid`     | Token passes validation | Upload interface with request metadata            |
| `uploading` | User initiates upload   | Progress indicator, disabled controls             |
| `success`   | Upload completes        | Confirmation message, upload summary              |
| `error`     | Upload fails            | Error message, retry option                       |

#### Valid State - Display Requirements

| Element                   | Source                                      | Security Note                    |
| ------------------------- | ------------------------------------------- | -------------------------------- |
| Request Number            | Document_Request\_\_c.Name                  | Safe to display                  |
| Request Date              | Document_Request**c.Request_Date**c         | Format as readable date          |
| Instructions              | Document_Request**c.Request_Instructions**c | Administrator's message          |
| Previously Uploaded Count | ContentDocumentLink count                   | Optional, shows existing uploads |

**Never display:** Source record info, internal IDs, recipient contact details, exact expiration timestamp, configuration details

#### File Upload Requirements

Validation limits are retrieved from the configuration (via Document_Request**c.Config_Developer_Name**c):

| Requirement          | Source                               | Default                            |
| -------------------- | ------------------------------------ | ---------------------------------- |
| Max file size        | Config: Max_File_Size_MB\_\_c        | 5 MB                               |
| Max files per upload | Config: Max_Files_Per_Upload\_\_c    | 10                                 |
| Allowed types        | Config: Allowed_File_Extensions\_\_c | pdf,jpg,jpeg,png,doc,docx,xls,xlsx |

**Client-side validation must include:**

- File size check before upload attempt
- File extension validation against configuration
- Duplicate filename detection within session
- Clear error messaging per file

#### Success State Requirements

Display confirmation that includes:

- Number of files uploaded
- Message: "Your documents have been received and are pending review"
- Note that someone will contact them if additional information needed
- Option to upload additional files (if within token window)

---

### 7.3 LWC: documentReviewPanel

**Location:** Document_Request\_\_c Record Page  
**Actor:** Administrator  
**Purpose:** Review uploaded files, approve/reject, commit to source record

#### Display Sections

**Request Summary:**

- Status badge (color-coded by status)
- Request Number and Date
- Link to Source Record (clickable navigation using Source_Object_API_Name**c and Source_Record_Id**c)
- Recipient information
- Original instructions sent
- Configuration used (for admin reference)

**Uploaded Files Section:**

- File cards showing: filename, size, upload date, preview thumbnail (if image/PDF)
- Per-file actions: Preview, Approve, Reject (with reason modal), Download
- Visual indicator of review status per file

**Bulk Actions:**

- Approve All Pending
- Reject All Pending (requires reason)

**Commit Section:**

- "Commit Approved Files to Record" button
- Only enabled when approved files exist
- Confirmation modal showing source record type and file count

#### Commit Workflow Logic

When administrator commits approved files:

1. Create ContentDocumentLink records linking approved files to Source_Record_Id\_\_c
2. Update Document_Request**c.Status**c to 'Approved'
3. Set Review_Completed_Date\_\_c to current timestamp
4. Complete associated Task record(s)
5. Show success confirmation with link to source record

---

### 7.4 Administrator Review Queue — List Views

**Purpose:** Provide administrators with visibility into pending document requests requiring action

#### List View Definitions

**Pending_Review (Primary Work Queue)**

| Attribute    | Value                                                   |
| ------------ | ------------------------------------------------------- |
| Name         | Pending Review                                          |
| Filter Logic | Status\_\_c IN ('Files_Received', 'Under_Review')       |
| Scope        | My records (Requested_By\_\_c = $User.Id) OR Team queue |
| Sort         | Files_Received_Date\_\_c ASC (oldest first)             |

| Column                      | Purpose                         |
| --------------------------- | ------------------------------- |
| Name (Request Number)       | Link to record                  |
| Status\_\_c                 | Current state                   |
| Recipient_Email\_\_c        | Identify recipient              |
| Source_Object_API_Name\_\_c | Type of source record           |
| File_Count\_\_c             | Number of files awaiting review |
| Files_Received_Date\_\_c    | When uploads arrived            |
| Token_Expiration\_\_c       | Urgency indicator               |

**My_Requests (Administrator's Complete History)**

| Attribute    | Value                                 |
| ------------ | ------------------------------------- |
| Name         | My Requests                           |
| Filter Logic | Requested_By\_\_c = $User.Id          |
| Scope        | All statuses                          |
| Sort         | Request_Date\_\_c DESC (newest first) |

| Column                      | Purpose                        |
| --------------------------- | ------------------------------ |
| Name (Request Number)       | Link to record                 |
| Status\_\_c                 | Current state                  |
| Recipient_Email\_\_c        | Identify recipient             |
| Source_Object_API_Name\_\_c | Type of source record          |
| Request_Date\_\_c           | When request was created       |
| Review_Completed_Date\_\_c  | When finalized (if applicable) |

**All_Requests (Manager/Admin View)**

| Attribute    | Value                                |
| ------------ | ------------------------------------ |
| Name         | All Requests                         |
| Filter Logic | (none — all records visible to user) |
| Scope        | Everything                           |
| Sort         | Request_Date\_\_c DESC               |

| Column                      | Purpose                           |
| --------------------------- | --------------------------------- |
| Name (Request Number)       | Link to record                    |
| Requested_By\_\_c           | Administrator who created request |
| Status\_\_c                 | Current state                     |
| Recipient_Email\_\_c        | Identify recipient                |
| Source_Object_API_Name\_\_c | Type of source record             |
| File_Count\_\_c             | Number of files                   |
| Request_Date\_\_c           | When created                      |

#### Queue Workflow

```
Administrator Daily Workflow:
┌─────────────────────────────────────────────────────────────┐
│  1. Administrator opens "Pending Review" list view          │
│  2. List shows requests with uploaded files awaiting review │
│  3. Administrator clicks request record to open detail page │
│  4. documentReviewPanel displays files for approval/reject  │
│  5. Administrator commits approved files to source record   │
│  6. Request moves out of "Pending Review" queue             │
└─────────────────────────────────────────────────────────────┘
```

---

## 8. Apex Service Specifications

### 8.1 DocumentRequestConfigService

**Sharing:** `with sharing`  
**Purpose:** Retrieve and validate configuration for document requests

#### Method: getConfigForObject

| Parameter     | Type   | Description                   |
| ------------- | ------ | ----------------------------- |
| objectApiName | String | API name of the source object |

**Returns:** Document_Request_Config\_\_mdt record or null if not configured

**Logic:**

1. Check cache for existing configuration
2. If not cached, query Custom Metadata Type by Source_Object_API_Name**c where Is_Active**c = true
3. Cache result and return

#### Method: getRecipientInfo

| Parameter | Type                           | Description          |
| --------- | ------------------------------ | -------------------- |
| recordId  | Id                             | Source record ID     |
| config    | Document_Request_Config\_\_mdt | Configuration record |

**Returns:** Wrapper containing recipient name, email, and optional Contact Id

**Logic:**

1. Parse field paths from configuration
2. Build dynamic SOQL query with required fields
3. Execute query and traverse relationship paths
4. Return wrapper with extracted values

**Error Handling:**

- Invalid field path: Throw descriptive exception
- Null values: Return wrapper with null fields (allow caller to validate)
- Query exception: Log error and throw user-friendly exception

#### Method: validateConfig

| Parameter | Type                           | Description               |
| --------- | ------------------------------ | ------------------------- |
| config    | Document_Request_Config\_\_mdt | Configuration to validate |

**Returns:** List of validation error messages (empty if valid)

**Logic:**

1. Verify Source_Object_API_Name\_\_c references valid sObject
2. Verify field paths are valid for the object
3. Verify email template exists (if specified)
4. Return list of any validation errors

---

### 8.2 DocumentRequestService (with sharing)

**Purpose:** Internal operations for authenticated administrator users

#### Method: createDocumentRequest

| Parameter              | Type    | Description                           |
| ---------------------- | ------- | ------------------------------------- |
| sourceRecordId         | Id      | Source record ID                      |
| sourceObjectApiName    | String  | API name of the source object         |
| requestInstructions    | String  | Administrator's message to recipient  |
| internalNotes          | String  | Internal notes (not sent)             |
| expirationDaysOverride | Integer | Optional override for expiration days |

**Returns:** Wrapper containing created request Id and Name

**Logic Flow:**

1. Retrieve configuration using DocumentRequestConfigService
2. Validate configuration exists and is active
3. Retrieve recipient information using configured field paths
4. Validate recipient email is not blank
5. Generate secure token
6. Calculate expiration using config default or override
7. Create Document_Request\_\_c record
8. Trigger email notification to recipient
9. Return created record reference

#### Method: approveFile

| Parameter        | Type | Description               |
| ---------------- | ---- | ------------------------- |
| contentVersionId | Id   | ContentVersion to approve |

**Logic:** Update Review_Status**c to 'Approved', set Reviewed_By**c and Review_Date\_\_c

#### Method: rejectFile

| Parameter        | Type   | Description                   |
| ---------------- | ------ | ----------------------------- |
| contentVersionId | Id     | ContentVersion to reject      |
| rejectionReason  | String | Required reason for rejection |

**Logic:** Update Review_Status\_\_c to 'Rejected', set rejection fields

#### Method: commitApprovedFiles

| Parameter         | Type | Description                     |
| ----------------- | ---- | ------------------------------- |
| documentRequestId | Id   | Document_Request\_\_c to commit |

**Logic Flow:**

1. Query Document_Request**c with Source_Record_Id**c and related ContentDocumentLinks
2. Identify ContentVersions with Review_Status\_\_c = 'Approved'
3. Create new ContentDocumentLink records pointing to Source_Record_Id\_\_c
4. Update request Status\_\_c to 'Approved'
5. Complete associated Task records

---

### 8.3 GuestDocumentUploadService (without sharing)

**Purpose:** Guest User operations with explicit security validation

**Critical:** This class MUST run `without sharing` to allow Guest User access, but MUST perform explicit token validation on every method call.

#### Method: validateToken

| Parameter | Type   | Description             |
| --------- | ------ | ----------------------- |
| token     | String | GUID from URL parameter |

**Returns:** Wrapper containing:

- isValid (Boolean)
- requestNumber (String) - only if valid
- requestDate (String) - formatted, only if valid
- instructions (String) - only if valid
- existingFileCount (Integer) - only if valid
- maxFileSizeMB (Integer) - from configuration
- maxFilesPerUpload (Integer) - from configuration
- allowedExtensions (List<String>) - from configuration

**Validation Logic:**

1. Verify token format matches UUID pattern
2. Query Document_Request**c by Request_Token**c
3. Check Token_Expiration\_\_c > NOW()
4. Check Status\_\_c not in terminal states
5. If any check fails, return invalid result with no data exposed
6. If expired, update Status\_\_c to 'Expired' before returning
7. Retrieve configuration limits from Config_Developer_Name\_\_c

**Security:** Never return source record information, internal IDs, or sensitive data regardless of token validity.

#### Method: uploadFiles

| Parameter | Type   | Description             |
| --------- | ------ | ----------------------- |
| token     | String | GUID for re-validation  |
| filesJson | String | JSON array of file data |

**File JSON Structure:**

```json
[
  {
    "fileName": "document.pdf",
    "base64Data": "...",
    "contentType": "application/pdf"
  }
]
```

**Validation Requirements:**

1. Re-validate token (call validateToken internally)
2. Retrieve configuration limits
3. Verify file count ≤ configured max
4. Verify each file size ≤ configured max after base64 decode
5. Verify each file extension in configured allowed list
6. Reject entire upload if any validation fails

**Logic Flow:**

1. Validate token
2. Parse and validate files against configuration
3. Create ContentVersion records with FirstPublishLocationId = Document_Request\_\_c.Id
4. Set Upload_Source**c = 'Portal_Upload' and Review_Status**c = 'Pending_Review'
5. If first upload (Status = 'Sent'), update to 'Files_Received' and create review Task
6. Return success/failure

---

### 8.4 Trigger: DocumentRequestTrigger

**Object:** Document_Request\_\_c  
**Events:** before update

**Logic:**

- Check if Token_Expiration\_\_c has passed
- If expired and Status**c not in terminal state, set Status**c = 'Expired'

---

### 8.5 Batch: ExpireDocumentRequestsBatch

**Purpose:** Scheduled cleanup of expired requests

**Schedule:** Daily at midnight

**Query Scope:**

- Token_Expiration\_\_c < NOW()
- Status\_\_c NOT IN ('Approved', 'Rejected', 'Expired')

**Action:** Set Status\_\_c = 'Expired' for all matching records

---

## 9. Email Specification

### 9.1 Email Template: Document_Request_Notification

**Template Type:** Lightning Email Template (or Visualforce)

**Available Merge Fields:**

| Merge Field     | Source                                      |
| --------------- | ------------------------------------------- |
| Request Number  | Document_Request\_\_c.Name                  |
| Request Date    | Document_Request**c.Request_Date**c         |
| Instructions    | Document_Request**c.Request_Instructions**c |
| Expiration Date | Document_Request**c.Token_Expiration**c     |
| Upload URL      | Constructed from Community base URL + token |
| Recipient Name  | Document_Request**c.Recipient_Name**c       |

### 9.2 Email Content Requirements

**Subject Line:** Include request number for reference

**Body Must Include:**

- Greeting with recipient name
- Clear statement of what is being requested
- The administrator's instructions
- Prominent, clickable upload link
- Expiration date/timeframe
- Contact information for questions

**Body Must NOT Include:**

- Details about the source record
- Internal Salesforce URLs or IDs
- Technical error messages
- Configuration details

### 9.3 Custom Email Templates

Configurations can specify a custom email template via `Email_Template_Name__c`. If specified, the system uses that template instead of the default. This allows different messaging for different use cases (e.g., formal for legal documents, friendly for customer onboarding).

---

## 10. Experience Cloud Configuration

### 10.1 Site Requirements

- Create page at path: `/document-upload`
- Page must be Guest accessible
- Minimal navigation (no authenticated user menus)
- Branded header/footer appropriate for public view

### 10.2 Guest User Profile Configuration

**Profile Name Recommendation:** Document Upload Portal Guest

**Object Permissions:**

- All object access controlled via Apex; no direct CRUD needed
- Standard Guest User restrictions apply

**Apex Class Access:**

- GuestDocumentUploadService (or Controller wrapping it)

### 10.3 Security Headers (Configure at Site Level)

- Prevent framing (X-Frame-Options: DENY)
- Prevent MIME sniffing
- Configure CSP to allow file uploads

---

## 11. Testing Requirements

### 11.1 Unit Test Coverage Requirements

| Class                        | Minimum Coverage | Key Scenarios                                                                 |
| ---------------------------- | ---------------- | ----------------------------------------------------------------------------- |
| DocumentRequestConfigService | 90%              | Config retrieval, field path parsing, caching, validation                     |
| DocumentRequestService       | 90%              | Create request, token generation, approve/reject, commit workflow             |
| GuestDocumentUploadService   | 90%              | Valid token, expired token, invalid token, file size limits, file type limits |
| ExpireDocumentRequestsBatch  | 90%              | Batch processing of expired requests                                          |
| Trigger Handler              | 90%              | Expiration status update                                                      |

### 11.2 Configuration Test Scenarios

| Scenario                      | Expected Behavior                            |
| ----------------------------- | -------------------------------------------- |
| Object not configured         | Quick action displays "not enabled" message  |
| Configuration inactive        | Quick action displays "not enabled" message  |
| Invalid email field path      | Descriptive error at request creation        |
| Null recipient email          | Validation error preventing request creation |
| Multi-level relationship path | Correct traversal and value retrieval        |
| Custom file size limit        | Guest upload validates against custom limit  |
| Custom file types             | Guest upload validates against custom types  |

### 11.3 Integration Test Scenarios

**Happy Path:**

1. Administrator creates request from configured source object
2. Email sent to recipient
3. Recipient clicks link, sees request info (no source record data)
4. Recipient uploads files
5. Administrator receives task notification
6. Administrator reviews and approves files
7. Administrator commits to source record
8. Files appear on source record

**Security Scenarios:**

- Invalid token returns no data, shows error
- Expired token returns no data, shows error
- Manipulated token (wrong format) rejected
- No source record information leaked in any error state

**Configuration Scenarios:**

- Request from unconfigured object fails gracefully
- Different objects use different configurations correctly
- File limits vary correctly by configuration

---

## 12. Deployment Checklist

### 12.1 Metadata Components Required

**Custom Metadata Type:**

- Document_Request_Config\_\_mdt with all fields

**Custom Objects:**

- Document_Request\_\_c with all fields

**Custom Fields on Standard Objects:**

- ContentVersion custom fields (Upload_Source**c, Review_Status**c, etc.)

**Apex Classes:**

- DocumentRequestConfigService
- DocumentRequestService
- GuestDocumentUploadService
- DocumentRequestTriggerHandler
- ExpireDocumentRequestsBatch
- All test classes

**Triggers:**

- DocumentRequestTrigger

**Lightning Web Components:**

- documentRequestQuickAction
- guestDocumentUpload
- documentReviewPanel

**Email Templates:**

- Document_Request_Notification (default)

**List Views:**

- Pending_Review, My_Requests, All_Requests on Document_Request\_\_c

### 12.2 Post-Deployment Configuration

1. Create Document_Request_Config\_\_mdt records for each enabled object
2. Assign Apex class access to Guest User profile
3. Configure Guest User profile in Experience Cloud site
4. Create Quick Actions for each configured object and add to page layouts
5. Add documentReviewPanel to Document_Request\_\_c page layout
6. Schedule ExpireDocumentRequestsBatch (daily at midnight)
7. Verify email deliverability settings
8. Test end-to-end for each configured object

### 12.3 Enabling a New Object (Post-Deployment)

To enable document requests for a new sObject:

1. **Create Configuration Record:**

   - Navigate to Setup > Custom Metadata Types > Document_Request_Config\_\_mdt > Manage Records
   - Create new record with object API name and field paths

2. **Create Quick Action:**

   - Create new Quick Action on the target object
   - Type: Lightning Web Component
   - Component: c:documentRequestQuickAction

3. **Add to Page Layout:**

   - Edit the object's Lightning Record Page
   - Add Quick Action to the Highlights Panel or action menu

4. **Test:**
   - Create a test request from the object
   - Verify email delivery
   - Test file upload and commit workflow

---

## 13. Open Items / TODOs

| Item                                      | Owner | Notes                                          |
| ----------------------------------------- | ----- | ---------------------------------------------- |
| Confirm Community base URL strategy       | Admin | Site.getBaseUrl() or Custom Setting?           |
| Define default email template branding    | Admin | Provide HTML template or requirements          |
| Identify initial objects to configure     | Admin | List of objects for initial rollout            |
| Define permission set assignment strategy | Admin | Which users/profiles get Admin permission set? |

---

## Appendix A: Object Relationship Diagram

```
┌─────────────────────────────────────┐
│ Document_Request_Config__mdt        │
│ (Custom Metadata)                   │
│                                     │
│ - Source_Object_API_Name__c         │
│ - Recipient_Email_Field_Path__c     │
│ - Recipient_Name_Field_Path__c      │
│ - Max_File_Size_MB__c               │
│ - Allowed_File_Extensions__c        │
└─────────────────┬───────────────────┘
                  │ Configures
                  ▼
┌─────────────────────────────────────┐
│ Any sObject (Source Record)         │
│ - Case                              │
│ - Custom_Object__c                  │
│ - (Any configured object)           │
└─────────────────┬───────────────────┘
                  │
                  │ Source_Record_Id__c
                  ▼
┌─────────────────────────────────────┐       ┌─────────────────────┐
│ Document_Request__c                 │──────▶│ ContentDocumentLink │
│                                     │       │ (Junction)          │
│ - Request_Token__c                  │       └─────────┬───────────┘
│ - Source_Record_Id__c               │                 │
│ - Source_Object_API_Name__c         │                 ▼
│ - Status__c                         │       ┌─────────────────────┐
└─────────────────┬───────────────────┘       │ ContentDocument     │
                  │                           │                     │
                  │ WhatId                    └─────────┬───────────┘
                  ▼                                     │
┌─────────────────────────────────────┐                 ▼
│ Task                                │       ┌─────────────────────┐
│ (Review Task)                       │       │ ContentVersion      │
└─────────────────────────────────────┘       │                     │
                                              │ - Review_Status__c  │
                                              │ - Upload_Source__c  │
                                              └─────────────────────┘
```

---

## Appendix B: Status Flow Diagram

```
                    ┌─────────┐
                    │  Draft  │ (Optional: Admin saves without sending)
                    └────┬────┘
                         │ Admin Sends Request
                         ▼
                    ┌─────────┐
            ┌───────│  Sent   │───────┐
            │       └────┬────┘       │
            │            │            │
    Token Expires   Recipient     No Upload
            │       Uploads       Within Window
            ▼            │            │
       ┌─────────┐       ▼            │
       │ Expired │◀──────────────────┘
       └─────────┘  ┌───────────────┐
                    │Files_Received │
                    └───────┬───────┘
                            │ Admin Reviews
                    ┌───────┴───────┐
                    ▼               ▼
             ┌───────────┐   ┌───────────┐
             │ Under_    │   │ (Direct   │
             │ Review    │   │  Approve) │
             └─────┬─────┘   └─────┬─────┘
                   │               │
           ┌───────┴───────┐       │
           ▼               ▼       │
    ┌───────────┐   ┌───────────┐  │
    │ Rejected  │   │ Approved  │◀─┘
    └───────────┘   └───────────┘
```

---

## Appendix C: Configuration Quick Reference

**To add document request capability to a new object:**

1. Create `Document_Request_Config__mdt` record:

   ```
   DeveloperName: Your_Object_Config
   Source_Object_API_Name__c: Your_Object__c
   Recipient_Email_Field_Path__c: Contact__r.Email
   Recipient_Name_Field_Path__c: Contact__r.Name
   Is_Active__c: true
   ```

2. Create Quick Action on `Your_Object__c`:

   - Type: Lightning Web Component
   - LWC: c:documentRequestQuickAction
   - Label: (from Config: Quick_Action_Label\_\_c)

3. Add Quick Action to page layout

4. Assign `Document_Request_Admin` permission set to users

---

_End of Technical Design Specification_
