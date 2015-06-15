//
//  MainVC.m
//  Smartlock
//
//  Created by RivenL on 15/3/17.
//  Copyright (c) 2015年 RivenL. All rights reserved.
//

#import "MainVC.h"
#import "ScanningQRCodeVC.h"

#import "LockDevicesVC.h"
#import "SendKeyVC.h"
#import "ProfileVC.h"
#import "BuyVC.h"
#import "NotificationMessageVC.h"
#import "MoreVC.h"

#import "RLAlertLabel.h"

#pragma mark -
#import "Message.h"
#import "RecordManager.h"
#import "KeyEntity.h"

#pragma mark -
#import "XMPPManager.h"

#import "RLColor.h"
#import "SoundManager.h"

#import "DeviceManager.h"

@interface MainVC () <UIWebViewDelegate> //<RLCycleScrollViewDelegate>

#pragma mark -
@property (nonatomic, strong) NSString *bannersUrl;
@property (nonatomic, strong) UIWebView *bannersView;

@property (nonatomic, strong) UIScrollView *scrollView;

@property (nonatomic, strong) UIButton *openLockBtn;
@property (nonatomic, strong) UIButton *cupidBtn;
@property (nonatomic, strong) UIImageView *arrow;

@property (nonatomic, strong) UIButton *myDeviceBtn;
@property (nonatomic, strong) UIButton *sendKeyBtn;
@property (nonatomic, strong) UIButton *profileBtn;
@property (nonatomic, strong) UIButton *buyBtn;
@property (nonatomic, strong) UIButton *messageBtn;
@property (nonatomic, strong) UIButton *moreBtn;

@property (nonatomic, strong) UILabel *messageBadgeLabel;

#pragma mark -
@property (nonatomic, strong) NSMutableArray *lockList;

#pragma mark -
@property (assign) BOOL isBannersLoaded;
@property (assign) BOOL isBannersLoading;

@property (assign) BOOL isLockListLoading;

#pragma mark -
@property (nonatomic, strong) NSData *dateData;

#pragma mark -
@property (nonatomic, strong) NSTimer *animationTimer;
@end

@implementation MainVC

- (void)dealloc {
    [self cancelPerformSelector];
    [self.lockList removeAllObjects], self.lockList = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setBackButtonHide:YES];

    self.messageBadgeNumber = [[MyCoreDataManager sharedManager] objectsCountWithKey:@"isRead" contains:@NO withTablename:NSStringFromClass([Message class])];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self setBackButtonHide:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self stopTimer];
    
    [self setBackButtonHide:NO];
    [self.bannersView stopLoading];
    self.bannersView.delegate = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setBackButtonHide:YES];

    self.title = NSLocalizedString(@"yongjiakeji", nil);
    
    [self setupBLCentralManaer];

    [[SoundManager sharedManager] prepareToPlay];
    
    [self setupBackground];
    [self setupBanners];
    [self setupMainView];
    
    [self setupLockList];
    
    [self setupNotification];
}

- (void)setupBLCentralManaer {
    self.manager = [RLBluetooth sharedBluetooth];
}

- (void)setupBackground {
    self.backgroundImage.image = [UIImage imageNamed:@"MainBackground.jpeg"];
//    self.view.backgroundColor = [RLColor colorWithHex:/*0x167CB0*/0x253640];//0xF2DF9B];
}

- (void)setupLockList {
    if(!self.lockList) {
        self.lockList = [NSMutableArray new];
    }
    [self loadLockList];
}

- (void)setupNotification {
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applictionWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveMessage) name:(NSString *)kReceiveMessage object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkReachable:) name:AFNetworkingReachabilityDidChangeNotification object:nil];
}

//- (void)applictionWillEnterForeground:(id)sender {
//    [self readLockPower];
//}

#pragma mark ----------- network status changed
- (void)networkReachable:(id)sender {
    NSNotification *notification = sender;
    NSDictionary *dic = notification.userInfo;
    NSInteger status = [[dic objectForKey:AFNetworkingReachabilityNotificationStatusItem] integerValue];
    if(status > 0) {
        [[XMPPManager sharedXMPPManager] reconnect];
        [self loadBannersRequest];
        
        [self loadLockListFromNet];
        [self updateRecords];
    }
    else {
        [self.bannersView stopLoading];
    }
}

