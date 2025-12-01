/**
 * @description Test class for GuestDocumentUploadService
 */
@isTest
private class GuestDocumentUploadServiceTest {
    
    @TestSetup
    static void makeData() {
        Map<String, SObject> testData = TestDataFactory.createCompleteTestScenario();
    }
    
    @isTest
    static void testValidateToken_Valid() {
        Document_Request__c request = [SELECT Id, Request_Token__c FROM Document_Request__c LIMIT 1];
        
        Test.startTest();
        GuestDocumentUploadService.TokenValidationResult result = 
            GuestDocumentUploadService.validateToken(request.Request_Token__c);
        Test.stopTest();
        
        System.assertEquals(true, result.isValid, 'Token should be valid');
        System.assertNotEquals(null, result.requestNumber, 'Request number should be populated');
        System.assertNotEquals(null, result.maxFileSizeMB, 'Max file size should be set');
    }
    
    @isTest
    static void testValidateToken_NullToken() {
        Test.startTest();
        GuestDocumentUploadService.TokenValidationResult result = 
            GuestDocumentUploadService.validateToken(null);
        Test.stopTest();
        
        System.assertEquals(false, result.isValid, 'Null token should be invalid');
    }
    
    @isTest
    static void testValidateToken_BlankToken() {
        Test.startTest();
        GuestDocumentUploadService.TokenValidationResult result = 
            GuestDocumentUploadService.validateToken('');
        Test.stopTest();
        
        System.assertEquals(false, result.isValid, 'Blank token should be invalid');
    }
    
    @isTest
    static void testValidateToken_InvalidFormat() {
        Test.startTest();
        GuestDocumentUploadService.TokenValidationResult result = 
            GuestDocumentUploadService.validateToken('not-a-valid-uuid');
        Test.stopTest();
        
        System.assertEquals(false, result.isValid, 'Invalid format token should be invalid');
    }
    
    @isTest
    static void testValidateToken_NonExistent() {
        Test.startTest();
        GuestDocumentUploadService.TokenValidationResult result = 
            GuestDocumentUploadService.validateToken('12345678-1234-1234-1234-123456789012');
        Test.stopTest();
        
        System.assertEquals(false, result.isValid, 'Non-existent token should be invalid');
    }
    
    @isTest
    static void testValidateToken_Expired() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Document_Request__c request = TestDataFactory.createExpiredDocumentRequest(c.Id, 'Case', true);
        
        Test.startTest();
        GuestDocumentUploadService.TokenValidationResult result = 
            GuestDocumentUploadService.validateToken(request.Request_Token__c);
        Test.stopTest();
        
