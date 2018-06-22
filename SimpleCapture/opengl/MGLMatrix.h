//
//  MGLMatrix.h
//  video
//
//  Created by bleach on 16/7/29.
//  Copyright © 2016年 howard_pang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/gltypes.h>
#import "MGLCommon.h"

@interface MGLMatrix : NSObject

@property (nonatomic, readonly) GLfloat* mtxElements;

- (MGLMatrix *)setIdentity;

- (MGLMatrix *)setLookAt:(GLfloat)eyeX eyeY:(GLfloat)eyeY eyeZ:(GLfloat)eyeZ centerX:(GLfloat)centerX centerY:(GLfloat)centerY centerZ:(GLfloat)centerZ upX:(GLfloat)upX upY:(GLfloat)upY upZ:(GLfloat)upZ;

- (MGLMatrix *)lookAt:(GLfloat)eyeX eyeY:(GLfloat)eyeY eyeZ:(GLfloat)eyeZ centerX:(GLfloat)centerX centerY:(GLfloat)centerY centerZ:(GLfloat)centerZ upX:(GLfloat)upX upY:(GLfloat)upY upZ:(GLfloat)upZ;

- (MGLMatrix *)setOrthographic:(GLfloat)left right:(GLfloat)right bottom:(GLfloat)bottom top:(GLfloat)top nearZ:(GLfloat)nearZ  farZ:(GLfloat)farZ;

- (MGLMatrix *)orthographic:(GLfloat)left right:(GLfloat)right bottom:(GLfloat)bottom top:(GLfloat)top nearZ:(GLfloat)nearZ  farZ:(GLfloat)farZ;

- (MGLMatrix *)setTranslate:(GLfloat)x y:(GLfloat)y z:(GLfloat)z;

- (MGLMatrix *)translate:(GLfloat)x y:(GLfloat)y z:(GLfloat)z;

- (MGLMatrix *)setScale:(GLfloat)xScale yScale:(GLfloat)yScale zScale:(GLfloat)zScale;

- (MGLMatrix *)scale:(GLfloat)xScale yScale:(GLfloat)yScale zScale:(GLfloat)zScale;

- (MGLMatrix *)setRotate:(GLfloat)deg xAxis:(GLfloat)xAxis yAxis:(GLfloat)yAxis zAxis:(GLfloat)zAxis;

- (MGLMatrix *)rotate:(GLfloat)deg xAxis:(GLfloat)xAxis yAxis:(GLfloat)yAxis zAxis:(GLfloat)zAxis;

- (MGLMatrix *)multiply:(MGLMatrix *)other;

/* 利用矩阵做转换的点 */
- (void)multiplyVector4:(MGLVertex4 *)vector4;

@end

