//
//  PTBBasePerformanceMonitor.m
//  PTBPerformanceCenter
//
//  Created by PerTerbin on 2018/6/3.
//  Copyright © 2018年 PerTerbin. All rights reserved.
//

#import "PTBBasePerformanceMonitor.h"

@implementation PTBBasePerformanceMonitor

- (void)startMonitoringWithNoticeBlock:(void(^)(CGFloat value))noticeBlock {
    // do something in subclass
}

- (void)stopMonitoring {
    // do something in subclass
}

@end
