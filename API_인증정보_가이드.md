# Salesforce API 인증 정보 관리 가이드

이 문서는 Salesforce에서 API 인증 정보(Client ID, Client Secret, Callback URL 등)를 안전하게 저장하고 관리하는 방법에 대해 설명합니다.

## 인증 정보

현재 프로젝트에서 사용하는 API 인증 정보:
- **Client ID**: 0e7b73a1-fe17-431c-8134-c27bedcaaf91
- **Client Secret**: 38185713-9d82-4874-9c2e-66e311457fb0
- **Callback URL**: https://orgfarm-70389b89be-dev-ed.develop.my.salesforce.com/services/authcallback/Giro_Auth_Provider

## 인증 정보 저장 방법

Salesforce에서는 다음과 같은 방법으로 API 인증 정보를 저장할 수 있습니다:

### 1. 명명된 자격 증명(Named Credential) - 권장 방법

Named Credential은 API 인증 정보를 안전하게 저장하고 관리하는 가장 권장되는 방법입니다.

#### 설정 방법:

1. **인증 공급자(Auth Provider) 설정**:
   - Salesforce 설정 > 보안 > 인증 공급자 > 새로 만들기
   - 다음 정보 입력:
     - 공급자 유형: OpenID Connect
     - 이름: Giro_Auth_Provider
     - URL 접미사: Giro_Auth_Provider
     - 소비자 키: 0e7b73a1-fe17-431c-8134-c27bedcaaf91 (Client ID)
     - 소비자 암호: 38185713-9d82-4874-9c2e-66e311457fb0 (Client Secret)
     - 인증 URL: https://api.giro.or.kr/oauth2/authorize (예시, 실제 URL 확인 필요)
     - 토큰 URL: https://api.giro.or.kr/oauth2/token (예시, 실제 URL 확인 필요)
     - 기본 범위: (필요한 범위 지정)
     - 콜백 URL: https://orgfarm-70389b89be-dev-ed.develop.my.salesforce.com/services/authcallback/Giro_Auth_Provider

2. **Named Credential 설정**:
   - Salesforce 설정 > 통합 > Named Credentials > 새로 만들기
   - 다음 정보 입력:
     - 레이블: Giro API
     - 이름: Giro_API
     - URL: https://api.giro.or.kr
     - 신원 유형: Named Principal
     - 인증 프로토콜: OAuth 2.0
     - 인증 공급자: Giro_Auth_Provider
     - 범위: (필요한 범위 지정)

3. **메타데이터 파일 생성**:

   Named Credential을 배포 가능한 메타데이터로 저장하려면 다음 파일을 생성합니다:

   **AuthProvider 메타데이터**:
   ```xml
   <!-- /force-app/main/default/authproviders/Giro_Auth_Provider.authprovider-meta.xml -->
   <?xml version="1.0" encoding="UTF-8"?>
   <AuthProvider xmlns="http://soap.sforce.com/2006/04/metadata">
       <friendlyName>Giro API 인증</friendlyName>
       <includeOrgIdInIdentifier>false</includeOrgIdInIdentifier>
       <providerType>OpenIdConnect</providerType>
       <requireMfa>false</requireMfa>
       <sendAccessTokenInHeader>true</sendAccessTokenInHeader>
       <sendClientCredentialsInHeader>false</sendClientCredentialsInHeader>
       <sendSecretInApis>true</sendSecretInApis>
       <authorizeUrl>https://api.giro.or.kr/oauth2/authorize</authorizeUrl>
       <tokenUrl>https://api.giro.or.kr/oauth2/token</tokenUrl>
       <consumerKey>0e7b73a1-fe17-431c-8134-c27bedcaaf91</consumerKey>
       <consumerSecret>38185713-9d82-4874-9c2e-66e311457fb0</consumerSecret>
       <defaultScopes>(필요한 범위)</defaultScopes>
       <executionUser>(실행 사용자 이름)</executionUser>
   </AuthProvider>
   ```

   **Named Credential 메타데이터**:
   ```xml
   <!-- /force-app/main/default/namedCredentials/Giro_API.namedCredential-meta.xml -->
   <?xml version="1.0" encoding="UTF-8"?>
   <NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
       <allowMergeFieldsInBody>false</allowMergeFieldsInBody>
       <allowMergeFieldsInHeader>false</allowMergeFieldsInHeader>
       <authProvider>Giro_Auth_Provider</authProvider>
       <endpoint>https://api.giro.or.kr</endpoint>
       <generateAuthorizationHeader>true</generateAuthorizationHeader>
       <label>Giro API</label>
       <oauthScope>(필요한 범위)</oauthScope>
       <principalType>NamedUser</principalType>
       <protocol>OAuth</protocol>
   </NamedCredential>
   ```

