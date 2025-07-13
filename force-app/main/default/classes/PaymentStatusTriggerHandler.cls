/**
 * 납부 상태 트리거 핸들러 클래스
 * @author GitHub Copilot
 * @date 2025-07-12
 */
public class PaymentStatusTriggerHandler extends TriggerHandler {
    
    /**
     * 생성자
     */
    public PaymentStatusTriggerHandler() {
        // 필요한 초기화 작업 수행
    }
    
    /**
     * before insert 이벤트 처리
     */
    protected override void beforeInsert(List<SObject> news) {
        List<PaymentStatus__c> newPaymentStatuses = (List<PaymentStatus__c>) news;
        
        for(PaymentStatus__c ps : newPaymentStatuses) {
            // 납부 기한이 설정되어 있고 오늘 날짜보다 이전인 경우 연체 상태로 설정
            if(ps.DueDate__c != null && ps.DueDate__c < Date.today()) {
                ps.IsOverdue__c = true;
            }
            
            // 초기 상태 설정
            if(ps.Status__c == null) {
                ps.Status__c = '미납';
            }
            
            // 최초 확인 일시 및 다음 확인 예정 일시 설정
            if(ps.LastCheckedDate__c == null) {
                ps.LastCheckedDate__c = Datetime.now();
            }
            
            if(ps.NextCheckDate__c == null) {
                ps.NextCheckDate__c = Datetime.now().addHours(1);
            }
        }
    }
    
    /**
     * before update 이벤트 처리
     */
    protected override void beforeUpdate(List<SObject> news, List<SObject> olds, Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {
        List<PaymentStatus__c> updatedPaymentStatuses = (List<PaymentStatus__c>) news;
        Map<Id, PaymentStatus__c> oldPsMap = (Map<Id, PaymentStatus__c>) oldMap;
        
        for(PaymentStatus__c ps : updatedPaymentStatuses) {
            PaymentStatus__c oldPs = oldPsMap.get(ps.Id);
            
            // 상태가 변경된 경우에만 처리
            if(ps.Status__c != oldPs.Status__c) {
                // 납부 완료인 경우 연체 상태 확인
                if(ps.Status__c == '납부완료' && ps.PaymentDate__c != null && ps.DueDate__c != null) {
                    ps.IsOverdue__c = ps.PaymentDate__c > ps.DueDate__c;
                }
                
                // 상태에 따라 다음 확인 일시 조정
                if(ps.Status__c == '납부완료') {
                    // 납부 완료 상태는 더 이상 자주 확인할 필요 없음
                    ps.NextCheckDate__c = Datetime.now().addDays(7);
                } else if(ps.Status__c == '미납' && ps.IsOverdue__c) {
                    // 연체 상태는 더 자주 확인
                    ps.NextCheckDate__c = Datetime.now().addMinutes(30);
                } else {
                    // 기본 확인 주기
                    ps.NextCheckDate__c = Datetime.now().addHours(1);
                }
            }
        }
    }
    
    /**
     * after update 이벤트 처리
     */
    protected override void afterUpdate(List<SObject> news, List<SObject> olds, Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {
        // 필요한 경우 구현
    }
}
