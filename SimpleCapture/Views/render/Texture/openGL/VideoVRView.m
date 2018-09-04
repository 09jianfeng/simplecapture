//
//  VRPlayerView.m
//  VRPlayer
//
//  Created by huafeng chen on 16/3/30.
//  Copyright © 2016年 huafeng chen. All rights reserved.
//

#import "VideoVRView.h"
#import <GLKit/GLKit.h>
#import <CoreMotion/CoreMotion.h>
#import "GLProgram.h"

#define MAX_OVERTURE 95.0
#define MIN_OVERTURE 25.0
#define DEFAULT_OVERTURE 85.0

#define ROLL_CORRECTION  M_PI/2.0

static const GLfloat kColorConversion709[] = {
    1.164,  1.164, 1.164,
    0.0, -0.213, 2.112,
    1.793, -0.533,   0.0,
};

// Uniform index.
enum {
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_Y,
    UNIFORM_UV,
    UNIFORM_COLOR_CONVERSION_MATRIX,
    NUM_UNIFORMS
};
static GLint uniforms[NUM_UNIFORMS];


@interface VideoVRView () <GLKViewDelegate>

@property (strong, nonatomic) GLProgram     *program;
@property (strong, nonatomic) EAGLContext   *context;
@property (strong, nonatomic) GLKView       *glkView;
@property (assign, nonatomic) GLfloat const *preferredConversion;
@property (assign, nonatomic) GLKMatrix4     modelViewProjectionMatrix;
@property (assign, nonatomic) GLuint         vertexArrayID;
@property (assign, nonatomic) GLuint         vertexBufferID;
@property (assign, nonatomic) GLuint         vertexIndicesBufferID;
@property (assign, nonatomic) GLuint         vertexTexCoordID;
@property (assign, nonatomic) GLuint         vertexTexCoordAttributeIndex;
@property (assign, nonatomic) CGFloat        overture;
@property (strong, nonatomic) CADisplayLink *displayLink;

@property (strong, nonatomic) CMMotionManager *motionManager;

@property (assign, nonatomic) CVOpenGLESTextureRef      lumaTexture;
@property (assign, nonatomic) CVOpenGLESTextureRef      chromaTexture;
@property (assign, nonatomic) CVOpenGLESTextureCacheRef videoTextureCache;

@property (assign, nonatomic) int            numIndices;
@property (assign, nonatomic) float          fingerRotationX;
@property (assign, nonatomic) float          fingerRotationY;

@property (assign, nonatomic) float         pitch; //倾斜角，对应着x
@property (assign, nonatomic) float         croll; //翻滚角，对应着y
@property (assign, nonatomic) float         yaw;  //偏航角度，对应着Z
@property (strong, nonatomic) NSOperationQueue* motionQueue;
@end

@implementation VideoVRView{
    BOOL _isFullScreen;
    CMAttitude* _mineattitude;
}

@synthesize pixelBuffer = _pixelBuffer;

#pragma mark - 初始化
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self customInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self customInit];
    }
    return self;
}

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    
    if (self.superview != nil) {
        [self.displayLink invalidate];
        self.displayLink = [CADisplayLink displayLinkWithTarget:self
                                                       selector:@selector(render:)];
        self.displayLink.frameInterval = 2;
        [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop]
                               forMode:NSDefaultRunLoopMode];
    }
}

- (void)customInit {
    _isLandscape = YES;
    [self setupData];
    [self setupGL];
    [self setupGLKView];
    [self setupGestureRecognizer];
    [self setupNotifications];
    
    [self startDeviceMotion:nil];
}

- (void)setupData {
    self.overture            = DEFAULT_OVERTURE;
    self.preferredConversion = kColorConversion709;
}

