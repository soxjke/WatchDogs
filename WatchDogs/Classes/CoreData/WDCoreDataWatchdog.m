//
//  WDCoreDataWatchdog.m
//  WatchDogs
//
//  Created by Petro Korienev on 5/1/16.
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

#import "WDCoreDataWatchdog.h"

#ifdef DEBUG

WDCoreDataWatchDogOptions wd_options =  WDCoreDataWatchDogOptionsMonitorContexts |
WDCoreDataWatchDogOptionsMonitorObjects |
WDCoreDataWatchDogOptionsMonitorCoordinators |
WDCoreDataWatchDogOptionsReportMisusages;


@implementation WDCoreDataWatchdog

- (void)setup {
    if (WDCoreDataWatchDogOptionsMonitorContexts & wd_options) {
        [self setupContextMonitoring];
    }
    if (WDCoreDataWatchDogOptionsMonitorObjects & wd_options) {
        [self setupObjectMonitoring];
    }
    if (WDCoreDataWatchDogOptionsMonitorCoordinators & wd_options) {
        [self setupCoordinatorMonitoring];
    }
}

- (void)setupContextMonitoring {
    IMP originalSaveImplementation = NULL;
    IMP originalInitImplementation = NULL;
    Ivar privateQueueIvar = NULL;
    
    Class MOCClass = [NSManagedObjectContext class];
    Method saveMethod = class_getInstanceMethod(MOCClass, @selector(save:));
    Method initMethod = class_getInstanceMethod(MOCClass, @selector(initWithConcurrencyType:));
    
    originalSaveImplementation = method_getImplementation(saveMethod);
    originalInitImplementation = method_getImplementation(initMethod);
    privateQueueIvar = class_getInstanceVariable(MOCClass, "_dispatchQueue");
    
    method_setImplementation(saveMethod, imp_implementationWithBlock(^BOOL(id context, NSError **errorBackPointer) { // SEL is ommited, it's not an error, it's an implementation detail of this runtime functionality
        dispatch_queue_t contextQueue = object_getIvar(context, privateQueueIvar);
        BOOL isAccessCorrect = ((!contextQueue || contextQueue == dispatch_get_main_queue()) && [NSThread isMainThread]) ||
        (dispatch_get_specific(kDTContextKey) == (__bridge void *)context);
        if (WDCoreDataWatchDogOptionsAssertMisusages & wd_options) {
            NSAssert(isAccessCorrect, @"Unwrapped save - CoreData race condition source");
        }
        if (WDCoreDataWatchDogOptionsReportMisusages & wd_options) {
            if (!isAccessCorrect) {
                NSArray *callStack = [NSThread callStackSymbols];
                callStack = [callStack subarrayWithRange:NSMakeRange(1, callStack.count - 1)];
                [self reportWithDescription:@"Unwrapped save - CoreData race condition source"
                                  forObject:context
                                     method:@selector(save:)
                                  callStack:callStack];
            }
        }
        return ((BOOL (*)(id, SEL, NSError**))originalSaveImplementation)(context, @selector(save:), errorBackPointer);
    }));
    
    method_setImplementation(initMethod, imp_implementationWithBlock(^id(id context, NSManagedObjectContextConcurrencyType type) { // SEL is ommited, it's not an error, it's an implementation detail of this runtime functionality
        context = ((id (*)(id, SEL, NSManagedObjectContextConcurrencyType))originalInitImplementation)(context, @selector(initWithConcurrencyType:), type);
        if (type == NSPrivateQueueConcurrencyType) {
            dispatch_queue_t contextQueue = object_getIvar(context, privateQueueIvar);
            dispatch_queue_set_specific(contextQueue, kDTContextKey, (__bridge void *)(context), NULL);
        }
        return context;
    }));
    
}

