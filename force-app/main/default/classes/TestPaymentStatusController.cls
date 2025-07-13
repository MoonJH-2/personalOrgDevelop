/**
 * 납부 상태 컨트롤러 테스트 클래스
 */
@isTest
public class TestPaymentStatusController {
    
    /**
     * 테스트 데이터 설정
     */
    @TestSetup
    static void setupTestData() {
        // 테스트용 납부 상태 레코드 생성
        List<PaymentStatus__c> testPayments = new List<PaymentStatus__c>();
        
        // 납부 완료 레코드
        testPayments.add(new PaymentStatus__c(
            Name = '테스트 납부 완료',
            OrgTranId__c = 'TEST-TRAN-001',
            PtcoCode__c = '901012345',
            Status__c = '납부완료',
            PayAmount__c = 10000,
            PaymentDate__c = Date.today().addDays(-5),
            LastCheckedDate__c = Datetime.now().addHours(-1),
            NextCheckDate__c = Datetime.now().addHours(1),
            DueDate__c = Date.today().addDays(-10),
            IsOverdue__c = false
        ));
        
        // 미납 레코드 (연체 아님)
        testPayments.add(new PaymentStatus__c(
            Name = '테스트 미납 (연체 아님)',
            OrgTranId__c = 'TEST-TRAN-002',
            PtcoCode__c = '901012345',
            Status__c = '미납',
            PayAmount__c = 20000,
            LastCheckedDate__c = Datetime.now().addHours(-2),
            NextCheckDate__c = Datetime.now(),
            DueDate__c = Date.today().addDays(5),
            IsOverdue__c = false
        ));
        
        // 미납 레코드 (연체)
        testPayments.add(new PaymentStatus__c(
            Name = '테스트 미납 (연체)',
            OrgTranId__c = 'TEST-TRAN-003',
            PtcoCode__c = '901012345',
            Status__c = '미납',
            PayAmount__c = 30000,
            LastCheckedDate__c = Datetime.now().addHours(-3),
            NextCheckDate__c = Datetime.now().addMinutes(-30),
            DueDate__c = Date.today().addDays(-2),
            IsOverdue__c = true
        ));
        
        // 부분 납부 레코드
        testPayments.add(new PaymentStatus__c(
            Name = '테스트 부분 납부',
            OrgTranId__c = 'TEST-TRAN-004',
            PtcoCode__c = '901012345',
            Status__c = '부분납부',
            PayAmount__c = 40000,
            PaymentDate__c = Date.today().addDays(-1),
            LastCheckedDate__c = Datetime.now().addHours(-4),
            NextCheckDate__c = Datetime.now().addHours(2),
            DueDate__c = Date.today().addDays(3),
            IsOverdue__c = false
        ));
        
        insert testPayments;
    }
    
    /**
     * 특정 납부 상태 조회 테스트
     */
    @isTest
    static void testGetPaymentStatus() {
        // 테스트 데이터 조회
        PaymentStatus__c testPayment = [
            SELECT Id FROM PaymentStatus__c 
            WHERE Name = '테스트 납부 완료' 
            LIMIT 1
        ];
        
        // 테스트 실행
        Test.startTest();
        PaymentStatus__c result = PaymentStatusController.getPaymentStatus(testPayment.Id);
        Test.stopTest();
        
        // 검증
        System.assertNotEquals(null, result, '납부 상태가 조회되어야 합니다.');
        System.assertEquals('납부완료', result.Status__c, '상태가 납부완료여야 합니다.');
        System.assertEquals(10000, result.PayAmount__c, '납부 금액이 일치해야 합니다.');
    }
    
    /**
     * 미납 납부 상태 목록 조회 테스트
     */
    @isTest
    static void testGetUnpaidPaymentStatuses() {
        // 테스트 실행
        Test.startTest();
        List<PaymentStatus__c> results = PaymentStatusController.getUnpaidPaymentStatuses();
        Test.stopTest();
        
        // 검증
        System.assertEquals(2, results.size(), '미납 상태인 레코드가 2개 있어야 합니다.');
        
        // 정렬 순서 검증 (DueDate__c 오름차순)
        Date firstDueDate = results[0].DueDate__c;
        Date secondDueDate = results[1].DueDate__c;
        System.assert(firstDueDate <= secondDueDate, '납부 기한 오름차순으로 정렬되어야 합니다.');
    }
    