### 2. 커스텀 설정(Custom Setting)

이미 생성된 `Giro_API_Settings__c` 커스텀 설정을 활용하여 인증 정보를 저장할 수 있습니다.

#### 사용 방법:

1. **데이터 입력**:
   - Salesforce 설정 > 사용자 정의 코드 > 커스텀 설정 > Giro API Settings > 관리
   - "새로 만들기" 클릭하여 기본 조직 수준 값 설정
   - Client ID, Client Secret, Callback URL 등의 필드에 값 입력

2. **Apex 코드에서 접근**:
   ```apex
   Giro_API_Settings__c settings = Giro_API_Settings__c.getOrgDefaults();
   String clientId = settings.Client_ID__c;
   String clientSecret = settings.Client_Secret__c;
   ```

### 3. 커스텀 메타데이터 유형(Custom Metadata Type)

커스텀 메타데이터는 배포 가능한 설정을 저장하는 방법입니다.

#### 설정 방법:

1. **커스텀 메타데이터 유형 생성**:
   - Salesforce 설정 > 사용자 정의 코드 > 커스텀 메타데이터 유형 > 새로 만들기
   - 레이블: Giro API Settings
   - 복수형 레이블: Giro API Settings
   - 객체 이름: Giro_API_Settings

2. **필드 추가**:
   - Client_ID (텍스트 필드)
   - Client_Secret (텍스트 필드)
   - Callback_URL (텍스트 필드)

3. **레코드 생성**:
   - "레코드 관리" 클릭
   - 새 레코드 추가하여 API 인증 정보 입력

4. **Apex에서 접근**:
   ```apex
   Giro_API_Settings__mdt settings = Giro_API_Settings__mdt.getInstance('Default');
   String clientId = settings.Client_ID__c;
   String clientSecret = settings.Client_Secret__c;
   ```

## 코드에서 인증 정보 사용하기

### Named Credential 사용 예시 (권장)

```apex
public with sharing class PaymentAPIClient {
    // API 엔드포인트
    private static final String API_ENDPOINT = 'callout:Giro_API/v1/payments';
    
    public static PaymentResponse getPaymentResult(String ptcoCode, String orgTranId) {
        PaymentResponse response = new PaymentResponse();
        
        try {
            // API 요청 준비
            HttpRequest req = new HttpRequest();
            req.setEndpoint(API_ENDPOINT);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json; charset=UTF-8');
            // Named Credential 사용 시 인증 토큰을 자동으로 처리
            
            // 파라미터 설정 및 요청 처리
            // ...
        } catch (Exception e) {
            // 예외 처리
        }
        
        return response;
    }
}
```

### 커스텀 설정 사용 예시

```apex
public with sharing class PaymentAPIClient {
    // API 엔드포인트
    private static final String API_ENDPOINT = 'https://api.giro.or.kr/v1/payments';
    
    // 액세스 토큰 가져오기
    private static String getAccessToken() {
        Giro_API_Settings__c settings = Giro_API_Settings__c.getOrgDefaults();
        String clientId = settings.Client_ID__c;
        String clientSecret = settings.Client_Secret__c;
        
        // 토큰 발급 로직 구현
        // ...
        
        return 'access_token';
    }
    
    public static PaymentResponse getPaymentResult(String ptcoCode, String orgTranId) {
        // API 호출 로직
        // ...
    }
}
```

## 보안 고려사항

1. **암호화**: Client Secret 등의 중요 정보는 암호화된 형태로 저장
2. **접근 제한**: 인증 정보에 대한 접근을 필요한 사용자만으로 제한
3. **정기적 교체**: 인증 정보는 정기적으로 교체하여 보안 강화
4. **Named Credential 사용**: 가능하면 항상 Named Credential 사용을 권장

## 참고 자료

- [Salesforce Named Credentials 문서](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/intro_named_credentials.htm)
- [Salesforce Auth Providers 문서](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/intro_auth_providers.htm)
- [Salesforce Custom Settings 문서](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/intro_custom_settings.htm)
