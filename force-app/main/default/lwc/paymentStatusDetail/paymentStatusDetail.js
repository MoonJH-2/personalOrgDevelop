import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getPaymentStatus from '@salesforce/apex/PaymentStatusController.getPaymentStatus';
import updatePaymentStatus from '@salesforce/apex/PaymentStatusController.updatePaymentStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PaymentStatusDetail extends LightningElement {
    @api recordId;
    @track paymentStatus;
    @track isLoading = false;
    @track error;
    
    wiredPaymentResult;
    
    // 납부 상태 정보 조회
    @wire(getPaymentStatus, { paymentStatusId: '$recordId' })
    wiredPayment(result) {
        this.wiredPaymentResult = result;
        if (result.data) {
            this.paymentStatus = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.paymentStatus = undefined;
            this.showToast('오류', '납부 상태 정보를 불러오는 중 오류가 발생했습니다: ' + this.error.message, 'error');
        }
    }
    
    // 납부 상태 수동 업데이트
    handleUpdateStatus() {
        this.isLoading = true;
        
        updatePaymentStatus({ paymentStatusId: this.recordId })
            .then(result => {
                this.paymentStatus = result;
                this.showToast('성공', '납부 상태가 업데이트되었습니다.', 'success');
            })
            .catch(error => {
                this.error = error;
                this.showToast('오류', '납부 상태 업데이트 중 오류가 발생했습니다: ' + error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // 새로고침
    handleRefresh() {
        this.isLoading = true;
        
        refreshApex(this.wiredPaymentResult)
            .then(() => {
                this.showToast('성공', '납부 상태 정보가 새로고침되었습니다.', 'success');
            })
            .catch(error => {
                this.showToast('오류', '납부 상태 정보 새로고침 중 오류가 발생했습니다: ' + error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // 토스트 메시지 표시
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
    
    // 포매팅된 납부 일자 (getter)
    get formattedPaymentDate() {
        if (!this.paymentStatus?.PaymentDate__c) {
            return '납부 정보 없음';
        }
        
        return new Date(this.paymentStatus.PaymentDate__c).toLocaleDateString('ko-KR', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
    }
    
    // 포매팅된 납부 기한 (getter)
    get formattedDueDate() {
        if (!this.paymentStatus?.DueDate__c) {
            return '기한 정보 없음';
        }
        
        return new Date(this.paymentStatus.DueDate__c).toLocaleDateString('ko-KR', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
    }
    
    // 포매팅된 마지막 확인 일자 (getter)
    get formattedLastCheckedDate() {
        if (!this.paymentStatus?.LastCheckedDate__c) {
            return '확인 정보 없음';
        }
        
        return new Date(this.paymentStatus.LastCheckedDate__c).toLocaleString('ko-KR', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }
    
    // 상태 배지 변형 (getter)
    get statusVariant() {
        if (!this.paymentStatus) return 'default';
        
        switch (this.paymentStatus.Status__c) {
            case '납부완료':
                return 'success';
            case '미납':
                return this.paymentStatus.IsOverdue__c ? 'error' : 'warning';
            case '부분납부':
                return 'info';
            default:
                return 'default';
        }
    }
    
    // 연체 여부 표시 (getter)
    get isOverdue() {
        return this.paymentStatus?.IsOverdue__c || false;
    }
}
