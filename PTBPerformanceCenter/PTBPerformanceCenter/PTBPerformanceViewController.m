//
//  PTBPerformanceViewController.m
//  PTBPerformanceCenter
//
//  Created by PerTerbin on 2018/6/3.
//  Copyright © 2018年 PerTerbin. All rights reserved.
//

#import "PTBPerformanceViewController.h"
#import "PTBPerformanceCenter.h"
#import "PTBMemoryMonitor.h"

#define kGoodColor                  [UIColor colorWithRed:135.0 / 255.0 green:183.0 / 255.0 blue:74.0 / 255.0 alpha:1]
#define kAverageColor               [UIColor colorWithRed:214.0 / 255.0 green:161.0 / 255.0 blue:69.0 / 255.0 alpha:1]
#define kPoorColor                  [UIColor colorWithRed:187.0 / 255.0 green:63.0 / 255.0 blue:55.0 / 255.0 alpha:1]
#define kDefaultColor               [UIColor colorWithRed:54.0 / 255.0 green:57.0 / 255.0 blue:64.0 / 255.0 alpha:1]
#define kCpuIndicatorColor          [UIColor colorWithRed:71.0 / 255.0 green:74.0 / 255.0 blue:81.0 / 255.0 alpha:1]
#define kMonitorValueColor          [UIColor colorWithRed:188.0 / 255.0 green:188.0 / 255.0 blue:188.0 / 255.0 alpha:1]
#define kMonitorTitleColor          [UIColor colorWithRed:20.0 / 255.0 green:20.0 / 255.0 blue:20.0 / 255.0 alpha:1]
#define kMonitorBackgroundColor     [UIColor colorWithRed:39.0 / 255.0 green:42.0 / 255.0 blue:49.0 / 255.0 alpha:1]

#define isiPhoneX (CGSizeEqualToSize(CGSizeMake(375.f, 812.f), [UIScreen mainScreen].bounds.size) || CGSizeEqualToSize(CGSizeMake(812.f, 375.f), [UIScreen mainScreen].bounds.size))


static CGFloat const kPerformanceViewWidth = 150;
static CGFloat const kPerformanceViewHeight = 90;
static CGFloat const kStackViewHeight = 180;

@interface PTBPerformanceViewController ()

@property (nonatomic, strong) UIView *backView;
@property (nonatomic, strong) UIView *monitorBackView;
@property (nonatomic, strong) CAShapeLayer *cpuArcLayer;
@property (nonatomic, strong) CAShapeLayer *fpsArcLayer;
@property (nonatomic, strong) CAShapeLayer *memoryArcLayer;
@property (nonatomic, strong) CATextLayer *cpuTextLayer;
@property (nonatomic, strong) CATextLayer *fpsTextLayer;
@property (nonatomic, strong) CATextLayer *memoryTextLayer;
@property (nonatomic, strong) CAShapeLayer *cpuIndicatorLayer;
@property (nonatomic, strong) UITextView *leakStackView;

@property (nonatomic, assign) CGFloat totalMemory;

@end