static CGFloat BannerViewHeight = 120.0f;
static NSString *kBannersPage = @"advice.jsp";
- (void)loadBannersRequest {
    if(!self.isBannersLoaded && !self.isBannersLoading) {
        self.isBannersLoading = YES;
        [self.bannersView loadRequest:[self requestForBanners:self.bannersUrl]];
    }
}

- (NSURLRequest *)requestForBanners:(NSString *)aUrl {
    DLog(@"%@", aUrl);
    NSURL *newsUrl = [NSURL URLWithString:[aUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:newsUrl];
    return request;
}

- (void)setupBanners {
    CGFloat ratio = (3.0/1.0);
    self.bannersUrl = [kRLHTTPMobileBaseURLString stringByAppendingString:kBannersPage];
    CGRect frame = self.view.frame;
    BannerViewHeight = frame.size.width/ratio;
    self.bannersView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, BannerViewHeight)];
    self.bannersView.delegate = self;
    self.bannersView.scrollView.bounces = NO;
    [self.view addSubview:self.bannersView];
    [self loadBannersRequest];
}

#define LockSize (120.0f)
- (void)setupMainView {
    if(!self.scrollView) {
        CGRect frame = self.view.frame;
        CGFloat heightOffset = BannerViewHeight;
        
        self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, heightOffset, frame.size.width, frame.size.height-heightOffset)];
        self.scrollView.contentSize = CGSizeMake(frame.size.width, self.scrollView.frame.size.height);
        self.scrollView.showsHorizontalScrollIndicator = NO;
        self.scrollView.showsVerticalScrollIndicator = NO;
        self.scrollView.backgroundColor = [UIColor clearColor];
        self.scrollView.panGestureRecognizer.delaysTouchesBegan = YES;
        [self.view addSubview:self.scrollView];
        
        /**************** central button ***************/
        frame = self.scrollView.frame;
        
        self.cupidBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.cupidBtn.frame = CGRectMake(frame.size.width/2+60, 5, 80, 80);
        [self.cupidBtn setImage:[UIImage imageNamed:@"Cupid.png"] forState:UIControlStateNormal];
        [self.scrollView addSubview:self.cupidBtn];
        
        frame = self.cupidBtn.frame;
        self.arrow = [[UIImageView alloc] initWithFrame:CGRectMake(frame.origin.x+3, frame.origin.y+46, frame.size.width/2, frame.size.height/2)];
        self.arrow.image = [UIImage imageNamed:@"Arrow.png"];
        [self.scrollView addSubview:self.arrow];
        
        frame = self.scrollView.frame;
        heightOffset = self.cupidBtn.frame.origin.y + self.cupidBtn.frame.size.height;
        
        self.openLockBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.openLockBtn.frame = CGRectMake(frame.size.width/2-LockSize, heightOffset-7, LockSize, LockSize+10);
        [self.openLockBtn setImage:[UIImage imageNamed:@"Lock.png"] forState:UIControlStateNormal];
        [self.openLockBtn setImage:[UIImage imageNamed:@"Unlock.png"] forState:UIControlStateSelected];
        [self.openLockBtn addTarget:self action:@selector(clickOpenLockBtn:) forControlEvents:UIControlEventTouchUpInside];
        [self.scrollView addSubview:self.openLockBtn];
        [self.scrollView bringSubviewToFront:self.arrow];
        
