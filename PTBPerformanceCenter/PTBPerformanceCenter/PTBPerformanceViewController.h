//
//  PTBPerformanceViewController.h
//  PTBPerformanceCenter
//
//  Created by PerTerbin on 2018/6/3.
//  Copyright © 2018年 PerTerbin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PTBPerformanceWindow.h"

@interface PTBPerformanceViewController : UIViewController<PTBPerformanceWindowDelegate>

- (void)setFPSValue:(CGFloat)fpsValue;
- (void)setCPUValue:(CGFloat)cpuValue;
- (void)setMemoryValue:(CGFloat)memoryValue;
- (void)findMenoryLeakWithViewStack:(NSArray *)viewStack retainCycle:(NSArray *)retainCycle;

@end