- (void)setupGL {
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.context];
    
    [self buildProgram];
    
    GLfloat *vVertices  = NULL;
    GLfloat *vTextCoord = NULL;
    GLushort *indices   = NULL;
    int numVertices = 0;
    self.numIndices = esGenSphere(200, 1.0f, &vVertices,  NULL,
                                  &vTextCoord, &indices, &numVertices);
    
    glGenVertexArraysOES(1, &_vertexArrayID);
    glBindVertexArrayOES(self.vertexArrayID);
    // Vertex
    glGenBuffers(1, &_vertexBufferID);
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBufferID);
    glBufferData(GL_ARRAY_BUFFER,
                 numVertices*3*sizeof(GLfloat),
                 vVertices,
                 GL_STATIC_DRAW);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition,
                          3,
                          GL_FLOAT,
                          GL_FALSE,
                          sizeof(GLfloat) * 3,
                          NULL);
    // Texture Coordinates
    glGenBuffers(1, &_vertexTexCoordID);
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexTexCoordID);
    glBufferData(GL_ARRAY_BUFFER,
                 numVertices*2*sizeof(GLfloat),
                 vTextCoord,
                 GL_DYNAMIC_DRAW);
    glEnableVertexAttribArray(self.vertexTexCoordAttributeIndex);
    glVertexAttribPointer(self.vertexTexCoordAttributeIndex,
                          2,
                          GL_FLOAT,
                          GL_FALSE,
                          sizeof(GLfloat) * 2,
                          NULL);
    //Indices
    glGenBuffers(1, &_vertexIndicesBufferID);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, self.vertexIndicesBufferID);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER,
                 sizeof(GLushort) * self.numIndices,
                 indices, GL_STATIC_DRAW);
    
    if (self.videoTextureCache == NULL) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_videoTextureCache);
        if (err != noErr) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
            return;
        }
    }
    
    [self.program use];
    glUniform1i(uniforms[UNIFORM_Y], 0);
    glUniform1i(uniforms[UNIFORM_UV], 1);
    glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, self.preferredConversion);
    
    free(vVertices);
    free(vTextCoord);
    free(indices);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.glkView.frame = self.frame;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    self.glkView.frame = self.frame;
}

- (void)setupGLKView {
    self.glkView                       = [[GLKView alloc] initWithFrame:self.frame];
    self.glkView.delegate              = self;
    self.glkView.context               = self.context;
    self.glkView.drawableDepthFormat   = GLKViewDrawableDepthFormat24;
    self.glkView.enableSetNeedsDisplay = NO;
    self.glkView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.glkView];
    
    NSLayoutConstraint *widthConstraint   = [NSLayoutConstraint constraintWithItem:self.glkView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeWidth multiplier:1 constant:0];
    NSLayoutConstraint *heightConstraint  = [NSLayoutConstraint constraintWithItem:self.glkView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeHeight multiplier:1 constant:0];
    NSLayoutConstraint *centerXConstraint = [NSLayoutConstraint constraintWithItem:self.glkView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1 constant:0];
    NSLayoutConstraint *centerYConstraint = [NSLayoutConstraint constraintWithItem:self.glkView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];
    [self addConstraints:@[
                           widthConstraint,
                           heightConstraint,
                           centerXConstraint,
                           centerYConstraint,
                           ]];
    
}

