/**
 * @description       : PaymentStatus 객체의 트리거 핸들러
 * @author            : Your Name
 * @last modified on  : 2024-01-10
 * @last modified by  : Your Name
**/
public class PaymentStatusTriggerHandler extends TriggerHandler {
    
    // 핸들러 이름 반환
    protected override String getHandlerName() {
        return 'PaymentStatusTriggerHandler';
    }
    
    // Before Insert 처리
    protected override void beforeInsert(List<SObject> news) {
        List<PaymentStatus__c> newPaymentStatuses = (List<PaymentStatus__c>) news;
        
        for (PaymentStatus__c ps : newPaymentStatuses) {
            // Transaction ID가 없으면 생성
            if (String.isBlank(ps.Transaction_ID__c)) {
                ps.Transaction_ID__c = generateTransactionId(ps);
            }
        }
    }
    
    // Before Update 처리
    protected override void beforeUpdate(List<SObject> news, List<SObject> olds, Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {
        List<PaymentStatus__c> newPaymentStatuses = (List<PaymentStatus__c>) news;
        Map<Id, PaymentStatus__c> oldPaymentStatusMap = (Map<Id, PaymentStatus__c>) oldMap;
        
        for (PaymentStatus__c ps : newPaymentStatuses) {
            PaymentStatus__c oldPs = oldPaymentStatusMap.get(ps.Id);
            
            // 상태가 '완납'으로 변경되었을 때
            if (ps.Status__c == '완납' && oldPs.Status__c != '완납') {
                // 납부 완료 처리
                ps.Payment_Date__c = ps.Payment_Date__c != null ? ps.Payment_Date__c : Datetime.now();
                ps.Payment_Amount__c = ps.Payment_Amount__c != null ? ps.Payment_Amount__c : ps.Amount__c;
            }
        }
    }
    
    // After Update 처리
    protected override void afterUpdate(List<SObject> news, List<SObject> olds, Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {
        List<PaymentStatus__c> newPaymentStatuses = (List<PaymentStatus__c>) news;
        Map<Id, PaymentStatus__c> oldPaymentStatusMap = (Map<Id, PaymentStatus__c>) oldMap;
        
        Set<Id> orderIds = new Set<Id>();
        List<PaymentStatus__c> completedPayments = new List<PaymentStatus__c>();
        
        for (PaymentStatus__c ps : newPaymentStatuses) {
            PaymentStatus__c oldPs = oldPaymentStatusMap.get(ps.Id);
            
            // 상태가 '완납'으로 변경되었을 때
            if (ps.Status__c == '완납' && oldPs.Status__c != '완납') {
                orderIds.add(ps.Order__c);
                completedPayments.add(ps);
            }
        }
        
        // Order의 전체 납부 상태 확인 및 업데이트
        if (!orderIds.isEmpty()) {
            checkAndUpdateOrderStatus(orderIds);
            
            // 납부 완료 알림 전송 (필요시)
            sendPaymentCompletionNotification(completedPayments);
        }
    }
    
    // Transaction ID 생성
    private String generateTransactionId(PaymentStatus__c ps) {
        GiroSettings__c settings = GiroSettings__c.getOrgDefaults();
        String partnerCode = settings != null ? settings.Partner_Code__c : '000000000';
        
        return partnerCode + 'T' + 
               Datetime.now().format('yyyyMMddHHmmss') + 
               'C' + String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 5);
    }
    
    // Order 상태 확인 및 업데이트
    private void checkAndUpdateOrderStatus(Set<Id> orderIds) {
        // 각 Order의 모든 PaymentStatus 확인
        Map<Id, Order> ordersToUpdate = new Map<Id, Order>();
        
        for (AggregateResult ar : [
            SELECT Order__c, 
                   COUNT(Id) totalCount,
                   SUM(CASE WHEN Status__c = '완납' THEN 1 ELSE 0 END) completedCount
            FROM PaymentStatus__c
            WHERE Order__c IN :orderIds
            GROUP BY Order__c
        ]) {
            Id orderId = (Id) ar.get('Order__c');
            Integer totalCount = (Integer) ar.get('totalCount');
            Integer completedCount = (Integer) ar.get('completedCount');
            
            // 모든 PaymentStatus가 완납인 경우
            if (totalCount == completedCount) {
                Order ord = new Order();
                ord.Id = orderId;
                ord.Status = 'Completed';
                ordersToUpdate.put(orderId, ord);
            }
        }
        
        if (!ordersToUpdate.isEmpty()) {
            update ordersToUpdate.values();
        }
    }
    
    // 납부 완료 알림 전송
    private void sendPaymentCompletionNotification(List<PaymentStatus__c> completedPayments) {
        // 이메일 알림 또는 플랫폼 이벤트 발행
        List<Payment_Completion_Event__e> events = new List<Payment_Completion_Event__e>();
        
        for (PaymentStatus__c ps : completedPayments) {
            Payment_Completion_Event__e event = new Payment_Completion_Event__e();
            event.PaymentStatus_Id__c = ps.Id;
            event.Order_Id__c = ps.Order__c;
            event.Payment_Amount__c = ps.Payment_Amount__c;
            event.Payment_Date__c = ps.Payment_Date__c;
            events.add(event);
        }
        
        if (!events.isEmpty()) {
            // EventBus.publish(events);
        }
    }
}