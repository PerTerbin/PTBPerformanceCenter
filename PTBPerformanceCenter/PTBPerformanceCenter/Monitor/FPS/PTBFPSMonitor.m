//
//  PTBFPSMonitor.m
//  PTBPerformanceCenter
//
//  Created by PerTerbin on 2018/6/3.
//  Copyright © 2018年 PerTerbin. All rights reserved.
//

#import "PTBFPSMonitor.h"

@interface PTBFPSMonitor ()

@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSMutableArray *timestampArray;

@end

@implementation PTBFPSMonitor

+ (instancetype)sharedInstance {
    static PTBFPSMonitor *monitor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        monitor = [[PTBFPSMonitor alloc] init];
    });
    
    return monitor;
}

- (void)startMonitoringWithNoticeBlock:(void(^)(CGFloat value))noticeBlock {
    self.noticeBlock = noticeBlock;

    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(envokeDisplayLink:)];
    _displayLink.paused = NO;
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopMonitoring {
    _displayLink.paused = YES;
    _displayLink = nil;
}

- (void)envokeDisplayLink:(CADisplayLink *)displayLink {
    if (!_timestampArray) {
        _timestampArray = [NSMutableArray arrayWithCapacity:60];
    }

    if (_timestampArray.count == 60) {
        [_timestampArray removeObject:_timestampArray.firstObject];
    }

    [_timestampArray addObject:@(displayLink.timestamp)];

    __block NSInteger fps = 0;
    [_timestampArray enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (displayLink.timestamp - [obj doubleValue] < 1) {
            fps++;
        } else {
            *stop = YES;
        }
    }];

    if (self.noticeBlock) {
        self.noticeBlock((CGFloat)fps);
    }
}

@end

