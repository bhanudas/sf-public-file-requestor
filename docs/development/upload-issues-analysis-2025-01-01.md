# File Upload Issues Analysis

**Date:** January 1, 2025  
**Analyst:** AI Assistant  
**Environment:** helen-prod (kahoowaiwaiana.my.salesforce.com)  
**Public Site:** www.helenhomestead.com

---

## Executive Summary

This document analyzes potential causes for file upload problems reported by testers in the Document Request Portal. The analysis covers code review, org configuration, and architectural considerations.

---

## 1. Critical Configuration Issues

### 1.1 Guest User Permission Set Assignment (HIGH PRIORITY)

**Finding:** The `Document_Request_Guest` permission set is only assigned to ONE guest user:

- **Assigned to:** "Helen Homestead Intake Application Site Guest User"
- **User ID:** 005Vs00000Nle82IAB

**Problem:** There are 14 different guest users in the org (one per Experience Cloud site). If uploads are attempted from a different site than "Helen Homestead Intake Application", the guest user won't have access to the required Apex classes.

**Affected Files:**

- `force-app/main/default/permissionsets/Document_Request_Guest.permissionset-meta.xml`

**Resolution Required:**

- Verify which Experience Cloud site hosts the `/secure-document-upload` page
- Assign the `Document_Request_Guest` permission set to that site's guest user
- The permission set grants access to `GuestDocumentUploadService` and `DocumentRequestConfigService`

### 1.2 Base Domain Configuration Mismatch

**Finding:** Custom Setting values in helen-prod:

- `Base_Domain__c`: `www.helenhomestead.com`
- `Upload_Path__c`: `/secure-document-upload`

**Potential Issue:** The URL `https://www.helenhomestead.com/secure-document-upload` must:

1. Resolve to the correct Experience Cloud site
2. Have the `guestDocumentUpload` LWC component deployed on that page
3. Have the correct guest user profile with Apex class access

**Verification Needed:**

- Confirm the LWC component is actually placed on a page at `/secure-document-upload`
- Confirm the site using this URL has the guest permission set assigned

---

## 2. Code-Level Issues

### 2.1 Token Case Sensitivity

**File:** `GuestDocumentUploadService.cls` (lines 43, 123)

**Finding:** The token lookup uses `.toLowerCase()`:

```apex
WHERE Request_Token__c = :token.toLowerCase()
```

**Potential Issue:** If tokens are stored with mixed case but the field is not configured as case-insensitive, lookups could fail. The token generation in `DocumentRequestService.generateToken()` uses hex encoding which produces lowercase characters, so this should be fine—but worth verifying the field configuration.

### 2.2 Base64 Encoding Memory Limits

**File:** `guestDocumentUpload.js` (lines 156-166)

**Finding:** Files are converted to base64 in the browser before upload:

```javascript
const filesData = await Promise.all(
  this.selectedFiles.map(async (fileWrapper) => {
    const base64 = await this.readFileAsBase64(fileWrapper.file);
    return { ... };
  })
);
```

**Potential Issues:**

1. **Browser Memory:** Base64 encoding increases file size by ~33%. A 5MB file becomes ~6.7MB in base64.
2. **Multiple Files:** Uploading 10 files of 5MB each = ~67MB of base64 data in memory.
3. **Apex Heap Limit:** The `uploadFiles` method decodes base64 server-side. Guest user Apex has a 6MB heap limit, which could be exceeded with large files.

**Symptoms:** Users may see "An error occurred during upload" or browser may become unresponsive.

### 2.3 Server-Side File Size Validation

**File:** `GuestDocumentUploadService.cls` (lines 158, 179-188)

**Finding:** File size is validated AFTER base64 decoding:

```apex
Integer maxSizeBytes = tokenResult.maxFileSizeMB * 1024 * 1024;
// ... later ...
if (fileData.size() > maxSizeBytes) {
```

**Issue:** The heap limit may be exceeded during `EncodingUtil.base64Decode()` before the size check occurs.

### 2.4 Extension Validation Edge Cases

**File:** `GuestDocumentUploadService.cls` (lines 279-284)

**Finding:** Extension extraction:

```apex
private static String getFileExtension(String fileName) {
  if (String.isBlank(fileName) || !fileName.contains('.')) {
    return '';
  }
  return fileName.substringAfterLast('.').toLowerCase();
}
```

**Potential Issue:** Files with multiple extensions (e.g., `document.backup.pdf`) will correctly use the last extension. However, files like `My.Report.Final` (no valid extension) will return `final` which won't match allowed extensions, causing unclear error messages.

### 2.5 Error Handling - Generic Messages

**File:** `GuestDocumentUploadService.cls` (lines 204-209)

**Finding:** DML exceptions return generic message:

```apex
} catch (Exception e) {
  result.success = false;
  result.errorMessage = 'Failed to upload files. Please try again.';
  return result;
}
```

**Issue:** Actual error details are lost. Could be:

- Sharing rules blocking insert
- Validation rules on ContentVersion
- Trigger exceptions
- Field-level security issues

### 2.6 Client-Side Validation Mismatch

**File:** `guestDocumentUpload.js` (lines 122-130)

**Finding:** Client-side extension validation:

```javascript
if (
  this.allowedExtensions.length > 0 &&
  !this.allowedExtensions.includes(extension)
) {
```

**Potential Issue:** The `allowedExtensions` array comes from the server. If the server returns extensions with spaces (e.g., from `getAllowedExtensions()` after split), the comparison may fail. The server trims extensions, but `includes()` is case-sensitive and the server lowercases while the client lowercases independently.