@implementation PTBPerformanceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self setupUI];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupUI {
    _backView = [[UIView alloc] initWithFrame:CGRectMake(0, isiPhoneX ? 30 : 0, kPerformanceViewWidth, kPerformanceViewHeight)];
    _backView.backgroundColor = kMonitorBackgroundColor;
    _backView.layer.cornerRadius = 25;
    [_backView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backViewTapped:)]];
    [_backView addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(backViewLongPressed:)]];
    [_backView addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(backViewPaned:)]];
    [self.view addSubview:_backView];
    
    _monitorBackView = [[UIView alloc] initWithFrame:_backView.bounds];
    _monitorBackView.backgroundColor = [UIColor clearColor];
    [_backView addSubview:_monitorBackView];
    
    // FPS
    CATextLayer *fpsTitleLayer = [self createTitleTextLayerWithSuperLayer:_monitorBackView.layer];
    fpsTitleLayer.frame = CGRectMake((_backView.bounds.size.width - 80) / 2, kPerformanceViewHeight * 0.08, 80, 15);
    fpsTitleLayer.string = @"FPS";
    
    CGFloat startAngle = 6.0 / 5.0 * M_PI;
    CAShapeLayer *fpsBackLayer = [CAShapeLayer layer];
    fpsBackLayer.lineWidth = 18;
    fpsBackLayer.strokeColor = kDefaultColor.CGColor;
    fpsBackLayer.fillColor = [UIColor clearColor].CGColor;
    _fpsArcLayer = [CAShapeLayer layer];
    _fpsArcLayer.lineWidth = fpsBackLayer.lineWidth;
    _fpsArcLayer.strokeColor = kPoorColor.CGColor;
    _fpsArcLayer.fillColor = [UIColor clearColor].CGColor;
    
    CGPoint fpsArcCenter = CGPointMake(kPerformanceViewWidth * 0.5, kPerformanceViewHeight * 0.65);
    CGFloat fpsArcRadius = kPerformanceViewHeight * 0.45;
    CGFloat endAngle = startAngle + 3.0 / 5.0 * M_PI;
    UIBezierPath *fpsFullPath = [UIBezierPath bezierPathWithArcCenter:fpsArcCenter radius:fpsArcRadius - _fpsArcLayer.lineWidth / 2 startAngle:startAngle endAngle:endAngle clockwise:true];
    fpsBackLayer.path = fpsFullPath.CGPath;
    _fpsArcLayer.path = fpsFullPath.CGPath;
    [_monitorBackView.layer addSublayer:fpsBackLayer];
    [_monitorBackView.layer addSublayer:_fpsArcLayer];
    
    CGFloat indicatorWidth = 8;
    CGFloat indicatorHeight = fpsArcCenter.y - kPerformanceViewHeight * 0.15;
    _cpuIndicatorLayer = [CAShapeLayer layer];
    _cpuIndicatorLayer.frame = CGRectMake(fpsArcCenter.x, kPerformanceViewHeight * 0.15 + indicatorHeight / 2, indicatorWidth, indicatorHeight);
    _cpuIndicatorLayer.backgroundColor = [UIColor clearColor].CGColor;
    _cpuIndicatorLayer.anchorPoint = CGPointMake(1.0, 1.0);
    _cpuIndicatorLayer.transform = CATransform3DRotate(_cpuIndicatorLayer.transform, M_PI * -0.3 + indicatorWidth / 2 / fpsArcRadius, 0, 0, 1);
    _cpuIndicatorLayer.fillColor = [UIColor colorWithRed:71.0 / 255.0 green:74.0 / 255.0 blue:81.0 / 255.0 alpha:1].CGColor;
    
    UIBezierPath *fpsIndicatorPath = [UIBezierPath bezierPath];
    [fpsIndicatorPath moveToPoint:CGPointMake(indicatorWidth / 2, 0)];
    [fpsIndicatorPath addQuadCurveToPoint:CGPointMake(indicatorWidth / 2, indicatorHeight) controlPoint:CGPointMake(0, indicatorHeight + 4)];
    [fpsIndicatorPath addQuadCurveToPoint:CGPointMake(indicatorWidth / 2, 0) controlPoint:CGPointMake(indicatorWidth, indicatorHeight + 4)];
    _cpuIndicatorLayer.path = fpsIndicatorPath.CGPath;
    
    [_monitorBackView.layer addSublayer:_cpuIndicatorLayer];
    
    _fpsTextLayer = [self createValueTextLayerWithSuperLayer:_monitorBackView.layer];
    _fpsTextLayer.frame = CGRectMake((_backView.bounds.size.width - 80) / 2, kPerformanceViewHeight * 0.25, 80, 15);
    
    // CPU
    CATextLayer *cpuTitleLayer = [self createTitleTextLayerWithSuperLayer:_monitorBackView.layer];
    cpuTitleLayer.frame = CGRectMake(0, kPerformanceViewHeight * 0.35, kPerformanceViewHeight * 0.55, 15);
    cpuTitleLayer.string = @"CPU";
    
    CAShapeLayer *cpuBackLayer = [CAShapeLayer layer];
    cpuBackLayer.lineWidth = 2;
    cpuBackLayer.strokeColor = kDefaultColor.CGColor;
    cpuBackLayer.fillColor = [UIColor clearColor].CGColor;
    _cpuArcLayer = [CAShapeLayer layer];
    _cpuArcLayer.lineWidth = cpuBackLayer.lineWidth;
    _cpuArcLayer.strokeColor = kPoorColor.CGColor;
    _cpuArcLayer.fillColor = [UIColor clearColor].CGColor;
    _cpuArcLayer.lineCap = kCALineJoinRound;
    
    UIBezierPath *cpuFullPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(kPerformanceViewHeight * 0.55 / 2, kPerformanceViewHeight * 0.72) radius:kPerformanceViewHeight * 0.45 / 2 - _cpuArcLayer.lineWidth / 2 startAngle:3.0 / 2.0 * M_PI endAngle:3.0 / 2.0 * M_PI + 2.0 * M_PI clockwise:true];
    cpuBackLayer.path = cpuFullPath.CGPath;
    _cpuArcLayer.path = cpuFullPath.CGPath;
    [_monitorBackView.layer addSublayer:cpuBackLayer];
    [_monitorBackView.layer addSublayer:_cpuArcLayer];
    
    _cpuTextLayer = [self createValueTextLayerWithSuperLayer:_monitorBackView.layer];
    _cpuTextLayer.frame = CGRectMake(0, kPerformanceViewHeight * 0.65, kPerformanceViewHeight * 0.55, 10);
    
    // Memory
    CATextLayer *memoryTitleLayer = [self createTitleTextLayerWithSuperLayer:_monitorBackView.layer];
    memoryTitleLayer.frame = CGRectMake(kPerformanceViewWidth - kPerformanceViewHeight * 0.55, kPerformanceViewHeight * 0.35, kPerformanceViewHeight * 0.55, 15);
    memoryTitleLayer.string = @"Memory";
    
    CAShapeLayer *memoryBackLayer = [CAShapeLayer layer];
    memoryBackLayer.lineWidth = 2;
    memoryBackLayer.strokeColor = kDefaultColor.CGColor;
    memoryBackLayer.fillColor = [UIColor clearColor].CGColor;
    _memoryArcLayer = [CAShapeLayer layer];
    _memoryArcLayer.lineWidth = memoryBackLayer.lineWidth;
    _memoryArcLayer.strokeColor = kPoorColor.CGColor;
    _memoryArcLayer.fillColor = [UIColor clearColor].CGColor;
    _memoryArcLayer.lineCap = kCALineJoinRound;
    
    UIBezierPath *memoryFullPath = [UIBezierPath bezierPathWithArcCenter:CGPointMake(kPerformanceViewWidth - kPerformanceViewHeight * 0.55 / 2, kPerformanceViewHeight * 0.72) radius:kPerformanceViewHeight * 0.45 / 2 - _cpuArcLayer.lineWidth / 2 startAngle:3.0 / 2.0 * M_PI endAngle:3.0 / 2.0 * M_PI + 2.0 * M_PI clockwise:true];
    memoryBackLayer.path = memoryFullPath.CGPath;
    _memoryArcLayer.path = memoryFullPath.CGPath;
    [_monitorBackView.layer addSublayer:memoryBackLayer];
    [_monitorBackView.layer addSublayer:_memoryArcLayer];
    
    _memoryTextLayer = [self createValueTextLayerWithSuperLayer:_monitorBackView.layer];
    _memoryTextLayer.fontSize = 7;
    _memoryTextLayer.frame = CGRectMake(kPerformanceViewWidth - kPerformanceViewHeight * 0.55, kPerformanceViewHeight * 0.59, kPerformanceViewHeight * 0.55, 25);
    
    // Leak
    _leakStackView = [[UITextView alloc] initWithFrame:_backView.bounds];
    _leakStackView.backgroundColor = [UIColor redColor];
    _leakStackView.layer.cornerRadius = _backView.layer.cornerRadius;
    _leakStackView.textColor = [UIColor whiteColor];
    _leakStackView.textAlignment = NSTextAlignmentCenter;
    _leakStackView.text = @"Possibly Memory Leak.";
    _leakStackView.hidden = YES;
    _leakStackView.editable = NO;
    _leakStackView.scrollEnabled = NO;
    _leakStackView.selectable = NO;
    [_leakStackView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(leakStackViewTapped:)]];
    [_leakStackView addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(leakStackViewLongPressed:)]];
    [_backView addSubview:_leakStackView];
}

