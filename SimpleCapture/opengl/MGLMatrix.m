//
//  MGLMatrix.m
//  video
//
//  Created by bleach on 16/7/29.
//  Copyright © 2016年 howard_pang. All rights reserved.
//

#import "MGLMatrix.h"
#import <math.h>

//带set前缀的是直接替换现有的矩阵,不带set的是与现在的混合
@implementation MGLMatrix {
    GLfloat* elements;
}

- (instancetype)init {
    if (self = [super init]) {
        elements = (GLfloat *)malloc(sizeof(GLfloat) * 16);
        [self setIdentity];
    }
    
    return self;
}

- (MGLMatrix *)setIdentity {
    // [ 0 4  8 12 ]
    // [ 1 5  9 13 ]
    // [ 2 6 10 14 ]
    // [ 3 7 11 15 ]
    elements[ 0] = elements[ 5] = elements[10] = elements[15] = 1.0f;
    elements[ 1] = elements[ 2] = elements[ 3] = elements[ 4] =
    elements[ 6] = elements[ 7] = elements[ 8] = elements[ 9] =
    elements[11] = elements[12] = elements[13] = elements[14] = 0.0;
    
    return self;
}

- (MGLMatrix *)setLookAt:(GLfloat)eyeX eyeY:(GLfloat)eyeY eyeZ:(GLfloat)eyeZ centerX:(GLfloat)centerX centerY:(GLfloat)centerY centerZ:(GLfloat)centerZ upX:(GLfloat)upX upY:(GLfloat)upY upZ:(GLfloat)upZ {
    GLfloat fx = centerX - eyeX;
    GLfloat fy = centerY - eyeY;
    GLfloat fz = centerZ - eyeZ;
    
    // Normalize f.
    GLfloat rlf = 1 / sqrtf(fx*fx + fy*fy + fz*fz);
    fx *= rlf;
    fy *= rlf;
    fz *= rlf;
    
    // Calculate cross product of f and up.
    GLfloat sx = fy * upZ - fz * upY;
    GLfloat sy = fz * upX - fx * upZ;
    GLfloat  sz = fx * upY - fy * upX;
    
    // Normalize s.
    GLfloat  rls = 1 / sqrtf(sx*sx + sy*sy + sz*sz);
    sx *= rls;
    sy *= rls;
    sz *= rls;
    
    // Calculate cross product of s and f.
    GLfloat ux = sy * fz - sz * fy;
    GLfloat uy = sz * fx - sx * fz;
    GLfloat uz = sx * fy - sy * fx;
    
    // Set to this.
    elements[0] = sx;
    elements[1] = ux;
    elements[2] = -fx;
    elements[3] = 0;
    
    elements[4] = sy;
    elements[5] = uy;
    elements[6] = -fy;
    elements[7] = 0;
    
    elements[8] = sz;
    elements[9] = uz;
    elements[10] = -fz;
    elements[11] = 0;
    
    elements[12] = 0;
    elements[13] = 0;
    elements[14] = 0;
    elements[15] = 1;
    
    // Translate.
    return [self translate:-eyeX y:-eyeY z:-eyeZ];
}

- (MGLMatrix *)lookAt:(GLfloat)eyeX eyeY:(GLfloat)eyeY eyeZ:(GLfloat)eyeZ centerX:(GLfloat)centerX centerY:(GLfloat)centerY centerZ:(GLfloat)centerZ upX:(GLfloat)upX upY:(GLfloat)upY upZ:(GLfloat)upZ {
    MGLMatrix* matrix = [[MGLMatrix alloc] init];
    return [self multiply:[matrix setLookAt:eyeX eyeY:eyeY eyeZ:eyeZ centerX:centerX centerY:centerY centerZ:centerZ upX:upX upY:upY upZ:upZ]];
}

- (MGLMatrix *)setOrthographic:(GLfloat)left right:(GLfloat)right bottom:(GLfloat)bottom top:(GLfloat)top nearZ:(GLfloat)nearZ  farZ:(GLfloat)farZ {
    elements[ 0] = 2.0f / (right - left);
    elements[ 1] = 0.0;
    elements[ 2] = 0.0;
    elements[ 3] = 0.0;
    
    elements[ 4] = 0.0;
    elements[ 5] = 2.0f / (top - bottom);
    elements[ 6] = 0.0;
    elements[ 7] = 0.0;
    
    elements[ 8] = 0.0;
    elements[ 9] = 0.0;
    elements[10] = -2.0f / (farZ - nearZ);
    elements[11] = 0.0;
    
    elements[12] = -(right + left) / (right - left);
    elements[13] = -(top + bottom) / (top - bottom);
    elements[14] = -(farZ + nearZ) / (farZ - nearZ);
    elements[15] = 1.0f;
    
    return self;
}

