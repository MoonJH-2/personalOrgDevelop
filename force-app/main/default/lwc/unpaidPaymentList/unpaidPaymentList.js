import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getUnpaidPaymentStatuses from '@salesforce/apex/PaymentStatusController.getUnpaidPaymentStatuses';
import updatePaymentStatus from '@salesforce/apex/PaymentStatusController.updatePaymentStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { 
        label: '납부 이름', 
        fieldName: 'recordLink', 
        type: 'url', 
        typeAttributes: { 
            label: { fieldName: 'Name' }, 
            target: '_blank' 
        },
        sortable: true
    },
    { 
        label: '납부 금액', 
        fieldName: 'PayAmount__c', 
        type: 'currency',
        typeAttributes: { 
            currencyCode: 'KRW',
            currencyDisplayAs: 'code',
            minimumFractionDigits: 0
        },
        sortable: true
    },
    { 
        label: '납부 기한', 
        fieldName: 'DueDate__c', 
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'long',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        },
        sortable: true
    },
    { 
        label: '상태', 
        fieldName: 'Status__c', 
        type: 'text',
        sortable: true
    },
    { 
        label: '연체 여부', 
        fieldName: 'IsOverdue__c', 
        type: 'boolean',
        sortable: true
    },
    { 
        label: '마지막 확인 일자', 
        fieldName: 'LastCheckedDate__c', 
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'long',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        },
        sortable: true
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: '상태 업데이트', name: 'update_status' },
                { label: '상세 보기', name: 'view_details' }
            ]
        }
    }
];

export default class UnpaidPaymentList extends LightningElement {
    @track columns = COLUMNS;
    @track data = [];
    @track isLoading = false;
    @track error;
    
    wiredPaymentsResult;
    
    // 미납 납부 상태 목록 조회
    @wire(getUnpaidPaymentStatuses)
    wiredPayments(result) {
        this.wiredPaymentsResult = result;
        this.isLoading = true;
        if (result.data) {
            this.data = this.processRecords(result.data);
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.data = [];
            this.showToast('오류', '미납 납부 목록을 불러오는 중 오류가 발생했습니다: ' + this.error.message, 'error');
        }
        this.isLoading = false;
    }
    
    // 레코드 처리 (URL 필드 추가)
    processRecords(records) {
        return records.map(record => {
            return {
                ...record,
                recordLink: '/' + record.Id
            };
        });
    }
    
    // 행 액션 처리
    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        
        switch (action.name) {
            case 'update_status':
                this.updateStatus(row.Id);
                break;
            case 'view_details':
                this.navigateToRecord(row.Id);
                break;
            default:
                break;
        }
    }
    
    // 납부 상태 업데이트
    updateStatus(recordId) {
        this.isLoading = true;
        
        updatePaymentStatus({ paymentStatusId: recordId })
            .then(result => {
                this.showToast('성공', '납부 상태가 업데이트되었습니다.', 'success');
                return refreshApex(this.wiredPaymentsResult);
            })
            .catch(error => {
                this.showToast('오류', '납부 상태 업데이트 중 오류가 발생했습니다: ' + error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // 레코드 페이지로 이동
    navigateToRecord(recordId) {
        window.open('/' + recordId, '_blank');
    }
    
    // 수동 새로고침
    handleRefresh() {
        this.isLoading = true;
        
        refreshApex(this.wiredPaymentsResult)
            .then(() => {
                this.showToast('성공', '미납 납부 목록이 새로고침되었습니다.', 'success');
            })
            .catch(error => {
                this.showToast('오류', '미납 납부 목록 새로고침 중 오류가 발생했습니다: ' + error.message, 'error');
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
    
    // 데이터 존재 여부 (getter)
    get hasData() {
        return this.data && this.data.length > 0;
    }
}
