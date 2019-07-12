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
    
    // 沙盒支付账号：jianshun.zhou@mxrcorp.com 密码：mxrTest@123
    
    /*
     主共享密钥
     
     主共享密钥是用于接收您所有自动续订订阅收据的唯一代码。要测试或提供自动续订订阅，您必须使用主共享密钥或为每个 App 使用一个 App 专用共享密钥。
     
     5dd23ad77f5f4e7b95bd3cd0f365cea3    2017年6月21日之前   可以重新生成
     
     App 专用共享密钥
    
     App 专用共享密钥是用于接收此 App 自动续订订阅收据的唯一代码。如果您需要将此 App 转让给其他开发人员，或者需要将主共享密钥设置为专用，可能需要使用 App 专用共享密钥。
     
     大家叫后台加个验证，如果苹果验证返回21004的话（21004 你提供的共享密钥和账户的共享密钥不一致），就加上password字段去验证，可以成功。
     
     沙盒账号在购买消耗性项目也需要添加password字段验证，非沙盒账号购买非自动续费项目无需验证password
     */
    
    /*
     Read the Receipt Data
     
     To retrieve the receipt data, use the appStoreReceiptURL method of NSBundle to locate the app’s receipt, and then read the entire file. Send this data to your server—as with all interactions with your server, the details are your responsibility.
     
     // Load the receipt from the app bundle.
     NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
     NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
     if (!receipt) {  No local receipt -- handle the error.  }
     
     //base64加密字符串
     NSString *receiptString = [receipt base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];

    ... Send the receipt data to your server ...
     */
    
    /*
     Validating Receipts With the App Store https://developer.apple.com/library/archive/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateRemotely.html
     
     On your server, create a JSON object with the following keys:
     
     Key              Value
     receipt-data  The base64 encoded receipt data.
     
     password      Only used for receipts that contain auto-renewable subscriptions. Your app’s shared secret (a hexadecimal string).
     
     exclude-old-transactions
     
     Only used for iOS7 style app receipts that contain auto-renewable or non-renewing subscriptions. If value is true, response includes only the latest renewal transaction for any subscriptions.
     
     Submit this JSON object as the payload of an HTTP POST request. In the test environment, use https://sandbox.itunes.apple.com/verifyReceipt as the URL. In production, use https://buy.itunes.apple.com/verifyReceipt as the URL.
     
     我们需要把Receipt发送給苹果的苹果的服务器验证用户的购买信息是否真实:
     
     在测试服务器中，发送receipt苹果的测试服务器
     （ https://sandbox.itunes.apple.com/verifyReceipt ）
     验证在正式服务器中(已上线Appstore)，发送receipt到苹果的正式服务器
     （ https://buy.itunes.apple.com/verifyReceipt )
     
     当我们把应用提交给苹果审核时，苹果也是在sandbox环境购买，其产生的购买凭证，也只能连接苹果的测试验证服务器
     所以我们可以先发到苹果的正式服务器验证，如果苹果返回21007，则再一次连接测试服务器进行验证;或者两个同时进行验证，一个通过即可。
   */
    
    /**
     * 21000 App Store不能读取你提供的JSON对象
     * 21002 receipt-data域的数据有问题
     * 21003 receipt无法通过验证
     * 21004 提供的shared secret不匹配你账号中的shared secret
     * 21005 receipt服务器当前不可用
     * 21006 receipt合法，但是订阅已过期。服务器接收到这个状态码时，receipt数据仍然会解码并一起发送
     * 21007 receipt是Sandbox receipt，但却发送至生产系统的验证服务
     * 21008 receipt是生产receipt，但却发送至Sandbox环境的验证服务
     */
    
    NSSet *productIdentifiers = [NSSet setWithObjects:@"MXRAUTOSUBSCRIBE002", nil];
    self.productRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    self.productRequest.delegate = self;
    [self.productRequest start];
}

- (void)handleUnfinishedTransactions {
    DLOG_METHOD
    [MLDefaultQueue.transactions enumerateObjectsUsingBlock:^(SKPaymentTransaction * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        switch (obj.transactionState) {
            case SKPaymentTransactionStatePurchased://购买成功
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
            case SKPaymentTransactionStateDeferred://等待确认，儿童模式需要询问家长同意
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
