# Document Request Portal

A configurable, object-agnostic secure document collection system for Salesforce. Administrators can request documents from external recipients via secure token-based URLs, with files uploaded through an Experience Cloud Guest User portal and a two-phase review workflow.

## Features

- **Object-Agnostic** — Works with any standard or custom sObject via configuration
- **Secure Token Access** — UUID-based tokens with configurable expiration
- **Guest User Upload** — No authentication required for recipients
- **Two-Phase Review** — Admin reviews uploads before committing to source record
- **Configurable Limits** — File size, count, and type restrictions per use case
- **Privacy-First** — No sensitive record data exposed to guest users

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    SALESFORCE INTERNAL                          │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Document_Request_Config__mdt (Custom Metadata)            │  │
│  │ Configures: objects, field paths, limits, templates       │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│  ┌──────────────┐    ┌──────▼──────────┐    ┌────────────────┐  │
│  │ Source       │───▶│ Document_       │───▶│ Task           │  │
│  │ Record       │    │ Request__c      │    │ (Review)       │  │
│  │ (Any Object) │    │ + Token         │    └────────────────┘  │
│  └──────────────┘    │ + Files         │                        │
│                      └────────┬────────┘                        │
└───────────────────────────────┼─────────────────────────────────┘
                                │ Email with Secure URL
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│              EXPERIENCE CLOUD (Guest User)                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ guestDocumentUpload LWC                                   │  │
│  │ - Token validation                                        │  │
│  │ - File upload with client-side validation                 │  │
│  │ - Success confirmation                                    │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### Custom Metadata

| Component                      | Description                                          |
| ------------------------------ | ---------------------------------------------------- |
| `Document_Request_Config__mdt` | Object configuration: field paths, limits, templates |

### Custom Objects

| Component             | Description                                            |
| --------------------- | ------------------------------------------------------ |
| `Document_Request__c` | Request tracking with secure token and status workflow |

### Apex Classes

| Class                           | Description                                      |
| ------------------------------- | ------------------------------------------------ |
| `DocumentRequestConfigService`  | Configuration retrieval with mockable CRUD layer |
| `DocumentRequestService`        | Request creation, file review, commit workflow   |
| `GuestDocumentUploadService`    | Guest user uploads (without sharing)             |
| `DocumentRequestTriggerHandler` | Token expiration handling                        |
| `ExpireDocumentRequestsBatch`   | Scheduled cleanup of expired requests            |
| `TestDataFactory`               | Reusable test data creation                      |

### LWC Components

| Component                    | Description                              |
| ---------------------------- | ---------------------------------------- |
| `documentRequestQuickAction` | Admin creates request from source record |
| `guestDocumentUpload`        | Portal upload interface for recipients   |
| `documentReviewPanel`        | Admin review and commit interface        |

### Permission Sets

| Permission Set           | Description                       |
| ------------------------ | --------------------------------- |
| `Document_Request_Admin` | Full access for administrators    |
| `Document_Request_Guest` | Apex class access for guest users |

## Installation

### Prerequisites

- Salesforce org with Experience Cloud enabled
- Salesforce CLI installed

### Deploy to Org

```bash
# Authenticate to your org
sf org login web --alias myorg

# Deploy all components
sf project deploy start --source-dir force-app --target-org myorg

# Run tests
sf apex run test --target-org myorg --test-level RunLocalTests --code-coverage
```

### Post-Deployment Setup

1. **Create Configuration Record**
   - Setup → Custom Metadata Types → Document Request Config → Manage Records
   - Create record for each object you want to enable

2. **Create Quick Action** (per object)
   - Setup → Object Manager → [Your Object] → Buttons, Links, and Actions
   - New Action → Lightning Web Component → `c:documentRequestQuickAction`

3. **Add to Page Layout**
   - Add Quick Action to the object's Lightning Record Page

4. **Configure Experience Cloud**
   - Add `guestDocumentUpload` component to a guest-accessible page
   - Assign `Document_Request_Guest` permission set to Guest User profile

5. **Schedule Batch Job**

   ```apex
   // Run daily at midnight
   ExpireDocumentRequestsBatch.scheduleDaily('Expire Document Requests');
   ```

6. **Assign Permission Set**
   ```bash
   sf org assign permset --name Document_Request_Admin --target-org myorg
   ```

## Configuration Example

```
DeveloperName: Case_Document_Request
Source_Object_API_Name__c: Case
Recipient_Email_Field_Path__c: Contact.Email
Recipient_Name_Field_Path__c: Contact.Name
Recipient_Contact_Field_Path__c: ContactId
Default_Expiration_Days__c: 7
Max_File_Size_MB__c: 5
Max_Files_Per_Upload__c: 10
Allowed_File_Extensions__c: pdf,jpg,jpeg,png,doc,docx
```

## Testing

The project includes comprehensive test coverage (96%+):

```bash
# Run all tests with coverage
sf apex run test --target-org myorg --test-level RunLocalTests --code-coverage --result-format human
```

### Mocking Custom Metadata in Tests

```apex
@isTest
static void testWithMockConfig() {
    // Create mock configuration
    Document_Request_Config__mdt mockConfig = DocumentRequestConfigService.createMockConfig(
        'Test_Config', 'Case', 'Contact.Email', 'Contact.Name', 'ContactId'
    );
    DocumentRequestConfigService.setMockConfig('Case', mockConfig);

    // ... run test ...

    DocumentRequestConfigService.clearMocks();
}
```

## Status Flow

```
Draft → Sent → Files_Received → Under_Review → Approved/Rejected
                    ↓
              (Token Expires) → Expired
```

## Security Considerations

- **Token Security**: UUID tokens generated via `Crypto.generateAesKey(128)`
- **Guest User Isolation**: `GuestDocumentUploadService` runs `without sharing` with explicit token validation
- **Data Exposure**: Only request metadata (number, date, instructions) exposed to guests
- **File Validation**: Server-side validation of size, count, and file types

## License

MIT

## Contributing

1. Fork the repository
2. Create a feature branch
3. Ensure tests pass with 90%+ coverage
4. Submit a pull request
