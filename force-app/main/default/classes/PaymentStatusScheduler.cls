/**
 * 납부 상태 업데이트를 정기적으로 실행하는 스케줄러 클래스
 */
public with sharing class PaymentStatusScheduler implements Schedulable {
    
    /**
     * 스케줄된 작업 실행
     */
    public void execute(SchedulableContext sc) {
        // 납부 상태 배치 실행
        Database.executeBatch(new PaymentStatusBatch(), 100); // 한 번에 100개씩 처리
    }
    
    /**
     * 1시간 간격으로 작업 스케줄링
     */
    public static String scheduleHourly() {
        String jobName = 'Payment Status Update - Hourly';
        String cronExp = '0 0 * * * ?'; // 매시 정각에 실행
        
        // 기존 작업이 있으면 삭제
        deleteExistingJob(jobName);
        
        // 새 작업 스케줄링
        PaymentStatusScheduler scheduler = new PaymentStatusScheduler();
        return System.schedule(jobName, cronExp, scheduler);
    }
    
    /**
     * 기존 스케줄 작업 삭제
     */
    private static void deleteExistingJob(String jobName) {
        List<CronTrigger> jobs = [
            SELECT Id 
            FROM CronTrigger 
            WHERE CronJobDetail.Name = :jobName
        ];
        
        if (!jobs.isEmpty()) {
            for (CronTrigger job : jobs) {
                System.abortJob(job.Id);
            }
        }
    }
    
    /**
     * 스케줄링 상태 확인
     */
    public static List<CronTrigger> getScheduledJobs() {
        return [
            SELECT Id, CronJobDetail.Name, CronExpression, State, NextFireTime
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Payment Status Update%'
            ORDER BY NextFireTime ASC
        ];
    }
}
