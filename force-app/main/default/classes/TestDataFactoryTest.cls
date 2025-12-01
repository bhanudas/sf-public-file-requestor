/**
 * @description Test class for TestDataFactory
 */
@isTest
private class TestDataFactoryTest {
    
    @isTest
    static void testCreateAccount() {
        Test.startTest();
        Account acc = TestDataFactory.createAccount('Test Account', true);
        Test.stopTest();
        
        System.assertNotEquals(null, acc.Id, 'Account should be created');
        System.assertEquals('Test Account', acc.Name, 'Name should match');
    }
    
    @isTest
    static void testCreateAccount_NoInsert() {
        Test.startTest();
        Account acc = TestDataFactory.createAccount('Test Account', false);
        Test.stopTest();
        
        System.assertEquals(null, acc.Id, 'Account should not be inserted');
    }
    
    @isTest
    static void testCreateContact() {
        Account acc = TestDataFactory.createAccount('Test', true);
        
        Test.startTest();
        Contact con = TestDataFactory.createContact(acc.Id, 'First', 'Last', 'test@test.com', true);
        Test.stopTest();
        
        System.assertNotEquals(null, con.Id, 'Contact should be created');
        System.assertEquals('test@test.com', con.Email, 'Email should match');
    }
    
    @isTest
    static void testCreateContact_NoInsert() {
        Account acc = TestDataFactory.createAccount('Test', true);
        
        Test.startTest();
        Contact con = TestDataFactory.createContact(acc.Id, 'First', 'Last', 'test@test.com', false);
        Test.stopTest();
        
        System.assertEquals(null, con.Id, 'Contact should not be inserted');
    }
    
    @isTest
    static void testCreateCase() {
        Account acc = TestDataFactory.createAccount('Test', true);
        Contact con = TestDataFactory.createContact(acc.Id, 'Test', 'Contact', 'test@test.com', true);
        
        Test.startTest();
        Case c = TestDataFactory.createCase(con.Id, 'Test Subject', true);
        Test.stopTest();
        
        System.assertNotEquals(null, c.Id, 'Case should be created');
        System.assertEquals('Test Subject', c.Subject, 'Subject should match');
    }
    
    @isTest
    static void testCreateCase_NoInsert() {
        Account acc = TestDataFactory.createAccount('Test', true);
        Contact con = TestDataFactory.createContact(acc.Id, 'Test', 'Contact', 'test@test.com', true);
        
        Test.startTest();
        Case c = TestDataFactory.createCase(con.Id, 'Test Subject', false);
        Test.stopTest();
        
        System.assertEquals(null, c.Id, 'Case should not be inserted');
    }
    
    @isTest
    static void testCreateDocumentRequest() {
        Account acc = TestDataFactory.createAccount('Test', true);
        Contact con = TestDataFactory.createContact(acc.Id, 'Test', 'Contact', 'test@test.com', true);
        Case c = TestDataFactory.createCase(con.Id, 'Test', true);
        
        Test.startTest();
        Document_Request__c req = TestDataFactory.createDocumentRequest(
            c.Id, 'Case', 'test@test.com', 'Test Name', 'Sent', true
        );
        Test.stopTest();
        
        System.assertNotEquals(null, req.Id, 'Request should be created');
        System.assertNotEquals(null, req.Request_Token__c, 'Token should be generated');
    }
    
    @isTest
    static void testCreateDocumentRequest_NoInsert() {
        Account acc = TestDataFactory.createAccount('Test', true);
        Contact con = TestDataFactory.createContact(acc.Id, 'Test', 'Contact', 'test@test.com', true);
        Case c = TestDataFactory.createCase(con.Id, 'Test', true);
        
        Test.startTest();
        Document_Request__c req = TestDataFactory.createDocumentRequest(
            c.Id, 'Case', 'test@test.com', 'Test Name', 'Sent', false
        );
        Test.stopTest();
        
        System.assertEquals(null, req.Id, 'Request should not be inserted');
    }
    
    @isTest
    static void testCreateExpiredDocumentRequest() {
        Account acc = TestDataFactory.createAccount('Test', true);
        Contact con = TestDataFactory.createContact(acc.Id, 'Test', 'Contact', 'test@test.com', true);
        Case c = TestDataFactory.createCase(con.Id, 'Test', true);
        
        Test.startTest();
        Document_Request__c req = TestDataFactory.createExpiredDocumentRequest(c.Id, 'Case', true);
        Test.stopTest();
        
        System.assertNotEquals(null, req.Id, 'Request should be created');
        System.assert(req.Token_Expiration__c < DateTime.now(), 'Token should be expired');
    }
    
    @isTest
    static void testCreateExpiredDocumentRequest_NoInsert() {
        Account acc = TestDataFactory.createAccount('Test', true);
        Contact con = TestDataFactory.createContact(acc.Id, 'Test', 'Contact', 'test@test.com', true);
        Case c = TestDataFactory.createCase(con.Id, 'Test', true);
        
        Test.startTest();
        Document_Request__c req = TestDataFactory.createExpiredDocumentRequest(c.Id, 'Case', false);
        Test.stopTest();
        
        System.assertEquals(null, req.Id, 'Request should not be inserted');
    }
    