- (void)buildProgram {

    NSString *fragmentShaderString = @"\
    precision mediump float;\
    uniform sampler2D SamplerY;\
    uniform sampler2D SamplerUV;\
    varying mediump vec2 v_textureCoordinate;\
    uniform mat3 colorConversionMatrix;\
    void main() {\
    mediump vec3 yuv;\
    lowp vec3 rgb;\
    yuv.x = (texture2D(SamplerY, v_textureCoordinate).r - (16.0/255.0))* 1.0;\
    yuv.yz = (texture2D(SamplerUV, v_textureCoordinate).rg - vec2(0.5, 0.5))* 1.0;\
    rgb = colorConversionMatrix * yuv;\
    gl_FragColor = vec4(rgb,1);\
    }";
    
    NSString *vertexShaderString = @"\
    attribute vec4 position;\
    attribute vec2 texCoord;\
    varying vec2 v_textureCoordinate;\
    uniform mat4 modelViewProjectionMatrix;\
    void main() {\
    v_textureCoordinate = texCoord;\
    gl_Position = modelViewProjectionMatrix * position;\
    }";

    self.program = [[GLProgram alloc] initWithVertexShaderString:vertexShaderString fragmentShaderString:fragmentShaderString];
    [self.program addAttribute:@"position"];
    [self.program addAttribute:@"texCoord"];
    
    if (![self.program link]) {
        NSString *programLog = [self.program programLog];
        NSLog(@"Program link log: %@", programLog);
        NSString *fragmentLog = [self.program fragmentShaderLog];
        NSLog(@"Fragment shader compile log: %@", fragmentLog);
        NSString *vertexLog = [self.program vertexShaderLog];
        NSLog(@"Vertex shader compile log: %@", vertexLog);
        self.program = nil;
        NSAssert(NO, @"Falied to link HalfSpherical shaders");
    }
    
    self.vertexTexCoordAttributeIndex = [self.program attributeIndex:@"texCoord"];
    
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = [self.program uniformIndex:@"modelViewProjectionMatrix"];
    uniforms[UNIFORM_Y] = [self.program uniformIndex:@"SamplerY"];
    uniforms[UNIFORM_UV] = [self.program uniformIndex:@"SamplerUV"];
    uniforms[UNIFORM_COLOR_CONVERSION_MATRIX] = [self.program uniformIndex:@"colorConversionMatrix"];
    
 
}

- (void)setupGestureRecognizer {
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] init];
    [pinch addTarget:self action:@selector(pinch:)];
    [self.glkView addGestureRecognizer:pinch];
}

- (void)pinch:(UIPinchGestureRecognizer *)sender {
    self.overture /= sender.scale;
    if (self.overture > MAX_OVERTURE)
        self.overture = MAX_OVERTURE;
    if (self.overture < MIN_OVERTURE)
        self.overture = MIN_OVERTURE;
}

