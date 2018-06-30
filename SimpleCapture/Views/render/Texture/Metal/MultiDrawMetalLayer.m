//
//  MultiDrawMetalLayer.m
//  yyvideolib
//
//  Created by YYInc on 2017/11/22.
//  Copyright © 2017年 yy. All rights reserved.
//

#if (TARGET_IPHONE_SIMULATOR)
// 在模拟器的情况下
#else
#import <time.h>
#import "MultiDrawMetalLayer.h"
#import <Metal/Metal.h>
#import <CoreVideo/CVMetalTextureCache.h>
#import <UIKit/UIKit.h>
#import "MGLCommon.h"
#import <simd/simd.h>
#include <time.h>
#include <sys/time.h>


// 屏幕的渲染FPS
#define RENDER_RATE 30
#define MAX_CAPACITY 9

typedef struct {
    matrix_float3x3 matrix;
    vector_float3 offset;
} ColorConversion;

typedef enum{
    COLOR_601              = 0,
    COLOR_601_FULLRANG     = 1,
    COLOR_709              = 2,
    COLOR_709_FULLRANG     = 3,
}MetalColorConversionType;



@implementation MutilVideoViewCoordinateInfo
-(NSString*) printInfo {
    NSString *info = [NSString stringWithFormat:@"index:%d, viewXY:(%d, %d) , openglXY:(%d, %d), W&H:(%d, %d)", _index, _viewX, _viewY, _openglX, _openglY, _width, _height];
    return info;
}

-(BOOL) isTheSame:(MutilVideoViewCoordinateInfo*) info {
    if (self.viewX != info.viewX ||
        self.viewY != info.viewY ||
        self.width != info.width ||
        self.height != info.height ||
        self.openglX != info.openglX ||
        self.openglY != info.openglY ||
        self.metalWidth != info.metalWidth ||
        self.metalHeight != info.metalHeight ||
        self.metalX != info.metalX ||
        self.metalY != info.metalY) {
        return NO;
    }
    return YES;
}

-(void) resetValueWithMutilVideoViewCoordinateInfo:(MutilVideoViewCoordinateInfo *)viewCoordinate {
    self.viewX = viewCoordinate.viewX;
    self.viewY = viewCoordinate.viewY;
    self.width = viewCoordinate.width;
    self.height = viewCoordinate.height;
    self.openglX = viewCoordinate.openglX;
    self.openglY = viewCoordinate.openglY;
    self.metalX = viewCoordinate.metalX;
    self.metalY = viewCoordinate.metalY;
    self.metalWidth = viewCoordinate.metalWidth;
    self.metalHeight = viewCoordinate.metalHeight;
    self.index = viewCoordinate.index;
}

+(id) initWithMutilVideoViewCoordinateInfo:(MutilVideoViewCoordinateInfo*)viewCoordinate {
    MutilVideoViewCoordinateInfo* newObject = [[MutilVideoViewCoordinateInfo alloc] init];
    [newObject resetValueWithMutilVideoViewCoordinateInfo:viewCoordinate];
    return newObject;
}

@end



@interface MultiDrawMetalLayer()

@property(atomic, strong) NSMutableDictionary *viewCoordinateInfoDictionary;
@property CADisplayLink *displayLink;
@property int systemVersion;
@property BOOL isStopDisplayLink;

@end;

