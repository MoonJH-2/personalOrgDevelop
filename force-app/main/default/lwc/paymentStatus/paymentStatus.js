import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import createInquiryPaymentUrl from '@salesforce/apex/GiroService.createInquiryPaymentUrl';
import createInputPaymentUrl from '@salesforce/apex/GiroService.createInputPaymentUrl';
import createLinkPaymentUrl from '@salesforce/apex/GiroService.createLinkPaymentUrl';
import checkPaymentResult from '@salesforce/apex/GiroService.checkPaymentResult';

const FIELDS = [
    'PaymentStatus__c.Name',
    'PaymentStatus__c.Amount__c',
    'PaymentStatus__c.DueDate__c',
    'PaymentStatus__c.Status__c',
    'PaymentStatus__c.InstallmentNumber__c',
    'PaymentStatus__c.Transaction_ID__c',
    'PaymentStatus__c.Link_Payment_URL__c',
    'PaymentStatus__c.Payment_Date__c',
    'PaymentStatus__c.Payment_Amount__c',
    'PaymentStatus__c.Payment_Bank__c'
];

export default class PaymentStatus extends LightningElement {
    @api recordId;
    @track paymentStatus;
    @track isLoading = false;
    @track paymentUrl = '';
    @track showPaymentModal = false;
    @track linkPaymentUrl = '';
    
    wiredPaymentResult;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredPayment(result) {
        this.wiredPaymentResult = result;
        if (result.data) {
            this.paymentStatus = {
                id: result.data.id,
                name: result.data.fields.Name.value,
                amount: result.data.fields.Amount__c.value,
                dueDate: result.data.fields.DueDate__c.value,
                status: result.data.fields.Status__c.value,
                installmentNumber: result.data.fields.InstallmentNumber__c.value,
                transactionId: result.data.fields.Transaction_ID__c.value,
                linkPaymentUrl: result.data.fields.Link_Payment_URL__c.value,
                paymentDate: result.data.fields.Payment_Date__c.value,
                paymentAmount: result.data.fields.Payment_Amount__c.value,
                paymentBank: result.data.fields.Payment_Bank__c.value
            };
        } else if (result.error) {
            this.showToast('Error', 'Error loading payment status', 'error');
        }
    }

    get isPaymentCompleted() {
        return this.paymentStatus && this.paymentStatus.status === '완납';
    }

    get canMakePayment() {
        return this.paymentStatus && this.paymentStatus.status === '미납';
    }

    get formattedAmount() {
        return this.paymentStatus ? 
            new Intl.NumberFormat('ko-KR', { 
                style: 'currency', 
                currency: 'KRW' 
            }).format(this.paymentStatus.amount) : '';
    }

    get formattedDueDate() {
        if (!this.paymentStatus || !this.paymentStatus.dueDate) return '';
        const date = new Date(this.paymentStatus.dueDate);
        return new Intl.DateTimeFormat('ko-KR').format(date);
    }

    get statusClass() {
        return this.paymentStatus && this.paymentStatus.status === '완납' ? 
            'slds-badge slds-theme_success' : 'slds-badge slds-theme_warning';
    }

    // 조회납부 처리
    handleInquiryPayment() {
        this.isLoading = true;
        createInquiryPaymentUrl({ paymentStatusId: this.recordId })
            .then(result => {
                if (result.rsp_code === 'A0000') {
                    this.paymentUrl = result.next_redirect_url;
                    this.showPaymentModal = true;
                    window.open(result.next_redirect_url, '_blank');
                } else {
                    this.showToast('Error', result.rsp_msg, 'error');
                }
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // 입력납부 처리
    handleInputPayment() {
        this.isLoading = true;
        createInputPaymentUrl({ paymentStatusId: this.recordId })
            .then(result => {
                if (result.rsp_code === 'A0000') {
                    this.paymentUrl = result.next_redirect_url;
                    this.showPaymentModal = true;
                    window.open(result.next_redirect_url, '_blank');
                } else {
                    this.showToast('Error', result.rsp_msg, 'error');
                }
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // 링크납부 URL 생성
    handleCreateLinkPayment() {
        this.isLoading = true;
        createLinkPaymentUrl({ paymentStatusId: this.recordId })
            .then(result => {
                if (result.rsp_code === 'A0000') {
                    this.linkPaymentUrl = result.link_pay_url;
                    this.showToast('Success', '링크납부 URL이 생성되었습니다.', 'success');
                    refreshApex(this.wiredPaymentResult);
                } else {
                    this.showToast('Error', result.rsp_msg, 'error');
                }
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // 납부 결과 확인
    handleCheckPaymentStatus() {
        if (!this.paymentStatus.transactionId) {
            this.showToast('Info', '확인할 거래가 없습니다.', 'info');
            return;
        }

        this.isLoading = true;
        checkPaymentResult({ transactionId: this.paymentStatus.transactionId })
            .then(result => {
                if (result.rsp_code === 'A0000') {
                    this.showToast('Success', '납부 상태가 업데이트되었습니다.', 'success');
                    refreshApex(this.wiredPaymentResult);
                } else {
                    this.showToast('Info', '아직 납부가 완료되지 않았습니다.', 'info');
                }
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // 링크 복사
    handleCopyLink() {
        if (this.paymentStatus.linkPaymentUrl) {
            navigator.clipboard.writeText(this.paymentStatus.linkPaymentUrl)
                .then(() => {
                    this.showToast('Success', '링크가 복사되었습니다.', 'success');
                })
                .catch(() => {
                    this.showToast('Error', '링크 복사에 실패했습니다.', 'error');
                });
        }
    }

    closeModal() {
        this.showPaymentModal = false;
        this.handleCheckPaymentStatus();
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}