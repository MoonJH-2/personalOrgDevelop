/**
 * 납부 상태 관련 기능을 위한 컨트롤러 클래스
 */
public with sharing class PaymentStatusController {
    
    /**
     * 특정 납부 상태 레코드의 정보 조회
     * @param paymentStatusId 납부 상태 레코드 ID
     * @return 납부 상태 정보
     */
    @AuraEnabled(cacheable=true)
    public static PaymentStatus__c getPaymentStatus(Id paymentStatusId) {
        try {
            return [
                SELECT Id, Name, OrgTranId__c, PtcoCode__c, PayAmount__c, PaymentDate__c,
                       LastCheckedDate__c, Status__c, PaymentMethod__c, IsOverdue__c, DueDate__c
                FROM PaymentStatus__c
                WHERE Id = :paymentStatusId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('납부 상태 정보를 가져오는 중 오류 발생: ' + e.getMessage());
        }
    }
    
    /**
     * 미납 상태인 납부 레코드 목록 조회
     * @return 미납 상태인 납부 레코드 목록
     */
    @AuraEnabled(cacheable=true)
    public static List<PaymentStatus__c> getUnpaidPaymentStatuses() {
        try {
            return [
                SELECT Id, Name, OrgTranId__c, PtcoCode__c, Status__c, PayAmount__c, 
                       DueDate__c, IsOverdue__c, LastCheckedDate__c
                FROM PaymentStatus__c
                WHERE Status__c = '미납'
                ORDER BY DueDate__c ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('미납 납부 상태 목록을 가져오는 중 오류 발생: ' + e.getMessage());
        }
    }
    
    /**
     * 납부 상태 요약 정보 조회
     * @return 납부 상태 요약 정보
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPaymentStatusSummary() {
        try {
            Map<String, Object> summary = new Map<String, Object>();
            
            // 납부 완료 건수
            Integer paidCount = [
                SELECT COUNT() 
                FROM PaymentStatus__c 
                WHERE Status__c = '납부완료'
            ];
            summary.put('paidCount', paidCount);
            
            // 미납 건수
            Integer unpaidCount = [
                SELECT COUNT() 
                FROM PaymentStatus__c 
                WHERE Status__c = '미납'
            ];
            summary.put('unpaidCount', unpaidCount);
            
            // 연체 건수
            Integer overdueCount = [
                SELECT COUNT() 
                FROM PaymentStatus__c 
                WHERE Status__c = '미납' AND IsOverdue__c = true
            ];
            summary.put('overdueCount', overdueCount);
            
            // 부분납부 건수
            Integer partialCount = [
                SELECT COUNT() 
                FROM PaymentStatus__c 
                WHERE Status__c = '부분납부'
            ];
            summary.put('partialCount', partialCount);
            
            return summary;
        } catch (Exception e) {
            throw new AuraHandledException('납부 상태 요약 정보를 가져오는 중 오류 발생: ' + e.getMessage());
        }
    }
    
    /**
     * 납부 상태 수동 업데이트
     * @param paymentStatusId 업데이트할 납부 상태 레코드 ID
     * @return 업데이트된 납부 상태 레코드
     */
    @AuraEnabled
    public static PaymentStatus__c updatePaymentStatus(Id paymentStatusId) {
        try {
            return PaymentStatusService.checkAndUpdatePaymentStatus(paymentStatusId);
        } catch (Exception e) {
            throw new AuraHandledException('납부 상태 업데이트 중 오류 발생: ' + e.getMessage());
        }
    }
    
    /**
     * 여러 납부 상태 일괄 업데이트
     * @param paymentStatusIds 업데이트할 납부 상태 레코드 ID 목록
     * @return 업데이트 성공 여부
     */
    @AuraEnabled
    public static Boolean batchUpdatePaymentStatuses(List<Id> paymentStatusIds) {
        try {
            PaymentStatusService.batchUpdatePaymentStatuses(paymentStatusIds);
            return true;
        } catch (Exception e) {
            throw new AuraHandledException('납부 상태 일괄 업데이트 중 오류 발생: ' + e.getMessage());
        }
    }
    
    /**
     * 스케줄러 작업 시작
     * @return 스케줄 작업 ID
     */
    @AuraEnabled
    public static String startScheduler() {
        try {
            return PaymentStatusScheduler.scheduleHourly();
        } catch (Exception e) {
            throw new AuraHandledException('스케줄러 시작 중 오류 발생: ' + e.getMessage());
        }
    }
    
    /**
     * 스케줄링된 작업 정보 조회
     * @return 스케줄링된 작업 목록
     */
    @AuraEnabled(cacheable=true)
    public static List<CronTrigger> getScheduledJobs() {
        try {
            return PaymentStatusScheduler.getScheduledJobs();
        } catch (Exception e) {
            throw new AuraHandledException('스케줄링된 작업 정보 조회 중 오류 발생: ' + e.getMessage());
        }
    }
}