@implementation MultiDrawMetalLayer
{
    id <CAMetalDrawable> _currentDrawable;
    BOOL _layerSizeDidUpdate;
    MTLRenderPassDescriptor *_renderPassDescriptor;
    
    // controller
//    dispatch_semaphore_t _inflight_semaphore;
    
    // renderer
    id <MTLDevice> _device;
    id <MTLCommandQueue> _commandQueue;
    id <MTLLibrary> _defaultLibrary;
    id <MTLRenderPipelineState> _pipelineState;
    id <MTLBuffer> _vertexBuffer;
    id <MTLDepthStencilState> _depthState;
    id <MTLTexture> _textureY;
    id <MTLTexture> _textureCbCr;
    id <MTLBuffer> _colorConversionBuffer;
    id <MTLBuffer> _color601ConversionBuffer;
    id <MTLBuffer> _color709ConversionBuffer;
    id <MTLBuffer> _color601FullRangeConversionBuffer;
    id <MTLBuffer> _color709FullRangeConversionBuffer;
    
    CVMetalTextureCacheRef _textureCache;
    MetalVideoFillModeType _metalFillMode;
    MetalColorConversionType _colorConversionType;
    
    int _picWidth;
    int _picHeigh;
    NSCondition *_condiLock;
    BOOL _isInBackground;
    
    int _capacity;
    dispatch_queue_t _renderQueue;
    CVPixelBufferRef _bgPixelBuf;
    MutilVideoViewCoordinateInfo* _bgViewCoordinate;
    
    id <MTLCommandBuffer> commandBuffer;
    id <MTLRenderCommandEncoder> renderEncoder;
    
    CVPixelBufferRef pixelList[MAX_CAPACITY];
    NSLock* _lockObj;
    
    BOOL _isLastCommandFinish;
}

- (void)dealloc{
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_lockObj lock];
    {
        for (int i = 0; i < _capacity; i++)
        {
            CVPixelBufferRef pixelBuffer = pixelList[i];
            if (pixelBuffer) {
                CVPixelBufferRelease(pixelBuffer);
            }
            pixelList[i] = NULL;
        }
        
        if (_viewCoordinateInfoDictionary) {
            [_viewCoordinateInfoDictionary removeAllObjects];
        }
        
        CVPixelBufferRelease(_bgPixelBuf);
        _bgViewCoordinate = nil;
    }
    [_lockObj unlock];
    
    if (_textureCache) {
        CFRelease(_textureCache);
    }
    
    _currentDrawable = nil;
    _renderPassDescriptor = nil;
    _device = nil;
    _commandQueue = nil;
    _defaultLibrary = nil;
    _pipelineState = nil;
    _vertexBuffer = nil;
    _depthState = nil;
    _textureY = nil;
    _textureCbCr = nil;
    _colorConversionBuffer = nil;
    _renderQueue = nil;
    _color601ConversionBuffer = nil;
    _color709ConversionBuffer = nil;
    _color601FullRangeConversionBuffer = nil;
   _color709FullRangeConversionBuffer = nil;
    NSLog(@"dealloc");
}

- (instancetype)init{
    return [self initWithFrame:[UIScreen mainScreen].bounds Capacity:9];
}

- (instancetype)initWithFrame:(CGRect)frame Capacity:(int) capacity {
    self = [super init];
    if (self) {
//        _inflight_semaphore = dispatch_semaphore_create(g_max_inflight_buffers);
        [self setFrame:frame];
        [self _setupMetal];
        [self _loadAssets];
        
        _isStopDisplayLink = NO;
        _displayLink = nil;
        _capacity = capacity;
        _systemVersion = [[[UIDevice currentDevice] systemVersion] intValue];
        
        _lockObj = [[NSLock alloc] init];
        _viewCoordinateInfoDictionary = [[NSMutableDictionary alloc] init];
        for (int i = 0; i < _capacity; i++) {
            pixelList[i] = NULL;
        }
        
        _renderQueue = dispatch_queue_create("com.yy.yyvideo.YYMetalLayer", DISPATCH_QUEUE_SERIAL);
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(layerBecomeActiveFromBackground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(layerWillResignActiveToBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(layerDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        
        _condiLock = [NSCondition new];
        _isLastCommandFinish = YES;
    }
    return self;
}

- (void)layerBecomeActiveFromBackground:(NSNotification *)sender{
    [_condiLock lock];
    _isInBackground = NO;
    [self resumeDisplayLink];
    NSLog(@"");
    [_condiLock unlock];
}

- (void)layerWillResignActiveToBackground:(NSNotification *)sender{
    [_condiLock lock];
    _isInBackground = YES;
    [self pauseDisplayLink];
    NSLog(@"");
    [_condiLock unlock];
}

- (void)layerDidEnterBackground:(NSNotification *)sender{
    [_condiLock lock];
    _isInBackground = YES;
    [self pauseDisplayLink];
    NSLog(@"");
    [_condiLock unlock];
}

- (void) removeFromSuperlayer {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf deinitDisplayLink];
    });
    [super removeFromSuperlayer];
}

