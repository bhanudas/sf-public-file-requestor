/**
 * @description Service class for Document Request operations (internal/authenticated users)
 */
public with sharing class DocumentRequestService {
  /**
   * @description Creates a new document request
   * @param sourceRecordId Source record ID
   * @param sourceObjectApiName API name of the source object
   * @param requestInstructions Administrator's message to recipient
   * @param internalNotes Internal notes (not sent)
   * @param expirationDaysOverride Optional override for expiration days
   * @return Wrapper containing created request Id and Name
   */
  @AuraEnabled
  public static DocumentRequestResult createDocumentRequest(
    Id sourceRecordId,
    String sourceObjectApiName,
    String requestInstructions,
    String internalNotes,
    Integer expirationDaysOverride
  ) {
    // Get configuration
    Document_Request_Config__mdt config = DocumentRequestConfigService.getConfigForObject(
      sourceObjectApiName
    );
    if (config == null) {
      throw new DocumentRequestException(
        'Document requests are not enabled for this object type.'
      );
    }

    // Get recipient info
    DocumentRequestConfigService.RecipientInfo recipientInfo = DocumentRequestConfigService.getRecipientInfo(
      sourceRecordId,
      config
    );

    if (String.isBlank(recipientInfo.email)) {
      throw new DocumentRequestException(
        'No email address found for the recipient on this record.'
      );
    }

    // Calculate expiration
    Integer expirationDays = expirationDaysOverride != null
      ? expirationDaysOverride
      : DocumentRequestConfigService.getExpirationDays(config);

    // Create the request
    Document_Request__c request = new Document_Request__c(
      Source_Record_Id__c = sourceRecordId,
      Source_Object_API_Name__c = sourceObjectApiName,
      Recipient_Email__c = recipientInfo.email,
      Recipient_Name__c = recipientInfo.name,
      Recipient_Contact__c = recipientInfo.contactId,
      Status__c = 'Sent',
      Request_Token__c = generateToken(),
      Token_Expiration__c = DateTime.now().addDays(expirationDays),
      Request_Date__c = DateTime.now(),
      Requested_By__c = UserInfo.getUserId(),
      Request_Instructions__c = requestInstructions,
      Internal_Notes__c = internalNotes,
      Config_Developer_Name__c = config.DeveloperName
    );

    insert request;

    // Query for auto-number and fields needed for email
    request = [
      SELECT
        Id,
        Name,
        Request_Token__c,
        Recipient_Email__c,
        Recipient_Name__c,
        Token_Expiration__c,
        Request_Instructions__c
      FROM Document_Request__c
      WHERE Id = :request.Id
    ];

    // Send email notification
    sendRequestEmail(request, config);

    return new DocumentRequestResult(
      request.Id,
      request.Name,
      request.Recipient_Email__c
    );
  }

  /**
   * @description Generates a secure UUID token
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
   * @description Gets recipient information for the Quick Action LWC
   * @param sourceRecordId The source record ID
   * @param sourceObjectApiName The API name of the source object
   * @return RecipientInfoResult with name and email
   */
  @AuraEnabled
  public static RecipientInfoResult getRecipientInfoForLwc(
    Id sourceRecordId,
    String sourceObjectApiName
  ) {
    // Get configuration
    Document_Request_Config__mdt config = DocumentRequestConfigService.getConfigForObject(
      sourceObjectApiName
    );
    if (config == null) {
      throw new DocumentRequestException(
        'Document requests are not enabled for this object type.'
      );
    }

    // Get recipient info
    DocumentRequestConfigService.RecipientInfo recipientInfo = DocumentRequestConfigService.getRecipientInfo(
      sourceRecordId,
      config
    );

    return new RecipientInfoResult(recipientInfo.name, recipientInfo.email);
  }

  /**
   * @description Sends email notification to recipient
   */
  private static void sendRequestEmail(
    Document_Request__c request,
    Document_Request_Config__mdt config
  ) {
    // Build upload URL using Custom Setting
    Document_Request_Settings__c settings = Document_Request_Settings__c.getInstance();

    String baseUrl;
    if (String.isNotBlank(settings?.Base_Domain__c)) {
      baseUrl = 'https://' + settings.Base_Domain__c;
    } else {
      baseUrl = Site.getBaseUrl();
      if (String.isBlank(baseUrl)) {
        baseUrl = URL.getOrgDomainUrl().toExternalForm();
      }
    }

    String uploadPath = String.isNotBlank(settings?.Upload_Path__c)
      ? settings.Upload_Path__c
      : '/document-upload';

    String uploadUrl =
      baseUrl +
      uploadPath +
      '?token=' +
      request.Request_Token__c;

    // Send email
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    email.setToAddresses(new List<String>{ request.Recipient_Email__c });
    email.setSubject('Document Request: ' + request.Name);

    String body =
      'Dear ' +
      (String.isNotBlank(request.Recipient_Name__c)
        ? request.Recipient_Name__c
        : 'Recipient') +
      ',\n\n';
    body += 'A document has been requested from you.\n\n';
    body += 'Request Number: ' + request.Name + '\n\n';
    body += 'Instructions:\n' + request.Request_Instructions__c + '\n\n';
    body +=
      'Please upload your documents using the following link:\n' +
      uploadUrl +
      '\n\n';
    body +=
      'This link will expire on: ' +
      request.Token_Expiration__c.format() +
      '\n\n';
    body += 'Thank you.';

    email.setPlainTextBody(body);

    try {
      Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    } catch (Exception e) {
      // Log but don't fail the request creation
      System.debug('Email send failed: ' + e.getMessage());
    }
  }

  /**
   * @description Approves a file
   */
  @AuraEnabled
  public static void approveFile(Id contentVersionId) {
    ContentVersion cv = [
      SELECT Id
      FROM ContentVersion
      WHERE Id = :contentVersionId
    ];
    cv.Review_Status__c = 'Approved';
    cv.Reviewed_By__c = UserInfo.getUserId();
    cv.Review_Date__c = DateTime.now();
    update cv;
  }

  /**
   * @description Rejects a file with reason
   */
  @AuraEnabled
  public static void rejectFile(Id contentVersionId, String rejectionReason) {
    if (String.isBlank(rejectionReason)) {
      throw new DocumentRequestException('Rejection reason is required.');
    }

    ContentVersion cv = [
      SELECT Id
      FROM ContentVersion
      WHERE Id = :contentVersionId
    ];
    cv.Review_Status__c = 'Rejected';
    cv.Reviewed_By__c = UserInfo.getUserId();
    cv.Review_Date__c = DateTime.now();
    cv.Rejection_Reason__c = rejectionReason;
    update cv;
  }

  /**
   * @description Commits approved files to the source record
   */
  @AuraEnabled
  public static void commitApprovedFiles(Id documentRequestId) {
    // Get the document request
    Document_Request__c request = [
      SELECT Id, Source_Record_Id__c, Source_Object_API_Name__c, Status__c
      FROM Document_Request__c
      WHERE Id = :documentRequestId
    ];

    if (String.isBlank(request.Source_Record_Id__c)) {
      throw new DocumentRequestException('Source record not found.');
    }

    // Get approved content document IDs
    List<ContentDocumentLink> existingLinks = [
      SELECT ContentDocumentId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :documentRequestId
    ];

    Set<Id> contentDocIds = new Set<Id>();
    for (ContentDocumentLink cdl : existingLinks) {
      contentDocIds.add(cdl.ContentDocumentId);
    }

    // Get approved files
    List<ContentVersion> approvedFiles = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE
        ContentDocumentId IN :contentDocIds
        AND Review_Status__c = 'Approved'
        AND IsLatest = TRUE
    ];

    if (approvedFiles.isEmpty()) {
      throw new DocumentRequestException('No approved files to commit.');
    }

    // Create links to source record
    List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
    for (ContentVersion cv : approvedFiles) {
      newLinks.add(
        new ContentDocumentLink(
          ContentDocumentId = cv.ContentDocumentId,
          LinkedEntityId = request.Source_Record_Id__c,
          ShareType = 'V',
          Visibility = 'AllUsers'
        )
      );
    }

    insert newLinks;

    // Update request status
    request.Status__c = 'Approved';
    request.Review_Completed_Date__c = DateTime.now();
    update request;

    // Complete associated tasks
    List<Task> tasks = [
      SELECT Id, Status
      FROM Task
      WHERE WhatId = :documentRequestId AND Status != 'Completed'
    ];

    for (Task t : tasks) {
      t.Status = 'Completed';
    }

    if (!tasks.isEmpty()) {
      update tasks;
    }
  }

  /**
   * @description Gets document request details for the review panel
   */
  @AuraEnabled(cacheable=true)
  public static DocumentRequestDetail getRequestDetails(Id documentRequestId) {
    Document_Request__c request = [
      SELECT
        Id,
        Name,
        Status__c,
        Request_Date__c,
        Token_Expiration__c,
        Source_Record_Id__c,
        Source_Object_API_Name__c,
        Recipient_Email__c,
        Recipient_Name__c,
        Recipient_Contact__c,
        Request_Instructions__c,
        Config_Developer_Name__c,
        File_Count__c,
        Files_Received_Date__c,
        Review_Completed_Date__c,
        Requested_By__c,
        Requested_By__r.Name
      FROM Document_Request__c
      WHERE Id = :documentRequestId
    ];

    return new DocumentRequestDetail(request);
  }

  /**
   * @description Gets files attached to a document request
   */
  @AuraEnabled(cacheable=true)
  public static List<FileDetail> getRequestFiles(Id documentRequestId) {
    List<ContentDocumentLink> links = [
      SELECT ContentDocumentId
      FROM ContentDocumentLink
      WHERE LinkedEntityId = :documentRequestId
    ];

    Set<Id> docIds = new Set<Id>();
    for (ContentDocumentLink cdl : links) {
      docIds.add(cdl.ContentDocumentId);
    }

    List<ContentVersion> versions = [
      SELECT
        Id,
        Title,
        ContentDocumentId,
        FileExtension,
        ContentSize,
        CreatedDate,
        Review_Status__c,
        Upload_Source__c,
        Reviewed_By__c,
        Reviewed_By__r.Name,
        Review_Date__c,
        Rejection_Reason__c
      FROM ContentVersion
      WHERE ContentDocumentId IN :docIds AND IsLatest = TRUE
      ORDER BY CreatedDate DESC
    ];

    List<FileDetail> files = new List<FileDetail>();
    for (ContentVersion cv : versions) {
      files.add(new FileDetail(cv));
    }

    return files;
  }

  /**
   * @description Updates request status to Under Review
   */
  @AuraEnabled
  public static void startReview(Id documentRequestId) {
    Document_Request__c request = [
      SELECT Id, Status__c
      FROM Document_Request__c
      WHERE Id = :documentRequestId
    ];

    if (request.Status__c == 'Files_Received') {
      request.Status__c = 'Under_Review';
      update request;
    }
  }

  /**
   * @description Rejects the entire request
   */
  @AuraEnabled
  public static void rejectRequest(Id documentRequestId, String reviewNotes) {
    Document_Request__c request = [
      SELECT Id, Status__c
      FROM Document_Request__c
      WHERE Id = :documentRequestId
    ];

    request.Status__c = 'Rejected';
    request.Review_Completed_Date__c = DateTime.now();
    request.Review_Notes__c = reviewNotes;
    update request;
  }

  // Wrapper classes
  public class DocumentRequestResult {
    @AuraEnabled
    public Id requestId { get; set; }
    @AuraEnabled
    public String requestName { get; set; }
    @AuraEnabled
    public String recipientEmail { get; set; }

    public DocumentRequestResult(
      Id requestId,
      String requestName,
      String recipientEmail
    ) {
      this.requestId = requestId;
      this.requestName = requestName;
      this.recipientEmail = recipientEmail;
    }
  }

  public class DocumentRequestDetail {
    @AuraEnabled
    public Id id { get; set; }
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public String status { get; set; }
    @AuraEnabled
    public DateTime requestDate { get; set; }
    @AuraEnabled
    public DateTime tokenExpiration { get; set; }
    @AuraEnabled
    public String sourceRecordId { get; set; }
    @AuraEnabled
    public String sourceObjectApiName { get; set; }
    @AuraEnabled
    public String recipientEmail { get; set; }
    @AuraEnabled
    public String recipientName { get; set; }
    @AuraEnabled
    public String instructions { get; set; }
    @AuraEnabled
    public Integer fileCount { get; set; }
    @AuraEnabled
    public DateTime filesReceivedDate { get; set; }
    @AuraEnabled
    public DateTime reviewCompletedDate { get; set; }
    @AuraEnabled
    public String requestedByName { get; set; }

    public DocumentRequestDetail(Document_Request__c req) {
      this.id = req.Id;
      this.name = req.Name;
      this.status = req.Status__c;
      this.requestDate = req.Request_Date__c;
      this.tokenExpiration = req.Token_Expiration__c;
      this.sourceRecordId = req.Source_Record_Id__c;
      this.sourceObjectApiName = req.Source_Object_API_Name__c;
      this.recipientEmail = req.Recipient_Email__c;
      this.recipientName = req.Recipient_Name__c;
      this.instructions = req.Request_Instructions__c;
      this.fileCount = req.File_Count__c != null
        ? (Integer) req.File_Count__c
        : 0;
      this.filesReceivedDate = req.Files_Received_Date__c;
      this.reviewCompletedDate = req.Review_Completed_Date__c;
      this.requestedByName = req.Requested_By__r?.Name;
    }
  }

  public class FileDetail {
    @AuraEnabled
    public Id id { get; set; }
    @AuraEnabled
    public Id contentDocumentId { get; set; }
    @AuraEnabled
    public String title { get; set; }
    @AuraEnabled
    public String fileExtension { get; set; }
    @AuraEnabled
    public Integer contentSize { get; set; }
    @AuraEnabled
    public DateTime createdDate { get; set; }
    @AuraEnabled
    public String reviewStatus { get; set; }
    @AuraEnabled
    public String uploadSource { get; set; }
    @AuraEnabled
    public String reviewedByName { get; set; }
    @AuraEnabled
    public DateTime reviewDate { get; set; }
    @AuraEnabled
    public String rejectionReason { get; set; }
    @AuraEnabled
    public String previewUrl { get; set; }
    @AuraEnabled
    public String downloadUrl { get; set; }

    public FileDetail(ContentVersion cv) {
      this.id = cv.Id;
      this.contentDocumentId = cv.ContentDocumentId;
      this.title = cv.Title;
      this.fileExtension = cv.FileExtension;
      this.contentSize = cv.ContentSize;
      this.createdDate = cv.CreatedDate;
      this.reviewStatus = cv.Review_Status__c;
      this.uploadSource = cv.Upload_Source__c;
      this.reviewedByName = cv.Reviewed_By__r?.Name;
      this.reviewDate = cv.Review_Date__c;
      this.rejectionReason = cv.Rejection_Reason__c;
      // Set file URLs for preview and download
      this.previewUrl =
        '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' +
        cv.Id;
      this.downloadUrl = '/sfc/servlet.shepherd/version/download/' + cv.Id;
    }
  }

  public class RecipientInfoResult {
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public String email { get; set; }

    public RecipientInfoResult(String name, String email) {
      this.name = name;
      this.email = email;
    }
  }

  public class DocumentRequestException extends Exception {
  }
}
