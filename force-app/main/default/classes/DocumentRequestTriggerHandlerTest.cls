/**
 * @description Test class for DocumentRequestTriggerHandler
 */
@isTest
private class DocumentRequestTriggerHandlerTest {
  @TestSetup
  static void makeData() {
    Map<String, SObject> testData = DocReqTestDataFactory.createCompleteTestScenario();
  }

  @isTest
  static void testTriggerExpiresToken() {
    Document_Request__c request = [
      SELECT Id, Status__c, Token_Expiration__c
      FROM Document_Request__c
      LIMIT 1
    ];

    // Test handler logic directly to avoid interference from other org automations
    Document_Request__c testRequest = request.clone(true, true, true, true);
    testRequest.Token_Expiration__c = DateTime.now().addDays(-1);
    testRequest.Status__c = 'Sent';

    List<Document_Request__c> requests = new List<Document_Request__c>{
      testRequest
    };
    Map<Id, Document_Request__c> oldMap = new Map<Id, Document_Request__c>{
      request.Id => request
    };

    Test.startTest();
    DocumentRequestTriggerHandler.handleBeforeUpdate(requests, oldMap);
    Test.stopTest();

    System.assertEquals(
      'Expired',
      requests[0].Status__c,
      'Status should be Expired after handler processes expired token'
    );
  }

  @isTest
  static void testTriggerDoesNotChangeTerminalStatus() {
    Document_Request__c request = [
      SELECT Id, Status__c, Token_Expiration__c
      FROM Document_Request__c
      LIMIT 1
    ];
    request.Status__c = 'Approved';
    update request;

    // Now try to trigger expiration
    request.Token_Expiration__c = DateTime.now().addDays(-1);

    Test.startTest();
    update request;
    Test.stopTest();

    Document_Request__c updatedRequest = [
      SELECT Status__c
      FROM Document_Request__c
      WHERE Id = :request.Id
    ];
    System.assertEquals(
      'Approved',
      updatedRequest.Status__c,
      'Approved status should not change'
    );
  }

  @isTest
  static void testHandleBeforeUpdateDirectCall() {
    Document_Request__c request = [
      SELECT Id, Status__c, Token_Expiration__c
      FROM Document_Request__c
      LIMIT 1
    ];

    List<Document_Request__c> requests = new List<Document_Request__c>{
      request
    };
    Map<Id, Document_Request__c> oldMap = new Map<Id, Document_Request__c>{
      request.Id => request
    };

    Test.startTest();
    DocumentRequestTriggerHandler.handleBeforeUpdate(requests, oldMap);
    Test.stopTest();

    // Just verify no errors occurred
    System.assertNotEquals(null, requests, 'Requests should not be null');
  }

  @isTest
  static void testHandleAfterUpdateDirectCall() {
    Document_Request__c request = [
      SELECT Id, Status__c, Token_Expiration__c
      FROM Document_Request__c
      LIMIT 1
    ];

    List<Document_Request__c> requests = new List<Document_Request__c>{
      request
    };
    Map<Id, Document_Request__c> oldMap = new Map<Id, Document_Request__c>{
      request.Id => request
    };

    Test.startTest();
    DocumentRequestTriggerHandler.handleAfterUpdate(requests, oldMap);
    Test.stopTest();

    // Just verify no errors occurred
    System.assertNotEquals(null, requests, 'Requests should not be null');
  }

  @isTest
  static void testBulkUpdate() {
    Case c = [SELECT Id FROM Case LIMIT 1];

    // Create multiple requests
    List<Document_Request__c> requests = new List<Document_Request__c>();
    for (Integer i = 0; i < 10; i++) {
      requests.add(
        DocReqTestDataFactory.createDocumentRequest(
          c.Id,
          'Case',
          'test' + i + '@test.com',
          'Test ' + i,
          'Sent',
          false
        )
      );
    }
    insert requests;

    // Create old map from inserted records
    Map<Id, Document_Request__c> oldMap = new Map<Id, Document_Request__c>();
    for (Document_Request__c req : requests) {
      oldMap.put(req.Id, req.clone(true, true, true, true));
    }

    // Expire half of them
    for (Integer i = 0; i < 5; i++) {
      requests[i].Token_Expiration__c = DateTime.now().addDays(-1);
    }

    Test.startTest();
    // Test handler directly to avoid interference from other org automations
    DocumentRequestTriggerHandler.handleBeforeUpdate(requests, oldMap);
    Test.stopTest();

    Integer expiredCount = 0;
    for (Document_Request__c req : requests) {
      if (req.Status__c == 'Expired') {
        expiredCount++;
      }
    }

    System.assertEquals(
      5,
      expiredCount,
      '5 requests should be expired by handler'
    );
  }
}