//        heightOffset += self.openLockBtn.frame.size.height + 20;
        heightOffset = self.scrollView.frame.size.height - 100;
        CGFloat btnWidth = (frame.size.width - 2*(15+5))/3;
        CGFloat btnWidthOffset = 15;
        CGFloat btnHeight = 40;
        self.myDeviceBtn = [self buttonWithTitle:NSLocalizedString(@"我的设备", nil) selector:@selector(clickMyDeviceBtn:) frame:CGRectMake(btnWidthOffset, heightOffset, btnWidth, btnHeight)];
        [self.scrollView addSubview:self.myDeviceBtn];
        
        btnWidthOffset += 5+btnWidth;
        self.sendKeyBtn = [self buttonWithTitle:NSLocalizedString(@"发送钥匙", nil) selector:@selector(clickSendKeyBtn:) frame:CGRectMake(btnWidthOffset, heightOffset, btnWidth, btnHeight)];
        [self.scrollView addSubview:self.sendKeyBtn];
        
        btnWidthOffset += 5+btnWidth;
        self.profileBtn = [self buttonWithTitle:NSLocalizedString(@"我的资料", nil) selector:@selector(clickProfileBtn:) frame:CGRectMake(btnWidthOffset, heightOffset, btnWidth, btnHeight)];
        [self.scrollView addSubview:self.profileBtn];
        
        heightOffset += btnHeight + 5;
        btnWidthOffset = 15;
        self.buyBtn = [self buttonWithTitle:NSLocalizedString(@"购买", nil) selector:@selector(clickBuyBtn:) frame:CGRectMake(btnWidthOffset, heightOffset, btnWidth, btnHeight)];
        [self.scrollView addSubview:self.buyBtn];
    
        btnWidthOffset += 5+btnWidth;
        self.messageBtn = [self buttonWithTitle:NSLocalizedString(@"消息", nil) selector:@selector(clickMessageBtn:) frame:CGRectMake(btnWidthOffset, heightOffset, btnWidth, btnHeight)];
        [self.scrollView addSubview:self.messageBtn];
        
        self.messageBadgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.messageBtn.frame.size.width-20-2, 2, 20, 20)];
        self.messageBadgeLabel.backgroundColor = [UIColor redColor];
        self.messageBadgeLabel.textColor = [UIColor whiteColor];
        
        self.messageBadgeLabel.textAlignment = NSTextAlignmentCenter;
        self.messageBadgeLabel.font = [UIFont systemFontOfSize:11];
        self.messageBadgeLabel.layer.cornerRadius = 10;
        self.messageBadgeLabel.clipsToBounds = YES;
        self.messageBadgeNumber = 0;
        [self.messageBtn addSubview:self.messageBadgeLabel];
        
        btnWidthOffset += 5+btnWidth;
        self.moreBtn = [self buttonWithTitle:NSLocalizedString(@"更多", nil) selector:@selector(clickMoreBtn:) frame:CGRectMake(btnWidthOffset, heightOffset, btnWidth, btnHeight)];
        [self.scrollView addSubview:self.moreBtn];
    }
}

- (UIButton *)buttonWithTitle:(NSString *)title selector:(SEL)selector frame:(CGRect)frame {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [RLColor colorWithHex:0x81D4EA];//[UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:0.5];
    button.frame = frame;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[RLColor colorWithHex:0x000000 alpha:0.8]/*[RLColor colorWithHex:0xF2E9AE alpha:0.9]*/ forState:UIControlStateNormal];
    button.layer.cornerRadius = 5.0f;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    
    return button;
}

- (void)loadLockList {
    __weak __typeof(self)weakSelf = self;
    [weakSelf.lockList removeAllObjects];
    NSArray *array = [[MyCoreDataManager sharedManager] objectsSortByAttribute:nil withTablename:NSStringFromClass([KeyEntity class])];
    for(KeyEntity *key in array) {
        [weakSelf.lockList addObject:[[KeyModel alloc] initWithKeyEntity:key]];
    }
    [self loadLockListFromNet];
}

- (void)loadLockListFromNet {
    if(self.isLockListLoading)
        return;
    self.isLockListLoading = YES;
    __weak __typeof(self)weakSelf = self;
    [DeviceManager lockList:[User sharedUser].sessionToken withBlock:^(DeviceResponse *response, NSError *error) {
        self.isLockListLoading = NO;
        if(error || !response.list.count) return;

        [weakSelf.lockList removeAllObjects];
        [weakSelf.lockList addObjectsFromArray:response.list];
        [[MyCoreDataManager sharedManager] deleteAllTableObjectInTable:NSStringFromClass([KeyEntity class])];
        for(KeyModel *key in weakSelf.lockList) {
            [[MyCoreDataManager sharedManager] insertUpdateObjectInObjectTable:keyEntityDictionaryFromKeyModel(key) updateOnExistKey:@"keyID" withTablename:NSStringFromClass([KeyEntity class])];
        }
    }];
}

