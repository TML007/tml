//
//  ViewController.m
//  Record
//
//  Created by sks on 2017/3/13.
//  Copyright © 2017年 tml. All rights reserved.
//

#import "ViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#define kNumberAudioQueueBuffers 3
#define kDefaultBufferDurationSeconds 0.02
#define kDefaultSampleRate 8000
#import "G711.h"
#import "AVAudioPlayer+PCM.h"
ViewController *vc = nil;
@interface ViewController ()
{
    //音频输入队列
    AudioQueueRef _audioQueue;
    //音频输入数据format
    AudioStreamBasicDescription _recordFormat;
    //音频输入缓冲区
    AudioQueueBufferRef _audioBuffers[kNumberAudioQueueBuffers];
    
    NSMutableData *_data;
    AVAudioPlayer *_player;
}
@property (nonatomic, assign) BOOL isRecording;
@property (atomic, assign) NSUInteger sampleRate;
@property (atomic, assign) double bufferDurationSeconds;
@property (nonatomic, strong) NSMutableData *data;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:@"开始" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    button.backgroundColor = [UIColor cyanColor];
    [self.view addSubview:button];
    [button addTarget:self action:@selector(starTML:) forControlEvents:UIControlEventTouchUpInside];
    button.frame = CGRectMake(50, 64, 100, 50);
    
    UIButton *stop = [UIButton buttonWithType:UIButtonTypeCustom];
    [stop setTitle:@"暂停" forState:UIControlStateNormal];
    [stop setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    stop.backgroundColor = [UIColor cyanColor];
    [self.view addSubview:stop];
    [stop addTarget:self action:@selector(stopTML:) forControlEvents:UIControlEventTouchUpInside];
    stop.frame = CGRectMake(50, 200, 100, 50);
    
    UIButton *play = [UIButton buttonWithType:UIButtonTypeCustom];
    [play setTitle:@"播放" forState:UIControlStateNormal];
    [play setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
    play.backgroundColor = [UIColor cyanColor];
    [self.view addSubview:play];
    [play addTarget:self action:@selector(playtml) forControlEvents:UIControlEventTouchUpInside];
    play.frame = CGRectMake(50, 300, 100, 50);

    
    self.sampleRate = kDefaultSampleRate;
    self.bufferDurationSeconds = kDefaultBufferDurationSeconds;
    //设置录音的format数据
    [self setupAudioFormat:kAudioFormatLinearPCM SampleRate:self.sampleRate];
    // Do any additional setup after loading the view, typically from a nib.
    //是否开启权限
    [self canRecord];
    vc = self;

}

- (void)starTML:(UIButton *)button {
    _data = [NSMutableData data];
    [self startRecording];
}

- (void)stopTML:(UIButton *)button {
    [self stopRecording];
}


- (void)playtml {
    [_player stop];
    //测试你的pcm音频数据
    _player = [[AVAudioPlayer alloc] initWithPcmData:_data pcmFormat:_recordFormat error:nil];
    [_player play];
    //也可以将你的g711a音频数据再次转成pcm音频数据  请调用这个方法
    /*
     int g711_decode(void *pout_buf, int *pout_len, const void *pin_buf, const int in_len , int type);
     */
}

- (BOOL)canRecord
{
    __block BOOL bCanRecord = YES;
    if ([[[UIDevice currentDevice]systemVersion]floatValue] >= 7.0) {
        
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        if ([audioSession respondsToSelector:@selector(requestRecordPermission:)]) {
            [audioSession performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
                if (granted) {
                    bCanRecord = YES;
                } else {
                    bCanRecord = NO;
                }
            }];
        }
    }
    NSLog(@"bCanRecord1 : %d",bCanRecord);
    return bCanRecord;
}
// 设置录音格式
- (void)setupAudioFormat:(UInt32) inFormatID SampleRate:(int)sampeleRate
{
    //重置下
    memset(&_recordFormat, 0, sizeof(_recordFormat));
    
    //设置采样率，这里先获取系统默认的测试下 //TODO:
    //采样率的意思是每秒需要采集的帧数
    _recordFormat.mSampleRate = sampeleRate;//[[AVAudioSession sharedInstance] sampleRate];
    
    //设置通道数,这里先使用系统的测试下 //TODO:
    _recordFormat.mChannelsPerFrame = 1;//(UInt32)[[AVAudioSession sharedInstance] inputNumberOfChannels];
    
    //设置format，录音格式pcm。
    _recordFormat.mFormatID = inFormatID;
    
    if (inFormatID == kAudioFormatLinearPCM){
        
        _recordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        //每个通道里，一帧采集的bit数目
        _recordFormat.mBitsPerChannel = 16;
        //结果分析: 8bit为1byte，即为1个通道里1帧需要采集2byte数据，再*通道数，即为所有通道采集的byte数目。
        //所以这里结果赋值给每帧需要采集的byte数目，然后这里的packet也等于一帧的数据。
        /*
         针对这里我说下：由于我项目发送的音频包长度和服务器那边约束读取参数的长度要保持一致 所以可以对宏定义kDefaultBufferDurationSeconds 根据你们对讲需求适当更改
         
         */
        _recordFormat.mBytesPerPacket = _recordFormat.mBytesPerFrame = (_recordFormat.mBitsPerChannel / 8) * _recordFormat.mChannelsPerFrame;
        _recordFormat.mFramesPerPacket = 1;
    }
}