- (void)setupNotifications {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [center addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [center addObserver:self selector:@selector(handleDeviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    self.displayLink.paused = YES;
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    self.displayLink.paused = NO;
}

- (void)handleDeviceOrientationDidChange:(NSNotification *)notification {
    if (!self.isUsingMotion) {
        return;
    }
    
    [self update];
}

#pragma mark - 生命周期结束
- (void)removeFromSuperview {
    [super removeFromSuperview];
    [self.displayLink invalidate];
}

- (void)dealloc {
    [self stopDeviceMotion];
    [self tearDownGL];
    [self unsetNotifications];
    [self unsetGLKView];
    
    if (_pixelBuffer != NULL) {
        CVPixelBufferRelease(_pixelBuffer);
    }
}

- (void)tearDownGL {
    [EAGLContext setCurrentContext:self.context];
    self.program = nil;
    self.glkView = nil;
    
    glDeleteBuffers(1, &_vertexBufferID);
    glDeleteVertexArraysOES(1, &_vertexArrayID);
    glDeleteBuffers(1, &_vertexTexCoordID);
    glDeleteBuffers(1, &_vertexIndicesBufferID);
    GLuint luma = CVOpenGLESTextureGetName(self.lumaTexture);
    glDeleteTextures(1, &luma);
    GLuint chroma = CVOpenGLESTextureGetName(self.chromaTexture);
    glDeleteTextures(1, &chroma);
    
    [self cleanUpTextures];
    if(_videoTextureCache) {
        CFRelease(_videoTextureCache);
    }
    [EAGLContext setCurrentContext:nil];
    self.context = nil;
}

- (void)unsetNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)unsetGLKView {
    [self.displayLink invalidate];
}


#pragma mark - 渲染
- (void)update {
    float aspect = fabs(self.bounds.size.width / self.bounds.size.height);
    
    //透视矩阵
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(self.overture), aspect, 0.1f, 400.0f);
    
    //model矩阵
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    modelViewMatrix = GLKMatrix4Scale(modelViewMatrix, 300.0, 300.0, 300.0);
    
    //摄像机矩阵
    GLKMatrix4 lookatMatrix = GLKMatrix4MakeLookAt(0, 0.0, 1.0, 0, 0, 0, 0, 1, 0);
    
    if (_isUsingMotion) {
        //顶点物体本身的x,y,z三个轴。
        //注意： x,y,z是对应于承载这个opengl es层的那个view的x,y,z。竖屏x,y,z就是跟屏幕的x,y,z轴一致。如果是横屏，则x轴与y轴跟屏幕的是对调的。 opengl这里的model的坐标参考系是跟view的一致的。
        modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, -M_PI_2, 1.0f, 0.0f, 0.0f);
        CMRotationMatrix a = _mineattitude.rotationMatrix;
        GLKMatrix4 rotatoinMatri = GLKMatrix4Make(a.m11, a.m21, a.m31, 0.0f,
                                                  a.m12, a.m22, a.m32, 0.0f,
                                                  a.m13, a.m23, a.m33, 0.0f,
                                                  0.0f,  0.0f,  0.0f,  1.0f);
        //手机平放在桌面，陀螺仪的方向是对应着lookat矩阵代表的摄像头方向是只向Z方向。（也就是说把Lookat矩阵的开始方向要对着Z的方向），并且摄像机Up方向是Y正方向。
        lookatMatrix = GLKMatrix4Multiply(lookatMatrix, rotatoinMatri);
        //look at的坐标系就是手机y坐标方向是Y轴，x坐标方向是x轴，正对着手机的Z轴。
        //注意：判断坐标系的时候要从模型最开始的状态，紧跟整个模型/摄像机在3D空间中的方向，然后再考虑摄像机应该绕着哪条轴旋转。不要被从手机看到的画面迷惑。 提示：可以把手机想象成整个3D模型中的一个平面，竖直放着手机，竖直方向是Y轴，横向是X轴，垂直于手机屏的是Z轴
        
        if(!_isLandscape){
            lookatMatrix = GLKMatrix4RotateX(lookatMatrix, self.fingerRotationX);
            //这里在屏幕上滑动的左右滑，为什么却是围绕着Z轴旋转？ 想象一下上面的注释，提示：抬起手机的时候lookat矩阵已经是指向了的球体的顶部（陀螺仪的旋转矩阵导致的）。
            lookatMatrix = GLKMatrix4RotateZ(lookatMatrix, -self.fingerRotationY);
        }else{
            lookatMatrix = GLKMatrix4RotateZ(lookatMatrix, self.fingerRotationX);
            lookatMatrix = GLKMatrix4RotateX(lookatMatrix, self.fingerRotationY);
        }
    }else{
        lookatMatrix = GLKMatrix4RotateX(lookatMatrix, self.fingerRotationX);
        lookatMatrix = GLKMatrix4RotateY(lookatMatrix, -self.fingerRotationY);
    }
    
    self.glkView.frame = self.frame;
    self.modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, lookatMatrix);
    self.modelViewProjectionMatrix = GLKMatrix4Multiply(self.modelViewProjectionMatrix, modelViewMatrix);
}

- (void)render:(CADisplayLink *)displayLink {
    @autoreleasepool {
        [self update];
        [self.glkView display];
    }
}


