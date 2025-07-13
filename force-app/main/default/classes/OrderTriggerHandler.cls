public with sharing class OrderTriggerHandler extends TriggerHandler {
    
    protected override void afterInsert(List<SObject> newList, Map<Id, SObject> newMap) {
        List<Order> newOrders = (List<Order>) newList;
        List<PaymentStatus__c> paymentStatusList = new List<PaymentStatus__c>();
        
        for (Order ord : newOrders) {
            if (ord.Status == 'Activated' && ord.Payment_Method__c != null) {
                paymentStatusList.addAll(createPaymentStatus(ord));
            }
        }
        
        if (!paymentStatusList.isEmpty()) {
            insert paymentStatusList;
        }
    }
    
    protected override void afterUpdate(List<SObject> newList, List<SObject> oldList, Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {
        List<Order> newOrders = (List<Order>) newList;
        Map<Id, Order> oldOrderMap = (Map<Id, Order>) oldMap;
        List<PaymentStatus__c> paymentStatusList = new List<PaymentStatus__c>();
        Set<Id> orderIdsToDeletePayments = new Set<Id>();
        
        for (Order ord : newOrders) {
            Order oldOrder = oldOrderMap.get(ord.Id);
            
            // Status가 Activated로 변경된 경우
            if (ord.Status == 'Activated' && oldOrder.Status != 'Activated' && ord.Payment_Method__c != null) {
                paymentStatusList.addAll(createPaymentStatus(ord));
            }
            
            // Payment Method가 변경된 경우
            if (ord.Payment_Method__c != oldOrder.Payment_Method__c && ord.Status == 'Activated') {
                orderIdsToDeletePayments.add(ord.Id);
                if (ord.Payment_Method__c != null) {
                    paymentStatusList.addAll(createPaymentStatus(ord));
                }
            }
        }
        
        // 기존 PaymentStatus 삭제
        if (!orderIdsToDeletePayments.isEmpty()) {
            delete [SELECT Id FROM PaymentStatus__c WHERE Order__c IN :orderIdsToDeletePayments];
        }
        
        // 새로운 PaymentStatus 생성
        if (!paymentStatusList.isEmpty()) {
            insert paymentStatusList;
        }
    }
    
    private static List<PaymentStatus__c> createPaymentStatus(Order ord) {
        List<PaymentStatus__c> paymentStatusList = new List<PaymentStatus__c>();
        
        Integer installmentCount = getInstallmentCount(ord.Payment_Method__c);
        Date startDate = ord.EffectiveDate != null ? ord.EffectiveDate : Date.today();
        Decimal installmentAmount = ord.TotalAmount / installmentCount;
        
        for (Integer i = 0; i < installmentCount; i++) {
            PaymentStatus__c ps = new PaymentStatus__c();
            ps.Order__c = ord.Id;
            ps.Name = ord.OrderNumber + ' - ' + (i + 1) + '회차';
            ps.InstallmentNumber__c = i + 1;
            ps.Amount__c = installmentAmount;
            ps.Status__c = '미납';
            
            // 납부 예정일 계산
            if (ord.Payment_Method__c == '월별') {
                ps.DueDate__c = startDate.addMonths(i);
            } else if (ord.Payment_Method__c == '분기별') {
                ps.DueDate__c = startDate.addMonths(i * 3);
            } else if (ord.Payment_Method__c == '반기별') {
                ps.DueDate__c = startDate.addMonths(i * 6);
            } else if (ord.Payment_Method__c == '년별') {
                ps.DueDate__c = startDate.addYears(i);
            }
            
            paymentStatusList.add(ps);
        }
        
        return paymentStatusList;
    }
    
    private static Integer getInstallmentCount(String paymentMethod) {
        // 기본값 12개월로 가정, 실제로는 비즈니스 요구사항에 따라 조정
        if (paymentMethod == '월별') {
            return 12;
        } else if (paymentMethod == '분기별') {
            return 4;
        } else if (paymentMethod == '반기별') {
            return 2;
        } else if (paymentMethod == '년별') {
            return 1;
        }
        return 1;
    }
}