    /**
     * 납부 상태 요약 정보 조회 테스트
     */
    @isTest
    static void testGetPaymentStatusSummary() {
        // 테스트 실행
        Test.startTest();
        Map<String, Object> summary = PaymentStatusController.getPaymentStatusSummary();
        Test.stopTest();
        
        // 검증
        System.assertEquals(1, summary.get('paidCount'), '납부완료 건수가 1건이어야 합니다.');
        System.assertEquals(2, summary.get('unpaidCount'), '미납 건수가 2건이어야 합니다.');
        System.assertEquals(1, summary.get('overdueCount'), '연체 건수가 1건이어야 합니다.');
        System.assertEquals(1, summary.get('partialCount'), '부분납부 건수가 1건이어야 합니다.');
    }
    
    /**
     * 납부 상태 업데이트 테스트
     */
    @isTest
    static void testUpdatePaymentStatus() {
        // 테스트용 모의 응답 클래스
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator();
        mock.addResponse(200, '{"rsp_code":"A0000","rsp_msg":"정상 처리","org_tran_id":"TEST-TRAN-002","pay_info":{"pay_stat_code":"01","pay_amt":20000,"pay_date":"20250710"}}');
        
        // 테스트 데이터 조회
        PaymentStatus__c testPayment = [
            SELECT Id FROM PaymentStatus__c 
            WHERE Name = '테스트 미납 (연체 아님)' 
            LIMIT 1
        ];
        
        // HTTP 콜아웃 모의 처리 설정
        Test.setMock(HttpCalloutMock.class, mock);
        
        // 테스트 실행
        Test.startTest();
        PaymentStatus__c updatedPayment = PaymentStatusController.updatePaymentStatus(testPayment.Id);
        Test.stopTest();
        
        // 검증
        System.assertNotEquals(null, updatedPayment, '업데이트된 납부 상태가 반환되어야 합니다.');
        System.assertEquals('납부완료', updatedPayment.Status__c, '상태가 납부완료로 업데이트되어야 합니다.');
    }
    
    /**
     * 일괄 업데이트 테스트
     */
    @isTest
    static void testBatchUpdatePaymentStatuses() {
        // 테스트용 모의 응답 클래스
        MockHttpResponseGenerator mock = new MockHttpResponseGenerator();
        mock.addResponse(200, '{"rsp_code":"A0000","rsp_msg":"정상 처리","org_tran_id":"TEST-TRAN-002","pay_info":{"pay_stat_code":"01","pay_amt":20000,"pay_date":"20250710"}}');
        
        // HTTP 콜아웃 모의 처리 설정
        Test.setMock(HttpCalloutMock.class, mock);

        // 테스트 데이터 조회
        List<Id> paymentIds = new List<Id>();
        for(PaymentStatus__c ps : [SELECT Id FROM PaymentStatus__c WHERE Status__c = '미납']) {
            paymentIds.add(ps.Id);
        }

        // 테스트 실행
        Test.startTest();
        Boolean result = PaymentStatusController.batchUpdatePaymentStatuses(paymentIds);
        Test.stopTest();
        
        // 검증
        System.assertEquals(true, result, '배치 작업이 성공적으로 시작되어야 합니다.');
    }
    
    /**
     * 스케줄러 시작 테스트
     */
    @isTest
    static void testStartScheduler() {
        // 테스트 실행
        Test.startTest();
        String jobId = PaymentStatusController.startScheduler();
        Test.stopTest();
        
        // 검증
        System.assertNotEquals(null, jobId, '스케줄 작업이 성공적으로 시작되어야 합니다.');
    }
    
    /**
     * 스케줄링된 작업 정보 조회 테스트
     */
    @isTest
    static void testGetScheduledJobs() {
        // 테스트 스케줄 작업 생성
        Test.startTest();
        String jobId = PaymentStatusController.startScheduler();
        List<CronTrigger> jobs = PaymentStatusController.getScheduledJobs();
        Test.stopTest();
        
        // 검증
        System.assertNotEquals(0, jobs.size(), '스케줄링된 작업이 하나 이상 있어야 합니다.');
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
                res.setBody('{"status":"success","result":{}}');
                return res;
            }
            return responses.remove(0);
        }
    }
}
