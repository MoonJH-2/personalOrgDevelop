import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import startScheduler from '@salesforce/apex/PaymentStatusController.startScheduler';
import getScheduledJobs from '@salesforce/apex/PaymentStatusController.getScheduledJobs';
import batchUpdatePaymentStatuses from '@salesforce/apex/PaymentStatusController.batchUpdatePaymentStatuses';

export default class PaymentConfiguration extends LightningElement {
    @track scheduledJobs = [];
    @track error;
    @track isLoading = false;
    @track showSpinner = false;
    
    wiredJobsResult;
    
    // 스케줄링된 작업 정보 조회
    @wire(getScheduledJobs)
    wiredJobs(result) {
        this.wiredJobsResult = result;
        this.isLoading = true;
        
        if (result.data) {
            this.scheduledJobs = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.scheduledJobs = [];
        }
        
        this.isLoading = false;
    }
    
    // 작업 일정 시작
    handleStartScheduler() {
        this.showSpinner = true;
        
        startScheduler()
            .then(result => {
                this.showToast('성공', '납부 상태 업데이트 스케줄러가 시작되었습니다.', 'success');
                return refreshApex(this.wiredJobsResult);
            })
            .catch(error => {
                this.showToast('오류', '스케줄러 시작 중 오류가 발생했습니다: ' + error.message, 'error');
            })
            .finally(() => {
                this.showSpinner = false;
            });
    }
    
    // 지금 업데이트 실행
    handleUpdateNow() {
        this.showSpinner = true;
        
        batchUpdatePaymentStatuses()
            .then(result => {
                if (result) {
                    this.showToast('성공', '납부 상태 업데이트 배치가 시작되었습니다.', 'success');
                } else {
                    this.showToast('오류', '배치 작업 시작에 실패했습니다.', 'error');
                }
            })
            .catch(error => {
                this.showToast('오류', '배치 작업 시작 중 오류가 발생했습니다: ' + error.message, 'error');
            })
            .finally(() => {
                this.showSpinner = false;
            });
    }
    
    // 새로고침 처리
    handleRefresh() {
        this.isLoading = true;
        
        refreshApex(this.wiredJobsResult)
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
    
    // 다음 실행 시간 형식화 (getter)
    get formattedNextFireTime() {
        if (!this.scheduledJobs || this.scheduledJobs.length === 0) {
            return '예정된 작업 없음';
        }
        
        const job = this.scheduledJobs[0];
        if (!job.nextFireTime) {
            return '다음 실행 시간 정보 없음';
        }
        
        return new Date(job.nextFireTime).toLocaleString('ko-KR', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }
    
    // 작업 상태 (getter)
    get jobStatus() {
        if (!this.scheduledJobs || this.scheduledJobs.length === 0) {
            return '작업 없음';
        }
        
        const job = this.scheduledJobs[0];
        return job.state || '상태 정보 없음';
    }
    
    // 실행 횟수 (getter)
    get executionCount() {
        if (!this.scheduledJobs || this.scheduledJobs.length === 0) {
            return 0;
        }
        
        const job = this.scheduledJobs[0];
        return job.timesTriggered || 0;
    }
    
    // 마지막 실행 시간 형식화 (getter)
    get formattedPreviousFireTime() {
        if (!this.scheduledJobs || this.scheduledJobs.length === 0) {
            return '이전 실행 없음';
        }
        
        const job = this.scheduledJobs[0];
        if (!job.previousFireTime) {
            return '이전 실행 시간 정보 없음';
        }
        
        return new Date(job.previousFireTime).toLocaleString('ko-KR', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }
}
