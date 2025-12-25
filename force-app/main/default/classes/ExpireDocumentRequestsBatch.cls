/**
 * @description Batch job to expire document requests with passed expiration dates
 * Schedule daily at midnight
 */
public with sharing class ExpireDocumentRequestsBatch implements Database.Batchable<SObject>, Schedulable {
  private static final Set<String> TERMINAL_STATUSES = new Set<String>{
    'Approved',
    'Rejected',
    'Expired'
  };

  /**
   * @description Schedulable execute method
   */
  public void execute(SchedulableContext sc) {
    Database.executeBatch(new ExpireDocumentRequestsBatch(), 200);
  }

  /**
   * @description Returns query for expired requests
   */
  public Database.QueryLocator start(Database.BatchableContext bc) {
    DateTime now = DateTime.now();
    return Database.getQueryLocator(
      [
        SELECT Id, Status__c, Token_Expiration__c
        FROM Document_Request__c
        WHERE Token_Expiration__c < :now AND Status__c NOT IN :TERMINAL_STATUSES
      ]
    );
  }

  /**
   * @description Updates status to Expired
   */
  public void execute(
    Database.BatchableContext bc,
    List<Document_Request__c> scope
  ) {
    for (Document_Request__c request : scope) {
      request.Status__c = 'Expired';
    }

    if (!scope.isEmpty()) {
      update scope;
    }
  }

  /**
   * @description Finish method (placeholder for future notification needs)
   */
  public void finish(Database.BatchableContext bc) {
    // Log completion or send admin notification if needed
  }

  /**
   * @description Schedule the batch job to run daily at midnight
   * @param jobName Name for the scheduled job
   * @return Job ID
   */
  public static String scheduleDaily(String jobName) {
    String cronExp = '0 0 0 * * ?'; // Daily at midnight
    return System.schedule(jobName, cronExp, new ExpireDocumentRequestsBatch());
  }
}
