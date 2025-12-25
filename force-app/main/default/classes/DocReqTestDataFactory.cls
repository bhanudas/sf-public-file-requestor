/**
 * @description Test data factory for Document Request Portal
 * Provides reusable test data creation methods
 */
@isTest
public class DocReqTestDataFactory {
  private static final String DEFAULT_EMAIL = 'test@example.com';
  private static final String DEFAULT_NAME = 'Test Contact';

  /**
   * @description Creates a test Account
   */
  public static Account createAccount(String name, Boolean doInsert) {
    Account acc = new Account(Name = name);
    if (doInsert) {
      insert acc;
    }
    return acc;
  }

  /**
   * @description Creates a test Contact
   */
  public static Contact createContact(
    Id accountId,
    String firstName,
    String lastName,
    String email,
    Boolean doInsert
  ) {
    Contact con = new Contact(
      AccountId = accountId,
      FirstName = firstName,
      LastName = lastName,
      Email = email
    );
    if (doInsert) {
      insert con;
    }
    return con;
  }

  /**
   * @description Creates a test Case with Contact
   */
  public static Case createCase(
    Id contactId,
    String subject,
    Boolean doInsert
  ) {
    Case c = new Case(
      ContactId = contactId,
      Subject = subject,
      Status = 'New',
      Origin = 'Web'
    );
    if (doInsert) {
      insert c;
    }
    return c;
  }

  /**
   * @description Creates a Document Request record
   */
  public static Document_Request__c createDocumentRequest(
    Id sourceRecordId,
    String sourceObjectApiName,
    String recipientEmail,
    String recipientName,
    String status,
    Boolean doInsert
  ) {
    Document_Request__c req = new Document_Request__c(
      Source_Record_Id__c = sourceRecordId,
      Source_Object_API_Name__c = sourceObjectApiName,
      Recipient_Email__c = recipientEmail,
      Recipient_Name__c = recipientName,
      Status__c = status,
      Request_Token__c = generateToken(),
      Token_Expiration__c = DateTime.now().addDays(7),
      Request_Date__c = DateTime.now(),
      Requested_By__c = UserInfo.getUserId(),
      Request_Instructions__c = 'Please upload the required documents.',
      Config_Developer_Name__c = 'Case_Document_Request'
    );
    if (doInsert) {
      insert req;
    }
    return req;
  }

  /**
   * @description Creates a Document Request with expired token
   */
  public static Document_Request__c createExpiredDocumentRequest(
    Id sourceRecordId,
    String sourceObjectApiName,
    Boolean doInsert
  ) {
    Document_Request__c req = createDocumentRequest(
      sourceRecordId,
      sourceObjectApiName,
      DEFAULT_EMAIL,
      DEFAULT_NAME,
      'Sent',
      false
    );
    req.Token_Expiration__c = DateTime.now().addDays(-1);
    if (doInsert) {
      insert req;
    }
    return req;
  }

  /**
   * @description Creates a ContentVersion (file) linked to a Document Request
   */
  public static ContentVersion createContentVersion(
    String fileName,
    String fileContent,
    String uploadSource,
    String reviewStatus,
    Boolean doInsert
  ) {
    ContentVersion cv = new ContentVersion(
      Title = fileName,
      PathOnClient = fileName,
      VersionData = Blob.valueOf(fileContent),
      Upload_Source__c = uploadSource,
      Review_Status__c = reviewStatus
    );
    if (doInsert) {
      insert cv;
    }
    return cv;
  }

  /**
   * @description Creates ContentVersion and links it to a Document Request
   */
  public static ContentVersion createLinkedContentVersion(
    Id documentRequestId,
    String fileName,
    String uploadSource,
    String reviewStatus
  ) {
    ContentVersion cv = new ContentVersion(
      Title = fileName,
      PathOnClient = fileName,
      VersionData = Blob.valueOf('Test file content for ' + fileName),
      Upload_Source__c = uploadSource,
      Review_Status__c = reviewStatus,
      FirstPublishLocationId = documentRequestId
    );
    insert cv;
    return cv;
  }

  /**
   * @description Links an existing ContentDocument to a record
   */
  public static ContentDocumentLink createContentDocumentLink(
    Id contentDocumentId,
    Id linkedEntityId,
    Boolean doInsert
  ) {
    ContentDocumentLink cdl = new ContentDocumentLink(
      ContentDocumentId = contentDocumentId,
      LinkedEntityId = linkedEntityId,
      ShareType = 'V',
      Visibility = 'AllUsers'
    );
    if (doInsert) {
      insert cdl;
    }
    return cdl;
  }

  /**
   * @description Generates a UUID-style token
   */
  public static String generateToken() {
    Blob aesKey = Crypto.generateAesKey(128);
    String hex = EncodingUtil.convertToHex(aesKey);
    return hex.substring(0, 8) +
      '-' +
      hex.substring(8, 12) +
      '-' +
      hex.substring(12, 16) +
      '-' +
      hex.substring(16, 20) +
      '-' +
      hex.substring(20, 32);
  }

  /**
   * @description Creates a complete test scenario with Account, Contact, Case, and Document Request
   */
  public static Map<String, SObject> createCompleteTestScenario() {
    Map<String, SObject> result = new Map<String, SObject>();

    Account acc = createAccount('Test Account', true);
    result.put('Account', acc);

    Contact con = createContact(acc.Id, 'Test', 'Contact', DEFAULT_EMAIL, true);
    result.put('Contact', con);

    Case c = createCase(con.Id, 'Test Case', true);
    result.put('Case', c);

    Document_Request__c req = createDocumentRequest(
      c.Id,
      'Case',
      DEFAULT_EMAIL,
      'Test Contact',
      'Sent',
      true
    );
    result.put('Document_Request__c', req);

    return result;
  }

  /**
   * @description Creates test files attached to a Document Request
   */
  public static List<ContentVersion> createTestFilesForRequest(
    Id documentRequestId,
    Integer fileCount
  ) {
    List<ContentVersion> files = new List<ContentVersion>();
    for (Integer i = 0; i < fileCount; i++) {
      files.add(
        createLinkedContentVersion(
          documentRequestId,
          'TestFile' + i + '.pdf',
          'Portal_Upload',
          'Pending_Review'
        )
      );
    }
    return files;
  }

  /**
   * @description Creates a Task for document review
   */
  public static Task createReviewTask(
    Id documentRequestId,
    Id ownerId,
    Boolean doInsert
  ) {
    Task t = new Task(
      Subject = 'Review Document Request',
      WhatId = documentRequestId,
      OwnerId = ownerId,
      Status = 'Open',
      Priority = 'Normal',
      ActivityDate = Date.today().addDays(3)
    );
    if (doInsert) {
      insert t;
    }
    return t;
  }
}