#pragma mark - metal prepare

- (void)_setupMetal
{
    // Find a usable device
    _device = MTLCreateSystemDefaultDevice();
    
    // Create a new command queue
    _commandQueue = [_device newCommandQueue];
    
    // Load all the shader files with a metal file extension in the project
    if (![self getDefaultLibrary]) {
        return;
    }
    
    // Setup metal layer and add as sub layer to view
    self.device = _device;
    self.pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    // Change this to NO if the compute encoder is used as the last pass on the drawable texture
    self.framebufferOnly = YES;
    
    CVMetalTextureCacheCreate(NULL, NULL, _device, NULL, &_textureCache);

    
    ColorConversion kColorConversion601 = {
        .matrix = {
            .columns[0] = { 1.164,  1.164, 1.164, },
            .columns[1] = { 0.000, -0.392, 2.017, },
            .columns[2] = { 1.596, -0.813, 0.000, },
        },
        .offset = { -(16.0/255.0), -0.5, -0.5 },
    };
    
    ColorConversion kColorConversion709 = {
        .matrix = {
            .columns[0] = { 1.164,  1.164, 1.164, },
            .columns[1] = { 0.000,  -0.213, 2.112, },
            .columns[2] = { 1.793, -0.533, 0.000, },
        },
        .offset = { -(16.0/255.0), -0.5, -0.5 },
    };
    
    
    ColorConversion kColorConversion601FullRange = {
        .matrix = {
            .columns[0] = { 1.0,  1.0, 1.0, },
            .columns[1] = { 0.000,  -0.343, 1.765, },
            .columns[2] = { 1.4, -0.711, 0.000, },
        },
        .offset = {0.000, -0.5, -0.5 },
    };
    
    
    ColorConversion kColorConversion709FullRange = {
        .matrix = {
            .columns[0] = { 1.0,  1.0, 1.0, },
            .columns[1] = { 0.000, -0.183, 1.816, },
            .columns[2] = { 1.540,  -0.459, 0.000, },
        },
        .offset = { 0.000, -0.5, -0.5 },
    };
    
    _color601ConversionBuffer = [_device newBufferWithBytes:&kColorConversion601 length:sizeof(ColorConversion) options:MTLResourceOptionCPUCacheModeDefault];
    _color709ConversionBuffer = [_device newBufferWithBytes:&kColorConversion709 length:sizeof(ColorConversion) options:MTLResourceOptionCPUCacheModeDefault];
    _color601FullRangeConversionBuffer = [_device newBufferWithBytes:&kColorConversion601FullRange length:sizeof(ColorConversion) options:MTLResourceOptionCPUCacheModeDefault];
    _color709FullRangeConversionBuffer = [_device newBufferWithBytes:&kColorConversion709FullRange length:sizeof(ColorConversion) options:MTLResourceOptionCPUCacheModeDefault];
    //初始化使用601
    _colorConversionBuffer = _color601ConversionBuffer;
   
}

- (BOOL)getDefaultLibrary{
    NSString *bundleResourcePath = [[NSBundle mainBundle] resourcePath];
    
    NSString *metalPath = [bundleResourcePath stringByAppendingPathComponent:@"default.metallib"];
    NSError *error = nil;
    _defaultLibrary = [_device newLibraryWithFile:metalPath error:&error];
    if (error) {
        _defaultLibrary = nil;
        NSLog(@"error default library is nil");
        return NO;
    }
    
    return YES;
}

