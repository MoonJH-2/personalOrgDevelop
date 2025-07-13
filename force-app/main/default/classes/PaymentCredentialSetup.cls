/**
 * API 인증 정보 설정을 위한 유틸리티 클래스
 * 필요 시 Custom Setting에 API 인증 정보를 저장하거나 검증하는 기능 제공
 */
public with sharing class PaymentCredentialSetup {
    
    /**
     * Custom Setting에 기본 API 인증 정보 설정
     * @param clientId API Client ID
     * @param clientSecret API Client Secret
     * @param callbackUrl API Callback URL
     * @return 설정 성공 여부
     */
    public static Boolean setupCredentials(String clientId, String clientSecret, String callbackUrl) {
        try {
            // Custom Setting에 값 설정
            Giro_API_Settings__c settings = Giro_API_Settings__c.getOrgDefaults();
            
            if (settings.Id == null) {
                settings = new Giro_API_Settings__c();
            }
            
            settings.Client_ID__c = clientId;
            settings.Client_Secret__c = clientSecret;
            
            // Callback URL 필드가 정의되어 있다면 설정
            // settings.Callback_URL__c = callbackUrl;
            
            upsert settings;
            return true;
        } catch (Exception e) {
            System.debug('API 인증 정보 설정 중 오류 발생: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * 현재 저장된 API 인증 정보 조회
     * @return API 인증 정보 설정
     */
    public static Giro_API_Settings__c getCredentials() {
        return Giro_API_Settings__c.getOrgDefaults();
    }
    
    /**
     * API 인증 정보가 유효한지 테스트
     * @return 테스트 결과
     */
    public static Map<String, Object> testCredentials() {
        Map<String, Object> result = new Map<String, Object>{
            'success' => false,
            'message' => ''
        };
        
        try {
            // 간단한 API 호출로 인증 정보 유효성 테스트
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Giro_API/v1/test');
            req.setMethod('GET');
            req.setTimeout(10000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            result.put('statusCode', res.getStatusCode());
            
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                result.put('success', true);
                result.put('message', '인증 정보가 유효합니다.');
            } else {
                result.put('message', '인증 정보가 유효하지 않습니다. 상태 코드: ' + res.getStatusCode());
            }
        } catch (Exception e) {
            result.put('message', '인증 테스트 중 오류 발생: ' + e.getMessage());
        }
        
        return result;
    }
}