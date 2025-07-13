/**
 * 납부 상태를 일괄 업데이트하는 배치 클래스
 */
public with sharing class PaymentStatusBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    private Integer processedRecords = 0;
    private Integer successfulUpdates = 0;
    private Integer failedUpdates = 0;
    private String batchProcessId;
    
    public PaymentStatusBatch() {
        this.batchProcessId = 'BATCH-' + Datetime.now().getTime();
    }
    
    /**
     * 배치 프로세스에서 처리할 레코드 쿼리
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime oneHourAgo = Datetime.now().addHours(-1);
        
        return Database.getQueryLocator([
            SELECT Id, OrgTranId__c, PtcoCode__c, Status__c, LastCheckedDate__c, NextCheckDate__c
            FROM PaymentStatus__c
            WHERE (NextCheckDate__c <= :Datetime.now() OR LastCheckedDate__c <= :oneHourAgo)
            AND Status__c != '납부완료'
            ORDER BY LastCheckedDate__c ASC
        ]);
    }
    
    /**
     * 각 배치 처리
     */
    public void execute(Database.BatchableContext bc, List<PaymentStatus__c> scope) {
        List<PaymentStatus__c> statusesToUpdate = new List<PaymentStatus__c>();
        
        for (PaymentStatus__c status : scope) {
            try {
                // API 클라이언트를 통해 납부 상태 조회
                PaymentAPIClient.PaymentResponse response = PaymentAPIClient.getPaymentResult(
                    status.PtcoCode__c,
                    status.OrgTranId__c
                );
                
                // 응답을 기반으로 납부 상태 업데이트
                if (response.isSuccess) {
                    status.Status__c = response.paymentInfo.status;
                    status.LastCheckedDate__c = Datetime.now();
                    status.NextCheckDate__c = Datetime.now().addHours(1); // 다음 확인은 1시간 후로 설정
                    
                    statusesToUpdate.add(status);
                    successfulUpdates++;
                } else {
                    // API 호출은 성공했지만 상태 업데이트에 필요한 정보가 없는 경우
                    System.debug('API 응답 실패: ' + response.responseCode + ' - ' + response.responseMessage);
                    failedUpdates++;
                }
            } catch (Exception e) {
                System.debug('납부 상태 업데이트 중 예외 발생: ' + e.getMessage() + '\n' + e.getStackTraceString());
                failedUpdates++;
            }
            
            processedRecords++;
        }
        
        // 일괄 업데이트
        if (!statusesToUpdate.isEmpty()) {
            try {
                update statusesToUpdate;
            } catch (Exception e) {
                System.debug('일괄 업데이트 중 예외 발생: ' + e.getMessage() + '\n' + e.getStackTraceString());
                failedUpdates += statusesToUpdate.size();
                successfulUpdates -= statusesToUpdate.size();
            }
        }
    }
    
    /**
     * 배치 프로세스 완료 후 처리
     */
    public void finish(Database.BatchableContext bc) {
        // 배치 처리 결과 로깅
        System.debug('납부 상태 배치 처리 완료:');
        System.debug('배치 프로세스 ID: ' + batchProcessId);
        System.debug('처리된 레코드 수: ' + processedRecords);
        System.debug('성공적으로 업데이트된 레코드 수: ' + successfulUpdates);
        System.debug('업데이트 실패한 레코드 수: ' + failedUpdates);
        
        // 결과 이메일 발송 등 추가 작업 가능
        sendCompletionEmail();
    }
    
    /**
     * 완료 이메일 발송
     */
    private void sendCompletionEmail() {
        // 실제 구현에서는 필요에 따라 이메일 발송 로직 구현
    }
}
