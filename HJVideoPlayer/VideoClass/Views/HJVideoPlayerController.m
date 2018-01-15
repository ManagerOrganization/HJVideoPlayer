//
//  HJVideoPlayerController.m
//  HJVideoPlayer
//
//  Created by WHJ on 2016/12/8.
//  Copyright © 2016年 WHJ. All rights reserved.
//

#import "HJVideoPlayerController.h"
#import "HJVideoTopView.h"
#import "HJVideoBottomView.h"
#import "HJVideoPlayManager.h"
#import "HJVideoUIManager.h"
#import "HJPlayerView.h"
#import <MediaPlayer/MediaPlayer.h>
#import "HJViewFactory.h"
#import "HJVideoMaskView.h"
#import "HJVideoPlayerHeader.h"

typedef NS_ENUM(NSUInteger, MoveDirection) {
    MoveDirection_none = 0,
    MoveDirection_up,
    MoveDirection_down,
    MoveDirection_left,
    MoveDirection_right
};



@interface HJVideoPlayerController ()

@property (nonatomic ,strong) HJVideoMaskView * maskView;

@property (nonatomic ,strong) HJVideoTopView * topView;

@property (nonatomic ,strong) HJVideoBottomView * bottomView;

@property (nonatomic ,assign) CGRect originFrame;

@property (nonatomic ,assign) CGFloat toolBarHeight;

@property (nonatomic, assign) BOOL isFullScreen;

@property (nonatomic, strong) HJPlayerView *playerView;

@property (nonatomic, assign) VideoPlayerStatus playStatus;

@property (nonatomic, assign) VideoPlayerStatus prePlayStatus;

@property (nonatomic, assign) NSInteger secondsForBottom;

@property (nonatomic, assign) CGPoint startPoint;

@property (nonatomic, assign) MoveDirection moveDirection;

/** 音量调节 */
@property (nonatomic, strong) UISlider *volumeSlider;

@property (nonatomic, assign) CGFloat sysVolume;
/** 亮度调节 */
@property (nonatomic, assign) CGFloat brightness;

/** 进度调节 */
@property (nonatomic, assign) CGFloat currentTime;


@end

#define kToolBarHalfHeight Ratio_X(30.f)
#define kToolBarFullHeight Ratio_X(40.f)
#define kFullScreenFrame CGRectMake(0 , 0, kScreenHeight, kScreenWidth)

#define imgVideoBackImg [UIImage imageFromBundleWithName:@"video_backImg.jpeg"]
#define imgPlay         [UIImage imageFromBundleWithName:@"video_play"]
#define imgPause        [UIImage imageFromBundleWithName:@"video_pause"]
static const NSInteger maxSecondsForBottom = 5.f;

@implementation HJVideoPlayerController

#pragma mark -lifeCycle

- (instancetype)initWithFrame:(CGRect)frame{
    self = [super init];
    if (self) {
        self.originFrame = frame;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self initW];
    [self handleVideoPlayerStatus];
    [self addObservers];
    [self addTapGesture];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];

}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];

}

- (void)dealloc{

    
}



- (void)initW
{
    self.secondsForBottom = maxSecondsForBottom;
    self.currentTime      = 0;
    
    //获取系统音量滚动条
    MPVolumeView *volumeView = [[MPVolumeView alloc]init];
    for (UIView *tmpView in volumeView.subviews) {
        if ([[tmpView.class description] isEqualToString:@"MPVolumeSlider"]) {
            self.volumeSlider = (UISlider *)tmpView;
        }
    }
}

