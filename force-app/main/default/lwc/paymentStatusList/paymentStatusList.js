import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';

import createLinkPaymentUrl from '@salesforce/apex/GiroService.createLinkPaymentUrl';
import checkPaymentResult from '@salesforce/apex/GiroService.checkPaymentResult';

const COLUMNS = [
    { 
        label: '회차', 
        fieldName: 'InstallmentNumber__c', 
        type: 'number',
        cellAttributes: { alignment: 'center' }
    },
    { 
        label: '납부금액', 
        fieldName: 'Amount__c', 
        type: 'currency',
        typeAttributes: { currencyCode: 'KRW' }
    },
    { 
        label: '납부예정일', 
        fieldName: 'DueDate__c', 
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        }
    },
    { 
        label: '상태', 
        fieldName: 'Status__c',
        cellAttributes: {
            class: { 
                fieldName: 'statusClass' 
            }
        }
    },
    {
        label: '납부일시',
        fieldName: 'Payment_Date__c',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }
    },
    {
        type: 'action',
        typeAttributes: { 
            rowActions: [
                { label: '조회납부', name: 'inquiry_payment' },
                { label: '입력납부', name: 'input_payment' },
                { label: '링크납부 생성', name: 'create_link' },
                { label: '상태확인', name: 'check_status' }
            ]
        }
    }
];

export default class PaymentStatusList extends LightningElement {
    @api recordId;
    @track paymentStatuses = [];
    @track isLoading = false;
    columns = COLUMNS;
    wiredResult;

    @wire(getRelatedListRecords, {
        parentRecordId: '$recordId',
        relatedListId: 'Payment_status__r',
        fields: [
            'PaymentStatus__c.Id',
            'PaymentStatus__c.Name',
            'PaymentStatus__c.InstallmentNumber__c',
            'PaymentStatus__c.Amount__c',
            'PaymentStatus__c.DueDate__c',
            'PaymentStatus__c.Status__c',
            'PaymentStatus__c.Transaction_ID__c',
            'PaymentStatus__c.Payment_Date__c',
            'PaymentStatus__c.Payment_Amount__c'
        ],
        sortBy: ['PaymentStatus__c.InstallmentNumber__c']
    })
    wiredPaymentStatuses(result) {
        this.wiredResult = result;
        if (result.data) {
            this.paymentStatuses = result.data.records.map(record => {
                const fields = record.fields;
                return {
                    Id: fields.Id.value,
                    Name: fields.Name.value,
                    InstallmentNumber__c: fields.InstallmentNumber__c.value,
                    Amount__c: fields.Amount__c.value,
                    DueDate__c: fields.DueDate__c.value,
                    Status__c: fields.Status__c.value,
                    Transaction_ID__c: fields.Transaction_ID__c.value,
                    Payment_Date__c: fields.Payment_Date__c.value,
                    statusClass: fields.Status__c.value === '완납' ? 
                        'slds-text-color_success' : 'slds-text-color_weak'
                };
            });
        } else if (result.error) {
            this.showToast('Error', 'Error loading payment statuses', 'error');
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        switch (actionName) {
            case 'inquiry_payment':
                this.navigateToPayment(row.Id, 'inquiry');
                break;
            case 'input_payment':
                this.navigateToPayment(row.Id, 'input');
                break;
            case 'create_link':
                this.createLinkPayment(row.Id);
                break;
            case 'check_status':
                this.checkPaymentStatus(row);
                break;
        }
    }

    navigateToPayment(paymentId, type) {
        // PaymentStatus 레코드 페이지로 이동
        window.open(`/lightning/r/PaymentStatus__c/${paymentId}/view`, '_blank');
    }

    createLinkPayment(paymentId) {
        this.isLoading = true;
        createLinkPaymentUrl({ paymentStatusId: paymentId })
            .then(result => {
                if (result.rsp_code === 'A0000') {
                    this.showToast('Success', '링크납부 URL이 생성되었습니다.', 'success');
                    refreshApex(this.wiredResult);
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

    checkPaymentStatus(row) {
        if (!row.Transaction_ID__c) {
            this.showToast('Info', '확인할 거래가 없습니다.', 'info');
            return;
        }

        this.isLoading = true;
        checkPaymentResult({ transactionId: row.Transaction_ID__c })
            .then(result => {
                if (result.rsp_code === 'A0000') {
                    this.showToast('Success', '납부 상태가 업데이트되었습니다.', 'success');
                    refreshApex(this.wiredResult);
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

    handleBatchLinkCreation() {
        // 미납 상태인 모든 항목에 대해 링크납부 URL 생성
        const unpaidStatuses = this.paymentStatuses.filter(ps => ps.Status__c === '미납');
        
        if (unpaidStatuses.length === 0) {
            this.showToast('Info', '미납 항목이 없습니다.', 'info');
            return;
        }

        this.isLoading = true;
        const promises = unpaidStatuses.map(ps => 
            createLinkPaymentUrl({ paymentStatusId: ps.Id })
        );

        Promise.all(promises)
            .then(results => {
                const successCount = results.filter(r => r.rsp_code === 'A0000').length;
                this.showToast(
                    'Success', 
                    `${successCount}개의 링크납부 URL이 생성되었습니다.`, 
                    'success'
                );
                refreshApex(this.wiredResult);
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get totalAmount() {
        return this.paymentStatuses.reduce((sum, ps) => sum + ps.Amount__c, 0);
    }

    get paidAmount() {
        return this.paymentStatuses
            .filter(ps => ps.Status__c === '완납')
            .reduce((sum, ps) => sum + ps.Amount__c, 0);
    }

    get unpaidAmount() {
        return this.totalAmount - this.paidAmount;
    }

    get paymentProgress() {
        return this.totalAmount > 0 ? 
            Math.round((this.paidAmount / this.totalAmount) * 100) : 0;
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