- (void)unlockOpenLockBtn {
    self.openLockBtn.userInteractionEnabled = YES;
    [self stopTimer];
}

- (void)cancelPerformSelector {
    [self stopTimer];
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(unlockOpenLockBtn) object:nil];
}

static int retry = 0;
- (void)clickOpenLockBtn:(UIButton *)button {
    if(!self.lockList.count) {
        [RLHUD hudAlertNoticeWithBody:NSLocalizedString(@"未检测到钥匙!", nil)];
        return;
    }
    retry = 0;
    if(![User getVoiceSwitch]) {
        [[SoundManager sharedManager] playSound:@"SoundOperator.mp3" looping:NO];
    }
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);

    self.openLockBtn.userInteractionEnabled = NO;
    __weak __typeof(self)weakSelf = self;
    [self cancelPerformSelector];
    [self performSelector:@selector(unlockOpenLockBtn) withObject:nil afterDelay:6.f];
    [self startOpenLockAnimation1:button];
    
    [[RLBluetooth sharedBluetooth] scanBLPeripheralsWithCompletionBlock:^(NSArray *peripherals) {
        if(peripherals == nil) {
            [weakSelf stopTimer];
            weakSelf.openLockBtn.userInteractionEnabled = YES;
            return ;
        }
        
        if(!peripherals.count) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [RLHUD hudAlertNoticeWithBody:NSLocalizedString(@"未找到设备,请检查蓝牙设备!", nil)];
            });
            weakSelf.openLockBtn.userInteractionEnabled = YES;
            [weakSelf stopTimer];
            return ;
        }
        
        for(KeyModel *key in self.lockList) {
            if(![key isValid]) {
                continue;
            }

            RLPeripheral *peripheral = [[RLBluetooth sharedBluetooth] peripheralForName:key.keyOwner.address];
            if(peripheral) {
#if 0
                [[RLBluetooth sharedBluetooth] connectPeripheral:peripheral withConnectedBlock:^{
//                    [weakSelf cancelPerformSelector];
                    RLService *service = [[RLBluetooth sharedBluetooth] serviceForUUIDString:@"1910" withPeripheral:peripheral];
                    RLCharacteristic *characteristic = [[RLBluetooth sharedBluetooth] characteristicForNotifyWithService:service];
                    
                    [characteristic setNotifyValue:YES completion:^(NSError *error) {
                        RLCharacteristic *innerCharacteristic = [[RLBluetooth sharedBluetooth] characteristicForUUIDString:@"fff2" withService:service];
//                        [weakSelf openLockWithCharacteristic:innerCharacteristic withKey:key];//lock.pwd];
                        [weakSelf readLockPowerWithCharacteristic:innerCharacteristic withKey:key];
                        
                    } onUpdate:^(NSData *data, NSError *error) {
                        
                        BL_response cmdResponse = responseWithBytes(( Byte *)[data bytes], data.length);
                        Byte crc = CRCOfCMDBytes((Byte *)[data bytes], data.length);
                        
                        RLCharacteristic *innerCharacteristic = [[RLBluetooth sharedBluetooth] characteristicForUUIDString:@"fff2" withService:service];
                        
                        if(cmdResponse.cmd_code == 0x06) {
                            if(cmdResponse.result.result == 0x01) {
                                [RLAlertLabel showInView:self.view withText:NSLocalizedString(@"电池电压过低，请更换电池！", nil) andFrame:CGRectMake(button.frame.origin.x+button.frame.size.width+10, button.frame.origin.y+button.frame.size.height+10, 140, 80)];
                            }
                            else if(cmdResponse.result.result == 0x00) {
                            }
                            else {
                                [RLHUD hudAlertNoticeWithBody:NSLocalizedString(@"管理员失效，请重新配对！", nil)];
                                return ;
                            }
                            [weakSelf openLockWithCharacteristic:innerCharacteristic withKey:key];
                            return ;
                        }
                        
                        if(![weakSelf isLockResponseDataOK:cmdResponse withCRC:crc]) {
                            return ;
                        }
                        
                        if(cmdResponse.cmd_code == 0x02) {
                            if(button.userInteractionEnabled) return ;
                            [weakSelf updateLockTimeWithCharacteristic:innerCharacteristic withKey:key];
                            [weakSelf openLock:key];
                        }
                        else if(cmdResponse.cmd_code == 0x03) {
                            NSData *data = [NSData dataWithBytes:cmdResponse.data length:cmdResponse.data_len];
                            
                            if(![data isEqualToData:self.dateData]) {
                                if(retry++ < 1) {
                                    [weakSelf updateLockTimeWithCharacteristic:innerCharacteristic withKey:key];
                                }
                                [RLHUD hudAlertErrorWithBody:NSLocalizedString(@"时间同步失败！", nil)];
                            }
                        }
                    }];
                }];
#else
                [[RLBluetooth sharedBluetooth] connectPeripheral:peripheral withConnectedBlock:^{
                    RLService *service = [[RLBluetooth sharedBluetooth] serviceForUUIDString:@"1910" withPeripheral:peripheral];
                    RLCharacteristic *characteristic = [[RLBluetooth sharedBluetooth] characteristicForNotifyWithService:service];
                    
                    [characteristic setNotifyValue:YES completion:^(NSError *error) {
                        RLCharacteristic *innerCharacteristic = [[RLBluetooth sharedBluetooth] characteristicForUUIDString:@"fff2" withService:service];
                        [weakSelf openLockWithCharacteristic:innerCharacteristic withKey:key];
                        
                    } onUpdate:^(NSData *data, NSError *error) {
                        
                        BL_response cmdResponse = responseWithBytes(( Byte *)[data bytes], data.length);
                        Byte crc = CRCOfCMDBytes((Byte *)[data bytes], data.length);
                        
                        DLog(@"%@", data);
                        RLCharacteristic *innerCharacteristic = [[RLBluetooth sharedBluetooth] characteristicForUUIDString:@"fff2" withService:service];
                        
                        if(cmdResponse.cmd_code == 0x03) {
                            if(cmdResponse.result.result == 0x01) {
                                [RLHUD hudAlertErrorWithBody:NSLocalizedString(@"时间同步失败！", nil)];
                            }
                            
                            return ;
                        }
                        
                        if(![weakSelf isLockResponseDataOK:cmdResponse withCRC:crc]) {
                            return ;
                        }
                        
                        if(cmdResponse.cmd_code == 0x02) {
                            if(button.userInteractionEnabled) {
                                return ;
                            }
                            
                            Byte powerCode = cmdResponse.data[1];
                            Byte updateTimeCode = cmdResponse.data[0];
                            if(powerCode == 0x01) {
                                [RLAlertLabel showInView:self.view withText:NSLocalizedString(@"电池电压过低，请更换电池！", nil) andFrame:CGRectMake(button.frame.origin.x+button.frame.size.width+10, button.frame.origin.y+button.frame.size.height+10, 140, 80)];
                            }
                            
                            if(updateTimeCode == 0x01) {
                                [RLHUD hudAlertErrorWithBody:NSLocalizedString(@"时间同步失败！", nil)];
                                [weakSelf updateLockTimeWithCharacteristic:innerCharacteristic withKey:key];
                            }
                            
                            [weakSelf openLock:key];
                        }
                    }];
                }];
#endif
                return;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [RLHUD hudAlertNoticeWithBody:NSLocalizedString(@"没有可用的设备或钥匙！", nil)];
            [weakSelf cancelPerformSelector];
            weakSelf.openLockBtn.userInteractionEnabled = YES;
        });
    }];
}