- (CATextLayer *)createTitleTextLayerWithSuperLayer:(CALayer *)superLayer {
    CATextLayer *titleLayer = [CATextLayer layer];
    titleLayer.foregroundColor = kMonitorValueColor.CGColor;
    titleLayer.fontSize = 7;
    titleLayer.alignmentMode = kCAAlignmentCenter;
    titleLayer.contentsScale = [UIScreen mainScreen].scale;
    [superLayer addSublayer:titleLayer];
    
    return titleLayer;
}

- (CATextLayer *)createValueTextLayerWithSuperLayer:(CALayer *)superLayer {
    CATextLayer *valueLayer = [CATextLayer layer];
    valueLayer.foregroundColor = kMonitorValueColor.CGColor;
    valueLayer.fontSize = 8;
    valueLayer.alignmentMode = kCAAlignmentCenter;
    valueLayer.contentsScale = [UIScreen mainScreen].scale;
    [superLayer addSublayer:valueLayer];
    
    return valueLayer;
}

- (void)showFindMenoryLeakAnimation {
    _monitorBackView.hidden = YES;
    _leakStackView.hidden = NO;
    _leakStackView.frame = _backView.bounds;
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    animation.fromValue = @(1.0);
    animation.toValue = @(0.0);
    animation.duration = 0.15;
    animation.repeatCount = MAXFLOAT;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    [_leakStackView.layer addAnimation:animation forKey:@"FindMenoryLeakAnimation"];
}

