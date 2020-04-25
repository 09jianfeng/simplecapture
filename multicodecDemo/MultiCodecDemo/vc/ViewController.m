//
//  ViewController.m
//  MultiCodecDemo
//
//  Created by JFChen on 2019/4/24.
//  Copyright © 2019 JFChen. All rights reserved.
//

#import "ViewController.h"
#import "AudioCaptureOrPlay.h"
#import "MultipeerConnectionLink.h"
#import "UDPSenderReceiver.h"
#import <SVProgressHUD.h>
#import "GCDAsyncUdpSocket.h"
#import "BufferManager.h"
#import "LogViewController.h"

#define MULTIPEER 0
#define UDPPORT 8080

extern void initG729Codec(void);
extern void encodeAudioData(short speechData[160],unsigned char serial[2][19]);
extern void initG729Decoder(void);
extern void decodeG729Data(unsigned char serial[30], short outData[160] , int status);
extern int getIntFromBigEndian(uint8_t *data);

@interface ViewController ()<AudioCaptureOrPlayDelegate, MultipeerConnectionLinkDelegate, WebProtocolDelegate, BufferManagerDelegate>

@property(nonatomic, copy) NSString *otherSizeIpAddress;
@property(nonatomic, strong) BufferManager *bufManager;

@end

@implementation ViewController{
    AudioCaptureOrPlay *_accPlay;
    MultipeerConnectionLink *_multiPeer;
    
    dispatch_queue_t _udpBraodQueue;
    UDPSenderReceiver *_udp;
    
    dispatch_queue_t _encodeQueue;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _udpBraodQueue = dispatch_queue_create("UDPBraodQueue", NULL);
    _encodeQueue = dispatch_queue_create("EncodeQueue", NULL);
    
    self.bufManager = [BufferManager new];
    self.bufManager.delegate = self;
    
    
    _accPlay = [AudioCaptureOrPlay new];
    _accPlay.audioDelegate = self;
    [AudioCaptureOrPlay setAudioSessionLouderSpeaker];
    
#if MULTIPEER
    _multiPeer = [[MultipeerConnectionLink alloc] init];
    _multiPeer.delegate = self;
#else
    _udp = [UDPSenderReceiver new];
    [_udp enableBroadCast];
    _udp.delegate = self;
#endif
    
    initG729Codec();
    initG729Decoder();
}



#pragma mark - audio delegate
- (void)captureData:(Byte *)bytes size:(NSUInteger)size{
    
    //NSLog(@"capturedata %tu",size);
    
    [self.bufManager addPCMDataToRecordBuffer:bytes size:size];
    
    dispatch_async(_encodeQueue, ^{
        Byte audioData[80 * 2 * 2];
        while ([self.bufManager getPCMDataFromRecordBuffer:audioData size:80 * 2 * 2]) {
            
            //前4个字节为帧id。15个字节为流内容
            unsigned char serialData[2][19];
            encodeAudioData((short *)audioData, serialData);
            
            [self->_bufManager addEncodedDataEnSide:[NSData dataWithBytes:serialData[0] length:19]];
            [self->_bufManager addEncodedDataEnSide:[NSData dataWithBytes:serialData[1] length:19]];
        }
        
#if MULTIPEER
        //    [self.bufManager addPCMDataToPlayBuffer:(Byte *)[data bytes] size:data.length];
        
        [self->_bufManager addEncodedDataEnSide:encodedData1];
        [self->_bufManager addEncodedDataEnSide:encodedData2];
        NSData * data1 = [self->_bufManager getEncodedDataEnSide];
        NSData * data2 = [self->_bufManager getEncodedDataEnSide];
        [self->_multiPeer sendData:data1 isReliable:YES];
        [self->_multiPeer sendData:data2 isReliable:YES];
        
#else
        
        //    [self addPCMDataToPlayBuffer:bytes size:size];
//        self->_otherSizeIpAddress = @"127.0.0.1";
//        [self->_udp linkToHost:@"127.0.0.1" port:UDPPORT];
        
        NSData * data1 = [self->_bufManager getEncodedDataEnSide];
        while (data1.length > 0) {
            [self->_udp sendData:data1];
            data1 = [self->_bufManager getEncodedDataEnSide];
        }
#endif
    });
}

- (void)playAudioData:(Byte *)bytes size:(NSUInteger)size{
    
    //NSLog(@"playdata %tu",size);
    
    [self.bufManager getPCMDataFromPlayBuffer:bytes size:size];
}

#pragma mark - btnevent
- (IBAction)btnSetupPeer:(id)sender {
#if MULTIPEER
    _multiPeer.isClient = YES;
    [_multiPeer setUpConnectionWitController:self];
#else
    
    //发广播，用来接收对方ip地址。
    dispatch_async(_udpBraodQueue, ^{
        while(nil == self->_otherSizeIpAddress || [self->_otherSizeIpAddress isEqualToString:@""]){
            NSString *str = @"broadcast";
            NSString *broadAdress = [UDPSenderReceiver getLocalIPAddressMask];
            [self->_udp linkToHost:broadAdress port:UDPPORT];
            [self->_udp sendData:[str dataUsingEncoding:NSUTF8StringEncoding]];
            sleep(2);
            NSLog(@"broadcast");
        }
    });
#endif
    
}

