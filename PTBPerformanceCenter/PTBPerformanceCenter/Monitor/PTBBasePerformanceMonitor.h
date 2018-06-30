//
//  PTBBasePerformanceMonitor.h
//  PTBPerformanceCenter
//
//  Created by PerTerbin on 2018/6/3.
//  Copyright © 2018年 PerTerbin. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PTBBasePerformanceMonitor : NSObject

@property (nonatomic, copy) void(^noticeBlock)(CGFloat value);

- (void)startMonitoringWithNoticeBlock:(void(^)(CGFloat value))noticeBlock;
- (void)stopMonitoring;

@end