- (void)_loadAssets
{
    if (!_defaultLibrary) {
        return;
    }
    
    // Load the fragment program into the library
    id <MTLFunction> fragmentProgram = [_defaultLibrary newFunctionWithName:@"fragmentColorConversion"];
    
    // Load the vertex program into the library
    id <MTLFunction> vertexProgram = [_defaultLibrary newFunctionWithName:@"vertexPassthrough"];
    
    // Create a reusable pipeline state
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"MyPipeline";
    [pipelineStateDescriptor setSampleCount: 1];
    [pipelineStateDescriptor setVertexFunction:vertexProgram];
    [pipelineStateDescriptor setFragmentFunction:fragmentProgram];
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineStateDescriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    
    NSError* error = NULL;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    if (!_pipelineState) {
        NSLog(@"Failed to created pipeline state, error %@", error);
    }
    
    MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionAlways;
    depthStateDesc.depthWriteEnabled = NO;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];
}

- (void)setupRenderPassDescriptorForTexture:(id <MTLTexture>)texture
{
    if (_renderPassDescriptor == nil)
        _renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    
    _renderPassDescriptor.colorAttachments[0].texture = texture;
    _renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    _renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0f, 0.0f, 0.0f, 1.0f);
    _renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
}

#pragma mark - metal render

- (id <CAMetalDrawable>)currentDrawable
{
    while (_currentDrawable == nil)
    {
        _currentDrawable = [self nextDrawable];
        if (!_currentDrawable)
        {
            NSLog(@"CurrentDrawable is nil");
        }
    }
    
    return _currentDrawable;
}

- (void)resetVerticeBuffer:(MutilVideoViewCoordinateInfo*) viewCoordinate{
    float frameWidth = viewCoordinate.metalWidth;
    float frameHeigh = viewCoordinate.metalHeight;
    
    float picWHRatio = (_picWidth*1.0)/(_picHeigh*1.0);
    float framWHRatio = frameWidth/frameHeigh;
    
    float widthRatio = 1.0;
    float heighRatio = 1.0;
    if (_metalFillMode == MetalFillModePreserveAspectRatio) {
        if (picWHRatio > framWHRatio) {
            float autoPicWidth = frameWidth;
            float autoPicHeigh = autoPicWidth/picWHRatio;
            widthRatio = autoPicWidth/frameWidth;
            heighRatio = autoPicHeigh/frameHeigh;
        }else{
            float autoPicHeigh = frameHeigh;
            float autoPicWidth =autoPicHeigh * picWHRatio;
            widthRatio = autoPicWidth/frameWidth;
            heighRatio = autoPicHeigh/frameHeigh;
        }
    }else if(_metalFillMode == MetalFillModePreserveAspectRatioAndFill){
        if (picWHRatio > framWHRatio) {
            float autoPicHeigh = frameHeigh;
            float autoPicWidth =autoPicHeigh * picWHRatio;
            widthRatio = autoPicWidth/frameWidth;
            heighRatio = autoPicHeigh/frameHeigh;
        }else{
            float autoPicWidth = frameWidth;
            float autoPicHeigh = autoPicWidth/picWHRatio;
            widthRatio = autoPicWidth/frameWidth;
            heighRatio = autoPicHeigh/frameHeigh;
        }
    }else{
        widthRatio = 1.0;
        heighRatio = 1.0;
    }
    
    float incubeVertexData[16] =
    {
        -1.0*widthRatio, -1.0*heighRatio,  0.0, 1.0,
        1.0*widthRatio, -1.0*heighRatio,  1.0, 1.0,
        -1.0*widthRatio,  1.0*heighRatio,  0.0, 0.0,
        1.0*widthRatio,  1.0*heighRatio,  1.0, 0.0,
    };
    
    // Setup the vertex buffers
    _vertexBuffer = [_device newBufferWithBytes:incubeVertexData length:sizeof(incubeVertexData) options:MTLResourceOptionCPUCacheModeDefault];
    _vertexBuffer.label = @"Vertices";
}