void inputBufferHandler(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, const AudioTimeStamp *inStartTime,UInt32 inNumPackets, const AudioStreamPacketDescription *inPacketDesc)
{

    if (inNumPackets > 0) {
        NSData *pcmData = [[NSData alloc]initWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
        if (pcmData&&pcmData.length>0) {
            //这里对实时返回的每一帧pcm数据进行拼接，可能每个人的项目需求不一样，留个口子
            [vc.data appendData:pcmData];
            if (vc.data.length>0) {
                //这里对实时返回的每一帧pcm数据转成g711a
                NSUInteger datalength = [pcmData length];
                Byte *byteData = (Byte *)[pcmData bytes];
                short *pPcm = (short *)byteData;
                int outlen = 0;
                int len =(int)datalength / 2;
                Byte * G711Buff = (Byte *)malloc(len);
                memset(G711Buff,0,len);
                int i;
                for (i=0; i<len; i++) {
                    //这个可以设置转成的格式：alaw、ulaw
                    G711Buff[i] = linear2alaw(pPcm[i]);
                }
                outlen = i;
                Byte *sendbuff = (Byte *)G711Buff;
                NSData * sendData = [[NSData alloc]initWithBytes:sendbuff length:len];
                NSLog(@"这个就是g711a数据：%@",sendData);
            }
        }
    }
        AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

-(void)startRecording
{
    NSError *error = nil;
    //设置audio session的category
    BOOL ret = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (!ret) {
        NSLog(@"设置声音环境失败");
        return;
    }
    
    //启用audio session
    ret = [[AVAudioSession sharedInstance] setActive:YES error:&error];
    if (!ret)
    {
        NSLog(@"启动失败");
        return;
    }
    
    _recordFormat.mSampleRate = self.sampleRate;
    
    //初始化音频输入队列
    AudioQueueNewInput(&_recordFormat, inputBufferHandler, (__bridge void *)(self), NULL, NULL, 0, &_audioQueue);
    
    //计算估算的缓存区大小
    int frames = (int)ceil(self.bufferDurationSeconds * _recordFormat.mSampleRate);
    int bufferByteSize = frames * _recordFormat.mBytesPerFrame;
    NSLog(@"缓冲区大小:%d",bufferByteSize);
    
    //创建缓冲器
    for (int i = 0; i < kNumberAudioQueueBuffers; ++i){
        AudioQueueAllocateBuffer(_audioQueue, bufferByteSize, &_audioBuffers[i]);
        AudioQueueEnqueueBuffer(_audioQueue, _audioBuffers[i], 0, NULL);
    }
    
    // 开始录音
    AudioQueueStart(_audioQueue, NULL);
    
    self.isRecording = YES;
}

-(void)stopRecording
{
    if (self.isRecording) {
        self.isRecording = NO;
        
        //停止录音队列和移除缓冲区,以及关闭session，这里无需考虑成功与否
        AudioQueueStop(_audioQueue, true);
        AudioQueueDispose(_audioQueue, true);
        [[AVAudioSession sharedInstance] setActive:NO error:nil];
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