- (void)setupObjectMonitoring {
    IMP originalResolveInstanceMethodImplementation = NULL;
    Ivar privateQueueIvar = NULL;
    
    Class MOClass   = [NSManagedObject class];
    Class MOCClass  = [NSManagedObjectContext class];
    
    Method resolveMethod = class_getClassMethod(MOClass, @selector(resolveInstanceMethod:));
    privateQueueIvar = class_getInstanceVariable(MOCClass, "_dispatchQueue");
    
    originalResolveInstanceMethodImplementation = method_getImplementation(resolveMethod);
    method_setImplementation(resolveMethod, imp_implementationWithBlock(^BOOL(Class class, SEL selector) { // SEL is ommited, it's not an error, it's an implementation detail of this runtime functionality. This selector is not a resolveInstanceMethod: but it's paramether.
        BOOL result = ((BOOL (*)(Class, SEL, SEL))originalResolveInstanceMethodImplementation)(class, @selector(resolveInstanceMethod:), selector);
        if (result) {
            static NSRegularExpression *regex = nil;
            if (!regex) {
                regex = [NSRegularExpression regularExpressionWithPattern:@"\\:" options:0 error:NULL];
            }
            NSString *selectorString = NSStringFromSelector(selector);
            NSUInteger numberOfArguments = [regex numberOfMatchesInString:selectorString options:0 range:NSMakeRange(0, [selectorString length])];
            Method methodToHook = class_getInstanceMethod(class, selector);
            IMP implementationToHook = method_getImplementation(methodToHook);
            
            char returnType[32];
            const char objectEncoding[] = @encode(id);
            method_getReturnType(methodToHook, returnType, 32);
            
            BOOL isObjectReturned = strstr(returnType, objectEncoding) == returnType;
            
            if (numberOfArguments == 0) {
                void(^verifierBlock)(id, SEL) = ^(id SELF, SEL callingSelector) {
                    id context = ((NSManagedObject *)SELF).managedObjectContext;
                    dispatch_queue_t contextQueue = object_getIvar(context, privateQueueIvar);
                    BOOL isAccessCorrect = ((!contextQueue || contextQueue == dispatch_get_main_queue()) && [NSThread isMainThread]) ||
                    (dispatch_get_specific(kDTContextKey) == (__bridge void *)context);
                    if (WDCoreDataWatchDogOptionsAssertMisusages & wd_options) {
                        NSAssert(isAccessCorrect, @"Unwrapped attribute getter - CoreData race condition source");
                    }
                    if (WDCoreDataWatchDogOptionsReportMisusages & wd_options) {
                        if (!isAccessCorrect) {
                            NSArray *callStack = [NSThread callStackSymbols];
                            callStack = [callStack subarrayWithRange:NSMakeRange(2, callStack.count - 2)];
                            [self reportWithDescription:@"Unwrapped attribute getter - CoreData race condition source"
                                              forObject:SELF
                                                 method:callingSelector
                                              callStack:callStack];
                        }
                    }
                };
                
                if (isObjectReturned) {
                    method_setImplementation(methodToHook, imp_implementationWithBlock(^id(id SELF) {
                        verifierBlock(SELF, selector);
                        return ((id (*)(id, SEL))implementationToHook)(SELF, selector);
                    }));
                }
                else {
                    method_setImplementation(methodToHook, imp_implementationWithBlock(^NSInteger(id SELF) {
                        verifierBlock(SELF, selector);
                        return ((NSInteger (*)(id, SEL))implementationToHook)(SELF, selector);
                    }));
                }
            }
            else if (numberOfArguments == 1) {
                method_setImplementation(methodToHook, imp_implementationWithBlock(^void(id SELF, id argument) {
                    id context = ((NSManagedObject *)SELF).managedObjectContext;
                    dispatch_queue_t contextQueue = object_getIvar(context, privateQueueIvar);
                    BOOL isAccessCorrect = ((!contextQueue || contextQueue == dispatch_get_main_queue()) && [NSThread isMainThread]) ||
                    (dispatch_get_specific(kDTContextKey) == (__bridge void *)context);
                    if (WDCoreDataWatchDogOptionsAssertMisusages & wd_options) {
                        NSAssert(isAccessCorrect, @"Unwrapped attribute setter - CoreData race condition source");
                    }
                    if (WDCoreDataWatchDogOptionsReportMisusages & wd_options) {
                        if (!isAccessCorrect) {
                            NSArray *callStack = [NSThread callStackSymbols];
                            callStack = [callStack subarrayWithRange:NSMakeRange(1, callStack.count - 1)];
                            [self reportWithDescription:@"Unwrapped attribute setter - CoreData race condition source"
                                              forObject:SELF
                                                 method:selector
                                              callStack:callStack];
                        }
                    }
                    return ((void (*)(id, SEL, id))implementationToHook)(SELF, selector, argument);
                }));
            }
            else {
                NSAssert(NO, @"Unexpected selector resolve: %@", selectorString);
            }
        }
        return result;
    }));
}

- (void)setupCoordinatorMonitoring {
    // To be done
}

- (void)reportWithDescription:(NSString *)description
                    forObject:(id)object
                       method:(SEL)method
                    callStack:(NSArray *)callStack {
    NSLog(@"%@", description);
    NSLog(@"Object - %@, selector - %@", object, NSStringFromSelector(method));
    NSLog(@"%@", callStack);
}

@end

#endif