#pragma mark - public method

-(CVPixelBufferRef) pixelBufferAtIndex:(int) index
{
    if (index > (_capacity - 1) || index < 0) {
        return NULL;
    }
    CVPixelBufferRef pixelBuffer = NULL;
    [_lockObj lock];
        pixelBuffer = pixelList[index];
        CVPixelBufferRetain(pixelBuffer);
    [_lockObj unlock];
    return pixelBuffer;
}

-(void)setBackgroudPixelBuffer:(CVPixelBufferRef)bgPixeBuffer ViewCoordinate:(MutilVideoViewCoordinateInfo*)viewCoordinate
{
    [_lockObj lock];
        CVPixelBufferRef retainBuffer = NULL;
        if (bgPixeBuffer) {
            retainBuffer = CVPixelBufferRetain(bgPixeBuffer);
        }
        if (_bgPixelBuf) {
            CVPixelBufferRelease(_bgPixelBuf);
        }
        _bgPixelBuf = retainBuffer;
        _bgViewCoordinate = viewCoordinate;
    [_lockObj unlock];
}

- (void)setPixelBuffer:(CVPixelBufferRef)pixelBuffer ViewCoordinate:(MutilVideoViewCoordinateInfo*) viewCoordinate{
    
    if (_isInBackground) {
        return;
    }
    
    if (viewCoordinate.index > (_capacity - 1) || viewCoordinate.index < 0) {
        NSLog(@"view coordinate index error. %d", viewCoordinate.index);
        return ;
    }
    
    [_lockObj lock];
    {
        CVPixelBufferRef oldPixelBuffer = pixelList[viewCoordinate.index];
        if(oldPixelBuffer) {
            CVPixelBufferRelease(oldPixelBuffer);
        } else {
            _layerSizeDidUpdate = YES;
        }
        pixelList[viewCoordinate.index] = CVPixelBufferRetain(pixelBuffer);
        
        int index = viewCoordinate.index;
        MutilVideoViewCoordinateInfo* originalViewCoordinate = [_viewCoordinateInfoDictionary objectForKey:@(index)];
        if (originalViewCoordinate) {
            if (![originalViewCoordinate isTheSame:viewCoordinate]) {
                [originalViewCoordinate resetValueWithMutilVideoViewCoordinateInfo:viewCoordinate];
                [_viewCoordinateInfoDictionary setObject:originalViewCoordinate forKey:@(index)];
            }
        } else {
            originalViewCoordinate = [MutilVideoViewCoordinateInfo initWithMutilVideoViewCoordinateInfo:viewCoordinate];
            [_viewCoordinateInfoDictionary setObject:originalViewCoordinate forKey:@(index)];
        }
    }
    [_lockObj unlock];
    
    [_condiLock lock];
    if (_isInBackground) {
        [_condiLock unlock];
        return;
    }
    
    @synchronized(self) {
        if (!self.displayLink && !_isStopDisplayLink) {
            __weak typeof(self) weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf initDisplayLink];
            });
        }
    }
    
    [_condiLock unlock];
}

-(void) removePixelBufferAtIndex:(int)index
{
    
    if (index > (_capacity - 1) || index < 0) {
        return;
    }
    
    [_lockObj lock];
    {
        CVPixelBufferRef pixelBuffer = pixelList[index];
        if (pixelBuffer) {
            // 先释放再替换
            CVPixelBufferRelease(pixelBuffer);
            pixelList[index] = NULL;
            [_viewCoordinateInfoDictionary removeObjectForKey:@(index)];
            
            int validCount = 0;
            for (int pixelIndex = 0; pixelIndex < _capacity; pixelIndex++) {
                if (pixelList[pixelIndex]) {
                    validCount++;
                }
            }
            
            NSLog(@"remove pixelbuffer at index:%d, validCount:%d", index, validCount);
        }
    }
    [_lockObj unlock];
    
    __weak typeof(self) weakSelf = self;
    dispatch_sync(_renderQueue, ^{
        [weakSelf doRender];
    });
}