- (void)startOpenLockAnimation1:(UIButton *)button {
    [self startTimer];
}

- (void)startOpenLockAnimation:(UIButton *)button {
    [self stopTimer];
    [self cancelPerformSelector];
    if(![User getVoiceSwitch]) {
        [[SoundManager sharedManager] playSound:@"DoorOpened.mp3" looping:NO];
    }
    button.userInteractionEnabled = NO;
    CGRect orignalFrame = self.arrow.frame;
    __weak __typeof(self)weakSelf = self;
    [UIView animateKeyframesWithDuration:0.5f delay:0.0f options:UIViewAnimationCurveLinear | UIViewAnimationOptionAllowUserInteraction animations:^{
        CGRect frame = self.arrow.frame;
        frame.origin = button.center;
        frame.origin.x += 10;
        frame.origin.y -= 22;
        weakSelf.arrow.frame = frame;
    } completion:^(BOOL finished) {
        if(finished) {
            weakSelf.arrow.frame = orignalFrame;
            weakSelf.arrow.hidden = NO;
            weakSelf.arrow.alpha = 0.0;
            button.selected = !button.selected;
            
            [UIView animateKeyframesWithDuration:0.5f delay:2.5f options:UIViewAnimationCurveLinear | UIViewAnimationOptionAllowUserInteraction animations:^{
                weakSelf.arrow.alpha = 0.95;
            } completion:^(BOOL finished) {
                weakSelf.arrow.alpha = 1.0;
                button.userInteractionEnabled = YES;
                button.selected = !button.selected;
            }];
        }
    }];
}
/*
- (void)rotateCircle:(UIButton *)button {
 
    self.circleView.hidden = !self.circleView.hidden;

    [[SoundManager sharedManager] playSound:@"SoundOperator.mp3" looping:NO];
    CGAffineTransform endAngle = CGAffineTransformMakeRotation(M_PI);
    [UIView animateWithDuration:1.5f delay:0.0f options:UIViewAnimationCurveLinear | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.circleView.transform = endAngle;
        
    } completion:^(BOOL finished) {
        if (finished) {
            
            CGAffineTransform beginAngle = CGAffineTransformMakeRotation(0);
            
            self.circleView.transform = beginAngle;
            self.circleView.hidden = YES;
            button.selected = !button.selected;
            button.userInteractionEnabled = YES;
        }
    }];
}
*/

