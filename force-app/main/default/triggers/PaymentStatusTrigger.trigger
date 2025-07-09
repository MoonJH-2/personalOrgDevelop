trigger PaymentStatusTrigger on PaymentStatus__c (before insert, before update, after update) {
    TriggerManager.prepare()
        .bind(new PaymentStatusTriggerHandler())
        .execute();
}