/**
 * 납부 API와 통신하는 클라이언트 클래스
 */
public with sharing class PaymentAPIClient {
    
    // API 엔드포인트 (Named Credential 사용)
    private static final String API_ENDPOINT = 'callout:Giro_API/v1/payments';
    
    // API 응답을 래핑하는 내부 클래스
    public class PaymentResponse {
        public Boolean isSuccess;
        public String responseCode;
        public String responseMessage;
        public PaymentInfo paymentInfo;
        
        public PaymentResponse() {
            this.isSuccess = false;
            this.paymentInfo = new PaymentInfo();
        }
    }
    
    // 납부 정보를 래핑하는 내부 클래스
    public class PaymentInfo {
        public String status;
        public Decimal amount;
        public Datetime paymentDate;
        public String paymentMethod;
        
        public PaymentInfo() {
            this.status = '미납';
        }
    }
    
    /**
     * 납부 결과 조회 API 호출
     * @param ptcoCode 제휴사 코드
     * @param orgTranId 제휴사 거래고유번호
     * @return 납부 응답 객체
     */
    public static PaymentResponse getPaymentResult(String ptcoCode, String orgTranId) {
        PaymentResponse response = new PaymentResponse();
        
        try {
            // API 요청 준비
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json; charset=UTF-8');
            // Named Credential 사용 시 Authorization 헤더는 자동으로 설정됨
            
            // 요청 파라미터 설정
            Map<String, Object> params = new Map<String, Object>{
                'ptco_code' => ptcoCode,
                'org_tran_id' => orgTranId
            };
            
            // 파라미터를 URL 쿼리스트링으로 변환하여 추가
            String endpoint = API_ENDPOINT + '?' + buildQueryString(params);
            req.setEndpoint(endpoint);
            
            // API 호출
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // 응답 처리
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                response.isSuccess = responseMap.get('rsp_code') == 'A0000';
                response.responseCode = (String) responseMap.get('rsp_code');
                response.responseMessage = (String) responseMap.get('rsp_msg');
                
                if (response.isSuccess && responseMap.containsKey('pay_info')) {
                    Map<String, Object> payInfo = (Map<String, Object>) responseMap.get('pay_info');
                    
                    response.paymentInfo.status = determinePaymentStatus(payInfo);
                    response.paymentInfo.amount = (Decimal) payInfo.get('pay_amt');
                    
                    String payDateStr = (String) payInfo.get('pay_date');
                    if (String.isNotBlank(payDateStr)) {
                        response.paymentInfo.paymentDate = parseDate(payDateStr);
                    }
                    
                    response.paymentInfo.paymentMethod = (String) payInfo.get('pay_meth_type');
                }
            } else {
                response.responseCode = String.valueOf(res.getStatusCode());
                response.responseMessage = 'API 호출 실패: ' + res.getStatus();
            }
        } catch (Exception e) {
            response.responseCode = 'E9999';
            response.responseMessage = '예외 발생: ' + e.getMessage();
            System.debug('API 호출 중 예외 발생: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
        
        return response;
    }
    
    /**
     * 액세스 토큰 가져오기
     * Named Credential 사용 시 토큰은 자동으로 관리됨
     * @return 액세스 토큰
     */
    private static String getAccessToken() {
        // Named Credential을 사용하므로 직접 토큰을 관리할 필요가 없음
        // 필요시 Custom Setting이나 커스텀 메타데이터에서 설정 정보 조회 가능
        return '';
    }
    
    /**
     * 납부 상태 결정
     * @param payInfo 납부 정보 맵
     * @return 결정된 납부 상태
     */
    private static String determinePaymentStatus(Map<String, Object> payInfo) {
        // 실제 구현에서는 API 응답의 구조에 맞게 로직 구현
        if (payInfo.containsKey('pay_stat_code')) {
            String payStatCode = (String) payInfo.get('pay_stat_code');
            
            if (payStatCode == '01') return '납부완료';
            if (payStatCode == '02') return '부분납부';
            if (payStatCode == '03') return '미납';
            // 기타 상태 코드에 따른 처리...
        }
        
        return '미납'; // 기본값
    }
    
    /**
     * 날짜 문자열을 Datetime으로 파싱
     * @param dateStr 날짜 문자열 (예: 20201021)
     * @return 파싱된 Datetime
     */
    private static Datetime parseDate(String dateStr) {
        if (String.isBlank(dateStr) || dateStr.length() < 8) return null;
        
        try {
            Integer year = Integer.valueOf(dateStr.substring(0, 4));
            Integer month = Integer.valueOf(dateStr.substring(4, 6));
            Integer day = Integer.valueOf(dateStr.substring(6, 8));
            
            return Datetime.newInstance(year, month, day);
        } catch (Exception e) {
            System.debug('날짜 파싱 실패: ' + dateStr);
            return null;
        }
    }
    
    /**
     * Map을 쿼리 스트링으로 변환
     * @param params 파라미터 맵
     * @return 쿼리 스트링
     */
    private static String buildQueryString(Map<String, Object> params) {
        List<String> queryParams = new List<String>();
        
        for (String key : params.keySet()) {
            String value = String.valueOf(params.get(key));
            queryParams.add(key + '=' + EncodingUtil.urlEncode(value, 'UTF-8'));
        }
        
        return String.join(queryParams, '&');
    }
}