- (void)stopFindMenoryLeakAnimation {
    [_leakStackView.layer removeAllAnimations];
}

#pragma mark - Public
- (void)setFPSValue:(CGFloat)fpsValue {
    CGFloat startAngle = 6.0 / 5.0 * M_PI;
    CGFloat endAngle = startAngle + 3.0 / 5.0 * M_PI * fpsValue / 60.0;
    if (fpsValue >= 57) {
        _fpsArcLayer.strokeColor = kGoodColor.CGColor;
    } else if(fpsValue >= 50) {
        _fpsArcLayer.strokeColor = kAverageColor.CGColor;
    } else {
        _fpsArcLayer.strokeColor = kPoorColor.CGColor;
    }
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _fpsArcLayer.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(_backView.bounds.size.width / 2, kPerformanceViewHeight * 0.65) radius:kPerformanceViewHeight * 0.45 - _fpsArcLayer.lineWidth / 2 startAngle:startAngle endAngle:endAngle clockwise:true].CGPath;
    _cpuIndicatorLayer.transform = CATransform3DMakeRotation(endAngle + M_PI / 2 + 4 / kPerformanceViewHeight * 0.6, 0, 0, 1);
    [CATransaction commit];
    _fpsTextLayer.string = [NSString stringWithFormat:@"%.0f", fpsValue];
}

- (void)setCPUValue:(CGFloat)cpuValue {
    CGFloat startAngle = 3.0 / 2.0 * M_PI;
    CGFloat endAngle = startAngle + 2.0 * M_PI * cpuValue / 100.0;
    if (cpuValue <= 20) {
        _cpuArcLayer.strokeColor = kGoodColor.CGColor;
    } else if(cpuValue <= 80) {
        _cpuArcLayer.strokeColor = kAverageColor.CGColor;
    } else {
        _cpuArcLayer.strokeColor = kAverageColor.CGColor;
    }
    
    _cpuTextLayer.string = [NSString stringWithFormat:@"%.2f%%", cpuValue];
    
    _cpuArcLayer.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(kPerformanceViewHeight * 0.55 / 2, kPerformanceViewHeight * 0.72) radius:kPerformanceViewHeight * 0.45 / 2 - _cpuArcLayer.lineWidth / 2 startAngle:startAngle endAngle:endAngle clockwise:true].CGPath;
}

- (void)setMemoryValue:(CGFloat)memoryValue {
    if (_totalMemory == 0) {
        _totalMemory = [PTBMemoryMonitor deviceUsedMemory] + [PTBMemoryMonitor deviceAvailableMemory];
    }
    
    CGFloat startAngle = 3.0 / 2.0 * M_PI;
    CGFloat endAngle = startAngle + 2.0 * M_PI * memoryValue / _totalMemory;
    if (memoryValue <= 200) {
        _memoryArcLayer.strokeColor = kGoodColor.CGColor;
    } else if(memoryValue <= 280) {
        _memoryArcLayer.strokeColor = kAverageColor.CGColor;
    } else {
        _memoryArcLayer.strokeColor = kAverageColor.CGColor;
    }
    
    _memoryArcLayer.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(kPerformanceViewWidth - kPerformanceViewHeight * 0.55 / 2, kPerformanceViewHeight * 0.72) radius:kPerformanceViewHeight * 0.45 / 2 - _cpuArcLayer.lineWidth / 2 startAngle:startAngle endAngle:endAngle clockwise:true].CGPath;
    _memoryTextLayer.string = [NSString stringWithFormat:@"%.2f\nMB\n%.2f%%", memoryValue, memoryValue / _totalMemory * 100.0];
}