#pragma mark - About UI
- (void)setupUI
{
    // 设置self
    [self.view setFrame:self.originFrame];
    
    // 设置player
    [self.playerView setFrame:self.view.frame];
    [self.playerView setBackgroundColor:[UIColor clearColor]];
    [self.playerView setImage:imgVideoBackImg];
    [self.playerView setUserInteractionEnabled:YES];
    [self.view addSubview:self.playerView];
    
    
    //设置遮罩层
    self.maskView = [[HJVideoMaskView alloc] initWithFrame:self.playerView.bounds];
    self.maskView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:.3];
    self.maskView.maskViewStatus = VideoMaskViewStatus_showPlayBtn;
    self.maskView.playBlock = ^(BOOL isPlay) {
        if (isPlay) {
            [kVideoPlayerManager play];
        }else{
            [kVideoPlayerManager pause];
        }
    };
    [self.playerView addSubview:self.maskView];
    

    
    // 设置topView
    self.topView.frame = CGRectMake(0, 0, self.maskView.frame.size.width, kToolBarHalfHeight);
    [self.maskView addSubview:self.topView];
    
    // 设置BottomView
    self.bottomView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    self.bottomView.frame = CGRectMake(0, CGRectGetHeight(self.maskView.frame) - kToolBarHalfHeight, self.maskView.frame.size.width, kToolBarHalfHeight);
    [self.maskView addSubview:self.bottomView];
    
    //
    kHJVideoUIManager.topView = self.topView;
    kHJVideoUIManager.bottomView = self.bottomView;
    
    // 调试颜色
    //    self.backgroundColor = [UIColor redColor];
    //    self.playerView.backgroundColor = [UIColor blueColor];
    
}

- (void)changeFullScreen:(BOOL)changeFull{
    
    [UIView animateWithDuration:kDefaultAnimationDuration animations:^{
        CGFloat toolBarHeight = 0;
        if (changeFull) {
            self.view.transform = CGAffineTransformMakeRotation(M_PI_2);
            self.view.frame = kFrame;
            toolBarHeight = kToolBarFullHeight;
        }else{
            self.view.transform = CGAffineTransformIdentity;
            self.view.frame = self.originFrame;
            toolBarHeight = kToolBarHalfHeight;
        }
        
        self.playerView.frame = self.view.bounds;
        self.topView.frame = CGRectMake(0, 0, self.view.width, toolBarHeight);
        self.bottomView.frame = CGRectMake(0, self.view.height-toolBarHeight, self.view.width, toolBarHeight);
        self.isFullScreen = changeFull;
        // 发送屏幕改变通知
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationChangeScreen object:@(changeFull)];
    }];
}




#pragma mark - 底部栏显示/隐藏

- (void)addTapGesture
{
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(showBottomAction)];
    [self.view addGestureRecognizer:tap];
    [self startTimer];
}

- (void)showBottomAction
{
    if (self.bottomView.alpha) {
        [self hideBottomView];
    }else{
        [self showBottomView];
    }
}

- (void)showBottomView
{
    [UIView animateWithDuration:0.25 animations:^{
        self.bottomView.alpha = 1.f;
    } completion:^(BOOL finished) {
        
        [self startTimer];
    }];
}

- (void)startTimer
{
    [self setSecondsForBottom:maxSecondsForBottom];
    [self.maskView setMaskViewStatus:VideoMaskViewStatus_showPlayBtn];
    [NSTimer scheduledTimerWithTimeInterval:1 target:self
                                   selector:@selector(hideMaskViewWithTimer:)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)hideBottomView
{
    [UIView animateWithDuration:0.25 animations:^{
        self.bottomView.alpha = 0.f;
    }];
}

- (void)hideBottomWithTimer:(NSTimer *)timer{
    
    if (self.bottomView.alpha == 0) {
        [timer invalidate];
        timer = nil;
    }else{
        self.secondsForBottom --;
        NSLog(@"隐藏底部栏:%zd",self.secondsForBottom);
        if (self.secondsForBottom <= 0) {
            [self hideBottomView];
        }
    }
}


- (void)hideMaskViewWithTimer:(NSTimer *)timer{
    if (self.maskView.hidden) {
        [timer invalidate];
        timer = nil;
    }else{
        self.secondsForBottom --;
        NSLog(@"隐藏底部栏:%zd",self.secondsForBottom);
        if (self.secondsForBottom <= 0) {
            [self hideBottomView];
            self.maskView.maskViewStatus = VideoMaskViewStatus_hide;
        }
    }
}


#pragma mark - Pravite Methods
- (void)handleVideoPlayerStatus{
    
    WS(weakSelf);
    [kVideoPlayerManager readyBlock:^(CGFloat totoalDuration) {
        NSLog(@"[%@]:准备播放",[self class]);
        weakSelf.playStatus = videoPlayer_readyToPlay;
    } monitoringBlock:^(CGFloat currentDuration) {
        weakSelf.playStatus = videoPlayer_playing;
    } endBlock:^{
        NSLog(@"[%@]:播放结束",[self class]);
        weakSelf.playStatus = videoPlayer_playEnd;
    } failedBlock:^{
        NSLog(@"[%@]:播放失败",[self class]);
        weakSelf.playStatus = videoPlayer_playFailed;
    }];
}


- (void)addObservers{
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];

}


