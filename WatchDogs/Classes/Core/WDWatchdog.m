//
//  WDWatchdog.m
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

#import "WDWatchdog.h"

@interface WDWatchdog ()

@property (nonatomic, strong, readwrite) id <WDWatchdogReporterProtocol> reporter;
@property (nonatomic, strong, readwrite) id <WDWatchdogAsserterProtocol> asserter;

@end

@implementation WDWatchdog

- (instancetype)initWithReporter:(id<WDWatchdogReporterProtocol>)reporter
                        asserter:(id<WDWatchdogAsserterProtocol>)asserter {
    self = [super init];
    if (self) {
        self.reporter = reporter;
        self.asserter = asserter;
    }
    return self;
}

- (void)setup {
    WDAssertAbstractImplementation
}

- (void)raiseErrorCode:(NSInteger)code
             forObject:(id)object
                method:(SEL)method {
    NSArray *callStack = [NSThread callStackSymbols];
    callStack = [callStack subarrayWithRange:NSMakeRange(2, callStack.count - 2)];
    NSMutableDictionary *userInfo = [NSMutableDictionary new];
    if (object) {
        userInfo[WDErrorObjectUserInfoKey] = object;
    }
    if (method) {
        userInfo[WDErrorMethodUserInfoKey] = NSStringFromSelector(method);
    }
    if ([[NSThread currentThread] name]) {
        userInfo[WDErrorThreadNameUserInfoKey] = [[NSThread currentThread] name];
    }
    if (callStack) {
        userInfo[WDErrorStackTraceUserInfoKey] = callStack;
    }
    userInfo[NSLocalizedDescriptionKey] = [self descriptionForErrorCode:code];
    NSError *error = [NSError errorWithDomain:[self errorDomain] code:code userInfo:userInfo];
    [self.reporter reportWithError:error];
    [self.asserter assertWithError:error];
}

- (NSString *)errorDomain {
    return WDErrorDomain.watchdogs;
}

- (NSString *)descriptionForErrorCode:(NSInteger)code {
    WDAssertAbstractImplementation
    return nil;
}

@end

#endif