trigger OrderTrigger on Order (after insert, after update) {
    TriggerManager.prepare()
        .bind(new OrderTriggerHandler())
        .execute();
}