    @isTest
    static void testCreateContentVersion() {
        Test.startTest();
        ContentVersion cv = TestDataFactory.createContentVersion(
            'test.pdf', 'Test content', 'Internal', null, true
        );
        Test.stopTest();
        
        System.assertNotEquals(null, cv.Id, 'ContentVersion should be created');
    }
    
    @isTest
    static void testCreateContentVersion_NoInsert() {
        Test.startTest();
        ContentVersion cv = TestDataFactory.createContentVersion(
            'test.pdf', 'Test content', 'Internal', null, false
        );
        Test.stopTest();
        
        System.assertEquals(null, cv.Id, 'ContentVersion should not be inserted');
    }
    
    @isTest
    static void testCreateLinkedContentVersion() {
        Map<String, SObject> testData = TestDataFactory.createCompleteTestScenario();
        Document_Request__c req = (Document_Request__c)testData.get('Document_Request__c');
        
        Test.startTest();
        ContentVersion cv = TestDataFactory.createLinkedContentVersion(
            req.Id, 'linked.pdf', 'Portal_Upload', 'Pending_Review'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, cv.Id, 'ContentVersion should be created');
        
        // Verify link
        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink 
                                           WHERE LinkedEntityId = :req.Id];
        System.assert(!links.isEmpty(), 'Content should be linked');
    }
    
    @isTest
    static void testCreateContentDocumentLink() {
        ContentVersion cv = TestDataFactory.createContentVersion('test.pdf', 'Test', null, null, true);
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        
        Account acc = TestDataFactory.createAccount('Test', true);
        
        Test.startTest();
        ContentDocumentLink cdl = TestDataFactory.createContentDocumentLink(
            cv.ContentDocumentId, acc.Id, true
        );
        Test.stopTest();
        
        System.assertNotEquals(null, cdl.Id, 'Link should be created');
    }
    
    @isTest
    static void testCreateContentDocumentLink_NoInsert() {
        ContentVersion cv = TestDataFactory.createContentVersion('test.pdf', 'Test', null, null, true);
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        
        Account acc = TestDataFactory.createAccount('Test', true);
        
        Test.startTest();
        ContentDocumentLink cdl = TestDataFactory.createContentDocumentLink(
            cv.ContentDocumentId, acc.Id, false
        );
        Test.stopTest();
        
        System.assertEquals(null, cdl.Id, 'Link should not be inserted');
    }
    
    @isTest
    static void testGenerateToken() {
        Test.startTest();
        String token1 = TestDataFactory.generateToken();
        String token2 = TestDataFactory.generateToken();
        Test.stopTest();
        
        System.assertNotEquals(null, token1, 'Token should be generated');
        System.assertEquals(36, token1.length(), 'Token should be 36 chars');
        System.assertNotEquals(token1, token2, 'Tokens should be unique');
    }
    
    @isTest
    static void testCreateCompleteTestScenario() {
        Test.startTest();
        Map<String, SObject> result = TestDataFactory.createCompleteTestScenario();
        Test.stopTest();
        
        System.assertNotEquals(null, result.get('Account'), 'Should have Account');
        System.assertNotEquals(null, result.get('Contact'), 'Should have Contact');
        System.assertNotEquals(null, result.get('Case'), 'Should have Case');
        System.assertNotEquals(null, result.get('Document_Request__c'), 'Should have Document Request');
    }
    
    @isTest
    static void testCreateTestFilesForRequest() {
        Map<String, SObject> testData = TestDataFactory.createCompleteTestScenario();
        Document_Request__c req = (Document_Request__c)testData.get('Document_Request__c');
        
        Test.startTest();
        List<ContentVersion> files = TestDataFactory.createTestFilesForRequest(req.Id, 5);
        Test.stopTest();
        
        System.assertEquals(5, files.size(), 'Should create 5 files');
    }
    
    @isTest
    static void testCreateReviewTask() {
        Map<String, SObject> testData = TestDataFactory.createCompleteTestScenario();
        Document_Request__c req = (Document_Request__c)testData.get('Document_Request__c');
        
        Test.startTest();
        Task t = TestDataFactory.createReviewTask(req.Id, UserInfo.getUserId(), true);
        Test.stopTest();
        
        System.assertNotEquals(null, t.Id, 'Task should be created');
        System.assertEquals(req.Id, t.WhatId, 'WhatId should match');
    }
    
    @isTest
    static void testCreateReviewTask_NoInsert() {
        Map<String, SObject> testData = TestDataFactory.createCompleteTestScenario();
        Document_Request__c req = (Document_Request__c)testData.get('Document_Request__c');
        
        Test.startTest();
        Task t = TestDataFactory.createReviewTask(req.Id, UserInfo.getUserId(), false);
        Test.stopTest();
        
        System.assertEquals(null, t.Id, 'Task should not be inserted');
    }
}