#pragma mark - generate sphere
static int esGenSphere(int numSlices, float radius, float **vertices, float **normals,
                float **texCoords, uint16_t **indices, int *numVertices_out) {
    int i;
    int j;
    int numParallels = numSlices / 2;
    int numVertices = ( numParallels + 1 ) * ( numSlices + 1 );
    int numIndices = numParallels * numSlices * 6;
    float angleStep = (2.0f *  M_PI) / ((float) numSlices);
    
    if ( vertices != NULL )
        *vertices = malloc ( sizeof(float) * 3 * numVertices );
    
    if ( texCoords != NULL )
        *texCoords = malloc ( sizeof(float) * 2 * numVertices );
    
    if ( indices != NULL )
        *indices = malloc ( sizeof(uint16_t) * numIndices );
    
    for ( i = 0; i < numParallels + 1; i++ ) {
        for ( j = 0; j < numSlices + 1; j++ ) {
            int vertex = ( i * (numSlices + 1) + j ) * 3;
            
            if ( vertices ) {
                (*vertices)[vertex + 0] = radius * sinf ( angleStep * (float)i ) *
                sinf ( angleStep * (float)j );
                (*vertices)[vertex + 1] = radius * cosf ( angleStep * (float)i );
                (*vertices)[vertex + 2] = radius * sinf ( angleStep * (float)i ) *
                cosf ( angleStep * (float)j );
            }
            
            if (texCoords) {
                int texIndex = ( i * (numSlices + 1) + j ) * 2;
                (*texCoords)[texIndex + 0] = (float) j / (float) numSlices;
                (*texCoords)[texIndex + 1] = 1.0f - ((float) i / (float) (numParallels));
            }
        }
    }
    
    // Generate the indices
    if ( indices != NULL ) {
        uint16_t *indexBuf = (*indices);
        for ( i = 0; i < numParallels ; i++ ) {
            for ( j = 0; j < numSlices; j++ ) {
                *indexBuf++  = i * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + ( j + 1 );
                
                *indexBuf++ = i * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + ( j + 1 );
                *indexBuf++ = i * ( numSlices + 1 ) + ( j + 1 );
            }
        }
    }
    
    if (numVertices_out) {
        *numVertices_out = numVertices;
    }
    
    return numIndices;
}


#pragma mark - texture cleanup
- (void)cleanUpTextures {
    if (self.lumaTexture) {
        CFRelease(self.lumaTexture);
        self.lumaTexture = NULL;
    }
    
    if (self.chromaTexture) {
        CFRelease(self.chromaTexture);
        self.chromaTexture = NULL;
    }
    
    // Periodic texture cache flush every frame
    CVOpenGLESTextureCacheFlush(self.videoTextureCache, 0);
}


#pragma mark - device motion management
- (void)startDeviceMotion:(NSError **)error {
    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.showsDeviceMovementDisplay = YES;
    self.motionQueue = [[NSOperationQueue alloc] init];
    self.motionManager.gyroUpdateInterval = 1.0/30.0;
    self.isUsingMotion = YES;
    
    self.motionManager.deviceMotionUpdateInterval = 1.0/30.0;
    __weak typeof(self) weakSelf = self;
    [self.motionManager startDeviceMotionUpdatesToQueue:self.motionQueue withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
        
        CMAttitude* attitude = motion.attitude;
        if (attitude == nil) return;
        _mineattitude = attitude;
        
        //手机平放在桌面，手机的左右两边的方向是Y轴，手机的上下是X轴，中心点指向屏幕外是Z轴
        float cPitch = attitude.pitch; // 绕着Y轴旋转
        float cRoll  = attitude.roll; // 绕着x轴旋转
        float cYaw   = attitude.yaw;  // 绕着Z轴旋转
        weakSelf.pitch = cPitch;
        weakSelf.croll = cRoll;
        weakSelf.yaw = cYaw;
    }];
}

- (void)stopDeviceMotion {
    self.isUsingMotion = NO;
    [self.motionManager stopDeviceMotionUpdates];
    [self.motionManager stopGyroUpdates];
    self.motionManager = nil;
    self.motionQueue = nil;
}

- (void)translateMotionToXY:(float)distX distY:(float)distY{
    distX *= -0.005;
    distY *= -0.005;
    self.fingerRotationX += distY * self.overture / 100;
    self.fingerRotationY -= distX * self.overture / 100;
    
    /*
    if (self.fingerRotationX > M_PI_2) {
        self.fingerRotationX = M_PI_2;
    } else if (self.fingerRotationX < -M_PI_2) {
        self.fingerRotationX = -M_PI_2;
    }*/
}