- (void)clickMyDeviceBtn:(UIButton *)button {
    LockDevicesVC *vc = [LockDevicesVC new];
    vc.mainVC = self;
    [vc.table addObjectFromArray:self.lockList];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)clickSendKeyBtn:(UIButton *)button {
    BOOL isAdmin = NO;
    for(KeyModel *key in self.lockList) {
        if(key.userType == 0) {
            isAdmin = YES;
            break;
        }
    }
    
    if(!isAdmin) {
        [RLHUD hudAlertWarningWithBody:NSLocalizedString(@"你并非管理员！", nil)];
        return;
    }
    SendKeyVC *vc = [[SendKeyVC alloc] init];
    vc.title = NSLocalizedString(@"发送钥匙", nil);
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)clickProfileBtn:(UIButton *)button {
    ProfileVC *vc = [[ProfileVC alloc] initWithStyle:UITableViewStyleGrouped];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)clickBuyBtn:(UIButton *)button {
    BuyVC *vc = [[BuyVC alloc] init];
    vc.title = NSLocalizedString(@"购买", nil);
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)clickMessageBtn:(UIButton *)button {
    [[MyCoreDataManager sharedManager] updateObjectsInObjectTable:@{@"isRead" : @YES} withKey:@"isRead" contains:@NO withTablename:NSStringFromClass([Message class])];

    self.messageBadgeNumber = 0;

    NotificationMessageVC *vc = [[NotificationMessageVC alloc] initWithStyle:UITableViewStyleGrouped];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)clickMoreBtn:(UIButton *)button {
    MoreVC *vc = [MoreVC new];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - 
- (void)startTimer {
    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateTimer) userInfo:nil repeats:YES];
}

- (void)updateTimer {
    self.arrow.hidden = !self.arrow.hidden;
}

- (void)stopTimer {
    [self.animationTimer invalidate], self.animationTimer = nil;
    self.arrow.hidden = NO;
}

#pragma mark - 
- (void)receiveMessage {
    self.messageBadgeNumber ++;
    [self loadLockListFromNet];
}

#pragma mark - public methods
#pragma mark -
- (void)addKey:(KeyModel *)key {
    if(!key )
        return;
    [self.lockList addObject:key ];
}