#pragma mark - Public Methods
- (void)play{
    NSLog(@"开始播放");
    [kVideoPlayerManager play];
    [self setPlayStatus:videoPlayer_playing];
}

- (void)pause{
    NSLog(@"暂停播放");
    [kVideoPlayerManager pause];
    [self setPlayStatus:videoPlayer_pause];
}

#pragma mark - Event Methods
- (void)applicationDidEnterBackground {

    if (self.playStatus == videoPlayer_playing) {
        [kVideoPlayerManager pause];
    }
}


- (void)applicationWillEnterForeground {
   
    if (self.prePlayStatus == videoPlayer_playing) {
        [kVideoPlayerManager play];
    }
}

- (void)playOrPauseAction:(UIButton *)sender{
    sender.selected = !sender.selected;
    if (sender.selected) {
        [self play];
    }else{
        [self pause];
    }
}
#pragma mark - getters / setters
- (HJVideoTopView *)topView{
    if (!_topView) {
        WS(weakSelf);
        _topView = [[HJVideoTopView alloc]init];
        _topView.backBlock = ^(){
            
            if(weakSelf.isFullScreen){//全屏返回
                [weakSelf changeFullScreen:NO];
            }else{//半屏返回操作
//                [weakSelf changeFullScreen:YES];
            }
        };
        
        _topView.showListBlock = ^(BOOL show){
            
        };
    }
    return _topView;
}

- (HJVideoBottomView *)bottomView{
    if (!_bottomView) {
        WS(weakSelf);
        _bottomView = [[HJVideoBottomView alloc] init];
        _bottomView.fullScreenBlock = ^(BOOL isFull){
            [weakSelf changeFullScreen:isFull];
        };
    }
    return _bottomView;
}

- (HJPlayerView *)playerView{
    if (!_playerView) {
        _playerView = [[HJPlayerView alloc] init];
    }
    return _playerView;
}


- (void)setUrl:(NSString *)url{
    if (!url) return;
    _url = url;
    [self.playerView setPlayer:[kVideoPlayerManager setUrl:_url]];
}

- (void)setPlayStatus:(VideoPlayerStatus)playStatus{
    
    self.prePlayStatus = _playStatus;
    _playStatus = playStatus;
}

#pragma mark - 触摸方法
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    
    [super touchesBegan:touches withEvent:event];
    UITouch * touch = [touches anyObject];
    self.startPoint = [touch locationInView:self.view];
    self.sysVolume = self.volumeSlider.value;
    self.brightness = [UIScreen mainScreen].brightness;
    self.currentTime = self.bottomView.progressValue;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{

    [super touchesMoved:touches withEvent:event];
    [self setSecondsForBottom:maxSecondsForBottom];
    UITouch * touch = [touches anyObject];
    CGPoint movePoint = [touch locationInView:self.view];
    
    CGFloat subX = movePoint.x - self.startPoint.x;
    CGFloat subY = movePoint.y - self.startPoint.y;
    CGFloat width  = self.view.width;
    CGFloat height = self.view.height;
    
    BOOL startInLeft = movePoint.x < self.view.width/2.f;
    
    
    if (self.moveDirection == MoveDirection_none) {
        if (subX >= 30) {
            self.moveDirection = MoveDirection_right;
        }else if(subX <= -30){
            self.moveDirection = MoveDirection_left;
        }else if (subY >= 30){
            self.moveDirection = MoveDirection_down;
        }else if (subY <= -30){
            self.moveDirection = MoveDirection_up;
        }
    }
    
    if (self.moveDirection == MoveDirection_right || self.moveDirection == MoveDirection_left) {//快进
        CGFloat offsetSeconds = self.bottomView.maximumValue*subX/width;
        [self.bottomView seekTo:self.currentTime + offsetSeconds];
    }else if (self.moveDirection == MoveDirection_up || self.moveDirection == MoveDirection_down){
        if (startInLeft) {//上调亮度
            [UIScreen mainScreen].brightness = self.brightness - subY/height;//10;
        }else{//上调音量
            self.volumeSlider.value = self.sysVolume - subY/height;//10;
        }
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    
    [super touchesEnded:touches withEvent:event];
    [self setMoveDirection:MoveDirection_none];
    [self setCurrentTime:0];
}

@end