- (MGLMatrix *)orthographic:(GLfloat)left right:(GLfloat)right bottom:(GLfloat)bottom top:(GLfloat)top nearZ:(GLfloat)nearZ  farZ:(GLfloat)farZ {
    MGLMatrix* matrix = [[MGLMatrix alloc] init];
    return [self multiply:[matrix setOrthographic:left right:right bottom:bottom top:top nearZ:nearZ farZ:farZ]];
}

- (MGLMatrix *)setTranslate:(GLfloat)x y:(GLfloat)y z:(GLfloat)z {
    // [ 0 4  8 12 ]   [ 1 0 0 x ]
    // [ 1 5  9 13 ] x [ 0 1 0 y ]
    // [ 2 6 10 14 ]   [ 0 0 1 z ]
    // [ 3 7 11 15 ]   [ 0 0 0 1 ]
    elements[0] = 1;  elements[4] = 0;  elements[8]  = 0;  elements[12] = x;
    elements[1] = 0;  elements[5] = 1;  elements[9]  = 0;  elements[13] = y;
    elements[2] = 0;  elements[6] = 0;  elements[10] = 1;  elements[14] = z;
    elements[3] = 0;  elements[7] = 0;  elements[11] = 0;  elements[15] = 1;
    return self;
};

- (MGLMatrix *)translate:(GLfloat)x y:(GLfloat)y z:(GLfloat)z {
    // [ 0 4  8 12 ]   [ 1 0 0 x ]
    // [ 1 5  9 13 ] x [ 0 1 0 y ]
    // [ 2 6 10 14 ]   [ 0 0 1 z ]
    // [ 3 7 11 15 ]   [ 0 0 0 1 ]
    elements[12] += elements[0] * x + elements[4] * y + elements[8]  * z;
    elements[13] += elements[1] * x + elements[5] * y + elements[9]  * z;
    elements[14] += elements[2] * x + elements[6] * y + elements[10] * z;
    elements[15] += elements[3] * x + elements[7] * y + elements[11] * z;
    return self;
};

- (MGLMatrix *)setScale:(GLfloat)xScale yScale:(GLfloat)yScale zScale:(GLfloat)zScale {
    // [ x 4  8 12 ]
    // [ 1 y  9 13 ]
    // [ 2 6  z 14 ]
    // [ 3 7 11 15 ]
    elements[ 0] = xScale;
    elements[ 5] = yScale;
    elements[10] = zScale;
    elements[15] = 1.0f;
    
    elements[ 1] = elements[ 2] = elements[ 3] = elements[ 4] =
    elements[ 6] = elements[ 7] = elements[ 8] = elements[ 9] =
    elements[11] = elements[12] = elements[13] = elements[14] = 0.0;
    return self;
}

- (MGLMatrix *)scale:(GLfloat)xScale yScale:(GLfloat)yScale zScale:(GLfloat)zScale {
    // [ x 4  8 12 ]
    // [ 1 y  9 13 ]
    // [ 2 6  z 14 ]
    // [ 3 7 11 15 ]
    elements[0] *= xScale;  elements[4] *= yScale;  elements[8]  *= zScale;
    elements[1] *= xScale;  elements[5] *= yScale;  elements[9]  *= zScale;
    elements[2] *= xScale;  elements[6] *= yScale;  elements[10] *= zScale;
    elements[3] *= xScale;  elements[7] *= yScale;  elements[11] *= zScale;
    return self;
}