- (void)removeKey:(KeyModel *)key {
    if(!key)
        return;
    [self.lockList removeObject:key];
}

- (void)setMessageBadgeNumber:(NSInteger)messageBadgeNumber {
    _messageBadgeNumber = messageBadgeNumber;

    if(messageBadgeNumber == 0) {
        self.messageBadgeLabel.hidden = YES;
        
        return;
    }
    
    self.messageBadgeLabel.hidden = NO;
    self.messageBadgeLabel.text = [NSString stringWithFormat:@"%li", (long)messageBadgeNumber];
}

#pragma mark - private methods
- (void)openLock:(KeyModel *)key {
    [self cancelPerformSelector];
    [self performSelectorOnMainThread:@selector(startOpenLockAnimation:) withObject:self.openLockBtn waitUntilDone:YES];
    if(key.type == kKeyTypeTimes) {
        if(key.validCount > 0) {
            --key.validCount;
            
            [[MyCoreDataManager sharedManager] updateObjectsInObjectTable:@{@"useCount":[NSNumber numberWithInteger:key.validCount]} withKey:@"keyID" contains:[NSNumber numberWithInteger:key.ID] withTablename:NSStringFromClass([KeyEntity class])];
        }
    }
    NSDictionary *record = createOpenLockRecord(key.ID, key.lockID);
    [[MyCoreDataManager sharedManager] insertObjectInObjectTable:record withTablename:NSStringFromClass([OpenLockRecord class])];
    [self updateRecords];
}

- (void)updateRecords {
    /*remove invalid records*/
    [RecordManager updateRecordsWithBlock:^(BOOL success) {
        [self loadLockListFromNet];
        
        for(KeyModel *key in self.lockList) {
            if(![key isValid]) {
                [RecordManager removeRecordsWithKeyID:(long long)key.ID];
                
                continue;
            }
        }
    }];
}

/**
 *  开锁
 *
 *  @param characteristic characteristic
 *  @param key            key
 */
- (void)openLockWithCharacteristic:(RLCharacteristic *)characteristic withKey:(KeyModel *)key {
    
    int len = 0;
    long long data = key.keyOwner.pwd;
    
    Byte *dateData = nil;
    
    Byte cmdMode = 0x00; //管理员
    if(key.userType == kUserTypeCommon) {
        cmdMode = 0x01; //非管理员
        dateData = dateToBytes(&len, key.invalidDate.length? key.invalidDate: @"2015-12-18");
    }
    else {
        dateData = dateNowToBytes(&len);
        self.dateData = [NSData dataWithBytes:dateData length:len];
    }
    
    int size = sizeof(data)+len;
    Byte *tempData = calloc(size, sizeof(Byte));
    memcpy(tempData, dateData, len);
    
    Byte *temp = (Byte *)&(data);
    for(NSInteger j = len; j<size; j++) {
        tempData[j] = temp[j-len];
    }
    
    NSData *writeData = [NSData dataWithBytes:tempData length:size];
    free(tempData);
    
    [[RLBluetooth sharedBluetooth] writeDataToCharacteristic:characteristic cmdCode:0x02 cmdMode:cmdMode withDatas:writeData];
}

/**
 *  同步时间
 *
 *  @param characteristic characteristic
 */
- (void)updateLockTimeWithCharacteristic:(RLCharacteristic *)characteristic withKey:(KeyModel *)key {
    if(!(key.userType == kUserTypeAdmin))
        return;
    int len = 0;
    long long data = key.keyOwner.pwd;
    Byte *dateData = dateNowToBytes(&len);
    self.dateData = [NSData dataWithBytes:dateData length:len];
    int size = sizeof(data)+len;
    Byte *tempData = calloc(size, sizeof(Byte));
    memcpy(tempData, dateData, len);
    
    Byte *temp = (Byte *)&(data);
    for(NSInteger j = len; j<size; j++) {
        tempData[j] = temp[j-len];
    }
    
    NSData *writeData = [NSData dataWithBytes:tempData length:size];
    free(tempData);
    
    Byte cmdMode = 0x01; //0x01->设置 0x00->读取
    
    [[RLBluetooth sharedBluetooth] writeDataToCharacteristic:characteristic cmdCode:0x03 cmdMode:cmdMode withDatas:writeData];
}

