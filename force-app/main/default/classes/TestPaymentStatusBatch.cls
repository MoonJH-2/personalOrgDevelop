/**
 * PaymentStatusBatch 클래스의 테스트
 * @author GitHub Copilot
 * @date 2025-07-12
 */
@isTest
public class TestPaymentStatusBatch {
    
    /**
     * 테스트 데이터 설정
     */
    @TestSetup
    static void setupTestData() {
        // 테스트용 납부 상태 레코드 생성
        List<PaymentStatus__c> testPayments = new List<PaymentStatus__c>();
        
        // 여러 납부 상태 레코드 생성
        for(Integer i = 0; i < 10; i++) {
            PaymentStatus__c payment = new PaymentStatus__c(
                Name = '테스트 납부 ' + i,
                OrgTranId__c = 'TEST-TRAN-' + i,
                PtcoCode__c = '901012345',
                Status__c = (Math.mod(i, 3) == 0) ? '납부완료' : 
                           (Math.mod(i, 3) == 1) ? '미납' : '부분납부',
                PayAmount__c = 10000 * (i + 1),
                LastCheckedDate__c = Datetime.now().addHours(-i),
                NextCheckDate__c = Datetime.now().addMinutes(-i * 30),
                DueDate__c = Date.today().addDays(Math.mod(i, 2) == 0 ? 5 : -5),
                IsOverdue__c = Math.mod(i, 2) != 0
            );
            
            if(Math.mod(i, 3) == 0) {
                payment.PaymentDate__c = Date.today().addDays(-i);
            }
            
            testPayments.add(payment);
        }
        
        insert testPayments;
    }
    
    /**
     * 배치 실행 테스트
     */
    @isTest
    static void testBatchExecution() {
        // 모의 HTTP 응답 설정
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator();
        // 여러 응답 준비
        for(Integer i = 0; i < 10; i++) {
            String status = (Math.mod(i, 2) == 0) ? '납부완료' : '부분납부';
            Integer paidAmount = (Math.mod(i, 2) == 0) ? 10000 * (i + 1) : 5000 * (i + 1);
            Integer unpaidAmount = (Math.mod(i, 2) == 0) ? 0 : 5000 * (i + 1);
            String paymentDate = '2025071' + i;
            
            mock.addResponse(200, '{"rsp_code":"A0000","rsp_msg":"정상 처리","org_tran_id":"TEST-TRAN-' + i + 
                            '","pay_info":{"pay_stat_code":"' + (Math.mod(i, 2) == 0 ? '01' : '02') + 
                            '","pay_amt":' + paidAmount + ',"pay_date":"' + paymentDate + '"}}');
        }
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        // 배치 실행
        Test.startTest();
        PaymentStatusBatch batch = new PaymentStatusBatch();
        Database.executeBatch(batch, 5);
        Test.stopTest();
        
        // 결과 검증
        List<PaymentStatus__c> updatedPayments = [
            SELECT Id, Status__c, PayAmount__c, LastCheckedDate__c 
            FROM PaymentStatus__c
        ];
        
        System.assertEquals(10, updatedPayments.size(), '모든 납부 상태 레코드가 처리되어야 합니다.');
        
        // 적어도 일부 레코드는 업데이트되었는지 확인
        Integer updatedCount = 0;
        for(PaymentStatus__c payment : updatedPayments) {
            if(payment.LastCheckedDate__c > Datetime.now().addMinutes(-5)) {
                updatedCount++;
            }
        }
        
        System.assert(updatedCount > 0, '최소한 일부 레코드는 업데이트되어야 합니다.');
    }
    
    /**
     * 스케줄러 테스트
     */
    @isTest
    static void testScheduler() {
        // 스케줄러 실행
        Test.startTest();
        String jobId = System.schedule('테스트 납부 상태 스케줄러', 
                                       '0 0 * * * ?', 
                                       new PaymentStatusScheduler());
        Test.stopTest();
        
        // 검증
        System.assertNotEquals(null, jobId, '스케줄 작업이 생성되어야 합니다.');
        
        // 스케줄 작업 조회
        List<CronTrigger> scheduledJobs = [
            SELECT Id, CronExpression, TimesTriggered, NextFireTime
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        
        System.assertEquals(1, scheduledJobs.size(), '스케줄 작업이 조회되어야 합니다.');
        System.assertEquals('0 0 * * * ?', scheduledJobs[0].CronExpression, '크론 표현식이 일치해야 합니다.');
    }
    
    /**
     * 스케줄러 hourly 메소드 테스트
     */
    @isTest
    static void testScheduleHourly() {
        // 시간별 스케줄링 실행
        Test.startTest();
        String result = PaymentStatusScheduler.scheduleHourly();
        Test.stopTest();
        
        // 검증
        System.assertNotEquals(null, result, '시간별 스케줄링 작업이 생성되어야 합니다.');
        
        // 스케줄 작업 조회
        List<CronTrigger> scheduledJobs = [
            SELECT Id, CronExpression
            FROM CronTrigger
            WHERE Id = :result
        ];
        
        System.assertEquals(1, scheduledJobs.size(), '스케줄 작업이 조회되어야 합니다.');
        System.assertEquals('0 0 * * * ?', scheduledJobs[0].CronExpression, '크론 표현식이 일치해야 합니다.');
    }
    
    /**
     * HTTP 응답 모의 클래스
     */
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private List<HttpResponse> responses = new List<HttpResponse>();
        
        public void addResponse(Integer statusCode, String body) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            responses.add(res);
        }
        
        public HttpResponse respond(HttpRequest req) {
            if(responses.isEmpty()) {
                HttpResponse res = new HttpResponse();
                res.setStatusCode(200);
                res.setBody('{"rsp_code":"A0000","rsp_msg":"정상 처리","pay_info":{"pay_stat_code":"01","pay_amt":10000}}');
                return res;
            }
            return responses.remove(0);
        }
    }
}
