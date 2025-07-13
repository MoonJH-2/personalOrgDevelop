import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getPaymentStatusSummary from '@salesforce/apex/PaymentStatusController.getPaymentStatusSummary';
import updateAllPaymentStatuses from '@salesforce/apex/PaymentStatusController.batchUpdatePaymentStatuses';
import startScheduler from '@salesforce/apex/PaymentStatusController.startScheduler';
import getScheduledJobs from '@salesforce/apex/PaymentStatusController.getScheduledJobs';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PaymentDashboard extends LightningElement {
    @track summaryData;
    @track isLoading = false;
    @track scheduledJobs = [];
    @track error;
    
    wiredSummaryResult;
    wiredJobsResult;
    
    // 납부 상태 요약 정보 조회
    @wire(getPaymentStatusSummary)
    wiredSummary(result) {
        this.wiredSummaryResult = result;
        if (result.data) {
            this.summaryData = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.summaryData = undefined;
            this.showToast('오류', '납부 상태 요약 정보를 불러오는 중 오류가 발생했습니다: ' + this.error.message, 'error');
        }
    }
    
    // 스케줄링된 작업 정보 조회
    @wire(getScheduledJobs)
    wiredScheduledJobs(result) {
        this.wiredJobsResult = result;
        if (result.data) {
            this.scheduledJobs = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.scheduledJobs = [];
            this.showToast('오류', '스케줄링 정보를 불러오는 중 오류가 발생했습니다: ' + this.error.message, 'error');
        }
    }
    
    // 모든 납부 상태 수동 업데이트
    handleUpdateAll() {
        this.isLoading = true;
        
        updateAllPaymentStatuses()
            .then(result => {
                this.showToast('성공', '납부 상태 업데이트가 요청되었습니다.', 'success');
                return refreshApex(this.wiredSummaryResult);
            })
            .catch(error => {
                this.showToast('오류', '납부 상태 업데이트 중 오류가 발생했습니다: ' + error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // 스케줄러 시작
    handleStartScheduler() {
        this.isLoading = true;
        
        startScheduler()
            .then(result => {
                this.showToast('성공', '1시간 간격 납부 상태 업데이트가 예약되었습니다. 작업 ID: ' + result, 'success');
                return refreshApex(this.wiredJobsResult);
            })
            .catch(error => {
                this.showToast('오류', '스케줄러 시작 중 오류가 발생했습니다: ' + error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // 새로고침
    handleRefresh() {
        this.isLoading = true;
        
        Promise.all([
            refreshApex(this.wiredSummaryResult),
            refreshApex(this.wiredJobsResult)
        ])
        .then(() => {
            this.showToast('성공', '데이터가 새로고침되었습니다.', 'success');
        })
        .catch(error => {
            this.showToast('오류', '데이터 새로고침 중 오류가 발생했습니다: ' + error.message, 'error');
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
    
    // 미납 건수 계산 (getter)
    get unpaidCount() {
        return this.summaryData ? this.summaryData.unpaidCount : 0;
    }
    
    // 납부완료 건수 계산 (getter)
    get paidCount() {
        return this.summaryData ? this.summaryData.paidCount : 0;
    }
    
    // 연체 건수 계산 (getter)
    get overdueCount() {
        return this.summaryData ? this.summaryData.overdueCount : 0;
    }
    
    // 스케줄링 상태 (getter)
    get isScheduled() {
        return this.scheduledJobs && this.scheduledJobs.length > 0;
    }
    
    // 다음 실행 시간 (getter)
    get nextRunTime() {
        if (this.scheduledJobs && this.scheduledJobs.length > 0) {
            return this.scheduledJobs[0].NextFireTime;
        }
        return '스케줄링 되지 않음';
    }
}
