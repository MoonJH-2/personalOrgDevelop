/**
 * @description       : 
 * @author            : Hyowon Hong
 * @last modified on  : 07-03-2025
 * @last modified by  : Hyowon Hong
**/
public with sharing class TriggerManager { 
    private List<TriggerHandler>    handlers;
    private Boolean                 isExecuting;
    private TriggerOperation        operationType;

    private List<SObject>       news;
    private List<SObject>       olds;
    private Map<Id, SObject>    newMap;
    private Map<Id, SObject>    oldMap;

    // 생성자
    private TriggerManager() {
        this.handlers = new List<TriggerHandler>();
        this.setting();
    }

    // 정적 팩토리 메서드
    public static TriggerManager prepare() {
        return new TriggerManager();
    }

    // 트리거 컨텍스트 설정
    private void setting() {
        this.isExecuting    = Trigger.isExecuting;
        this.operationType  = Trigger.operationType;
        this.news           = Trigger.new;
        this.olds           = Trigger.old;
        this.newMap         = Trigger.newMap;
        this.oldMap         = Trigger.oldMap;
    }

    // 핸들러 바인딩
    public TriggerManager bind(TriggerHandler handler) {
        handler.setting(this.isExecuting, this.operationType);
        this.handlers.add(handler);
        return this;
    }

    // 핸들러 실행
    public void execute() {
        for (TriggerHandler handler : handlers) {
            handler.execute(this.news, this.olds, this.newMap, this.oldMap);
        }
    }
}