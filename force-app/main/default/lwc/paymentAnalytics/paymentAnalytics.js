import { LightningElement, wire, track } from 'lwc';
import getPaymentStatusSummary from '@salesforce/apex/PaymentStatusController.getPaymentStatusSummary';
import { refreshApex } from '@salesforce/apex';

export default class PaymentAnalytics extends LightningElement {
    @track summaryData;
    @track chartData;
    @track error;
    @track isLoading = true;
    
    wiredSummaryResult;
    
    // 납부 상태 요약 정보 조회
    @wire(getPaymentStatusSummary)
    wiredSummary(result) {
        this.wiredSummaryResult = result;
        this.isLoading = true;
        
        if (result.data) {
            this.summaryData = result.data;
            this.error = undefined;
            
            // 차트 데이터 생성
            this.prepareChartData();
        } else if (result.error) {
            this.error = result.error;
            this.summaryData = undefined;
            this.chartData = undefined;
        }
        
        this.isLoading = false;
    }
    
    // 차트 데이터 준비
    prepareChartData() {
        if (this.summaryData) {
            this.chartData = {
                labels: ['납부완료', '미납', '연체', '부분납부'],
                datasets: [
                    {
                        label: '건수',
                        data: [
                            this.summaryData.paidCount || 0,
                            this.summaryData.unpaidCount || 0,
                            this.summaryData.overdueCount || 0,
                            this.summaryData.partialCount || 0
                        ],
                        backgroundColor: [
                            'rgba(75, 192, 75, 0.2)',  // 녹색 (납부완료)
                            'rgba(255, 206, 86, 0.2)', // 노란색 (미납)
                            'rgba(255, 99, 132, 0.2)', // 빨간색 (연체)
                            'rgba(54, 162, 235, 0.2)'  // 파란색 (부분납부)
                        ],
                        borderColor: [
                            'rgba(75, 192, 75, 1)',
                            'rgba(255, 206, 86, 1)',
                            'rgba(255, 99, 132, 1)',
                            'rgba(54, 162, 235, 1)'
                        ],
                        borderWidth: 1
                    }
                ]
            };
        }
    }
    
    // 새로고침 처리
    handleRefresh() {
        this.isLoading = true;
        
        refreshApex(this.wiredSummaryResult)
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // 총 건수 계산 (getter)
    get totalCount() {
        if (!this.summaryData) return 0;
        
        return (this.summaryData.paidCount || 0) +
               (this.summaryData.unpaidCount || 0) +
               (this.summaryData.partialCount || 0);
    }
    
    // 총 납부 금액 계산 (getter)
    get totalPaidAmount() {
        return this.summaryData?.totalPaidAmount || 0;
    }
    
    // 총 미납 금액 계산 (getter)
    get totalUnpaidAmount() {
        return this.summaryData?.totalUnpaidAmount || 0;
    }
    
    // 납부율 계산 (getter)
    get paymentRate() {
        if (!this.summaryData || !this.totalCount) return '0';
        
        return ((this.summaryData.paidCount || 0) / this.totalCount * 100).toFixed(1);
    }
    
    // 미납율 계산 (getter)
    get unpaidRate() {
        if (!this.summaryData || !this.totalCount) return '0';
        
        return (((this.summaryData.unpaidCount || 0) + (this.summaryData.overdueCount || 0)) / this.totalCount * 100).toFixed(1);
    }
    
    // 연체율 계산 (getter)
    get overdueRate() {
        if (!this.summaryData || !this.totalCount) return '0';
        
        return ((this.summaryData.overdueCount || 0) / this.totalCount * 100).toFixed(1);
    }
}
