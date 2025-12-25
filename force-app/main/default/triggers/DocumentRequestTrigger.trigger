/**
 * @description Trigger for Document_Request__c object
 */
trigger DocumentRequestTrigger on Document_Request__c(
  before update,
  after update
) {
  if (Trigger.isBefore) {
    if (Trigger.isUpdate) {
      DocumentRequestTriggerHandler.handleBeforeUpdate(
        Trigger.new,
        Trigger.oldMap
      );
    }
  }

  if (Trigger.isAfter) {
    if (Trigger.isUpdate) {
      DocumentRequestTriggerHandler.handleAfterUpdate(
        Trigger.new,
        Trigger.oldMap
      );
    }
  }
}