- (MGLMatrix *)setRotate:(GLfloat)deg xAxis:(GLfloat)xAxis yAxis:(GLfloat)yAxis zAxis:(GLfloat)zAxis {
    GLfloat radian = M_PI * deg / 180;
    
    GLfloat s = sinf(radian);
    GLfloat c = cos(radian);
    
    if (0 != xAxis && 0 == yAxis && 0 == zAxis) {
        // Rotation around X axis
        if (xAxis < 0) {
            s = -s;
        }
        elements[0] = 1;  elements[4] = 0;  elements[ 8] = 0;  elements[12] = 0;
        elements[1] = 0;  elements[5] = c;  elements[ 9] =-s;  elements[13] = 0;
        elements[2] = 0;  elements[6] = s;  elements[10] = c;  elements[14] = 0;
        elements[3] = 0;  elements[7] = 0;  elements[11] = 0;  elements[15] = 1;
    } else if (0 == xAxis && 0 != yAxis && 0 == zAxis) {
        // Rotation around Y axis
        if (yAxis < 0) {
            s = -s;
        }
        elements[0] = c;  elements[4] = 0;  elements[ 8] = s;  elements[12] = 0;
        elements[1] = 0;  elements[5] = 1;  elements[ 9] = 0;  elements[13] = 0;
        elements[2] =-s;  elements[6] = 0;  elements[10] = c;  elements[14] = 0;
        elements[3] = 0;  elements[7] = 0;  elements[11] = 0;  elements[15] = 1;
    } else if (0 == xAxis && 0 == yAxis && 0 != zAxis) {
        // Rotation around Z axis
        if (zAxis < 0) {
            s = -s;
        }
        elements[0] = c;  elements[4] =-s;  elements[ 8] = 0;  elements[12] = 0;
        elements[1] = s;  elements[5] = c;  elements[ 9] = 0;  elements[13] = 0;
        elements[2] = 0;  elements[6] = 0;  elements[10] = 1;  elements[14] = 0;
        elements[3] = 0;  elements[7] = 0;  elements[11] = 0;  elements[15] = 1;
    } else {
        // Rotation around another axis
        GLfloat len = sqrtf(xAxis * xAxis + yAxis * yAxis + zAxis * zAxis);
        if (len != 1.0f) {
            GLfloat rlen = 1 / len;
            xAxis *= rlen;
            yAxis *= rlen;
            zAxis *= rlen;
        }
        GLfloat nc = 1 - c;
        GLfloat xy = xAxis * yAxis;
        GLfloat yz = yAxis * zAxis;
        GLfloat zx = zAxis * xAxis;
        GLfloat xs = xAxis * s;
        GLfloat ys = yAxis * s;
        GLfloat zs = zAxis * s;
        
        elements[ 0] = xAxis * xAxis * nc +  c;
        elements[ 1] = xy * nc + zs;
        elements[ 2] = zx * nc - ys;
        elements[ 3] = 0;
        
        elements[ 4] = xy * nc - zs;
        elements[ 5] = yAxis * yAxis * nc +  c;
        elements[ 6] = yz * nc + xs;
        elements[ 7] = 0;
        
        elements[ 8] = zx * nc + ys;
        elements[ 9] = yz * nc - xs;
        elements[10] = zAxis * zAxis * nc +  c;
        elements[11] = 0;
        
        elements[12] = 0;
        elements[13] = 0;
        elements[14] = 0;
        elements[15] = 1;
    }
    
    return self;
}

- (MGLMatrix *)rotate:(GLfloat)deg xAxis:(GLfloat)xAxis yAxis:(GLfloat)yAxis zAxis:(GLfloat)zAxis {
    MGLMatrix* matrix = [[MGLMatrix alloc] init];
    return [self multiply:[matrix setRotate:deg xAxis:xAxis yAxis:yAxis zAxis:zAxis]];
}

- (MGLMatrix *)multiply:(MGLMatrix *)other {
    // [ 0 4  8 12 ]   [ 0 4  8 12 ]
    // [ 1 5  9 13 ] x [ 1 5  9 13 ]
    // [ 2 6 10 14 ]   [ 2 6 10 14 ]
    // [ 3 7 11 15 ]   [ 3 7 11 15 ]
    GLfloat* e;
    GLfloat* a;
    GLfloat* b;
    GLfloat ai0, ai1, ai2, ai3;
    
    // Calculate e = a * b
    e = elements;
    a = elements;
    b = other.mtxElements;
    
    BOOL shouldFree = NO;
    if (e == b) {
        b = (GLfloat *)malloc(sizeof(GLfloat) * 16);
        for (GLuint i = 0; i < 16; ++i) {
            b[i] = e[i];
        }
        shouldFree = YES;
    }
    
    for (GLuint i = 0; i < 4; i++) {
        ai0=a[i];
        ai1=a[i + 4];
        ai2=a[i + 8];
        ai3=a[i + 12];
        e[i]      = ai0 * b[0]  + ai1 * b[1]  + ai2 * b[2]  + ai3 * b[3];
        e[i + 4]  = ai0 * b[4]  + ai1 * b[5]  + ai2 * b[6]  + ai3 * b[7];
        e[i + 8]  = ai0 * b[8]  + ai1 * b[9]  + ai2 * b[10] + ai3 * b[11];
        e[i + 12] = ai0 * b[12] + ai1 * b[13] + ai2 * b[14] + ai3 * b[15];
    }
    
    if (shouldFree) {
        free(b);
    }
    
    return self;
}

- (void)multiplyVector4:(MGLVertex4 *)vector4 {
    GLfloat vx = vector4->vx;
    GLfloat vy = vector4->vy;
    GLfloat vz = vector4->vz;
    GLfloat vw = vector4->vw;
    
    vector4->vx = vx * elements[0] + vy * elements[4] + vz * elements[ 8] + vw * elements[12];
    vector4->vy = vx * elements[1] + vy * elements[5] + vz * elements[ 9] + vw * elements[13];
    vector4->vz = vx * elements[2] + vy * elements[6] + vz * elements[10] + vw * elements[14];
    vector4->vw = vx * elements[3] + vy * elements[7] + vz * elements[11] + vw * elements[15];
}

- (GLfloat *)mtxElements {
    return elements;
}

- (void)dealloc {
    if (elements) {
        free(elements);
    }
}

@end
