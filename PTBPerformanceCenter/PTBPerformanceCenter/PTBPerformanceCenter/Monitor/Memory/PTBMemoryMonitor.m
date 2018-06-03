//
//  PTBMemoryMonitor.m
//  PTBPerformanceCenter
//
//  Created by PerTerbin on 2018/6/3.
//  Copyright © 2018年 PerTerbin. All rights reserved.
//

#import "PTBMemoryMonitor.h"
#import <sys/sysctl.h>
#import <mach/mach.h>

@interface PTBMemoryMonitor()

@property (nonatomic, strong) NSTimer *timer;

@end

@implementation PTBMemoryMonitor

+ (instancetype)sharedInstance {
    static PTBMemoryMonitor *monitor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        monitor = [[PTBMemoryMonitor alloc] init];
    });
    
    return monitor;
}

- (void)startMonitoringWithNoticeBlock:(void(^)(CGFloat value))noticeBlock {
    self.noticeBlock = noticeBlock;
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(noticeMemoryValue) userInfo:nil repeats:YES];
}

- (void)stopMonitoring {
    [_timer invalidate];
    _timer = nil;
}

- (void)noticeMemoryValue {
    if (self.noticeBlock) {
        self.noticeBlock([self usedMemory]);
    }
}

- (CGFloat)usedMemory {
    task_basic_info_data_t taskInfo;
    mach_msg_type_number_t infoCount = TASK_BASIC_INFO_COUNT;
    kern_return_t kernReturn = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&taskInfo, &infoCount);
    
    if (kernReturn != KERN_SUCCESS) {
        return NSNotFound;
    }
    
    CGFloat value = (CGFloat)(taskInfo.resident_size / 1024.0 / 1024.0);
    
    return value;
}

+ (CGFloat)deviceUsedMemory {
    size_t length = 0;
    int mib[6] = {0};
    
    int pagesize = 0;
    mib[0] = CTL_HW;
    mib[1] = HW_PAGESIZE;
    length = sizeof(pagesize);
    if (sysctl(mib, 2, &pagesize, &length, NULL, 0) < 0) {
        return 0;
    }
    
    mach_msg_type_number_t count = HOST_VM_INFO_COUNT;
    
    vm_statistics_data_t vmstat;
    
    if (host_statistics(mach_host_self(), HOST_VM_INFO, (host_info_t)&vmstat, &count) != KERN_SUCCESS) {
        return 0;
    }
    
    int wireMem = vmstat.wire_count * pagesize;
    int activeMem = vmstat.active_count * pagesize;
    
    return (CGFloat)(wireMem + activeMem) / 1024.0 / 1024.0;
}

+ (CGFloat)deviceAvailableMemory {
    vm_statistics64_data_t vmStats;
    mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
    kern_return_t kernReturn = host_statistics(mach_host_self(),
                                               HOST_VM_INFO,
                                               (host_info_t)&vmStats,
                                               &infoCount);
    
    if (kernReturn != KERN_SUCCESS) {
        return NSNotFound;
    }
    
    return (CGFloat)(vm_page_size * (vmStats.free_count + vmStats.inactive_count)  / 1024.0 / 1024.0);
}

@end
