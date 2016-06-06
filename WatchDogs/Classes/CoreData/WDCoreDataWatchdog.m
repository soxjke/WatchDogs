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

#ifdef DEBUG

#import "WDCoreDataWatchdog.h"
#import <CoreData/CoreData.h>
#import <objc/runtime.h>

const char *kWDContextKey = "wd_context";

@implementation WDCoreDataWatchdog

- (void)setup {
    if (WDCoreDataWatchdogMonitorOptionsContexts & self.options) {
        [self setupContextMonitoring];
    }
    if (WDCoreDataWatchdogMonitorOptionsObjects & self.options) {
        [self setupObjectMonitoring];
    }
    if (WDCoreDataWatchdogMonitorOptionsCoordinators & self.options) {
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
        (dispatch_get_specific(kWDContextKey) == (__bridge void *)context);
        if (!isAccessCorrect) {
            [self raiseErrorCode:WDErrorCodesCoreData.unwrappedSave
                       forObject:context
                          method:@selector(save:)];
        }
        return ((BOOL (*)(id, SEL, NSError**))originalSaveImplementation)(context, @selector(save:), errorBackPointer);
    }));
    
    method_setImplementation(initMethod, imp_implementationWithBlock(^id(id context, NSManagedObjectContextConcurrencyType type) { // SEL is ommited, it's not an error, it's an implementation detail of this runtime functionality
        context = ((id (*)(id, SEL, NSManagedObjectContextConcurrencyType))originalInitImplementation)(context, @selector(initWithConcurrencyType:), type);
        if (type == NSPrivateQueueConcurrencyType) {
            dispatch_queue_t contextQueue = object_getIvar(context, privateQueueIvar);
            dispatch_queue_set_specific(contextQueue, kWDContextKey, (__bridge void *)(context), NULL);
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
                    (dispatch_get_specific(kWDContextKey) == (__bridge void *)context);
                    if (!isAccessCorrect) {
                        [self raiseErrorCode:WDErrorCodesCoreData.unwrappedGetter
                                   forObject:SELF
                                      method:callingSelector];
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
                    (dispatch_get_specific(kWDContextKey) == (__bridge void *)context);
                    if (!isAccessCorrect) {
                        [self raiseErrorCode:WDErrorCodesCoreData.unwrappedSetter
                                   forObject:SELF
                                      method:selector];
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

- (NSString *)errorDomain {
    return WDErrorDomain.coreData;
}

- (NSString *)descriptionForErrorCode:(NSInteger)code {
    return mapCoreDataErrorCodeToDescription(code);
}

@end

#endif