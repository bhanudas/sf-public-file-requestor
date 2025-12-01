/**
 * @description Test class for DocumentRequestService
 */
@isTest
private class DocumentRequestServiceTest {
    
    @TestSetup
    static void makeData() {
        Map<String, SObject> testData = TestDataFactory.createCompleteTestScenario();
    }
    
    @isTest
    static void testGenerateToken() {
        String token = DocumentRequestService.generateToken();
        System.assertNotEquals(null, token, 'Token should not be null');
        System.assertEquals(36, token.length(), 'Token should be 36 characters (UUID format)');
        System.assert(token.contains('-'), 'Token should contain dashes');
    }
    
    @isTest
    static void testApproveFile() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        ContentVersion cv = TestDataFactory.createLinkedContentVersion(
            request.Id, 'test.pdf', 'Portal_Upload', 'Pending_Review'
        );
        
        Test.startTest();
        DocumentRequestService.approveFile(cv.Id);
        Test.stopTest();
        
        ContentVersion updatedCv = [SELECT Review_Status__c, Reviewed_By__c, Review_Date__c 
                                    FROM ContentVersion WHERE Id = :cv.Id];
        System.assertEquals('Approved', updatedCv.Review_Status__c, 'Status should be Approved');
        System.assertEquals(UserInfo.getUserId(), updatedCv.Reviewed_By__c, 'Reviewer should be current user');
        System.assertNotEquals(null, updatedCv.Review_Date__c, 'Review date should be set');
    }
    
    @isTest
    static void testRejectFile() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        ContentVersion cv = TestDataFactory.createLinkedContentVersion(
            request.Id, 'test.pdf', 'Portal_Upload', 'Pending_Review'
        );
        
        Test.startTest();
        DocumentRequestService.rejectFile(cv.Id, 'Document is illegible');
        Test.stopTest();
        
        ContentVersion updatedCv = [SELECT Review_Status__c, Rejection_Reason__c 
                                    FROM ContentVersion WHERE Id = :cv.Id];
        System.assertEquals('Rejected', updatedCv.Review_Status__c, 'Status should be Rejected');
        System.assertEquals('Document is illegible', updatedCv.Rejection_Reason__c, 'Reason should be set');
    }
    
    @isTest
    static void testRejectFile_NoReason() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        ContentVersion cv = TestDataFactory.createLinkedContentVersion(
            request.Id, 'test.pdf', 'Portal_Upload', 'Pending_Review'
        );
        
        Test.startTest();
        try {
            DocumentRequestService.rejectFile(cv.Id, '');
            System.assert(false, 'Should have thrown exception');
        } catch (DocumentRequestService.DocumentRequestException e) {
            System.assertEquals('Rejection reason is required.', e.getMessage(), 'Error message should match');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCommitApprovedFiles() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Document_Request__c request = [SELECT Id, Source_Record_Id__c FROM Document_Request__c LIMIT 1];
        
        // Create and approve a file
        ContentVersion cv = TestDataFactory.createLinkedContentVersion(
            request.Id, 'test.pdf', 'Portal_Upload', 'Pending_Review'
        );
        DocumentRequestService.approveFile(cv.Id);
        
        Test.startTest();
        DocumentRequestService.commitApprovedFiles(request.Id);
        Test.stopTest();
        
        // Verify request status updated
        Document_Request__c updatedRequest = [SELECT Status__c, Review_Completed_Date__c 
                                               FROM Document_Request__c WHERE Id = :request.Id];
        System.assertEquals('Approved', updatedRequest.Status__c, 'Status should be Approved');
        System.assertNotEquals(null, updatedRequest.Review_Completed_Date__c, 'Review completed date should be set');
        
        // Verify file linked to source record
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink 
                                           WHERE LinkedEntityId = :request.Source_Record_Id__c];
        System.assert(!links.isEmpty(), 'File should be linked to source record');
    }
    
    @isTest
    static void testCommitApprovedFiles_NoApprovedFiles() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        
        Test.startTest();
        try {
            DocumentRequestService.commitApprovedFiles(request.Id);
            System.assert(false, 'Should have thrown exception');
        } catch (DocumentRequestService.DocumentRequestException e) {
            System.assertEquals('No approved files to commit.', e.getMessage(), 'Error message should match');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetRequestDetails() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        
        Test.startTest();
        DocumentRequestService.DocumentRequestDetail detail = 
            DocumentRequestService.getRequestDetails(request.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, detail, 'Detail should not be null');
        System.assertNotEquals(null, detail.name, 'Name should not be null');
        System.assertNotEquals(null, detail.status, 'Status should not be null');
    }
    
    @isTest
    static void testGetRequestFiles() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        TestDataFactory.createLinkedContentVersion(request.Id, 'test.pdf', 'Portal_Upload', 'Pending_Review');
        
        Test.startTest();
        List<DocumentRequestService.FileDetail> files = 
            DocumentRequestService.getRequestFiles(request.Id);
        Test.stopTest();
        
        System.assertEquals(1, files.size(), 'Should have one file');
        System.assertEquals('test.pdf', files[0].title, 'File name should match');
    }
    
    @isTest
    static void testStartReview() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        request.Status__c = 'Files_Received';
        update request;
        
        Test.startTest();
        DocumentRequestService.startReview(request.Id);
        Test.stopTest();
        
        Document_Request__c updatedRequest = [SELECT Status__c FROM Document_Request__c WHERE Id = :request.Id];
        System.assertEquals('Under_Review', updatedRequest.Status__c, 'Status should be Under_Review');
    }
    
    @isTest
    static void testRejectRequest() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        
        Test.startTest();
        DocumentRequestService.rejectRequest(request.Id, 'Documents not acceptable');
        Test.stopTest();
        
        Document_Request__c updatedRequest = [SELECT Status__c, Review_Notes__c 
                                               FROM Document_Request__c WHERE Id = :request.Id];
        System.assertEquals('Rejected', updatedRequest.Status__c, 'Status should be Rejected');
        System.assertEquals('Documents not acceptable', updatedRequest.Review_Notes__c, 'Notes should be set');
    }
    
    @isTest
    static void testDocumentRequestResultClass() {
        DocumentRequestService.DocumentRequestResult result = 
            new DocumentRequestService.DocumentRequestResult(null, 'REQ-00001');
        System.assertEquals('REQ-00001', result.requestName, 'Request name should match');
    }
    
    @isTest
    static void testFileDetailClass() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        ContentVersion cv = TestDataFactory.createLinkedContentVersion(
            request.Id, 'test.pdf', 'Portal_Upload', 'Pending_Review'
        );
        
        ContentVersion queriedCv = [SELECT Id, Title, ContentDocumentId, FileExtension, ContentSize,
                                           CreatedDate, Review_Status__c, Upload_Source__c,
                                           Reviewed_By__c, Reviewed_By__r.Name, Review_Date__c, Rejection_Reason__c
                                    FROM ContentVersion WHERE Id = :cv.Id];
        
        DocumentRequestService.FileDetail detail = new DocumentRequestService.FileDetail(queriedCv);
        System.assertEquals('test.pdf', detail.title, 'Title should match');
        System.assertEquals('Pending_Review', detail.reviewStatus, 'Review status should match');
    }
    
    @isTest
    static void testDocumentRequestDetailClass() {
        Document_Request__c request = [SELECT Id, Name, Status__c, Request_Date__c, Token_Expiration__c,
                   Source_Record_Id__c, Source_Object_API_Name__c,
                   Recipient_Email__c, Recipient_Name__c, Recipient_Contact__c,
                   Request_Instructions__c, Config_Developer_Name__c,
                   File_Count__c, Files_Received_Date__c, Review_Completed_Date__c,
                   Requested_By__c, Requested_By__r.Name
            FROM Document_Request__c LIMIT 1];
        
        DocumentRequestService.DocumentRequestDetail detail = 
            new DocumentRequestService.DocumentRequestDetail(request);
        
        System.assertNotEquals(null, detail.name, 'Name should be populated');
        System.assertNotEquals(null, detail.status, 'Status should be populated');
    }
    
    @isTest
    static void testCommitApprovedFiles_WithTask() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Document_Request__c request = [SELECT Id, Source_Record_Id__c FROM Document_Request__c LIMIT 1];
        
        // Create and approve a file
        ContentVersion cv = TestDataFactory.createLinkedContentVersion(
            request.Id, 'test.pdf', 'Portal_Upload', 'Pending_Review'
        );
        DocumentRequestService.approveFile(cv.Id);
        
        // Create a task
        TestDataFactory.createReviewTask(request.Id, UserInfo.getUserId(), true);
        
        Test.startTest();
        DocumentRequestService.commitApprovedFiles(request.Id);
        Test.stopTest();
        
        // Verify task was completed
        List<Task> tasks = [SELECT Status FROM Task WHERE WhatId = :request.Id];
        for (Task t : tasks) {
            System.assertEquals('Completed', t.Status, 'Task should be completed');
        }
    }
    
    @isTest
    static void testGetRequestFiles_NoFiles() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        
        // Delete any existing files
        List<ContentDocumentLink> links = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :request.Id];
        if (!links.isEmpty()) {
            Set<Id> docIds = new Set<Id>();
            for (ContentDocumentLink cdl : links) {
                docIds.add(cdl.ContentDocumentId);
            }
            delete [SELECT Id FROM ContentDocument WHERE Id IN :docIds];
        }
        
        Test.startTest();
        List<DocumentRequestService.FileDetail> files = 
            DocumentRequestService.getRequestFiles(request.Id);
        Test.stopTest();
        
        System.assertEquals(0, files.size(), 'Should have no files');
    }
    
    @isTest
    static void testStartReview_AlreadyUnderReview() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        request.Status__c = 'Under_Review';
        update request;
        
        Test.startTest();
        DocumentRequestService.startReview(request.Id);
        Test.stopTest();
        
        Document_Request__c updatedRequest = [SELECT Status__c FROM Document_Request__c WHERE Id = :request.Id];
        System.assertEquals('Under_Review', updatedRequest.Status__c, 'Status should remain Under_Review');
    }
    
    @isTest
    static void testCreateDocumentRequest_NoConfig() {
        Account acc = TestDataFactory.createAccount('Test', true);
        
        Test.startTest();
        try {
            DocumentRequestService.createDocumentRequest(
                acc.Id, 'Account', 'Test instructions', 'Notes', null
            );
            System.assert(false, 'Should have thrown exception');
        } catch (DocumentRequestService.DocumentRequestException e) {
            System.assert(e.getMessage().contains('not enabled'), 'Error should mention not enabled');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCreateDocumentRequest_WithMockConfig() {
        // Create test data
        Account acc = TestDataFactory.createAccount('Test Account', true);
        Contact con = TestDataFactory.createContact(acc.Id, 'Test', 'Contact', 'recipient@test.com', true);
        Case c = TestDataFactory.createCase(con.Id, 'Test Case', true);
        
        // Set up mock configuration
        Document_Request_Config__mdt mockConfig = DocumentRequestConfigService.createMockConfig(
            'Case_Document_Request',
            'Case',
            'Contact.Email',
            'Contact.Name',
            'ContactId'
        );
        DocumentRequestConfigService.setMockConfig('Case', mockConfig);
        
        Test.startTest();
        DocumentRequestService.DocumentRequestResult result = DocumentRequestService.createDocumentRequest(
            c.Id, 'Case', 'Please provide documents', 'Internal notes', 14
        );
        Test.stopTest();
        
        // Clear mocks
        DocumentRequestConfigService.clearMocks();
        
        System.assertNotEquals(null, result.requestId, 'Request should be created');
        System.assertNotEquals(null, result.requestName, 'Request name should be populated');
        
        // Verify the request
        Document_Request__c req = [SELECT Status__c, Recipient_Email__c, Recipient_Name__c,
                                          Request_Instructions__c, Internal_Notes__c, Token_Expiration__c
                                   FROM Document_Request__c WHERE Id = :result.requestId];
        System.assertEquals('Sent', req.Status__c, 'Status should be Sent');
        System.assertEquals('recipient@test.com', req.Recipient_Email__c, 'Email should match');
        System.assertEquals('Please provide documents', req.Request_Instructions__c, 'Instructions should match');
    }
    
    @isTest
    static void testCreateDocumentRequest_NoRecipientEmail() {
        // Create test data without email
        Account acc = TestDataFactory.createAccount('Test Account', true);
        Contact con = new Contact(AccountId = acc.Id, FirstName = 'Test', LastName = 'NoEmail');
        insert con;
        Case c = TestDataFactory.createCase(con.Id, 'Test Case', true);
        
        // Set up mock configuration
        Document_Request_Config__mdt mockConfig = DocumentRequestConfigService.createMockConfig(
            'Case_Document_Request',
            'Case',
            'Contact.Email',
            'Contact.Name',
            'ContactId'
        );
        DocumentRequestConfigService.setMockConfig('Case', mockConfig);
        
        Test.startTest();
        try {
            DocumentRequestService.createDocumentRequest(
                c.Id, 'Case', 'Please provide documents', null, null
            );
            System.assert(false, 'Should have thrown exception');
        } catch (DocumentRequestService.DocumentRequestException e) {
            System.assert(e.getMessage().contains('No email address'), 'Error should mention no email');
        }
        Test.stopTest();
        
        DocumentRequestConfigService.clearMocks();
    }
    
    @isTest
    static void testCreateDocumentRequest_DefaultExpiration() {
        Account acc = TestDataFactory.createAccount('Test Account', true);
        Contact con = TestDataFactory.createContact(acc.Id, 'Test', 'Contact', 'test@test.com', true);
        Case c = TestDataFactory.createCase(con.Id, 'Test Case', true);
        
        Document_Request_Config__mdt mockConfig = DocumentRequestConfigService.createMockConfig(
            'Case_Document_Request',
            'Case',
            'Contact.Email',
            'Contact.Name',
            'ContactId'
        );
        DocumentRequestConfigService.setMockConfig('Case', mockConfig);
        
        Test.startTest();
        DocumentRequestService.DocumentRequestResult result = DocumentRequestService.createDocumentRequest(
            c.Id, 'Case', 'Please provide documents', null, null
        );
        Test.stopTest();
        
        DocumentRequestConfigService.clearMocks();
        
        Document_Request__c req = [SELECT Token_Expiration__c FROM Document_Request__c WHERE Id = :result.requestId];
        // Default is 7 days
        DateTime expectedMin = DateTime.now().addDays(6);
        DateTime expectedMax = DateTime.now().addDays(8);
        System.assert(req.Token_Expiration__c > expectedMin && req.Token_Expiration__c < expectedMax,
                      'Expiration should be approximately 7 days from now');
    }
    
    @isTest
    static void testApproveFile_VerifyFields() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        ContentVersion cv = TestDataFactory.createLinkedContentVersion(
            request.Id, 'test.pdf', 'Portal_Upload', 'Pending_Review'
        );
        
        Test.startTest();
        DocumentRequestService.approveFile(cv.Id);
        Test.stopTest();
        
        ContentVersion updatedCv = [SELECT Review_Status__c, Reviewed_By__c, Review_Date__c 
                                    FROM ContentVersion WHERE Id = :cv.Id];
        System.assertEquals('Approved', updatedCv.Review_Status__c, 'Status should be Approved');
        System.assertNotEquals(null, updatedCv.Reviewed_By__c, 'Reviewer should be set');
        System.assertNotEquals(null, updatedCv.Review_Date__c, 'Review date should be set');
    }
    
    @isTest
    static void testCommitApprovedFiles_NoSourceRecord() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        request.Source_Record_Id__c = null;
        update request;
        
        Test.startTest();
        try {
            DocumentRequestService.commitApprovedFiles(request.Id);
            System.assert(false, 'Should have thrown exception');
        } catch (DocumentRequestService.DocumentRequestException e) {
            System.assert(e.getMessage().contains('Source record'), 'Error should mention source record');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testMultipleFilesApproval() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        
        // Create multiple files
        List<ContentVersion> files = TestDataFactory.createTestFilesForRequest(request.Id, 3);
        
        Test.startTest();
        // Approve all files
        for (ContentVersion cv : files) {
            ContentVersion refreshedCv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id];
            DocumentRequestService.approveFile(refreshedCv.Id);
        }
        Test.stopTest();
        
        // Verify all approved
        List<ContentDocumentLink> links = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :request.Id];
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : links) {
            docIds.add(cdl.ContentDocumentId);
        }
        
        List<ContentVersion> approvedFiles = [SELECT Review_Status__c FROM ContentVersion 
                                               WHERE ContentDocumentId IN :docIds AND IsLatest = true];
        for (ContentVersion cv : approvedFiles) {
            System.assertEquals('Approved', cv.Review_Status__c, 'All files should be approved');
        }
    }
    
    @isTest
    static void testRejectFile_WithDetails() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        ContentVersion cv = TestDataFactory.createLinkedContentVersion(
            request.Id, 'test.pdf', 'Portal_Upload', 'Pending_Review'
        );
        
        Test.startTest();
        DocumentRequestService.rejectFile(cv.Id, 'Document quality is too low');
        Test.stopTest();
        
        ContentVersion updatedCv = [SELECT Review_Status__c, Rejection_Reason__c, 
                                           Reviewed_By__c, Review_Date__c 
                                    FROM ContentVersion WHERE Id = :cv.Id];
        System.assertEquals('Rejected', updatedCv.Review_Status__c, 'Status should be Rejected');
        System.assertEquals('Document quality is too low', updatedCv.Rejection_Reason__c, 'Reason should match');
        System.assertNotEquals(null, updatedCv.Reviewed_By__c, 'Reviewer should be set');
        System.assertNotEquals(null, updatedCv.Review_Date__c, 'Review date should be set');
    }
    
    @isTest
    static void testGetRequestDetails_WithAllFields() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        
        // Add some files
        TestDataFactory.createLinkedContentVersion(request.Id, 'test.pdf', 'Portal_Upload', 'Pending_Review');
        
        // Update request with more data
        request.Status__c = 'Files_Received';
        request.Files_Received_Date__c = DateTime.now();
        request.File_Count__c = 1;
        update request;
        
        Test.startTest();
        DocumentRequestService.DocumentRequestDetail detail = 
            DocumentRequestService.getRequestDetails(request.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, detail.id, 'ID should be populated');
        System.assertEquals('Files_Received', detail.status, 'Status should match');
        System.assertEquals(1, detail.fileCount, 'File count should match');
    }
    
    @isTest
    static void testRejectRequest_WithNotes() {
        Document_Request__c request = [SELECT Id FROM Document_Request__c LIMIT 1];
        
        Test.startTest();
        DocumentRequestService.rejectRequest(request.Id, 'Documents do not meet requirements. Please resubmit.');
        Test.stopTest();
        
        Document_Request__c updatedRequest = [SELECT Status__c, Review_Notes__c, Review_Completed_Date__c 
                                               FROM Document_Request__c WHERE Id = :request.Id];
        System.assertEquals('Rejected', updatedRequest.Status__c, 'Status should be Rejected');
        System.assertNotEquals(null, updatedRequest.Review_Notes__c, 'Notes should be set');
        System.assertNotEquals(null, updatedRequest.Review_Completed_Date__c, 'Review date should be set');
    }
    
    @isTest
    static void testCommitApprovedFiles_MultipleFiles() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Document_Request__c request = [SELECT Id, Source_Record_Id__c FROM Document_Request__c LIMIT 1];
        
        // Create and approve multiple files
        List<ContentVersion> files = TestDataFactory.createTestFilesForRequest(request.Id, 3);
        for (ContentVersion cv : files) {
            ContentVersion refreshedCv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id];
            DocumentRequestService.approveFile(refreshedCv.Id);
        }
        
        Test.startTest();
        DocumentRequestService.commitApprovedFiles(request.Id);
        Test.stopTest();
        
        // Verify all files linked to source
        List<ContentDocumentLink> sourceLinks = [SELECT Id FROM ContentDocumentLink 
                                                  WHERE LinkedEntityId = :request.Source_Record_Id__c];
        System.assertEquals(3, sourceLinks.size(), 'All 3 files should be linked to source');
    }
}

