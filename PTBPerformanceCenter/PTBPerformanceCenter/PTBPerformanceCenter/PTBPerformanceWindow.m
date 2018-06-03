//
//  PTBPerformanceWindow.m
//  PTBPerformanceCenter
//
//  Created by PerTerbin on 2018/6/3.
//  Copyright © 2018年 PerTerbin. All rights reserved.
//

#import "PTBPerformanceWindow.h"

@implementation PTBPerformanceWindow

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    BOOL able = [super pointInside:point withEvent:event];
    if ([_delegate respondsToSelector:@selector(pointInside:withEvent:)]) {
        able = [_delegate pointInside:point withEvent:event];
    }
    
    return able;
}

@end
