trigger OrderTrigger on Order (after insert, after update) {
    new OrderTriggerHandler().execute(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap);
}