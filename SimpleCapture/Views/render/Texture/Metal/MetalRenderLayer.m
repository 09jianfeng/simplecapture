//
//  MetalRenderLayer.m
//  SimpleCapture
//
//  Created by JFChen on 2018/6/18.
//  Copyright © 2018年 duowan. All rights reserved.
//


#if (TARGET_IPHONE_SIMULATOR)
// 在模拟器的情况下
#else

#import "MetalRenderLayer.h"
#import <Metal/Metal.h>
#import <CoreVideo/CVMetalTextureCache.h>
#import <UIKit/UIKit.h>
#import <simd/simd.h>
#import "MGLCommon.h"

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


@implementation MetalRenderLayer
{
    id <CAMetalDrawable> _currentDrawable;
    BOOL _layerSizeDidUpdate;
    MTLRenderPassDescriptor *_renderPassDescriptor;
    
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
    BOOL _isInBackground;
    
    BOOL _isLastCommandBufferFinish;
    
    CADisplayLink *_displayLink;
}

- (void)dealloc{
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if(_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
    }
    
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
    _color601ConversionBuffer = nil;
    _color709ConversionBuffer = nil;
    _color601FullRangeConversionBuffer = nil;
    _color709FullRangeConversionBuffer = nil;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        [self _setupMetal];
        [self _loadAssets];
        _isLastCommandBufferFinish = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(layerBecomeActiveFromBackground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(layerWillResignActiveToBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(layerDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayingLinkDraw)];
        _displayLink.frameInterval = 2.0;
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    }
    return self;
}

- (void)layerBecomeActiveFromBackground:(NSNotification *)sender{
    _isInBackground = NO;
}

- (void)layerWillResignActiveToBackground:(NSNotification *)sender{
    _isInBackground = YES;
}

- (void)layerDidEnterBackground:(NSNotification *)sender{
    _isInBackground = YES;
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
    
    //    ColorConversion colorConversion = {
    //        .matrix = {
    //            .columns[0] = { 1.164,  1.164, 1.164, },
    //            .columns[1] = { 0.000, -0.392, 2.017, },
    //            .columns[2] = { 1.596, -0.813, 0.000, },
    //        },
    //        .offset = { -(16.0/255.0), -0.5, -0.5 },
    //    };
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

- (void)setupRenderPassDescriptorForTexture:(id <MTLTexture>) texture
{
    if (_renderPassDescriptor == nil)
    _renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    
    _renderPassDescriptor.colorAttachments[0].texture = texture;
    _renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    _renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0f, 0.0f, 0.0f, 1.0f);
    _renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
}

#pragma mark - metal render

- (void)_render
{
    if (!_isLastCommandBufferFinish) {
        NSLog(@"last command buffer have not finish");
        return;
    }
    
    // Create a new command buffer for each renderpass to the current drawable
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
    
    // obtain a drawable texture for this render pass and set up the renderpass descriptor for the command encoder to render into
    id <CAMetalDrawable> drawable = [self currentDrawable];
    if (!drawable) {
        return;
    }
    
    [self setupRenderPassDescriptorForTexture:drawable.texture];
    
    // Create a render command encoder so we can render into something
    id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:_renderPassDescriptor];
    renderEncoder.label = @"MyRenderEncoder";
    [renderEncoder setDepthStencilState:_depthState];
    
    // Set context state
    if(_textureY != nil && _textureCbCr != nil)
    {
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
    [renderEncoder endEncoding];
    
    _isLastCommandBufferFinish = NO;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        _isLastCommandBufferFinish = YES;
    }];
    
    // Schedule a present once the framebuffer is complete
    [commandBuffer presentDrawable:drawable];
    
    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
}

- (id <CAMetalDrawable>)currentDrawable
{
    int tryTime = 0;
    while (_currentDrawable == nil)
    {
        _currentDrawable = [self nextDrawable];
        if (!_currentDrawable)
        {
            NSLog(@"CurrentDrawable is nil");
            tryTime++;
            if (tryTime > 3) {
                return nil;
            }
        }
    }
    
    return _currentDrawable;
}

- (void)resetVerticeBuffer{
    float frameWidth = CGRectGetWidth(self.bounds);
    float frameHeigh = CGRectGetHeight(self.bounds);
    
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

- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer{
    if (!_defaultLibrary) {
        NSLog(@"_defaultLibrary is nil");
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
        NSLog(@"buffer kColorConversion601");
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
            _layerSizeDidUpdate = YES;
        }
        
        MTLPixelFormat pixelFormat = MTLPixelFormatR8Unorm;
        
        CVMetalTextureRef texture = NULL;
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, _textureCache, pixelBuffer, NULL, pixelFormat, width, height, 0, &texture);
        if(status == kCVReturnSuccess)
        {
            textureY = CVMetalTextureGetTexture(texture);
            CFRelease(texture);
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
        }
    }
    
    if(textureY != nil && textureCbCr != nil)
    {
        // always assign the textures atomic
        _textureY = textureY;
        _textureCbCr = textureCbCr;
    }
    
    @autoreleasepool {
        if (_layerSizeDidUpdate)
        {
            CGFloat scale = [UIScreen mainScreen].scale;
            CGSize drawableSize = self.bounds.size;
            drawableSize.width *= scale;
            drawableSize.height *= scale;
            
            self.drawableSize = drawableSize;
            [self resetVerticeBuffer];
            _layerSizeDidUpdate = NO;
        }
        
        // draw
        [self _render];
        
        _currentDrawable = nil;
    }
}

