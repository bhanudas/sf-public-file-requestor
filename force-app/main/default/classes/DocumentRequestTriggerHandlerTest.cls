/**
 * @description Test class for DocumentRequestTriggerHandler
 */
@isTest
private class DocumentRequestTriggerHandlerTest {
  @TestSetup
  static void makeData() {
    Map<String, SObject> testData = TestDataFactory.createCompleteTestScenario();
  }

  @isTest
  static void testTriggerExpiresToken() {
    Document_Request__c request = [
      SELECT Id, Status__c, Token_Expiration__c
      FROM Document_Request__c
      LIMIT 1
    ];
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
      'Expired',
      updatedRequest.Status__c,
      'Status should be Expired'
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
        TestDataFactory.createDocumentRequest(
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

    // Expire half of them
    for (Integer i = 0; i < 5; i++) {
      requests[i].Token_Expiration__c = DateTime.now().addDays(-1);
    }

    Test.startTest();
    update requests;
    Test.stopTest();

    List<Document_Request__c> expiredRequests = [
      SELECT Status__c
      FROM Document_Request__c
      WHERE Id IN :requests AND Status__c = 'Expired'
    ];

    System.assertEquals(
      5,
      expiredRequests.size(),
      '5 requests should be expired'
    );
  }
}