#pragma mark - touches
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    float distX = [touch locationInView:touch.view].x -
    [touch previousLocationInView:touch.view].x;
    float distY = [touch locationInView:touch.view].y -
    [touch previousLocationInView:touch.view].y;
    distX *= -0.005;
    distY *= -0.005;
    self.fingerRotationX += distY * self.overture / 100;
    self.fingerRotationY -= distX * self.overture / 100;
    
    /*
    if (self.fingerRotationX > M_PI_2) {
        self.fingerRotationX = M_PI_2;
    } else if (self.fingerRotationX < -M_PI_2) {
        self.fingerRotationX = -M_PI_2;
    }
     */
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    //self.isUsingMotion = NO;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    //self.isUsingMotion = YES;
}

#pragma mark - getter / setter
-(CVPixelBufferRef) pixelBuffer
{
    return _pixelBuffer;
}

- (void)setPixelBuffer:(CVPixelBufferRef)pb
{
    @synchronized (self) {
        if(_pixelBuffer) {
            CVPixelBufferRelease(_pixelBuffer);
        }
        _pixelBuffer = CVPixelBufferRetain(pb);
    }
}

#pragma mark - GLKViewDelegate
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    
    CVPixelBufferRef pixelBufferCp;
    @synchronized (self) {
        if (self.pixelBuffer == NULL) {
            return;
        }
        pixelBufferCp = CVPixelBufferRetain(self.pixelBuffer);
    }
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BITS);
    
    [self.program use];
    
    glBindVertexArrayOES(self.vertexArrayID);
    
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, GL_FALSE, self.modelViewProjectionMatrix.m);
    
    if (self.videoTextureCache == NULL) {
        NSLog(@"No video texture cache");
        return;
    }
    
    size_t planeCount = CVPixelBufferGetPlaneCount(pixelBufferCp);
    if(planeCount == 0) {
        NSLog(@"[VRender] pixel buffer plane count is 0");
        return;
    }
    

    [self cleanUpTextures];
    
    // Y-plane
    glActiveTexture(GL_TEXTURE0);
        
    int frameWidth = (int)CVPixelBufferGetWidth(self.pixelBuffer);
    int frameHeight = (int)CVPixelBufferGetHeight(self.pixelBuffer);

    CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                self.videoTextureCache,
                                                                pixelBufferCp,
                                                                NULL,
                                                                GL_TEXTURE_2D,
                                                                GL_RED_EXT,
                                                                frameWidth,
                                                                frameHeight,
                                                                GL_RED_EXT,
                                                                GL_UNSIGNED_BYTE,
                                                                0,
                                                                &_lumaTexture);
    if (err) {
        NSLog(@"[VRPlayView]Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    
    glBindTexture(CVOpenGLESTextureGetTarget(self.lumaTexture),
                  CVOpenGLESTextureGetName(self.lumaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // UV-plane.
    glActiveTexture(GL_TEXTURE1);
    err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                       self.videoTextureCache,
                                                       pixelBufferCp,
                                                       NULL,
                                                       GL_TEXTURE_2D,
                                                       GL_RG_EXT,
                                                       frameWidth / 2,
                                                       frameHeight / 2,
                                                       GL_RG_EXT,
                                                       GL_UNSIGNED_BYTE,
                                                       1,
                                                       &_chromaTexture);
    if (err) {
        NSLog(@"[VRPlayView]Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    
    glBindTexture(CVOpenGLESTextureGetTarget(self.chromaTexture),
                  CVOpenGLESTextureGetName(self.chromaTexture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glDrawElements(GL_TRIANGLES, self.numIndices,
                   GL_UNSIGNED_SHORT, 0);
    CVPixelBufferRelease(pixelBufferCp);
}

@end