- (void)readLockPowerWithCharacteristic:(RLCharacteristic *)characteristic withKey:(KeyModel *)key {
    long long data = key.keyOwner.pwd;
    NSData *writeData = [NSData dataWithBytes:&data length:sizeof(long long)];
    Byte cmdMode = 0x00; //0x01->设置 0x00->读取
    
    [[RLBluetooth sharedBluetooth] writeDataToCharacteristic:characteristic cmdCode:0x06 cmdMode:cmdMode withDatas:writeData];
}

- (void)handleLockResponseData:(NSData *)data {
    BL_response cmdResponse = responseWithBytes(( Byte *)[data bytes], data.length);
    Byte crc = CRCOfCMDBytes((Byte *)[data bytes], data.length);
    switch (cmdResponse.cmd_code) {
        case 0x01:
            break;
        case 0x02:
            break;
        case 0x03:
            break;
        case 0x04:
            break;
        case 0x05:
            break;
        default:
            break;
    }
    if(crc == cmdResponse.CRC && cmdResponse.result.result == 0) {
        
    }
}

- (BOOL)isLockResponseDataOK:(BL_response)response withCRC:(Byte)crc {
    if(crc == response.CRC && response.result.result == 0) {
        return YES;
    }
    
    return NO;
}

- (void)readLockPower {
    __weak __typeof(self)weakSelf = self;
    [[RLBluetooth sharedBluetooth] scanBLPeripheralsWithCompletionBlock:^(NSArray *peripherals) {
        if(peripherals == nil) {
            return ;
        }
        
        if(!peripherals.count) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [RLHUD hudAlertErrorWithBody:NSLocalizedString(@"未找到设备,请检查蓝牙设备", nil)];
            });
            return ;
        }
        
        for(KeyModel *key in self.lockList) {
            if(![key isValid]) {
                continue;
            }
            
            RLPeripheral *peripheral = [[RLBluetooth sharedBluetooth] peripheralForName:key.keyOwner.address];
            if(peripheral) {
                [[RLBluetooth sharedBluetooth] connectPeripheral:peripheral withConnectedBlock:^{
                    RLService *service = [[RLBluetooth sharedBluetooth] serviceForUUIDString:@"1910" withPeripheral:peripheral];
                    RLCharacteristic *characteristic = [[RLBluetooth sharedBluetooth] characteristicForNotifyWithService:service];
                    
                    [characteristic setNotifyValue:YES completion:^(NSError *error) {
                        RLCharacteristic *innerCharacteristic = [[RLBluetooth sharedBluetooth] characteristicForUUIDString:@"fff2" withService:service];
                        [weakSelf readLockPowerWithCharacteristic:innerCharacteristic withKey:key];
                        
                    } onUpdate:^(NSData *data, NSError *error) {
                        BL_response cmdResponse = responseWithBytes(( Byte *)[data bytes], data.length);
                        if(cmdResponse.cmd_code == 0x06) {
                            if(cmdResponse.result.result == 0x01) {
                                [RLHUD hudAlertNoticeWithBody:NSLocalizedString(@"电池电压过低，请更换电池！", nil)];
                            }
                        }
                    }];
                }];
                
                return;
            }
        }
    }];
}
#pragma mark -
#if 0
- (void)cycleScrollView:(RLCycleScrollView *)cycleScrollView didSelectItemAtIndex:(NSInteger)index {

}
#endif

#pragma mark - UIWebViewDelegate
- (void)webViewDidStartLoad:(UIWebView *)webView {
    self.isBannersLoaded = NO;
    self.isBannersLoading = YES;
    [RLHUD hudProgressWithBody:nil onView:webView timeout:5.0f];
}
- (void)webViewDidFinishLoad:(UIWebView *)webView{
    self.isBannersLoaded = YES;
    self.isBannersLoading = NO;
    [RLHUD hideProgress];
}
- (void) webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    DLog(@"error=%@", error);
    self.isBannersLoaded = NO;
    self.isBannersLoading = NO;
    [RLHUD hideProgress];
}
@end
