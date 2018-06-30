//
//  PTBPerformanceCenter.h
//  PTBPerformanceCenter
//
//  Created by PerTerbin on 2018/6/3.
//  Copyright © 2018年 PerTerbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PTBPerformanceViewController.h"

@interface PTBPerformanceCenter : NSObject

@property (nonatomic, strong, readonly) PTBPerformanceViewController *viewController;

+ (instancetype)defaultCenter;

- (void)enable;
- (void)disable;

@end
