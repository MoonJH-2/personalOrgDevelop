public class PaymentCheckBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // 미납 상태이고 Transaction ID가 있는 PaymentStatus 조회
        return Database.getQueryLocator([
            SELECT Id, Transaction_ID__c, Status__c
            FROM PaymentStatus__c
            WHERE Status__c = '미납' 
            AND Transaction_ID__c != null
            AND DueDate__c <= TODAY
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<PaymentStatus__c> scope) {
        for (PaymentStatus__c payment : scope) {
            try {
                // 납부 결과 확인
                GiroService.PaymentResultResponse result = 
                    GiroService.checkPaymentResult(payment.Transaction_ID__c);
                
                // 결과는 GiroService에서 자동으로 업데이트됨
                
            } catch (Exception e) {
                // 에러 로깅
                System.debug('Error checking payment for ' + payment.Id + ': ' + e.getMessage());
            }
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        // 완료 후 처리 (필요시 이메일 알림 등)
    }
    
    // 스케줄러로 매일 실행하기 위한 메소드
    public static void scheduleJob() {
        String cronExp = '0 0 1 * * ?'; // 매일 새벽 1시
        System.schedule('Payment Status Check', cronExp, new PaymentCheckScheduler());
    }
}

// 스케줄러 클래스
public class PaymentCheckScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        PaymentCheckBatch batch = new PaymentCheckBatch();
        Database.executeBatch(batch, 50); // 50개씩 처리
    }
}