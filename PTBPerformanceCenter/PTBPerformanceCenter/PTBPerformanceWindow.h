//
//  PTBPerformanceWindow.h
//  PTBPerformanceCenter
//
//  Created by PerTerbin on 2018/6/3.
//  Copyright © 2018年 PerTerbin. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PTBPerformanceWindowDelegate <NSObject>

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event;

@end

@interface PTBPerformanceWindow : UIWindow

@property (nonatomic, weak) id<PTBPerformanceWindowDelegate> delegate;

@end