- (void)setPixelBuffer:(CVPixelBufferRef)pixelBuffer{
    if(_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
    }
    _pixelBuffer = CVPixelBufferRetain(pixelBuffer);
    
    [self renderPixelBuffer:pixelBuffer];
}

- (void)clearContents{
    @autoreleasepool {
        // 创建YUV pixelbuffer
        CVPixelBufferRef yuvPixelBuffer = [self createYUVPixelBufferWith:0 g:0 b:0];
        [self setPixelBuffer:yuvPixelBuffer];
        CVPixelBufferRelease(yuvPixelBuffer);
    }
}

- (void)setFrame:(CGRect)frame{
    _layerSizeDidUpdate = YES;
    [super setFrame:frame];
}

- (void)setFillMode:(MetalVideoFillModeType)fillMode{
    _metalFillMode = fillMode;
    _layerSizeDidUpdate = YES;
}

#pragma mark - tool
- (CVPixelBufferRef)createYUVPixelBufferWith:(float)r g:(float)g b:(float)b{
    CVPixelBufferRef yuvPixelBuffer;
    CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, (void*)[NSDictionary dictionary]);
    CFDictionarySetValue(attrs, kCVPixelBufferOpenGLESCompatibilityKey, (void*)[NSNumber numberWithBool:YES]);
    
    CVReturn err = CVPixelBufferCreate(kCFAllocatorDefault, _picWidth, _picHeigh, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, attrs, &yuvPixelBuffer);
    if (err) {
        return NULL;
    }
    CFRelease(attrs);
    
    CVPixelBufferLockBaseAddress(yuvPixelBuffer, 0);
    
    uint8_t * yPtr = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(yuvPixelBuffer, 0);
    size_t strideY = CVPixelBufferGetBytesPerRowOfPlane(yuvPixelBuffer, 0);
    
    uint8_t * uvPtr = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(yuvPixelBuffer, 1);
    size_t strideUV = CVPixelBufferGetBytesPerRowOfPlane(yuvPixelBuffer, 1);
    
    for (int j = 0; j < _picHeigh; j++) {
        for (int i = 0; i < _picWidth; i++) {
            int16_t y = (0.257*r + 0.504*g + 0.098*b) + 16;
            if (y > 255) {
                y = 255;
            } else if (y < 0) {
                y = 0;
            }
            
            yPtr[j*strideY + i] = (uint8_t)y;
        }
    }
    
    for (int j = 0; j < _picHeigh/2; j++) {
        for (int i = 0; i < _picWidth/2; i++) {
            int16_t u = (-0.148*r - 0.291*g + 0.439*b) + 128;
            int16_t v = (0.439*r - 0.368*g - 0.071*b) + 128;
            
            if (u > 255) {
                u = 255;
            } else if (u < 0) {
                u = 0;
            }
            
            if (v > 255) {
                v = 255;
            } else if (v < 0) {
                v = 0;
            }
            
            uvPtr[j*strideUV + i*2 + 0] = (uint8_t)u;
            uvPtr[j*strideUV + i*2 + 1] = (uint8_t)v;
        }
    }
    
    CVPixelBufferUnlockBaseAddress(yuvPixelBuffer, 0);
    
    return yuvPixelBuffer;
}

- (CGRect)getRenderPosition{
    float frameWidth = CGRectGetWidth(self.bounds);
    float frameHeigh = CGRectGetHeight(self.bounds);
    
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
    
    int width = frameWidth * widthRatio;
    int heigh = frameHeigh * heighRatio;
    CGRect renderRect = CGRectMake(frameWidth/2 - width/2, frameHeigh/2 - heigh/2, width, heigh);
    return renderRect;
}


- (void)displayingLinkDraw{
    [self openGLRender];
}

#pragma mark - openglDelegate
- (void)setContianerFrame:(CGRect)rect{
    [self setFrame:rect];
}

- (void)openGLRender{
    if(_pixelBuffer){
        CVPixelBufferRef pixelbuffer = CVPixelBufferRetain(_pixelBuffer);
        [self setPixelBuffer:_pixelBuffer];
        CVPixelBufferRelease(pixelbuffer);
        return;
    }
    
    NSString *imageName = [NSString stringWithFormat:@"container.jpg"];
    UIImage *image = [UIImage imageNamed:imageName];
    CVPixelBufferRef pixelbuffer = imageToYUVPixelBuffer(image);
    [self setPixelBuffer:pixelbuffer];
    CVPixelBufferRelease(pixelbuffer);
}

- (void)removeFromSuperContainer{
    [_displayLink invalidate];
    [self removeFromSuperlayer];
}

@end

#endif