- (void)setFrame:(CGRect)frame{
    _layerSizeDidUpdate = YES;
    [super setFrame:frame];
}

- (void)setFillMode:(MetalVideoFillModeType)fillMode{
    _metalFillMode = fillMode;
    _layerSizeDidUpdate = YES;
}

-(void) initDisplayLink {
    if (!self.displayLink && !_isStopDisplayLink) {
        NSLog(@"start display link");
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
#if (!defined(__IPHONE_10_0) || (__IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_10_0))
        _displayLink.frameInterval = 60 / RENDER_RATE;
#else
        if ([_displayLink respondsToSelector:@selector(setPreferredFramesPerSecond:)]) {
            if (@available(iOS 10.0, *)) {
                _displayLink.preferredFramesPerSecond = RENDER_RATE;
            } else {
                _displayLink.frameInterval = 60 / RENDER_RATE;
            }
        } else {
            _displayLink.frameInterval = 60 / RENDER_RATE;
        }
#endif
        [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    }
}

-(void) deinitDisplayLink {
    NSLog(@"stop displayLink");
    self.isStopDisplayLink = YES;
    self.displayLink.paused = YES;
    [self.displayLink invalidate];
    self.displayLink = nil;
}

-(void) pauseDisplayLink
{
    _displayLink.paused = YES;
}

-(void) resumeDisplayLink
{
    _displayLink.paused = NO;
}

-(void) displayLinkCallback:(CADisplayLink*) sender {
    __weak typeof(self) weakSelf = self;
    dispatch_sync(_renderQueue, ^{
        [weakSelf doRender];
    });
}

-(void) doRender
{
    if (_isInBackground || self.isStopDisplayLink) {
        NSLog(@"do not render screen with opengles while appp is in background mode, inbackgroud %d, stop display link %x", _isInBackground, self.isStopDisplayLink);
        return ;
    }
    if (CGRectIsEmpty(self.frame)) {
        NSLog(@"yyvideolib , frame is empty !");
        return;
    }
    
    if (!_isLastCommandFinish) {
        NSLog(@"lastConmandhave not finish");
        return;
    }
    
    _isLastCommandFinish = NO;
    [_lockObj lock];
    {
        [self beginRender];
        if (_bgPixelBuf && _bgViewCoordinate) {
            [self render:_bgPixelBuf ViewCoordinate:_bgViewCoordinate];
        }
        for (int i = 0; i < _capacity; i++)
        {
            CVPixelBufferRef pixelBuffer = pixelList[i];
            if (pixelBuffer) {
                MutilVideoViewCoordinateInfo* viewCoordinate = [self.viewCoordinateInfoDictionary objectForKey:@(i)];
                if (viewCoordinate) {
                    [self render:pixelBuffer ViewCoordinate:viewCoordinate];
                } else {
                    NSLog(@"the pixel buffer would not be rendered, bacause of the view coordinate is nil!");
                }
            }
        }
        [self endRender];
    }
    [_lockObj unlock];
}

-(void) beginRender
{
    if (!_defaultLibrary) {
        NSLog(@"_defaultLibrary is nil");
        return;
    }
    if (_layerSizeDidUpdate)
    {
        CGFloat scale = [UIScreen mainScreen].scale;
        CGSize drawableSize = self.bounds.size;
        drawableSize.width *= scale;
        drawableSize.height *= scale;
        
        self.drawableSize = drawableSize;
        _layerSizeDidUpdate = NO;
    }
    
//    dispatch_semaphore_wait(_inflight_semaphore, DISPATCH_TIME_FOREVER);
    
    // Create a new command buffer for each renderpass to the current drawable
    commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
    
    // obtain a drawable texture for this render pass and set up the renderpass descriptor for the command encoder to render into
    [self currentDrawable];
    [self setupRenderPassDescriptorForTexture:_currentDrawable.texture];
    
    renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_renderPassDescriptor];
    renderEncoder.label = @"MyRenderEncoder";
    [renderEncoder setDepthStencilState:_depthState];
}

