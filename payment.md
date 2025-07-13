
# 납부서비스 (홈 오픈API 오픈지로 납부서비스)

---

## 1. 제휴사 연동 납부  
제휴사의 서비스를 이용하여 고객이 지로 요금을 납부하기 위한 서비스입니다.  
지로 요금의 납부 방법은 조회 납부와 입력 납부로 구분됩니다.  

- **조회 납부**  
  납부할 장표에 인자된 전자납부번호로 고지 내역을 조회하여 납부 하는 방식  
- **입력 납부**  
  고지 내역 조회 절차 없이 장표에 인자된 정보를 직접 입력하여 납부하는 방식  

오픈지로는 납부를 위해 고객으로부터 계좌 비밀번호를 입력받는 모바일 웹페이지를 제공합니다.  
제휴사는 해당 페이지의 URL을 생성하기 위해 오픈지로 시스템이 제공하는 오픈API를 사용합니다.  
URL 수신 이후는 일반 HTTP 요청/응답으로 납부를 진행합니다.

### 1.1 제휴사 연동 **조회납부 결제 URL 생성**  
- **요청 메시지 URL**  
  ```http
  POST https://api.giro.or.kr/v1/payments/giro-inqr-pay-url
  ```  
- **요청 메시지 명세**  
  - **Header**
    - `Content-Type: application/json; charset=UTF-8`
    - `Authorization: Bearer <access_token>`

  - **Body Parameters**

    | 구분       | 파라미터       | 설명                                                         | 필수 | 타입  | 길이 최소 | 길이 최대 |
    |------------|----------------|-------------------------------------------------------------|------|-------|----------|----------|
    | 제휴사정보 | ptco_code      | 제휴사 코드                                                  | Y    | N     | 9        | 9        |
    |            | org_tran_id    | 제휴사 거래고유번호                                          | Y    | AN    | 30       | 30       |
    | 부과정보   | cls_code       | 고지내역 이용기관 분류코드                                   | Y    | N     | 2        | 2        |
    |            | giro_no        | 고지내역 이용기관 지로번호                                   | Y    | N     | 7        | 7        |
    |            | epay_no        | 전자납부번호 (“-” 제외)                                     | Y    | AN    | –        | 14       |
    |            | pay_yymm       | 부과 년월 (YYYYMM)                                           | Y    | N     | 6        | 6        |
    |            | noti_issu_type | 고지 형태                                                   | Y    | N     | 1        | 1        |
    |            | etc_type_code  | 기타 구분 코드                                              | Y    | N     | 2        | 2        |
    | 납부자정보 | pyr_name       | 예금주(납부자) 성명                                          | Y    | AHNS  | –        | 10       |
    |            | pyr_brdd       | 예금주 생년월일/사업자번호                                   | Y    | N     | 6        | 10       |
    |            | bank_code      | 출금 금융기관 코드                                          | Y    | N     | 3        | 3        |
    |            | acnt_no        | 출금 계좌 번호 (“-” 제외)                                   | Y    | N     | –        | 16       |
    |            | pyr_cell_no    | 납부자 연락처 (휴대전화번호)                                | Y    | N     | –        | 14       |
    |            | pyr_ci         | 납부자 CI                                                   | N    | ANS   | –        | 88       |

- **요청 메시지 예제**  
  ```json
  {
      "ptco_code": "901012345",
      "org_tran_id": "951012345T20201021152245C00012",
      "cls_code": "90",
      "giro_no": "1234567",
      "epay_no": "6004744616",
      "pay_yymm": "202009",
      "noti_issu_type": "0",
      "etc_type_code": "00",
      "pyr_name": "김지로",
      "pyr_brdd": "830322",
      "bank_code": "020",
      "acnt_no": "12345678001",
      "pyr_cell_no": "01012345678",
      "pyr_ci": "B9VjDzU/Eo53vZWRylYXFFREh5HIki2aJ11kt0gPf9S34+djci9VH4hPV0TxBXlSFCqVZfdcgdcrkvySRo20Dw=="
  }
  ```

- **응답 메시지 명세**  
  - **Header**
    - `Content-Type: application/json; charset=UTF-8`

  - **Body Parameters**

    | 파라미터         | 설명                                                      | 타입 | 길이 최소 | 길이 최대 |
    |------------------|-----------------------------------------------------------|------|----------|----------|
    | rsp_code         | 응답코드(API)                                             | AN   | 5        | 5        |
    | rsp_msg          | 응답메시지(API)                                           | AHNS | 0        | 300      |
    | org_tran_id      | 요청받은 제휴사 거래고유번호                              | AN   | 30       | 30       |
    | next_redirect_url| 모바일 웹페이지 URL (계좌비밀번호 입력용, 유효시간 10분)     | ANS  | –        | 256      |

- **응답 메시지 예제**  
  ```json
  {
      "rsp_code": "A0000",
      "rsp_msg": "정상 처리",
      "org_tran_id": "951012345T20201021152245C00012",
      "next_redirect_url": "https://www.giro.or.kr/open/apipay.do?T=bad3ca116631ec2415b99a95ecd7545d"
  }
  ```

---

## 1.2 제휴사 연동 **입력납부 결제 URL 생성**  
- **요청 메시지 URL**  
  ```http
  POST https://api.giro.or.kr/v1/payments/giro-inpt-pay-url
  ```
- **요청 메시지 및 예제**  
  구조는 조회납부와 동일하며, 추가 파라미터(`prtf_kind`, `cust_inqr_no`, `pay_amt`)가 포함됩니다.  
- **응답 메시지 예제**  
  ```json
  {
      "rsp_code": "A0000",
      "rsp_msg": "정상 처리",
      "org_tran_id": "951012345T20201021094500C00512",
      "next_redirect_url": "https://www.giro.or.kr/open/apipay.do?T=..."
  }
  ```

---

## 2. 링크납부  
이용기관에서 부과한 요금이 금융회사에 수납되었는지 확인합니다.  
오픈지로 시스템은 모든 결제 채널의 실시간 수납 여부를 제공합니다.

### 2.1 링크납부 URL 생성  
- **요청 메시지 URL**  
  ```http
  POST https://api.giro.or.kr/v1/payments/link-pay-url
  ```
- **요청 메시지 및 예제**  
  조회납부/입력납부 파라미터를 구분(`pay_meth_type`, `prtf_kind` 등)하여 전송합니다.  
- **응답 메시지 예제**  
  ```json
  {
      "rsp_code": "A0000",
      "rsp_msg": "정상 처리",
      "org_tran_id": "951012345T20201021152245C00012",
      "link_pay_url": "https://www.giro.or.kr/open/linkpay.do?T=..."
  }
  ```

---

## 3. 납부결과 조회  
납부가 완료된 내역을 조회합니다. 조회 가능 기간은 납부일로부터 최대 5년입니다.

- **요청 메시지 URL**  
  ```http
  GET https://api.giro.or.kr/v1/payments
  ```
- **요청 메시지 예제**  
  ```json
  {
      "ptco_code": "901012345",
      "org_tran_id": "951012345T20201021152245C00012"
  }
  ```
- **응답 메시지 예제**  
  ```json
  {
      "rsp_code": "A0000",
      "rsp_msg": "정상 처리",
      "bill_info": { /* 고지내역 */ },
      "pay_info": { /* 납부정보 */ }
  }
  ```
