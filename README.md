# 前言

众所周知，如今的用户变得越来越关心app的体验，开发者必须关注应用性能所带来的用户流失问题。目前危害较大的性能问题主要有：闪退、卡顿、发热、耗电快、网络劫持等，但是做过iOS开发的人都知道，在开发过程中我们没有一个很直观的工具可以实时的知道开发者写出来的代码会不会造成性能问题，虽然Xcode里提供了耗电量检测、内存泄漏检测等工具，但是这些工具使用效果并不理想（如Leak无法发现循环引用造成的内存泄漏）。所以这篇文章主要是介绍一款实时监控app各项性能指标的工具，包括**CPU占用率、内存使用量、内存泄漏、FPS、卡顿检测**，并且会分析造成这些性能问题的原因。

![](https://upload-images.jianshu.io/upload_images/6691810-8f00fe25c492fcfc.gif?imageMogr2/auto-orient/strip)

# CPU

CPU 是移动设备最重要的组成部分，如果开发者写的代码有问题导致CPU负载过高，会导致app使用过程中发生卡顿，同时也可能导致手机发热发烫，耗电过快，严重影响用户体验。
如果想避免CPU负载过高可以通过检测app的CPU使用率，然后可以发现导致CPU过高的代码，并根据具体情况优化。那该如何检测CPU使用率呢？大学期间学过计算机的应该都上过操作系统这门课，学过的都知道线程CPU是调度和分配的基本单位，而应用作为进程运行时，包含了多个不同的线程，这样如果我们能知道app里所有线程占用 CPU 的情况，也就能知道整个app的 CPU 占用率。幸运的是我们在**Mach** 层中 *thread_basic_info* 结构体发现了我们想要的东西，*thread_basic_info* 结构体定义如下：
```
struct thread_basic_info {
        time_value_t    user_time;      /* user run time */
        time_value_t    system_time;    /* system run time */
        integer_t       cpu_usage;      /* scaled cpu usage percentage */
        policy_t        policy;         /* scheduling policy in effect */
        integer_t       run_state;      /* run state (see below) */
        integer_t       flags;          /* various flags (see below) */
        integer_t       suspend_count;  /* suspend count for thread */
        integer_t       sleep_time;     /* number of seconds that thread
                                           has been sleeping */
};
```
其中*cpu_usage*即为该线程的CPU使用率，接下来我们需要获取app的所有线程，iOS内核提供了 *thread_info* API 调用获取指定 task 的线程列表，然后可以通过 *thread_info* API 调用来查询指定线程的信息，*thread_info* API 在 thread_act.h 中定义。
```
kern_return_t task_threads
(
	task_t target_task,
	thread_act_array_t *act_list,
	mach_msg_type_number_t *act_listCnt
);
```
*task_threads* 将 *target_task* 任务中的所有线程保存在 *act_list* 数组中。
现在我们能够取得app的所有线程，并且能够取得每个线程的CPU使用率，这样获取app的CPU使用率的代码就呼之欲出，直接上代码：
```
- (CGFloat)usedCpu {
    kern_return_t kr = { 0 };
    task_info_data_t tinfo = { 0 };
    mach_msg_type_number_t task_info_count = TASK_INFO_MAX;
    
    kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
    if (kr != KERN_SUCCESS) {
        return 0.0f;
    }
    
    task_basic_info_t basic_info = { 0 };
    thread_array_t thread_list = { 0 };
    mach_msg_type_number_t thread_count = { 0 };
    
    thread_info_data_t thinfo = { 0 };
    thread_basic_info_t basic_info_th = { 0 };
    
    basic_info = (task_basic_info_t)tinfo;
    
    // get threads in the task
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return 0.0f;
    }
    
    long tot_sec = 0;
    long tot_usec = 0;
    float tot_cpu = 0;
    
    for (int i = 0; i < thread_count; i++) {
        mach_msg_type_number_t thread_info_count = THREAD_INFO_MAX;
        
        kr = thread_info(thread_list[i], THREAD_BASIC_INFO, (thread_info_t)thinfo, &thread_info_count);
        if (kr != KERN_SUCCESS) {
            return 0.0f;
        }
        
        basic_info_th = (thread_basic_info_t)thinfo;
        if ((basic_info_th->flags & TH_FLAGS_IDLE) == 0) {
            tot_sec = tot_sec + basic_info_th->user_time.seconds + basic_info_th->system_time.seconds;
            tot_usec = tot_usec + basic_info_th->system_time.microseconds + basic_info_th->system_time.microseconds;
            tot_cpu = tot_cpu + basic_info_th->cpu_usage / (float)TH_USAGE_SCALE;
        }
    }
    
    kr = vm_deallocate( mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t) );
    if (kr != KERN_SUCCESS) {
        return 0.0f;
    }
    
    return (CGFloat)tot_cpu * 100;
}
```
有了获取CPU使用率的方法后我们只要再加个定时器去实时查询，并将得到的结果显示在界面上即可：
```
 - (void)startMonitoringWithNoticeBlock:(void(^)(CGFloat value))noticeBlock {
    self.noticeBlock = noticeBlock;
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(noticeCPUValue) userInfo:nil repeats:YES];
}

- (void)noticeCPUValue {
    if (self.noticeBlock) {
        self.noticeBlock([self usedCpu]);
    }
}
```

# Memory

物理内存（RAM）与 CPU 一样都是系统中最稀少的资源，也是最有可能产生竞争的资源，应用内存与性能直接相关 - 通常是以牺牲别的应用为代价。 不像 PC 端，iOS 没有交换空间作为备选资源，这就使得内存资源尤为重要。
## App占用的内存

获取app内存的API同样可以在**Mach**层找到，*mach_task_basic_info* 结构体存储了 Mach task 的内存使用信息，其中 *resident_size* 就是应用使用的物理内存大小，*virtual_size* 是虚拟内存大小。
```
#define MACH_TASK_BASIC_INFO     20         /* always 64-bit basic info */
struct mach_task_basic_info {
        mach_vm_size_t  virtual_size;       /* virtual memory size (bytes) */
        mach_vm_size_t  resident_size;      /* resident memory size (bytes) */
        mach_vm_size_t  resident_size_max;  /* maximum resident memory size (bytes) */
        time_value_t    user_time;          /* total user run time for
                                               terminated threads */
        time_value_t    system_time;        /* total system run time for
                                               terminated threads */
        policy_t        policy;             /* default policy for new threads */
        integer_t       suspend_count;      /* suspend count for task */
};
```
最后得到获取当前 App Memory 的使用情况：
```
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
```
## 设备已使用的内存

```
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
```
##设备可用的内存
```
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
```
# FPS

FPS即屏幕每秒的刷新率，范围在0-60之间，60最佳。FPS是测量用于保存、显示动态视频的信息数量，每秒钟帧数愈多，所显示的动作就会愈流畅，优秀的app都要保证FPS 在 55-60 之间，这样才会给用户流畅的感觉，反之，用户则会感觉到卡顿。
对于FPS的计算网上争议颇多，这边使用的和 *YYKit* 中的 *YYFPSLabel* 原理一样，系统提供了 *CADisplayLink* 这个 API，该API在屏幕每次绘制的时候都会回调，通过接收 *CADisplayLink* 的回调，计算每秒钟收到的回调次数得到屏幕每秒的刷新次数，从而得到 FPS，具体代码如下：
```
- (void)startMonitoringWithNoticeBlock:(void(^)(CGFloat value))noticeBlock {
    self.noticeBlock = noticeBlock;

    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(envokeDisplayLink:)];
    _displayLink.paused = NO;
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
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
```
值得注意的是基于 *CADisplayLink* 实现的 FPS 在生产场景中只有指导意义，不能代表真实的 FPS，因为基于 *CADisplayLink* 实现的 FPS 无法完全检测出当前 Core Animation 的性能情况，它只能检测出当前 RunLoop 的帧率。

# Freezing

## 为什么会出现卡顿

从一个像素到最后真正显示在屏幕上，iPhone 究竟在这个过程中做了些什么？想要了解背后的运作流程，首先需要了解屏幕显示的原理。iOS 上完成图形的显示实际上是 CPU、GPU 和显示器协同工作的结果，具体来说，CPU 负责计算显示内容，包括视图的创建、布局计算、图片解码、文本绘制等，CPU 完成计算后会将计算内容提交给 GPU，GPU 进行变换、合成、渲染后将渲染结果提交到帧缓冲区，当下一次垂直同步信号（简称 V-Sync）到来时，最后显示到屏幕上。下面是显示流程的示意图：

![显示流程示意图](https://upload-images.jianshu.io/upload_images/6691810-896ca635826bd1a4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

上文中提到 V-Sync 是什么，以及为什么要在 iPhone 的显示流程引入它呢？在 iPhone 中使用的是双缓冲机制，即上图中的 FrameBuffer 有两个缓冲区，双缓冲区的引入是为了提升显示效率，但是与此同时，他引入了一个新的问题，当视频控制器还未读取完成时，比如屏幕内容刚显示一半时，GPU 将新的一帧内容提交到帧缓冲区并把两个缓冲区进行交换后，视频控制器就会把新的一帧数据的下半段显示到屏幕上，造成画面撕裂现象，V-Sync 就是为了解决画面撕裂问题，开启 V-Sync 后，GPU 会在显示器发出 V-Sync 信号后，去进行新帧的渲染和缓冲区的更新。

搞清楚了 iPhone 的屏幕显示原理后，下面来看看在 iPhone 上为什么会出现卡顿现象，上文已经提及在图像真正在屏幕显示之前，CPU 和 GPU 需要完成自身的任务，而如果他们完成的时间错过了下一次 V-Sync 的到来（通常是1000/60=16.67ms），这样就会出现显示屏还是之前帧的内容，这就是界面卡顿的原因（离屏渲染就是典型的卡顿问题）。不难发现，无论是 CPU 还是 GPU 引起错过 V-Sync 信号，都会造成界面卡顿。

![卡顿原因示意图](https://upload-images.jianshu.io/upload_images/6691810-80960f97a81d8aaa.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

那如何检测卡顿呢？比较常见的思路是：开辟一条单独的子线程，让这条子线程去实时检测主线程的 RunLoop 情况，实时计算 kCFRunLoopBeforeSources 和 kCFRunLoopAfterWaiting 两个状态之间的耗时是否超过某个阀值，如果超过阈值即认定主线程发生了卡顿。下面是代码实现：
```
static void runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
    MyClass *object = (__bridge MyClass*)info;
    
    // 记录状态值
    object->activity = activity;
    
    // 发送信号
    dispatch_semaphore_t semaphore = moniotr->semaphore;
    dispatch_semaphore_signal(semaphore);
}

- (void)registerObserver
{
    CFRunLoopObserverContext context = {0,(__bridge void*)self,NULL,NULL};
    CFRunLoopObserverRef observer = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                                            kCFRunLoopAllActivities,
                                                            YES,
                                                            0,
                                                            &runLoopObserverCallBack,
                                                            &context);
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
    
    // 创建信号
    semaphore = dispatch_semaphore_create(0);
    
    // 在子线程监控时长
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (YES)
        {
            // 假定连续5次超时50ms认为卡顿(当然也包含了单次超时250ms)
            long st = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 50*NSEC_PER_MSEC));
            if (st != 0)
            {
                if (activity==kCFRunLoopBeforeSources || activity==kCFRunLoopAfterWaiting)
                {
                    if (++timeoutCount < 5)
                        continue;
                    // 检测到卡顿，进行卡顿上报
                }
            }
            timeoutCount = 0;
        }
    });
}              
```
当检测到卡顿后可以进一步收集卡顿现场，如堆栈信息等，关于收集堆栈信息这里就不细说，很多第三方库都有实现，我之前是使用了项目中已经集成的收集崩溃信息的三方库，通过这个库在收集堆栈信息。

# MemoryLeak 

内存泄漏也是造成app内存过高的主要原因，如果iPhone手机的性能都很强，如果一个app会因为内存过高被系统强制杀掉，大部分都是存在内存泄漏。内存泄漏对于开发和测试而言表现得并不明显，如果它不泄漏到一定程度是用户是无法察觉的，但是这也是开发者必须杜绝的一大问题。
## 查找内存泄漏

对于内存泄漏Xcode提供了Leak工具，但是使用过的人都知道Leak无法查出很多泄漏（如循环引用），在这里检测内存泄漏使用的是微信读书团队 Mr.佘 提供的工具 [MLeakFinder](https://github.com/Tencent/MLeaksFinder)。
这里大致讲一下实现原理，当一个VC（或者View）被pop或者被dismiss 2 秒后还没有被销毁则认定该VC（或View）发生了泄漏。那如何知道 2 秒后该对象有没有被释放呢，
```
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self swizzleSEL:@selector(popViewControllerAnimated:) withSEL:@selector(swizzled_popViewControllerAnimated:)];
    });
}
```
通过方法交换将系统的pop方法换掉，然后注入自己的代码实现，当调用pop时会调用 *willDealloc* 方法，该方法实现如下：
```
- (BOOL)willDealloc {
    __weak id weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong id strongSelf = weakSelf;
        [strongSelf assertNotDealloc];
    });
    
    return YES;
}
```
通过弱引用持有自身，并在 2 秒后调用 *assertNotDealloc*, 如果 2 秒内该对象已释放这里的 *weakSelf* 为nil，也就什么都不会发生，反之则认为发生了内存泄漏，进行下一步操作，如弹出警告等。
这里只是大致讲一下 *MLeakFinder* 的原理，详细介绍可以去 [他的博客 ](http://wereadteam.github.io/2016/07/20/MLeaksFinder2/)详细了解。
## 查找循环引用

查找循环引用使用的是 Facebook 开源库 *FBRetainCycleDetector* ,具体也可以去网上查找相关资料，这里就不详细说。