-(void) render:(CVPixelBufferRef)pixelBuffer ViewCoordinate:(MutilVideoViewCoordinateInfo*) viewCoordinate
{
    if(pixelBuffer == NULL) {
        NSLog(@"Pixel buffer is null");
        return;
    }
     MetalColorConversionType currentColorConversionType = COLOR_601;
    
    FourCharCode fourcc = CVPixelBufferGetPixelFormatType(pixelBuffer);
    CFTypeRef colorAttachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
    if(colorAttachments)
    {
        if(CFStringCompare(colorAttachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo)
        {
            if (fourcc == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
                fourcc == kCVPixelFormatType_420YpCbCr8Planar)
            {
                _colorConversionBuffer = _color601ConversionBuffer;
                currentColorConversionType = COLOR_601;
            }
            else
            {
                _colorConversionBuffer = _color601FullRangeConversionBuffer;
                currentColorConversionType = COLOR_601_FULLRANG;
            }
        }
        else if(CFStringCompare(colorAttachments, kCVImageBufferYCbCrMatrix_ITU_R_709_2, 0) == kCFCompareEqualTo)
        {
            if (fourcc == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
                fourcc == kCVPixelFormatType_420YpCbCr8Planar)
            {
                _colorConversionBuffer = _color709ConversionBuffer;
                currentColorConversionType = COLOR_709;
            }
            else
            {
                _colorConversionBuffer = _color709FullRangeConversionBuffer;
                currentColorConversionType = COLOR_709_FULLRANG;
            }
        }
        else
        {
            if (fourcc == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
                fourcc == kCVPixelFormatType_420YpCbCr8Planar)
            {
                _colorConversionBuffer = _color601ConversionBuffer;
                currentColorConversionType = COLOR_601;
            }
            else
            {
                _colorConversionBuffer = _color601FullRangeConversionBuffer;
                currentColorConversionType = COLOR_601_FULLRANG;
                
            }
        }
    }
    else
    {
        _colorConversionBuffer = _color601ConversionBuffer;
        currentColorConversionType = COLOR_601;
    }
    
    
    if (_colorConversionType != currentColorConversionType)
    {
        _colorConversionType = currentColorConversionType;
        NSLog(@"currentColorConversionType=%d,lastColorConversionType=%d",currentColorConversionType,_colorConversionType);
    }

    id<MTLTexture> textureY = nil;
    id<MTLTexture> textureCbCr = nil;
    
    // textureY
    {
        size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        if (width != _picWidth || height != _picHeigh) {
            _picWidth = (int)width;
            _picHeigh = (int)height;
        }
        
        MTLPixelFormat pixelFormat = MTLPixelFormatR8Unorm;
        
        CVMetalTextureRef texture = NULL;
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, _textureCache, pixelBuffer, NULL, pixelFormat, width, height, 0, &texture);
        if(status == kCVReturnSuccess)
        {
            textureY = CVMetalTextureGetTexture(texture);
            CFRelease(texture);
        } else {
            NSLog(@"create textureY error status:%d, index:%d", status, viewCoordinate.index);
        }
    }
    
    // textureCbCr
    {
        size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
        MTLPixelFormat pixelFormat = MTLPixelFormatRG8Unorm;
        
        CVMetalTextureRef texture = NULL;
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, _textureCache, pixelBuffer, NULL, pixelFormat, width, height, 1, &texture);
        if(status == kCVReturnSuccess)
        {
            textureCbCr = CVMetalTextureGetTexture(texture);
            CFRelease(texture);
        } else {
            NSLog(@"create textureCbCr error status:%d, index:%d", status, viewCoordinate.index);
        }
    }
    
    if(textureY != nil && textureCbCr != nil)
    {
        // always assign the textures atomic
        _textureY = textureY;
        _textureCbCr = textureCbCr;
    }
    else
    {
        if (textureY == nil) {
            NSLog(@"metal textureY is nil");
        }
        if (textureCbCr == nil) {
            NSLog(@"metal textureCbCr is nil");
        }
    }
    
    @autoreleasepool {
        [self resetVerticeBuffer:viewCoordinate];
        // Create a render command encoder so we can render into something
        
        // Set context state
        if(_textureY != nil && _textureCbCr != nil)
        {
            MTLViewport viewport;
            viewport.znear = -1.0f;
            viewport.zfar = 1.0f;
            viewport.originX = viewCoordinate.metalX;
            viewport.originY = viewCoordinate.metalY;
            viewport.width = viewCoordinate.metalWidth;
            viewport.height = viewCoordinate.metalHeight;
            [renderEncoder setViewport:viewport];
            [renderEncoder pushDebugGroup:@"DrawCube"];
            [renderEncoder setRenderPipelineState:_pipelineState];
            [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
            [renderEncoder setFragmentTexture:_textureY atIndex:0];
            [renderEncoder setFragmentTexture:_textureCbCr atIndex:1];
            [renderEncoder setFragmentBuffer:_colorConversionBuffer offset:0 atIndex:0];
            
            // Tell the render context we want to draw our primitives
            [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4 instanceCount:1];
            [renderEncoder popDebugGroup];
        }
        
        // We're done encoding commands
    }
}