- (IBAction)btnServerBegin:(id)sender {
#if MULTIPEER
    _multiPeer.isClient = NO;
    [_multiPeer setUpConnectionWitController:self];
#else
    [_udp bindPort:UDPPORT];
#endif
}

- (IBAction)btnBeginCaptureAudio:(id)sender {
    [_accPlay startCapture];
}

- (IBAction)btnBeginPlayAudio:(id)sender {
    [_accPlay startPlay];
}

- (IBAction)btnPause:(id)sender {
}

- (IBAction)btnPausePlay:(id)sender {
}

- (IBAction)btnLog:(id)sender {
    LogViewController *logView = [LogViewController new];
    [self.navigationController pushViewController:logView animated:YES];
}


#pragma mark - multipeerDelegate
- (void)didReceiveData:(NSData *)data{
    dispatch_async(_udpBraodQueue, ^{
        NSData *innerData = data;
        
        while (innerData.length >= 19) {
            NSData *subData = [innerData subdataWithRange:NSMakeRange(0, 19)];
            Byte *subByte = (Byte *)[subData bytes];
            
            int frameId1 = getIntFromBigEndian(subByte);
            
            // 30个字节往里面塞
            unsigned char serial[15];
            for (int i = 0; i < 15; i++) {
                serial[i] = subByte[i+4];
            }
            
            [self.bufManager addEncodedData:frameId1 data:[NSData dataWithBytes:serial length:15]];
            
            innerData = [innerData subdataWithRange:NSMakeRange(19, innerData.length - 19)];
        }
    });
}



#pragma mark - udpdelegate
- (void)finishStartServer:(NSString *)ipadress port:(int)port{
    NSLog(@"finishstartserver:%@ port:%d", ipadress, port);
}

- (void)serverDidClose{
    NSLog(@"serverDidClose");
}

- (void)didReceiveData:(NSData *)data fromIP:(NSData *)fromIP{
    //接收广播信息，用来获取对方ip地址。
    if (nil == _otherSizeIpAddress || [_otherSizeIpAddress isEqualToString:@""]) {
        NSString *receiveDataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if ([receiveDataStr isEqualToString:@"broadcast"]) {
            
            NSString * ipS = [GCDAsyncUdpSocket hostFromAddress:fromIP];
            uint16_t port = [GCDAsyncUdpSocket portFromAddress:fromIP];
            
            NSArray *ipsAra = [ipS componentsSeparatedByString:@":"];
            if (ipsAra.count > 2) {
                NSLog(@"ipv6");
                return;
            }
            
            NSLog(@"other size ip:%@ port:%d",ipS , port);
            if ([ipS rangeOfString:[UDPSenderReceiver getLocalIPAddress]].location != NSNotFound) {
                NSLog(@"local broadcast");
                return;
            }
            
            self->_otherSizeIpAddress = ipS;
            NSString *str = @"broadcast";
            [_udp linkToHost:ipS port:UDPPORT];
            [_udp sendData:[str dataUsingEncoding:NSUTF8StringEncoding]];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"get ip success");
                [SVProgressHUD setMaximumDismissTimeInterval:2];
                [SVProgressHUD showSuccessWithStatus:[NSString stringWithFormat:@"连接成功，%@",self->_otherSizeIpAddress]];
            });
        }
        return;
    }
    
    
    dispatch_async(_udpBraodQueue, ^{
        NSData *innerData = data;
        
        while (innerData.length >= 19) {
            NSData *subData = [innerData subdataWithRange:NSMakeRange(0, 19)];
            Byte *subByte = (Byte *)[subData bytes];
            
            int frameId1 = getIntFromBigEndian(subByte);
            
            // 30个字节往里面塞
            unsigned char serial[15];
            for (int i = 0; i < 15; i++) {
                serial[i] = subByte[i+4];
            }

            [self.bufManager addEncodedData:frameId1 data:[NSData dataWithBytes:serial length:15]];

            innerData = [innerData subdataWithRange:NSMakeRange(19, innerData.length - 19)];
        }
    });
}


#pragma mark - bufmanagerDelegate
- (void)shouldDecodeWith:(NSData *)data status:(int)status{
    short outData[160];
    for (int i = 0; i < 160; i++) {
        outData[i] = 0;
    }
    
    //status 0:两条流都有收到 1:收到奇流 2:收到偶流 3:两条流都没收到
    decodeG729Data((unsigned char *)[data bytes], outData, status);
    [self.bufManager addPCMDataToPlayBuffer:(Byte *)outData size:320];
}


@end