---

## 3. Experience Cloud Configuration Issues

### 3.1 Component Exposure

**File:** `guestDocumentUpload.js-meta.xml`

**Finding:** Component targets are configured correctly:

```xml
<targets>
  <target>lightningCommunity__Page</target>
  <target>lightningCommunity__Default</target>
</targets>
```

**Verification Needed:**

- Confirm the component is actually placed on an Experience Cloud page
- Confirm the page URL matches `/secure-document-upload`

### 3.2 Content Security Policy (CSP)

**Potential Issue:** Experience Cloud sites have strict CSP settings. The `lightning-input type="file"` should work, but custom file handling via FileReader API may be blocked in some CSP configurations.

**Symptoms:** File selection works but upload fails silently.

### 3.3 CORS / Network Issues

**Potential Issue:** If the Experience Cloud site uses a custom domain (www.helenhomestead.com), CORS settings must allow requests from that domain to Salesforce APIs.

---

## 4. Data Model Issues

### 4.1 Object Sharing Model

**File:** `Document_Request__c.object-meta.xml`

**Finding:**

```xml
<sharingModel>Private</sharingModel>
<externalSharingModel>Private</externalSharingModel>
```

**Consideration:** With private sharing, `GuestDocumentUploadService` runs `without sharing`, so this should not be an issue. However, the `DocumentRequestConfigService` runs `with sharing` - verify that custom metadata is accessible to guest users.

### 4.2 ContentVersion Custom Fields

**Files:**

- `ContentVersion/fields/Review_Status__c.field-meta.xml`
- `ContentVersion/fields/Upload_Source__c.field-meta.xml`

**Potential Issue:** If these custom fields on ContentVersion aren't accessible to the guest user profile (even via Apex), inserts may fail.

---

## 5. Production Data Analysis

### 5.1 Existing Document Request

**Finding:** One document request exists in production:

- **ID:** a1DVs000002RwpxMAC
- **Name:** REQ-00000
- **Status:** Approved
- **File Count:** 2
- **Files Received Date:** 2025-12-25

**Observation:** This record successfully received files, indicating the core functionality works. Issues may be:

- Intermittent (timing, load, specific file types)
- Specific to certain users or browsers
- Related to recent changes not yet deployed

---

## 6. Recommended Investigation Steps

### Immediate Actions

1. **Verify Permission Set Assignment**
   - Check which guest user is associated with www.helenhomestead.com
   - Assign `Document_Request_Guest` permission set to that user

2. **Check Browser Console**
   - Have testers open browser developer tools
   - Look for JavaScript errors during file selection/upload
   - Check network tab for failed API calls

3. **Review Debug Logs**
   - Enable debug logging for the guest user
   - Attempt an upload and review logs for exceptions

### Configuration Checks

4. **Experience Cloud Builder**
   - Verify `guestDocumentUpload` component is on `/secure-document-upload` page
   - Check page is published and accessible to guest users

5. **Custom Metadata Access**
   - Verify `Document_Request_Config__mdt` records are accessible
   - Test by accessing the upload URL with a valid token

### Code Improvements (Future)

6. **Enhanced Error Logging**
   - Add System.debug statements in catch blocks
   - Consider custom logging object for guest user errors

7. **Chunked Upload**
   - For large files, implement chunked upload to avoid heap limits
   - This is a significant architectural change

---

## 7. Quick Diagnostic Queries

Run these in helen-prod to gather more information:

```sql
-- Check all guest users and their profiles
SELECT Id, Username, Profile.Name, IsActive
FROM User
WHERE UserType = 'Guest'

-- Check permission set assignments for Document_Request_Guest
SELECT Assignee.Name, Assignee.Profile.Name
FROM PermissionSetAssignment
WHERE PermissionSet.Name = 'Document_Request_Guest'

-- Check recent document requests
SELECT Name, Status__c, CreatedDate, File_Count__c,
       Recipient_Email__c, Config_Developer_Name__c
FROM Document_Request__c
ORDER BY CreatedDate DESC
LIMIT 10
```

---

## 8. Files Referenced in This Analysis

| File                                            | Purpose                           |
| ----------------------------------------------- | --------------------------------- |
| `GuestDocumentUploadService.cls`                | Server-side upload handling       |
| `guestDocumentUpload.js`                        | Client-side upload logic          |
| `guestDocumentUpload.html`                      | Upload form UI                    |
| `guestDocumentUpload.js-meta.xml`               | Component exposure settings       |
| `DocumentRequestConfigService.cls`              | Configuration retrieval           |
| `Document_Request_Guest.permissionset-meta.xml` | Guest user permissions            |
| `Document_Request_Settings__c`                  | Custom setting for URL config     |
| `Document_Request_Config__mdt`                  | Custom metadata for object config |

---

## 9. Summary of Most Likely Causes

| Priority | Issue                                                  | Likelihood | Impact                  |
| -------- | ------------------------------------------------------ | ---------- | ----------------------- |
| 1        | Guest permission set not assigned to correct site user | HIGH       | Uploads fail completely |
| 2        | LWC component not placed on Experience Cloud page      | HIGH       | Page shows nothing      |
| 3        | Heap limit exceeded for large files                    | MEDIUM     | Large file uploads fail |
| 4        | Browser memory issues with multiple files              | MEDIUM     | Browser hangs/crashes   |
| 5        | CSP blocking FileReader API                            | LOW        | Silent failures         |
| 6        | Custom field access on ContentVersion                  | LOW        | Insert fails            |

---

_End of Analysis_
