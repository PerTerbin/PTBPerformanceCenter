//
//  PTBPerformanceCenter.m
//  PTBPerformanceCenter
//
//  Created by PerTerbin on 2018/6/3.
//  Copyright © 2018年 PerTerbin. All rights reserved.
//

#import "PTBPerformanceCenter.h"
#import "PTBPerformanceWindow.h"
#import "PTBPerformanceViewController.h"
#import "PTBFPSMonitor.h"
#import "PTBCPUMonitor.h"
#import "PTBMemoryMonitor.h"

@interface PTBPerformanceCenter ()

@property (nonatomic, strong) PTBPerformanceWindow *window;
@property (nonatomic, strong) PTBPerformanceViewController *viewController;

@end

@implementation PTBPerformanceCenter

+ (instancetype)defaultCenter {
    static PTBPerformanceCenter *center;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        center = [[PTBPerformanceCenter alloc] init];
    });
    
    return center;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _viewController = [[PTBPerformanceViewController alloc] init];
        
        _window = [[PTBPerformanceWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _window.rootViewController = _viewController;
        _window.windowLevel = UIWindowLevelAlert + 1000;
        _window.delegate = _viewController;
        _window.hidden = YES;
    }
    
    return self;
}

- (void)enable {
    if (_window.hidden == NO) {
        return;
    }
    
    _window.hidden = NO;
    
    __weak typeof(self) weakSelf = self;
    // FPS
    [[PTBFPSMonitor sharedInstance] startMonitoringWithNoticeBlock:^(CGFloat value) {
        [weakSelf.viewController setFPSValue:value];
    }];
    
    // CPU
    [[PTBCPUMonitor sharedInstance] startMonitoringWithNoticeBlock:^(CGFloat value) {
        [weakSelf.viewController setCPUValue:value];
    }];
    
    // Memory
    [[PTBMemoryMonitor sharedInstance] startMonitoringWithNoticeBlock:^(CGFloat value) {
        [weakSelf.viewController setMemoryValue:value];
    }];
}

- (void)disable {
    if (_window.hidden == YES) {
        return;
    }
    
    _window.hidden = YES;
    
    [[PTBFPSMonitor sharedInstance] stopMonitoring];
    [[PTBCPUMonitor sharedInstance] stopMonitoring];
    [[PTBMemoryMonitor sharedInstance] stopMonitoring];
}

@end
