//
//  WDConstants.h
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

typedef struct {
    NSString __unsafe_unretained *watchdogs;
    NSString __unsafe_unretained *coreData;
} WDErrorDomainStruct;

extern WDErrorDomainStruct const WDErrorDomain;

typedef struct {
    NSInteger general;
} WDErrorCodesWatchdogsStruct;

extern WDErrorCodesWatchdogsStruct const WDErrorCodesWatchdogs;

typedef struct {
    NSInteger unwrappedSave;
    NSInteger unwrappedGetter;
    NSInteger unwrappedSetter;
} WDErrorCodesCoreDataStruct;

extern WDErrorCodesCoreDataStruct const WDErrorCodesCoreData;
extern NSString *mapCoreDataErrorCodeToDescription(NSInteger errorCode);

extern NSString * const WDErrorStackTraceUserInfoKey;
extern NSString * const WDErrorThreadNameUserInfoKey;
extern NSString * const WDErrorObjectUserInfoKey;
extern NSString * const WDErrorMethodUserInfoKey;

#endif