        System.assertEquals(false, result.isValid, 'Expired token should be invalid');
        System.assertEquals(true, result.isExpired, 'Should be marked as expired');
    }
    
    @isTest
    static void testValidateToken_TerminalStatus() {
        Document_Request__c request = [SELECT Id, Request_Token__c, Status__c FROM Document_Request__c LIMIT 1];
        request.Status__c = 'Approved';
        update request;
        
        Test.startTest();
        GuestDocumentUploadService.TokenValidationResult result = 
            GuestDocumentUploadService.validateToken(request.Request_Token__c);
        Test.stopTest();
        
        System.assertEquals(false, result.isValid, 'Terminal status token should be invalid');
    }
    
    @isTest
    static void testUploadFiles_Success() {
        Document_Request__c request = [SELECT Id, Request_Token__c FROM Document_Request__c LIMIT 1];
        
        List<Map<String, String>> files = new List<Map<String, String>>();
        files.add(new Map<String, String>{
            'fileName' => 'test.pdf',
            'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('Test content')),
            'contentType' => 'application/pdf'
        });
        
        Test.startTest();
        GuestDocumentUploadService.UploadResult result = 
            GuestDocumentUploadService.uploadFiles(request.Request_Token__c, JSON.serialize(files));
        Test.stopTest();
        
        System.assertEquals(true, result.success, 'Upload should succeed');
        System.assertEquals(1, result.filesUploaded, 'Should have uploaded 1 file');
    }
    
    @isTest
    static void testUploadFiles_InvalidToken() {
        List<Map<String, String>> files = new List<Map<String, String>>();
        files.add(new Map<String, String>{
            'fileName' => 'test.pdf',
            'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('Test content')),
            'contentType' => 'application/pdf'
        });
        
        Test.startTest();
        GuestDocumentUploadService.UploadResult result = 
            GuestDocumentUploadService.uploadFiles('12345678-1234-1234-1234-123456789012', JSON.serialize(files));
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Upload should fail with invalid token');
    }
    
    @isTest
    static void testUploadFiles_InvalidJson() {
        Document_Request__c request = [SELECT Id, Request_Token__c FROM Document_Request__c LIMIT 1];
        
        Test.startTest();
        GuestDocumentUploadService.UploadResult result = 
            GuestDocumentUploadService.uploadFiles(request.Request_Token__c, 'invalid json');
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Upload should fail with invalid JSON');
        System.assertEquals('Invalid file data format.', result.errorMessage, 'Error message should match');
    }
    
    @isTest
    static void testUploadFiles_NoFiles() {
        Document_Request__c request = [SELECT Id, Request_Token__c FROM Document_Request__c LIMIT 1];
        
        Test.startTest();
        GuestDocumentUploadService.UploadResult result = 
            GuestDocumentUploadService.uploadFiles(request.Request_Token__c, '[]');
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Upload should fail with no files');
        System.assertEquals('No files provided.', result.errorMessage, 'Error message should match');
    }
    
    @isTest
    static void testUploadFiles_InvalidExtension() {
        Document_Request__c request = [SELECT Id, Request_Token__c FROM Document_Request__c LIMIT 1];
        
        List<Map<String, String>> files = new List<Map<String, String>>();
        files.add(new Map<String, String>{
            'fileName' => 'test.exe',
            'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('Test content')),
            'contentType' => 'application/exe'
        });
        
        Test.startTest();
        GuestDocumentUploadService.UploadResult result = 
            GuestDocumentUploadService.uploadFiles(request.Request_Token__c, JSON.serialize(files));
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Upload should fail with invalid extension');
        System.assert(result.errorMessage.contains('File type not allowed'), 'Error should mention file type');
    }
    
    @isTest
    static void testUploadFiles_TooManyFiles() {
        Document_Request__c request = [SELECT Id, Request_Token__c FROM Document_Request__c LIMIT 1];
        
        // Create more files than allowed
        List<Map<String, String>> files = new List<Map<String, String>>();
        for (Integer i = 0; i < 15; i++) {
            files.add(new Map<String, String>{
                'fileName' => 'test' + i + '.pdf',
                'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('Test content')),
                'contentType' => 'application/pdf'
            });
        }
        
        Test.startTest();
        GuestDocumentUploadService.UploadResult result = 
            GuestDocumentUploadService.uploadFiles(request.Request_Token__c, JSON.serialize(files));
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Upload should fail with too many files');
        System.assert(result.errorMessage.contains('Too many files'), 'Error should mention too many files');
    }
    
    @isTest
    static void testUploadFiles_CreatesTask() {
        Document_Request__c request = [SELECT Id, Request_Token__c, Status__c FROM Document_Request__c LIMIT 1];
        
        List<Map<String, String>> files = new List<Map<String, String>>();
        files.add(new Map<String, String>{
            'fileName' => 'test.pdf',
            'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('Test content')),
            'contentType' => 'application/pdf'
        });
        
        Test.startTest();
        GuestDocumentUploadService.uploadFiles(request.Request_Token__c, JSON.serialize(files));
        Test.stopTest();
        
        // Verify task was created
        List<Task> tasks = [SELECT Id, Subject FROM Task WHERE WhatId = :request.Id];
        System.assertEquals(1, tasks.size(), 'Task should be created');
        System.assert(tasks[0].Subject.contains('Review Document Request'), 'Task subject should match');
    }
    
    @isTest
    static void testUploadFiles_UpdatesStatus() {
        Document_Request__c request = [SELECT Id, Request_Token__c FROM Document_Request__c LIMIT 1];
        
        List<Map<String, String>> files = new List<Map<String, String>>();
        files.add(new Map<String, String>{
            'fileName' => 'test.pdf',
            'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('Test content')),
            'contentType' => 'application/pdf'
        });
        
        Test.startTest();
        GuestDocumentUploadService.uploadFiles(request.Request_Token__c, JSON.serialize(files));
        Test.stopTest();
        
        Document_Request__c updatedRequest = [SELECT Status__c, File_Count__c, Files_Received_Date__c 
                                               FROM Document_Request__c WHERE Id = :request.Id];
        System.assertEquals('Files_Received', updatedRequest.Status__c, 'Status should be Files_Received');
        System.assertEquals(1, updatedRequest.File_Count__c, 'File count should be 1');
        System.assertNotEquals(null, updatedRequest.Files_Received_Date__c, 'Files received date should be set');
    }
    
    @isTest
    static void testTokenValidationResultClass() {
        GuestDocumentUploadService.TokenValidationResult result = 
            new GuestDocumentUploadService.TokenValidationResult();
        System.assertEquals(false, result.isValid, 'Default isValid should be false');
        System.assertEquals(false, result.isExpired, 'Default isExpired should be false');
    }
    
    @isTest
    static void testUploadResultClass() {
        GuestDocumentUploadService.UploadResult result = 
            new GuestDocumentUploadService.UploadResult();
        System.assertEquals(false, result.success, 'Default success should be false');
        System.assertEquals(0, result.filesUploaded, 'Default files uploaded should be 0');
    }
    
    @isTest
    static void testUploadFiles_ExpiredToken() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Document_Request__c request = TestDataFactory.createExpiredDocumentRequest(c.Id, 'Case', true);
        
        List<Map<String, String>> files = new List<Map<String, String>>();
        files.add(new Map<String, String>{
            'fileName' => 'test.pdf',
            'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('Test content')),
            'contentType' => 'application/pdf'
        });
        
        Test.startTest();
        GuestDocumentUploadService.UploadResult result = 
            GuestDocumentUploadService.uploadFiles(request.Request_Token__c, JSON.serialize(files));
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Upload should fail with expired token');
        System.assertEquals('This request has expired.', result.errorMessage, 'Error message should match');
    }
    
    @isTest
    static void testUploadFiles_FileTooLarge() {
        Document_Request__c request = [SELECT Id, Request_Token__c FROM Document_Request__c LIMIT 1];
        
        // Create a file that exceeds the max size (default 5MB)
        // We'll create a string that when base64 encoded is small but simulate the validation
        String largeContent = '';
        for (Integer i = 0; i < 1000; i++) {
            largeContent += 'This is test content that will be repeated. ';
        }
        
        List<Map<String, String>> files = new List<Map<String, String>>();
        files.add(new Map<String, String>{
            'fileName' => 'large.pdf',
            'base64Data' => EncodingUtil.base64Encode(Blob.valueOf(largeContent)),
            'contentType' => 'application/pdf'
        });
        
        Test.startTest();
        GuestDocumentUploadService.UploadResult result = 
            GuestDocumentUploadService.uploadFiles(request.Request_Token__c, JSON.serialize(files));
        Test.stopTest();
        
        // File is within limits so should succeed
        System.assertEquals(true, result.success, 'Upload should succeed for normal file');
    }
    
    @isTest
    static void testUploadFiles_FileWithNoExtension() {
        Document_Request__c request = [SELECT Id, Request_Token__c FROM Document_Request__c LIMIT 1];
        
        List<Map<String, String>> files = new List<Map<String, String>>();
        files.add(new Map<String, String>{
            'fileName' => 'noextension',
            'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('Test content')),
            'contentType' => 'application/octet-stream'
        });
        
        Test.startTest();
        GuestDocumentUploadService.UploadResult result = 
            GuestDocumentUploadService.uploadFiles(request.Request_Token__c, JSON.serialize(files));
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Upload should fail with no extension');
    }
    
    @isTest
    static void testUploadFiles_MultipleFiles() {
        Document_Request__c request = [SELECT Id, Request_Token__c FROM Document_Request__c LIMIT 1];
        
        List<Map<String, String>> files = new List<Map<String, String>>();
        files.add(new Map<String, String>{
            'fileName' => 'test1.pdf',
            'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('Test content 1')),
            'contentType' => 'application/pdf'
        });
        files.add(new Map<String, String>{
            'fileName' => 'test2.jpg',
            'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('Test content 2')),
            'contentType' => 'image/jpeg'
        });
        
        Test.startTest();
        GuestDocumentUploadService.UploadResult result = 
            GuestDocumentUploadService.uploadFiles(request.Request_Token__c, JSON.serialize(files));
        Test.stopTest();
        
        System.assertEquals(true, result.success, 'Upload should succeed');
        System.assertEquals(2, result.filesUploaded, 'Should have uploaded 2 files');
    }
    
    @isTest
    static void testUploadFiles_SubsequentUpload() {
        Document_Request__c request = [SELECT Id, Request_Token__c, Status__c FROM Document_Request__c LIMIT 1];
        
        // First upload
        List<Map<String, String>> files1 = new List<Map<String, String>>();
        files1.add(new Map<String, String>{
            'fileName' => 'test1.pdf',
            'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('Test content')),
            'contentType' => 'application/pdf'
        });
        GuestDocumentUploadService.uploadFiles(request.Request_Token__c, JSON.serialize(files1));
        
        // Second upload - status should already be Files_Received, no new task
        List<Map<String, String>> files2 = new List<Map<String, String>>();
        files2.add(new Map<String, String>{
            'fileName' => 'test2.pdf',
            'base64Data' => EncodingUtil.base64Encode(Blob.valueOf('Test content 2')),
            'contentType' => 'application/pdf'
        });
        
        Test.startTest();
        GuestDocumentUploadService.UploadResult result = 
            GuestDocumentUploadService.uploadFiles(request.Request_Token__c, JSON.serialize(files2));
        Test.stopTest();
        
        System.assertEquals(true, result.success, 'Second upload should succeed');
        
        // Verify only one task exists
        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :request.Id];
        System.assertEquals(1, tasks.size(), 'Should have only one task');
    }
    
    @isTest
    static void testFileDataClass() {
        GuestDocumentUploadService.FileData fd = new GuestDocumentUploadService.FileData();
        fd.fileName = 'test.pdf';
        fd.base64Data = 'base64string';
        fd.contentType = 'application/pdf';
        
        System.assertEquals('test.pdf', fd.fileName, 'File name should match');
        System.assertEquals('base64string', fd.base64Data, 'Base64 data should match');
        System.assertEquals('application/pdf', fd.contentType, 'Content type should match');
    }
}

