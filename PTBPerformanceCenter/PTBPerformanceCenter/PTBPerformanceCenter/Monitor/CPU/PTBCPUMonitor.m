//
//  PTBCPUMonitor.m
//  PTBPerformanceCenter
//
//  Created by PerTerbin on 2018/6/3.
//  Copyright © 2018年 PerTerbin. All rights reserved.
//

#import "PTBCPUMonitor.h"
#import "mach/mach.h"

@interface PTBCPUMonitor()

@property (nonatomic, strong) NSTimer *timer;

@end

@implementation PTBCPUMonitor

+ (instancetype)sharedInstance {
    static PTBCPUMonitor *monitor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        monitor = [[PTBCPUMonitor alloc] init];
    });
    
    return monitor;
}

- (void)startMonitoringWithNoticeBlock:(void(^)(CGFloat value))noticeBlock {
    self.noticeBlock = noticeBlock;
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(noticeCPUValue) userInfo:nil repeats:YES];
}

- (void)stopMonitoring {
    [_timer invalidate];
    _timer = nil;
}

- (void)noticeCPUValue {
    if (self.noticeBlock) {
        self.noticeBlock([self usedCpu]);
    }
}

- (CGFloat)usedCpu {
    kern_return_t kr = { 0 };
    task_info_data_t tinfo = { 0 };
    mach_msg_type_number_t task_info_count = TASK_INFO_MAX;
    
    kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        return 0.0f;
    }
    
    task_basic_info_t basic_info = { 0 };
    thread_array_t thread_list = { 0 };
    mach_msg_type_number_t thread_count = { 0 };
    
    thread_info_data_t thinfo = { 0 };
    thread_basic_info_t basic_info_th = { 0 };
    
    basic_info = (task_basic_info_t)tinfo;
    
    // get threads in the task
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return 0.0f;
    }
    
    long tot_sec = 0;
    long tot_usec = 0;
    float tot_cpu = 0;
    
    for (int i = 0; i < thread_count; i++) {
        mach_msg_type_number_t thread_info_count = THREAD_INFO_MAX;
        
        kr = thread_info(thread_list[i], THREAD_BASIC_INFO, (thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            return 0.0f;
        }
        
        basic_info_th = (thread_basic_info_t)thinfo;
        if ((basic_info_th->flags & TH_FLAGS_IDLE) == 0) {
            tot_sec = tot_sec + basic_info_th->user_time.seconds + basic_info_th->system_time.seconds;
            tot_usec = tot_usec + basic_info_th->system_time.microseconds + basic_info_th->system_time.microseconds;
            tot_cpu = tot_cpu + basic_info_th->cpu_usage / (float)TH_USAGE_SCALE;
        }
    }
    
    kr = vm_deallocate( mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t) );
    if (kr != KERN_SUCCESS) {
        return 0.0f;
    }
    
    return (CGFloat)tot_cpu * 100;
}

@end
