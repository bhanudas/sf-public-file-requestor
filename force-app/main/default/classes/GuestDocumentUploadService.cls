/**
 * @description Service class for Guest User document upload operations
 * Runs WITHOUT SHARING to allow Guest User access, with explicit token validation
 */
public without sharing class GuestDocumentUploadService {
  private static final Set<String> TERMINAL_STATUSES = new Set<String>{
    'Approved',
    'Rejected',
    'Expired'
  };

  private static final Pattern UUID_PATTERN = Pattern.compile(
    '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'
  );

  /**
   * @description Validates a token and returns request metadata if valid
   * @param token GUID from URL parameter
   * @return Wrapper with validation result and safe metadata
   */
  @AuraEnabled
  public static TokenValidationResult validateToken(String token) {
    TokenValidationResult result = new TokenValidationResult();

    // Validate token format
    if (String.isBlank(token) || !isValidUuidFormat(token)) {
      result.isValid = false;
      return result;
    }

    // Query for request
    List<Document_Request__c> requests = [
      SELECT
        Id,
        Name,
        Request_Date__c,
        Request_Instructions__c,
        Status__c,
        Token_Expiration__c,
        Config_Developer_Name__c,
        File_Count__c
      FROM Document_Request__c
      WHERE Request_Token__c = :token.toLowerCase()
      LIMIT 1
    ];

    if (requests.isEmpty()) {
      result.isValid = false;
      return result;
    }

    Document_Request__c request = requests[0];

    // Check if expired
    if (request.Token_Expiration__c < DateTime.now()) {
      // Update status to expired if not already terminal
      if (!TERMINAL_STATUSES.contains(request.Status__c)) {
        request.Status__c = 'Expired';
        update request;
      }
      result.isValid = false;
      result.isExpired = true;
      return result;
    }

    // Check if in terminal state
    if (TERMINAL_STATUSES.contains(request.Status__c)) {
      result.isValid = false;
      return result;
    }

    // Token is valid - populate safe metadata
    result.isValid = true;
    result.requestNumber = request.Name;
    result.requestDate = request.Request_Date__c.format();
    result.instructions = request.Request_Instructions__c;
    result.existingFileCount = request.File_Count__c != null
      ? (Integer) request.File_Count__c
      : 0;

    // Get configuration limits
    Document_Request_Config__mdt config = DocumentRequestConfigService.getConfigByDeveloperName(
      request.Config_Developer_Name__c
    );

    result.maxFileSizeMB = DocumentRequestConfigService.getMaxFileSizeMB(
      config
    );
    result.maxFilesPerUpload = DocumentRequestConfigService.getMaxFilesPerUpload(
      config
    );
    result.allowedExtensions = DocumentRequestConfigService.getAllowedExtensions(
      config
    );

    return result;
  }

  /**
   * @description Uploads files for a document request
   * @param token GUID for re-validation
   * @param filesJson JSON array of file data
   * @return Upload result
   */
  @AuraEnabled
  public static UploadResult uploadFiles(String token, String filesJson) {
    UploadResult result = new UploadResult();

    // Re-validate token
    TokenValidationResult tokenResult = validateToken(token);
    if (!tokenResult.isValid) {
      result.success = false;
      result.errorMessage = tokenResult.isExpired
        ? 'This request has expired.'
        : 'Invalid or expired request.';
      return result;
    }

    // Get the request
    Document_Request__c request = [
      SELECT Id, Status__c, File_Count__c, Config_Developer_Name__c
      FROM Document_Request__c
      WHERE Request_Token__c = :token.toLowerCase()
      LIMIT 1
    ];

    // Parse files
    List<FileData> files;
    try {
      files = (List<FileData>) JSON.deserialize(
        filesJson,
        List<FileData>.class
      );
    } catch (Exception e) {
      result.success = false;
      result.errorMessage = 'Invalid file data format.';
      return result;
    }

    // Validate file count
    if (files.isEmpty()) {
      result.success = false;
      result.errorMessage = 'No files provided.';
      return result;
    }

    if (files.size() > tokenResult.maxFilesPerUpload) {
      result.success = false;
      result.errorMessage =
        'Too many files. Maximum is ' +
        tokenResult.maxFilesPerUpload +
        '.';
      return result;
    }

    // Validate and create files
    List<ContentVersion> contentVersions = new List<ContentVersion>();
    Integer maxSizeBytes = tokenResult.maxFileSizeMB * 1024 * 1024;

    for (FileData file : files) {
      // Validate extension
      String extension = getFileExtension(file.fileName);
      if (!tokenResult.allowedExtensions.contains(extension.toLowerCase())) {
        result.success = false;
        result.errorMessage = 'File type not allowed: ' + extension;
        return result;
      }

      // Decode and validate size
      Blob fileData;
      try {
        fileData = EncodingUtil.base64Decode(file.base64Data);
      } catch (Exception e) {
        result.success = false;
        result.errorMessage = 'Invalid file data for: ' + file.fileName;
        return result;
      }

      if (fileData.size() > maxSizeBytes) {
        result.success = false;
        result.errorMessage =
          'File too large: ' +
          file.fileName +
          '. Maximum size is ' +
          tokenResult.maxFileSizeMB +
          ' MB.';
        return result;
      }

      // Create ContentVersion
      contentVersions.add(
        new ContentVersion(
          Title = file.fileName,
          PathOnClient = file.fileName,
          VersionData = fileData,
          FirstPublishLocationId = request.Id,
          Upload_Source__c = 'Portal_Upload',
          Review_Status__c = 'Pending_Review'
        )
      );
    }

    // Insert files
    try {
      insert contentVersions;
    } catch (Exception e) {
      result.success = false;
      result.errorMessage = 'Failed to upload files. Please try again.';
      return result;
    }

    // Update request status and file count
    Boolean isFirstUpload = request.Status__c == 'Sent';
    Integer newFileCount =
      (request.File_Count__c != null ? (Integer) request.File_Count__c : 0) +
      files.size();

    request.File_Count__c = newFileCount;
    if (isFirstUpload) {
      request.Status__c = 'Files_Received';
      request.Files_Received_Date__c = DateTime.now();
    }

    update request;

    // Create review task if first upload
    if (isFirstUpload) {
      createReviewTask(request);
    }

    result.success = true;
    result.filesUploaded = files.size();
    result.message = 'Your documents have been received and are pending review.';

    return result;
  }

  /**
   * @description Creates a review task for the requesting user
   */
  private static void createReviewTask(Document_Request__c request) {
    // Get the requesting user
    Document_Request__c fullRequest = [
      SELECT Id, Name, Requested_By__c, Recipient_Email__c, File_Count__c
      FROM Document_Request__c
      WHERE Id = :request.Id
    ];

    if (fullRequest.Requested_By__c != null) {
      Task reviewTask = new Task(
        Subject = 'Review Document Request: ' + fullRequest.Name,
        WhatId = fullRequest.Id,
        OwnerId = fullRequest.Requested_By__c,
        Status = 'Open',
        Priority = 'Normal',
        ActivityDate = Date.today().addDays(3),
        Description = 'Documents received from ' +
          fullRequest.Recipient_Email__c +
          '. File count: ' +
          fullRequest.File_Count__c
      );
      insert reviewTask;
    }
  }

  /**
   * @description Validates UUID format
   */
  private static Boolean isValidUuidFormat(String token) {
    if (String.isBlank(token)) {
      return false;
    }
    return UUID_PATTERN.matcher(token.toLowerCase()).matches();
  }

  /**
   * @description Extracts file extension from filename
   */
  private static String getFileExtension(String fileName) {
    if (String.isBlank(fileName) || !fileName.contains('.')) {
      return '';
    }
    return fileName.substringAfterLast('.').toLowerCase();
  }

  // Wrapper classes
  public class TokenValidationResult {
    @AuraEnabled
    public Boolean isValid { get; set; }
    @AuraEnabled
    public Boolean isExpired { get; set; }
    @AuraEnabled
    public String requestNumber { get; set; }
    @AuraEnabled
    public String requestDate { get; set; }
    @AuraEnabled
    public String instructions { get; set; }
    @AuraEnabled
    public Integer existingFileCount { get; set; }
    @AuraEnabled
    public Integer maxFileSizeMB { get; set; }
    @AuraEnabled
    public Integer maxFilesPerUpload { get; set; }
    @AuraEnabled
    public List<String> allowedExtensions { get; set; }

    public TokenValidationResult() {
      this.isValid = false;
      this.isExpired = false;
    }
  }

  public class UploadResult {
    @AuraEnabled
    public Boolean success { get; set; }
    @AuraEnabled
    public String errorMessage { get; set; }
    @AuraEnabled
    public String message { get; set; }
    @AuraEnabled
    public Integer filesUploaded { get; set; }

    public UploadResult() {
      this.success = false;
      this.filesUploaded = 0;
    }
  }

  public class FileData {
    public String fileName { get; set; }
    public String base64Data { get; set; }
    public String contentType { get; set; }
  }
}