- (void)findMenoryLeakWithViewStack:(NSArray *)viewStack retainCycle:(NSArray *)retainCycle {
    [self showFindMenoryLeakAnimation];
    
    NSString *title = @"\n\n\nPossibly Memory Leak.\n\n\n\n";
    NSString *viewStackTitle = @"View Stack:";
    NSString *retainCycleTitle = @"\n\nReatin Cycle:";
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:title attributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];
    [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:viewStackTitle attributes:@{NSForegroundColorAttributeName : [UIColor yellowColor]}]];
    
    __block NSString *viewStackString = @"";
    [viewStack enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        viewStackString = [NSString stringWithFormat:@"%@\n\n%@", viewStackString, obj];
    }];
    [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:viewStackString attributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}]];
    
    [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:retainCycleTitle attributes:@{NSForegroundColorAttributeName : [UIColor yellowColor]}]];
    
    __block NSString *retainCycleString = @"";
    [retainCycle enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        retainCycleString = [NSString stringWithFormat:@"%@\n\n%@", retainCycleString, obj];
    }];
    [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:retainCycleString attributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}]];
    
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentCenter;
    [attributedString addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, attributedString.length)];
    [attributedString addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:10] range:NSMakeRange(0, attributedString.length)];
    
    _leakStackView.attributedText = attributedString;
}

#pragma mark Gesture
- (void)backViewTapped:(UIGestureRecognizer *)recognizer {
    // nothing to do
}

- (void)backViewLongPressed:(UIGestureRecognizer *)recognizer {
    [[PTBPerformanceCenter defaultCenter] disable];
}

- (void)leakStackViewTapped:(UIGestureRecognizer *)recognizer {
    [self stopFindMenoryLeakAnimation];
    
    CGRect stackViewframe = _leakStackView.frame;
    CGRect backViewFrame = _backView.frame;
    if (stackViewframe.size.height == kPerformanceViewHeight) {
        stackViewframe.size.height = kStackViewHeight;
        backViewFrame.size.height = kStackViewHeight;
        _leakStackView.scrollEnabled = YES;
    } else {
        stackViewframe.size.height = kPerformanceViewHeight;
        backViewFrame.size.height = kPerformanceViewHeight;
        _leakStackView.scrollEnabled = NO;
    }
    
    [UIView animateWithDuration:0.2 animations:^{
        _leakStackView.frame = stackViewframe;
        _backView.frame = backViewFrame;
    }];
}

- (void)backViewPaned:(UIPanGestureRecognizer *)recognizer {
    CGPoint point = [recognizer translationInView:self.view];
    CGPoint center = CGPointMake(recognizer.view.center.x + point.x, recognizer.view.center.y + point.y);
    
    if (center.x - recognizer.view.bounds.size.width / 2 < 0) {
        center.x = recognizer.view.bounds.size.width / 2;
    }
    if (center.x + recognizer.view.bounds.size.width / 2 > self.view.bounds.size.width) {
        center.x = self.view.bounds.size.width - recognizer.view.bounds.size.width / 2;
    }
    if (center.y - recognizer.view.bounds.size.height / 2 < 0) {
        center.y = recognizer.view.bounds.size.height / 2;
    }
    if (center.y + recognizer.view.bounds.size.height / 2 > self.view.bounds.size.height) {
        center.y = self.view.bounds.size.height - recognizer.view.bounds.size.height / 2;
    }
    
    if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled) {
        if (center.y - recognizer.view.bounds.size.height / 2 <= 50) {
            center.y = recognizer.view.bounds.size.height / 2;
        } else if (self.view.bounds.size.height - (center.y + recognizer.view.bounds.size.height / 2) <= 50) {
            center.y = self.view.bounds.size.height - recognizer.view.bounds.size.height / 2;
        } else if (center.x >= self.view.bounds.size.width / 2) {
            center.x = self.view.bounds.size.width - recognizer.view.bounds.size.width / 2;
        } else {
            center.x = recognizer.view.bounds.size.width / 2;
        }
        [UIView animateWithDuration:0.15 animations:^{
            recognizer.view.center = center;
        }];
    } else {
        recognizer.view.center = center;
        [recognizer setTranslation:CGPointMake(0, 0) inView:self.view];
    }
}

- (void)leakStackViewLongPressed:(UIGestureRecognizer *)recognizer {
    _monitorBackView.hidden = NO;
    _leakStackView.hidden = YES;
    
    CGRect stackViewframe = _leakStackView.frame;
    CGRect backViewFrame = _backView.frame;
    stackViewframe.size.height = kPerformanceViewHeight;
    backViewFrame.size.height = kPerformanceViewHeight;
    _backView.frame = backViewFrame;
    _leakStackView.frame = stackViewframe;
}

#pragma mark - PTBPerformanceWindowDelegate
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (CGRectContainsPoint(_backView.bounds, [_backView convertPoint:point fromView:self.view])) {
        return YES;
    }
    return NO;
}

@end
