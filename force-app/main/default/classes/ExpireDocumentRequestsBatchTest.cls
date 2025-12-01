/**
 * @description Test class for ExpireDocumentRequestsBatch
 */
@isTest
private class ExpireDocumentRequestsBatchTest {
    
    @TestSetup
    static void makeData() {
        Account acc = TestDataFactory.createAccount('Test Account', true);
        Contact con = TestDataFactory.createContact(acc.Id, 'Test', 'Contact', 'test@test.com', true);
        Case c = TestDataFactory.createCase(con.Id, 'Test Case', true);
        
        // Create an expired request
        TestDataFactory.createExpiredDocumentRequest(c.Id, 'Case', true);
        
        // Create a valid request
        TestDataFactory.createDocumentRequest(c.Id, 'Case', 'test@test.com', 'Test', 'Sent', true);
    }
    
    @isTest
    static void testBatchExecution() {
        Test.startTest();
        Database.executeBatch(new ExpireDocumentRequestsBatch());
        Test.stopTest();
        
        // Verify expired request was updated
        List<Document_Request__c> expiredRequests = [
            SELECT Status__c 
            FROM Document_Request__c 
            WHERE Token_Expiration__c < :DateTime.now()
        ];
        
        for (Document_Request__c req : expiredRequests) {
            System.assertEquals('Expired', req.Status__c, 'Status should be Expired');
        }
    }
    
    @isTest
    static void testScheduleDaily() {
        Test.startTest();
        String jobId = ExpireDocumentRequestsBatch.scheduleDaily('Test Expire Job');
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Job ID should not be null');
        
        // Verify job was scheduled
        List<CronTrigger> jobs = [SELECT Id FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(1, jobs.size(), 'Job should be scheduled');
    }
    
    @isTest
    static void testSchedulableExecute() {
        Test.startTest();
        ExpireDocumentRequestsBatch batch = new ExpireDocumentRequestsBatch();
        String cronExp = '0 0 0 * * ?';
        String jobId = System.schedule('Test Schedule', cronExp, batch);
        Test.stopTest();
        
        System.assertNotEquals(null, jobId, 'Scheduled job should be created');
    }
    
    @isTest
    static void testBatchDoesNotAffectTerminalStatus() {
        Document_Request__c request = [SELECT Id, Status__c FROM Document_Request__c WHERE Status__c = 'Sent' LIMIT 1];
        request.Status__c = 'Approved';
        request.Token_Expiration__c = DateTime.now().addDays(-1); // Expired but already approved
        update request;
        
        Test.startTest();
        Database.executeBatch(new ExpireDocumentRequestsBatch());
        Test.stopTest();
        
        Document_Request__c updatedRequest = [SELECT Status__c FROM Document_Request__c WHERE Id = :request.Id];
        System.assertEquals('Approved', updatedRequest.Status__c, 'Approved status should not change');
    }
}