-(void) endRender
{
    [renderEncoder endEncoding];
    // Call the view's completion handler which is required by the view since it will signal its semaphore and set up the next buffer
//    __block dispatch_semaphore_t block_sema = _inflight_semaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        _isLastCommandFinish = YES;
    }];
    
    // Schedule a present once the framebuffer is complete
    [commandBuffer presentDrawable:_currentDrawable];
    
    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
    
    _currentDrawable = nil;
    
    commandBuffer = nil;
    
    renderEncoder = nil;
}

-(uint32_t) getTickCount
{
    struct timeval now;
    gettimeofday(&now, NULL);
    return (uint32_t) (((uint64_t)now.tv_sec * USEC_PER_SEC + now.tv_usec) / 1000);
}

#pragma mark - openglDelegate
- (void)setContianerFrame:(CGRect)rect{
    [self setFrame:rect];
}

- (void)openGLRender{
    
    NSString *imageName = [NSString stringWithFormat:@"container.jpg"];
    UIImage *image = [UIImage imageNamed:imageName];
    CVPixelBufferRef pixelbuffer = imageToYUVPixelBuffer(image);
    
    int screenScale = [UIScreen mainScreen].scale;
    
    int width  = CGRectGetWidth(self.bounds)/3 * screenScale;
    int heigh = CGRectGetHeight(self.bounds)/3 * screenScale;
    if (width > heigh) {
        width = heigh;
    }else{
        heigh = width;
    }
    
    int lineIndex = 0;
    int rowIndex = 0;
    for (int i = 0; i < 9; i++) {
        lineIndex = i / 3;
        rowIndex = i % 3;
        
        MutilVideoViewCoordinateInfo* info = [MutilVideoViewCoordinateInfo new];
        info.metalX = rowIndex * width;
        info.metalY = lineIndex * heigh;
        info.metalWidth = width;
        info.metalHeight = heigh;
        info.index = i;
        [self setPixelBuffer:pixelbuffer ViewCoordinate:info];
    }

    CVPixelBufferRelease(pixelbuffer);
}

- (void)removeFromSuperContainer{
    [_displayLink invalidate];
    [self removeFromSuperlayer];
}

@end

#endif

