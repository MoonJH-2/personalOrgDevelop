/**
 * 납부 상태 관련 서비스를 제공하는 클래스
 */
public with sharing class PaymentStatusService {
    
    /**
     * 납부 상태를 조회하여 업데이트
     * @param paymentStatusId 납부 상태 레코드 ID
     * @return 업데이트된 납부 상태 레코드
     */
    public static PaymentStatus__c checkAndUpdatePaymentStatus(Id paymentStatusId) {
        PaymentStatus__c paymentStatus = [
            SELECT Id, OrgTranId__c, PtcoCode__c, Status__c, LastCheckedDate__c, NextCheckDate__c
            FROM PaymentStatus__c
            WHERE Id = :paymentStatusId
        ];
        
        // API 클라이언트를 통해 납부 상태 조회
        PaymentAPIClient.PaymentResponse response = PaymentAPIClient.getPaymentResult(
            paymentStatus.PtcoCode__c, 
            paymentStatus.OrgTranId__c
        );
        
        // 응답을 기반으로 납부 상태 업데이트
        if (response.isSuccess) {
            paymentStatus.Status__c = response.paymentInfo.status;
            paymentStatus.LastCheckedDate__c = Datetime.now();
            paymentStatus.NextCheckDate__c = Datetime.now().addHours(1); // 다음 확인은 1시간 후로 설정
            
            update paymentStatus;
        }
        
        return paymentStatus;
    }
    
    /**
     * 특정 기준에 따라 업데이트가 필요한 납부 상태 레코드 조회
     * @return 업데이트가 필요한 납부 상태 레코드 목록
     */
    public static List<PaymentStatus__c> getPaymentStatusesToUpdate() {
        Datetime oneHourAgo = Datetime.now().addHours(-1);
        
        return [
            SELECT Id, OrgTranId__c, PtcoCode__c, Status__c, LastCheckedDate__c, NextCheckDate__c
            FROM PaymentStatus__c
            WHERE (NextCheckDate__c <= :Datetime.now() OR LastCheckedDate__c <= :oneHourAgo)
            AND Status__c != '납부완료'
            ORDER BY LastCheckedDate__c ASC
            LIMIT 100
        ];
    }
    
    /**
     * 미납 상태인 납부 레코드 조회
     * @return 미납 상태인 납부 레코드 목록
     */
    public static List<PaymentStatus__c> getUnpaidPaymentStatuses() {
        return [
            SELECT Id, Name, OrgTranId__c, PtcoCode__c, Status__c, PayAmount__c, 
                   DueDate__c, IsOverdue__c, LastCheckedDate__c
            FROM PaymentStatus__c
            WHERE Status__c = '미납'
            ORDER BY DueDate__c ASC
        ];
    }
    
    /**
     * 여러 납부 상태 레코드 일괄 업데이트
     * @param paymentStatusIds 업데이트할 납부 상태 레코드 ID 목록
     * @return 업데이트된 납부 상태 레코드 목록
     */
    public static List<PaymentStatus__c> batchUpdatePaymentStatuses(List<Id> paymentStatusIds) {
        List<PaymentStatus__c> updatedStatuses = new List<PaymentStatus__c>();
        
        for (Id statusId : paymentStatusIds) {
            try {
                PaymentStatus__c updated = checkAndUpdatePaymentStatus(statusId);
                updatedStatuses.add(updated);
            } catch (Exception e) {
                System.debug('Error updating payment status: ' + statusId + '. Error: ' + e.getMessage());
                // 여기에 에러 처리 로직 추가
            }
        }
        
        return updatedStatuses;
    }
    
    /**
     * 납부 상태 데이터 검증
     * @param paymentStatus 검증할 납부 상태 레코드
     * @return 검증 결과
     */
    public static Boolean validatePaymentStatus(PaymentStatus__c paymentStatus) {
        // 필수 필드 검증
        if (String.isBlank(paymentStatus.OrgTranId__c) || 
            String.isBlank(paymentStatus.PtcoCode__c)) {
            return false;
        }
        
        // 추가 검증 로직...
        
        return true;
    }
}
