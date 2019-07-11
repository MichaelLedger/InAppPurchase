//
//  MLInAppPurchaseManager.h
//  InAppPurchaseDemo
//
//  Created by MountainX on 2019/7/11.
//  Copyright © 2019 MTX Software Technology Co.,Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MLInAppPurchaseManager : NSObject

+ (instancetype)sharedManager;

- (void)startPay;

@end

NS_ASSUME_NONNULL_END
