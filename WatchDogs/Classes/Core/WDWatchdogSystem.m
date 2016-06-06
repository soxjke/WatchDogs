//
//  WDWatchdogSystem.m
//  WatchDogs
//
//  Created by Petro Korienev on 5/6/16.
//  Copyright (c) 2016 Petro Korienev <soxjke@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#ifdef DEBUG

#import "WDWatchdogSystem.h"
#import "WDWatchdogBuilder.h"
#import "WDWatchdogNSLogReporter.h"
#import "WDWatchdogAsserter.h"

@implementation WDWatchdogSystem

static BOOL isAsserterEnabledByDefault = NO;

+ (void)enableDefaultAssertions {
    isAsserterEnabledByDefault = YES;
}

+ (WDCoreDataWatchdog *)runCoreDataWatchDog {
    WDCoreDataWatchdog *watchdog = [WDWatchdogBuilder<WDCoreDataWatchdog *> createWatchdogOfClass:[WDCoreDataWatchdog class]
                                                                                     withReporter:[WDWatchdogNSLogReporter new]
                                                                                         asserter:isAsserterEnabledByDefault ? [WDWatchdogAsserter new] : nil];
    watchdog.options = WDCoreDataWatchdogMonitorOptionsDefault;
    [watchdog setup];
    return watchdog;
}

@end

#endif
