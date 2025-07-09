public with sharing class GiroService {
    
    private static GiroSettings__c settings = GiroSettings__c.getOrgDefaults();
    private static final String API_BASE_URL = settings.API_Base_URL__c;
    
    // API Response Wrapper Classes
    public class GiroApiResponse {
        public String rsp_code;
        public String rsp_msg;
        public String org_tran_id;
        public String next_redirect_url;
        public String link_pay_url;
    }
    
    public class PaymentResultResponse {
        public String rsp_code;
        public String rsp_msg;
        public BillInfo bill_info;
        public PaymentInfo pay_info;
    }
    
    public class BillInfo {
        public String cls_code;
        public String giro_no;
        public String prtf_kind;
        public String pay_meth_type;
        public String epay_no;
        public String pay_yymm_seq;
        public String dudt_tm1s;
        public String dudt_in_amt;
        public String name;
        public String org_name;
    }
    
    public class PaymentInfo {
        public String pay_dtm;
        public String pay_amt;
        public String pyr_name;
        public String bank_name;
        public String acnt_no_masking;
    }
    
    // OAuth Token 획득
    @AuraEnabled
    public static String getAccessToken() {
        try {
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint('callout:Giro_Auth_Provider/oauth2/token');
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            String body = 'grant_type=client_credentials' +
                         '&client_id=' + EncodingUtil.urlEncode(settings.Client_ID__c, 'UTF-8') +
                         '&client_secret=' + EncodingUtil.urlEncode(settings.Client_Secret__c, 'UTF-8');
            request.setBody(body);
            
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                Map<String, Object> tokenResponse = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                return (String) tokenResponse.get('access_token');
            } else {
                throw new AuraHandledException('Failed to get access token: ' + response.getStatus());
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error getting access token: ' + e.getMessage());
        }
    }
    
    // 조회납부 URL 생성
    @AuraEnabled
    public static GiroApiResponse createInquiryPaymentUrl(String paymentStatusId) {
        try {
            PaymentStatus__c payment = [
                SELECT Id, Name, Order__c, Order__r.AccountId, Order__r.Account.Name,
                       Order__r.Account.PersonBirthdate, Amount__c, DueDate__c
                FROM PaymentStatus__c 
                WHERE Id = :paymentStatusId
            ];
            
            // 고유 거래번호 생성
            String transactionId = settings.Partner_Code__c + 'T' + 
                                 Datetime.now().format('yyyyMMddHHmmss') + 
                                 'C' + String.valueOf(payment.Id).right(5);
            
            Map<String, Object> requestBody = new Map<String, Object>{
                'ptco_code' => settings.Partner_Code__c,
                'org_tran_id' => transactionId,
                'cls_code' => settings.Classification_Code__c,
                'giro_no' => settings.Giro_Number__c,
                'epay_no' => generateEpayNumber(payment),
                'pay_yymm' => payment.DueDate__c.format('yyyyMM'),
                'noti_issu_type' => '0',
                'etc_type_code' => '00',
                'pyr_name' => payment.Order__r.Account.Name,
                'pyr_brdd' => formatBirthdate(payment.Order__r.Account.PersonBirthdate),
                'bank_code' => '020', // 기본값, 실제로는 Account에서 가져와야 함
                'acnt_no' => '12345678901234', // 기본값, 실제로는 Account에서 가져와야 함
                'pyr_cell_no' => '01012345678' // 기본값, 실제로는 Account에서 가져와야 함
            };
            
            return callGiroApi('/v1/payments/giro-inqr-pay-url', 'POST', requestBody);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating payment URL: ' + e.getMessage());
        }
    }
    
    // 입력납부 URL 생성
    @AuraEnabled
    public static GiroApiResponse createInputPaymentUrl(String paymentStatusId) {
        try {
            PaymentStatus__c payment = [
                SELECT Id, Name, Order__c, Order__r.AccountId, Order__r.Account.Name,
                       Order__r.Account.PersonBirthdate, Amount__c, DueDate__c
                FROM PaymentStatus__c 
                WHERE Id = :paymentStatusId
            ];
            
            String transactionId = settings.Partner_Code__c + 'T' + 
                                 Datetime.now().format('yyyyMMddHHmmss') + 
                                 'C' + String.valueOf(payment.Id).right(5);
            
            Map<String, Object> requestBody = new Map<String, Object>{
                'ptco_code' => settings.Partner_Code__c,
                'org_tran_id' => transactionId,
                'prtf_kind' => 'O',
                'cls_code' => settings.Classification_Code__c,
                'giro_no' => settings.Giro_Number__c,
                'cust_inqr_no' => generateCustomerInquiryNumber(payment),
                'pay_amt' => String.valueOf(payment.Amount__c.intValue()),
                'pyr_brdd' => formatBirthdate(payment.Order__r.Account.PersonBirthdate),
                'pyr_name' => payment.Order__r.Account.Name,
                'bank_code' => '020',
                'acnt_no' => '12345678901234',
                'pyr_cell_no' => '01012345678'
            };
            
            return callGiroApi('/v1/payments/giro-inpt-pay-url', 'POST', requestBody);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating input payment URL: ' + e.getMessage());
        }
    }
    
    // 링크납부 URL 생성
    @AuraEnabled
    public static GiroApiResponse createLinkPaymentUrl(String paymentStatusId) {
        try {
            PaymentStatus__c payment = [
                SELECT Id, Name, Order__c, Order__r.AccountId, Order__r.Account.Name,
                       Amount__c, DueDate__c
                FROM PaymentStatus__c 
                WHERE Id = :paymentStatusId
            ];
            
            String transactionId = settings.Partner_Code__c + 'T' + 
                                 Datetime.now().format('yyyyMMddHHmmss') + 
                                 'C' + String.valueOf(payment.Id).right(5);
            
            Map<String, Object> requestBody = new Map<String, Object>{
                'ptco_code' => settings.Partner_Code__c,
                'org_tran_id' => transactionId,
                'cls_code' => settings.Classification_Code__c,
                'giro_no' => settings.Giro_Number__c,
                'pay_meth_type' => 'Q',
                'epay_no' => generateEpayNumber(payment),
                'pay_yymm' => payment.DueDate__c.format('yyyyMM'),
                'noti_issu_type' => '0',
                'etc_type_code' => '00'
            };
            
            GiroApiResponse response = callGiroApi('/v1/payments/link-pay-url', 'POST', requestBody);
            
            // 링크 URL 저장
            if (response.rsp_code == 'A0000') {
                payment.Link_Payment_URL__c = response.link_pay_url;
                update payment;
            }
            
            return response;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error creating link payment URL: ' + e.getMessage());
        }
    }
    
    // 납부 결과 조회
    @AuraEnabled
    public static PaymentResultResponse checkPaymentResult(String transactionId) {
        try {
            Map<String, Object> params = new Map<String, Object>{
                'ptco_code' => settings.Partner_Code__c,
                'org_tran_id' => transactionId
            };
            
            String queryString = '?ptco_code=' + settings.Partner_Code__c + 
                               '&org_tran_id=' + transactionId;
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(API_BASE_URL + '/v1/payments' + queryString);
            request.setMethod('GET');
            request.setHeader('Content-Type', 'application/json; charset=UTF-8');
            request.setHeader('Authorization', 'Bearer ' + getAccessToken());
            
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                PaymentResultResponse result = (PaymentResultResponse) JSON.deserialize(
                    response.getBody(), PaymentResultResponse.class
                );
                
                // 납부 완료시 상태 업데이트
                if (result.rsp_code == 'A0000' && result.pay_info != null) {
                    updatePaymentStatus(transactionId, result);
                }
                
                return result;
            } else {
                throw new AuraHandledException('API Error: ' + response.getStatus());
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Error checking payment result: ' + e.getMessage());
        }
    }
    
    // Helper Methods
    private static GiroApiResponse callGiroApi(String endpoint, String method, Map<String, Object> body) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(API_BASE_URL + endpoint);
        request.setMethod(method);
        request.setHeader('Content-Type', 'application/json; charset=UTF-8');
        request.setHeader('Authorization', 'Bearer ' + getAccessToken());
        
        if (body != null) {
            request.setBody(JSON.serialize(body));
        }
        
        HttpResponse response = http.send(request);
        
        if (response.getStatusCode() == 200) {
            return (GiroApiResponse) JSON.deserialize(response.getBody(), GiroApiResponse.class);
        } else {
            throw new AuraHandledException('API Error: ' + response.getStatus());
        }
    }
    
    private static String generateEpayNumber(PaymentStatus__c payment) {
        // 전자납부번호 생성 로직 (최대 14자리)
        return String.valueOf(payment.Id).right(10).replaceAll('[^0-9]', '');
    }
    
    private static String generateCustomerInquiryNumber(PaymentStatus__c payment) {
        // 고객조회번호 생성 로직 (최대 20자리)
        return Datetime.now().format('yyyyMMdd') + String.valueOf(payment.Id).right(12).replaceAll('[^0-9]', '');
    }
    
    private static String formatBirthdate(Date birthdate) {
        if (birthdate != null) {
            return birthdate.format().substring(2).replace('-', '');
        }
        return '000000';
    }
    
    private static void updatePaymentStatus(String transactionId, PaymentResultResponse result) {
        // Transaction ID로 PaymentStatus 찾아서 업데이트
        List<PaymentStatus__c> payments = [
            SELECT Id, Status__c, Transaction_ID__c
            FROM PaymentStatus__c
            WHERE Transaction_ID__c = :transactionId
            LIMIT 1
        ];
        
        if (!payments.isEmpty()) {
            PaymentStatus__c payment = payments[0];
            payment.Status__c = '완납';
            payment.Payment_Date__c = Datetime.parse(result.pay_info.pay_dtm);
            payment.Payment_Amount__c = Decimal.valueOf(result.pay_info.pay_amt);
            payment.Payment_Bank__c = result.pay_info.bank_name;
            update payment;
        }
    }
}