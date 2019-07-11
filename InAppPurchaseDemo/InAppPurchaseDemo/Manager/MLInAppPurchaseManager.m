//
//  MLInAppPurchaseManager.m
//  InAppPurchaseDemo
//
//  Created by MountainX on 2019/7/11.
//  Copyright © 2019 MTX Software Technology Co.,Ltd. All rights reserved.
//

#import "MLInAppPurchaseManager.h"
#import <StoreKit/StoreKit.h>

#define DLOG_METHOD NSLog(@"%s", __func__);

#define MLDefaultQueue [SKPaymentQueue defaultQueue]

@interface MLInAppPurchaseManager () <SKProductsRequestDelegate, SKPaymentTransactionObserver>

@property (nonatomic, strong) SKProductsRequest *productRequest;

@property (copy, nonatomic) NSArray<SKProduct *> *products;

@property (nonatomic, assign) BOOL purchasing;

@end

@implementation MLInAppPurchaseManager

+ (instancetype)sharedManager {
    static MLInAppPurchaseManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[MLInAppPurchaseManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    if (self = [super init]) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        [self loadInSaleProducts];
    }
    return self;
}

#pragma mark - Private Methods
- (void)loadInSaleProducts {
    // MBZ006 MBZ30 MBZ60 MBZ128 MBZ258 MBZ418 MBZ518 消耗型项目(可多次购买)
    // MBZ06 非消耗型项目(一次购买即可)
    // MXRMANUALSUBSCRIBE001 MXRVIP40 MXRVIP68 非续期订阅
    // MXRAUTOSUBSCRIBE001  MXRAUTOSUBSCRIBE002 自动续期订阅
    NSSet *productIdentifiers = [NSSet setWithObjects:@"MXRAUTOSUBSCRIBE002", nil];
    self.productRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    self.productRequest.delegate = self;
    [self.productRequest start];
}

- (void)handleUnfinishedTransactions {
    DLOG_METHOD
    [MLDefaultQueue.transactions enumerateObjectsUsingBlock:^(SKPaymentTransaction * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        switch (obj.transactionState) {
            case SKPaymentTransactionStatePurchased:
                NSLog(@"Transaction is in queue, user has been charged.  Client should complete the transaction.");
                [MLDefaultQueue finishTransaction:obj];
                break;
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"Transaction is being added to the server queue.");
                // Attempting to finish a purchasing transaction will throw an exception.
                break;
            case SKPaymentTransactionStateRestored://恢复购买
                NSLog(@"Transaction was restored from user's purchase history.  Client should complete the transaction.");
                [MLDefaultQueue finishTransaction:obj];
                break;
            case SKPaymentTransactionStateFailed:
                NSLog(@"Transaction was cancelled or failed before being added to the server queue.");
                [MLDefaultQueue finishTransaction:obj];
                break;
            case SKPaymentTransactionStateDeferred:
                NSLog(@"The transaction is in the queue, but its final status is pending external action.");
                [MLDefaultQueue finishTransaction:obj];
                break;
            default:
                break;
        }
    }];
}

#pragma mark - Public Method
- (void)startPay {
    SKProduct *product = [self.products firstObject];
    if (!product) {
        self.purchasing = YES;
        [self loadInSaleProducts];
        return;
    }
    
    [self handleUnfinishedTransactions];
    
    SKPayment *payment = [SKPayment paymentWithProduct:product];
    if (![SKPaymentQueue canMakePayments]) {
        NSLog(@"Device Not support InAppPurchase!");
        return;
    }
    
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    DLOG_METHOD
    self.products = response.products;
    if (self.products.count > 0 && self.purchasing) {
        [self startPay];
        self.purchasing = NO;
    }
}
#pragma mark SKRequestDelegate
- (void)requestDidFinish:(SKRequest *)request {
    DLOG_METHOD
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    DLOG_METHOD
    NSLog(@"%@", error.localizedDescription);
}

#pragma mark - SKPaymentTransactionObserver
// Sent when the transaction array has changed (additions or state changes).  Client should check state of transactions and finish as appropriate.

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    [transactions enumerateObjectsUsingBlock:^(SKPaymentTransaction * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        switch (obj.transactionState) {
            case SKPaymentTransactionStatePurchased:
                NSLog(@"SKPaymentTransactionStatePurchased");
                if (obj.originalTransaction) {//自动续期订阅
                    NSLog(@"自动续期订阅");
                } else {//普通购买或者非续费订阅
                    NSLog(@"普通购买或者非续费订阅");
                }
                break;
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"SKPaymentTransactionStatePurchasing");
                break;
            case SKPaymentTransactionStateRestored:
                NSLog(@"SKPaymentTransactionStateRestored");
                break;
            case SKPaymentTransactionStateDeferred:
                NSLog(@"SKPaymentTransactionStateDeferred");
                break;
            case SKPaymentTransactionStateFailed:
                NSLog(@"SKPaymentTransactionStateFailed");
                break;
            default:
                break;
        }
    }];
}

// Sent when transactions are removed from the queue (via finishTransaction:).
- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    DLOG_METHOD
}

// Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    DLOG_METHOD
}

// Sent when all transactions from the user's purchase history have successfully been added back to the queue.
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    DLOG_METHOD
}

// Sent when the download state has changed.
- (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray<SKDownload *> *)downloads {
    DLOG_METHOD
}

// Sent when a user initiates an IAP buy from the App Store
- (BOOL)paymentQueue:(SKPaymentQueue *)queue shouldAddStorePayment:(SKPayment *)payment forProduct:(SKProduct *)product {
    return YES;
}

@end
