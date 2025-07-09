/**
 * @description       : 
 * @author            : Hyowon Hong
 * @last modified on  : 07-03-2025
 * @last modified by  : Hyowon Hong
**/
public virtual class TriggerHandler { 
    // 재귀 방지를 위한 정적 플래그 
    private static Set<String> executedHandlers = new Set<String>();

    // 트리거 컨텍스트 변수
    protected Boolean           isExecuting;
    protected TriggerOperation  operationType;
    public static Trigger_Handler_Manager__mdt triggerOption;
    public static Map<String, Trigger_Handler_Manager__mdt> triggerOptionMap;

    // 설정 메서드
    public void setting(Boolean isExecuting, TriggerOperation operationType) {
        this.isExecuting    = isExecuting;
        this.operationType  = operationType;
    }

    // 재귀 방지
    protected Boolean isFirstRun() {
        String handlerKey = this.getHandlerName() + ':' + this.operationType;
        if (executedHandlers.contains(handlerKey)) {
            return false;
        }
        executedHandlers.add(handlerKey);
        return true;
    }

    // 핸들러 이름 반환 (오버라이드 가능)
    protected virtual String getHandlerName() {
        return String.valueOf(this).split(':')[0];
    }

    @TestVisible
    private static Boolean getCurrentHandlerOption(String currentClassName) {
        if (triggerOptionMap == null) {
            triggerOptionMap = new Map<String, Trigger_Handler_Manager__mdt>();
            for (Trigger_Handler_Manager__mdt taOption : [SELECT Id, DeveloperName, IsActive__c FROM Trigger_Handler_Manager__mdt]) {
                triggerOptionMap.put(taOption.DeveloperName, taOption);
            }
        }
        triggerOption = triggerOptionMap.get(currentClassName);
        return triggerOption != null ? triggerOption.IsActive__c : false;
    }

    // 실행 메서드
    public virtual void execute(List<SObject> news, List<SObject> olds, Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {
        List<Trigger_Exception_Log__c> exLogs = new List<Trigger_Exception_Log__c>();
        Boolean isActive = getCurrentHandlerOption(getHandlerName());

        try {
            if (isActive) {
                if (!isExecuting || !isFirstRun()) {
                    return;
                }
        
                switch on operationType {
                    when BEFORE_INSERT {
                        beforeInsert(news);
                    }
                    when BEFORE_UPDATE {
                        beforeUpdate(news, olds, newMap, oldMap);
                    }
                    when BEFORE_DELETE {
                        beforeDelete(olds, oldMap);
                    }
                    when AFTER_INSERT {
                        afterInsert(news, newMap);
                    }
                    when AFTER_UPDATE {
                        afterUpdate(news, olds, newMap, oldMap);
                    }
                    when AFTER_DELETE {
                        afterDelete(olds, oldMap);
                    }
                    when AFTER_UNDELETE {
                        afterUndelete(news, newMap);
                    }
                }
            } else {
                Trigger_Exception_Log__c exLog = new Trigger_Exception_Log__c();
                exLog.TriggerHandlerName__c = this.getHandlerName();
                exLog.ErrorMessage__c       = operationType + ' : Trigger InActive';
                exLog.ExceptionType__c      = 'Trigger InActive';
                exLogs.add(exLog);
            }
        } catch (Exception ex) {
            system.debug(ex.getLineNumber());
            system.debug(ex.getMessage());
            system.debug(ex.getTypeName());
            system.debug(this.getHandlerName()); 
            
            Trigger_Exception_Log__c exLog = new Trigger_Exception_Log__c();
            exLog.TriggerHandlerName__c = this.getHandlerName();
            exLog.LineNumber__c         = ex.getLineNumber();
            exLog.ErrorMessage__c       = this.getHandlerName() + ' : ' + ex.getMessage();
            exLog.ExceptionType__c      = ex.getTypeName();
            exLogs.add(exLog);
        } finally {
            if (!exLogs.isEmpty()) {
                insert exLogs;
            }
        }
    }

    // 가상 메서드 (하위 클래스에서 오버라이드)
    protected virtual void beforeInsert(List<SObject> news) {}
    protected virtual void beforeUpdate(List<SObject> news, List<SObject> olds, Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {}
    protected virtual void beforeDelete(List<SObject> olds, Map<Id, SObject> oldMap) {}
    protected virtual void afterInsert(List<SObject> news, Map<Id, SObject> newMap) {}
    protected virtual void afterUpdate(List<SObject> news, List<SObject> olds, Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {}
    protected virtual void afterDelete(List<SObject> olds, Map<Id, SObject> oldMap) {}
    protected virtual void afterUndelete(List<SObject> news, Map<Id, SObject> newMap) {}
}