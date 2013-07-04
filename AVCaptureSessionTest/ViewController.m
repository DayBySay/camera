//
//  ViewController.m
//  AVCaptureSessionTest
//
//  Created by 清 貴幸 on 2013/07/03.
//  Copyright (c) 2013年 清 貴幸. All rights reserved.
//

#import "ViewController.h"

@interface ViewController () {
    AVCaptureSession *_session;
}

@property (weak, nonatomic) IBOutlet UIImageView *CaptureImageView;
@property (strong, nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (strong, nonatomic) AVCaptureDeviceInput *videoInput;

-(IBAction)capture:(id)sender;
-(IBAction)changeCamera:(id)sender;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
//    [self showEnableVideoDevices];
    [self setupAVCapture];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput
       didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    // イメージバッファの取得
    CVImageBufferRef    buffer;
    buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // イメージバッファのロック
    // ロックしないと画像が書き換えられる
    CVPixelBufferLockBaseAddress(buffer, 0);
    
    // イメージバッファ情報の取得
    uint8_t*    base;
    size_t      width, height, bytesPerRow;
    base = CVPixelBufferGetBaseAddress(buffer);
    width = CVPixelBufferGetWidth(buffer);
    height = CVPixelBufferGetHeight(buffer);
    bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
    
    // ビットマップコンテキストの作成
    CGColorSpaceRef colorSpace;
    CGContextRef    cgContext;
    colorSpace = CGColorSpaceCreateDeviceRGB();
    cgContext = CGBitmapContextCreate(
                                      base, width, height, 8, bytesPerRow, colorSpace,
                                      kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    
    // 画像の作成
    CGImageRef  cgImage;
    UIImage*    image;
    cgImage = CGBitmapContextCreateImage(cgContext);
    //向き(orientation)を指定する
    image = [UIImage imageWithCGImage:cgImage scale:1.0f
                          orientation:UIImageOrientationRight];
    // CGImageContextはARCでは開放されない
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);
    
    // イメージバッファのアンロック
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    
    // 画像の表示
    _CaptureImageView.image = image;
}

-(void)setupAVCapture
{
    // sessionクラスのインスタンスを作成
    _session = [[AVCaptureSession alloc] init];
    
    NSString *preset = [self _getSessionPreset];
    
    // sessionの整合性を保つためにトランザクションをはる
    [_session beginConfiguration];
    [_session setSessionPreset:preset];
    
    AVCaptureInput *input = [self _createCameraInput:AVCaptureDevicePositionBack];
    _videoInput = input;
    AVCaptureOutput *output = [self _createVideoOutput];
    _stillImageOutput = [self _createStwillImageOutput];
    [_session addInput:input];
    [_session addOutput:output];
    [_session addOutput:_stillImageOutput];
    [_session commitConfiguration];
    [_session startRunning];
}

-(NSString*)_getSessionPreset
{
    NSString *preset;
    // プリセットを選ぶ
    // 画像の品質や解像度が違う
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        preset = AVCaptureSessionPreset1280x720;
    }
    else
    {
        preset = AVCaptureSessionPreset640x480;
    }
    
    return preset;
}

-(AVCaptureInput*)_createCameraInput:(AVCaptureDevicePosition)position
{
    // セッションへのインプットにビデオデバイスを設定する
    NSError *error;
    AVCaptureDeviceInput *input;
    input = [[AVCaptureDeviceInput alloc] initWithDevice:[self cameraWithPosition:position] error:&error];
    return input;
}

-(AVCaptureOutput*)_createVideoOutput
{
    AVCaptureVideoDataOutput * dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [dataOutput setAlwaysDiscardsLateVideoFrames:YES]; // Probably want to set this to NO when recording
    [dataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                                             forKey:(id)kCVPixelBufferPixelFormatTypeKey]]; // Necessary for manual preview
    // メインキューを取得してメインスレッドでで実行させる
    [dataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    return dataOutput;
}

-(AVCaptureStillImageOutput*)_createStwillImageOutput
{
    // Setup the still image file output
    AVCaptureStillImageOutput *newStillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                    AVVideoCodecJPEG, AVVideoCodecKey,
                                    nil];
    [newStillImageOutput setOutputSettings:outputSettings];
    return newStillImageOutput;
}

-(void)capture:(id)sender
{
    [self capture];
}

// アルバムに画像を保存
-(void)capture
{
    // アウトプットの出力を探す
    AVCaptureConnection *stillImageConnection = [ViewController connectionWithMediaType:AVMediaTypeVideo fromConnections:[_stillImageOutput connections]];
    if ([stillImageConnection isVideoOrientationSupported])
        [stillImageConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    [_stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection
                                                         completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
															 
															 ALAssetsLibraryWriteImageCompletionBlock completionBlock = ^(NSURL *assetURL, NSError *error) {
																 if (error) {
                                                                     NSLog(@"%@", error);
																 }
															 };
															 
															 if (imageDataSampleBuffer != NULL) {
																 NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
																 ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
																 
                                                                 UIImage *image = [[UIImage alloc] initWithData:imageData];
																 [library writeImageToSavedPhotosAlbum:[image CGImage]
																						   orientation:(ALAssetOrientation)[image imageOrientation]
																					   completionBlock:completionBlock];
															 }
															 else
																 completionBlock(nil, error);
                                                         }];
}

-(void)changeCamera:(id)sender
{
    [self toggleCamera];
}


- (BOOL) toggleCamera
{
    BOOL success = NO;
    
    if ([[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count] > 1) {
        NSError *error;
        AVCaptureDeviceInput *newVideoInput;
        AVCaptureDevicePosition position = [[_videoInput device] position];
        
        if (position == AVCaptureDevicePositionBack)
            newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self frontFacingCamera] error:&error];
        else if (position == AVCaptureDevicePositionFront)
            newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self backFacingCamera] error:&error];
        else
            goto bail;
        
        if (newVideoInput != nil) {
            [_session beginConfiguration];
            [_session removeInput:_videoInput];
            if ([_session canAddInput:newVideoInput]) {
                [_session addInput:newVideoInput];
                [self setVideoInput:newVideoInput];
            } else {
                [_session addInput:[self videoInput]];
            }
            [_session commitConfiguration];
            success = YES;
        } else if (error) {
        }
        
        _videoInput = newVideoInput;
    }

bail:
    return success;
}

// ポジションでカメラを返す
- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}

// フロントのカメラを返す
- (AVCaptureDevice *) frontFacingCamera
{
    return [self cameraWithPosition:AVCaptureDevicePositionFront];
}

// バックのカメラを返す
- (AVCaptureDevice *) backFacingCamera
{
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
}

// 特定のメディアタイプの接続を探す
+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections
{
	for ( AVCaptureConnection *connection in connections ) {
		for ( AVCaptureInputPort *port in [connection inputPorts] ) {
			if ( [[port mediaType] isEqual:mediaType] ) {
				return connection;
			}
		}
	}
	return nil;
}

-(void)showEnableVideoDevices
{
    NSArray *devices = [AVCaptureDevice devices];
    for (AVCaptureDevice *device in devices) {
        NSLog(@"Device name: %@", [device localizedName]);
        if ([device hasMediaType:AVMediaTypeVideo]) {
            if ([device position] == AVCaptureDevicePositionBack) {
                NSLog(@"Device position : back");
            }
            else {
                NSLog(@"Device position : front");
            }
        }
    }
}

@end
