/**
 * @description Trigger handler for Document_Request__c
 */
public with sharing class DocumentRequestTriggerHandler {
    
    private static final Set<String> TERMINAL_STATUSES = new Set<String>{
        'Approved', 'Rejected', 'Expired'
    };
    
    /**
     * @description Handles before update logic
     * @param newRecords New record values
     * @param oldRecordsMap Old record values by Id
     */
    public static void handleBeforeUpdate(
        List<Document_Request__c> newRecords,
        Map<Id, Document_Request__c> oldRecordsMap
    ) {
        checkTokenExpiration(newRecords, oldRecordsMap);
    }
    
    /**
     * @description Checks if tokens have expired and updates status
     */
    private static void checkTokenExpiration(
        List<Document_Request__c> newRecords,
        Map<Id, Document_Request__c> oldRecordsMap
    ) {
        DateTime now = DateTime.now();
        
        for (Document_Request__c request : newRecords) {
            // Skip if already in terminal state
            if (TERMINAL_STATUSES.contains(request.Status__c)) {
                continue;
            }
            
            // Check if expired
            if (request.Token_Expiration__c != null && request.Token_Expiration__c < now) {
                request.Status__c = 'Expired';
            }
        }
    }
    
    /**
     * @description Handles after update logic (placeholder for future use)
     */
    public static void handleAfterUpdate(
        List<Document_Request__c> newRecords,
        Map<Id, Document_Request__c> oldRecordsMap
    ) {
        // Reserved for future functionality
    }
}

