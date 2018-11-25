//
//  TextureGLKViewShader.h
//  SimpleCapture
//
//  Created by JFChen on 2018/11/10.
//  Copyright © 2018 duowan. All rights reserved.
//

#import <Foundation/Foundation.h>

#define STRINGIZE(x) #x
#define SHADER_STRING(text) @ STRINGIZE(text)

#define PictureEffect 0
#define BeautyEffect 1

#if PictureEffect
// vertex shader
static NSString *const TextureRGBVS = SHADER_STRING
(
 attribute vec3 aPos;
 attribute vec2 aTextCoord;
 attribute vec3 acolor;
 
 //纹理坐标，传给片段着色器的
 varying vec2 TexCoord;
 varying vec3 outColor;
 
 void main() {
     gl_Position = vec4(aPos,1.0);
     TexCoord = aTextCoord.xy;
     outColor = acolor.rgb;
 }
 );

// fragment shader
static NSString *const TextureRGBFS = SHADER_STRING
(
 
 //指明精度
 precision mediump float;
 
 //纹理坐标，从顶点着色器那里传过来
 varying mediump vec2 TexCoord;
 varying mediump vec3 outColor;
 
 //纹理采样器
 uniform sampler2D texture;
 
 uniform float sliderValue;
 uniform vec2 vecSize;
 uniform mat2 upsidedown;
 vec2 mosaicSize = vec2(16,16);
 
 vec4 dip_filter(mat3 _filter, sampler2D _image, vec2 _xy, vec2 texSize)
 {
     
     mat3 _filter_pos_delta_x=mat3(vec3(-1.0, 0.0, 1.0), vec3(0.0, 0.0 ,1.0) ,vec3(1.0,0.0,1.0));
     mat3 _filter_pos_delta_y=mat3(vec3(-1.0,-1.0,-1.0),vec3(-1.0,0.0,0.0),vec3(-1.0,1.0,1.0));
     vec4 final_color = vec4(0.0, 0.0, 0.0, 0.0);
     for(int i = 0; i<3; i++)
     {
         for(int j = 0; j<3; j++)
         {
             vec2 _xy_new = vec2(_xy.x + _filter_pos_delta_x[i][j], _xy.y + _filter_pos_delta_y[i][j]);
             vec2 _uv_new = vec2(_xy_new.x/texSize.x, _xy_new.y/texSize.y);
             final_color += texture2D(_image,_uv_new) * _filter[i][j];
         }
     }
     return final_color;
 }
 
 vec4 xposure(vec4 _color, float gray, float ex)
 {
     float b = (4.0*ex - 1.0);
     float a = 1.0 - b;
     float f = gray*(a*gray + b);
     return f*_color;
 }
 
 // https://blog.csdn.net/neng18/article/details/38083987?utm_source=tuicool&utm_medium=referral 图像效果参考这个博客
 void main() {
     //跟颜色值混合
     //     gl_FragColor = texture2D(texture, TexCoord) * vec4(outColor, 1.0);
     
     //正常显示
     //     gl_FragColor = texture2D(texture, TexCoord).rgba;
     
     /*
      {//图像翻转
      vec2 vecImageSize = vecSize;
      vec2 posNew = vec2(vecImageSize.x - TexCoord.x,vecImageSize.y-TexCoord.y);
      vec3 irgb = texture2D(texture,posNew).rgb;
      gl_FragColor = vec4(irgb,1.0);
      }
      */
     
     /*
      {//矩阵图像翻转
      vec3 irgb = texture2D(texture,TexCoord * upsidedown).rgb;
      gl_FragColor = vec4(irgb,1.0);
      }
      */
     
     /*
      {//浮雕
      vec2 tex = TexCoord;
      vec2 upLeftUV = vec2(tex.x-1.0/vecSize.x,tex.y-1.0/vecSize.y);
      vec4 curColor = texture2D(texture,TexCoord);
      vec4 upLeftColor = texture2D(texture,upLeftUV);
      vec4 delColor = curColor - upLeftColor;
      float h = 0.3*delColor.x + 0.59*delColor.y + 0.11*delColor.z;
      vec4 bkColor = vec4(0.5, 0.5, 0.5, 1.0);
      gl_FragColor = vec4(h,h,h,0.0) +bkColor;
      }
      */
     
     /*
      {//马赛克
      vec2 intXY = vec2(TexCoord.x*vecSize.x, TexCoord.y*vecSize.y);
      vec2 XYMosaic = vec2(floor(intXY.x/mosaicSize.x)*mosaicSize.x,floor(intXY.y/mosaicSize.y)*mosaicSize.y);
      vec2 UVMosaic = vec2(XYMosaic.x/vecSize.x,XYMosaic.y/vecSize.y);
      vec4 baseMap = texture2D(texture,UVMosaic);
      gl_FragColor = baseMap;
      }*/
     
     
     /*
      {// 模糊
      vec2 intXY = vec2(TexCoord.x * vecSize.x, TexCoord.y * vecSize.y);
      //box 模糊
      //          mat3 _smooth_fil = mat3(1.0/9.0,1.0/9.0,1.0/9.0,
      //                                  1.0/9.0,1.0/9.0,1.0/9.0,
      //                                  1.0/9.0,1.0/9.0,1.0/9.0);
      
      //拉普拉斯锐化
      //         mat3 _smooth_fil = mat3(-1.0,-1.0,-1.0,
      //                                 -1.0,9.0,-1.0,
      //                                 -1.0,-1.0,-1.0);
      
      mat3 _smooth_fil = mat3(1.0/16.0,2.0/16.0,1.0/16.0,
      2.0/16.0,4.0/16.0,2.0/16.0,
      1.0/16.0,2.0/16.0,1.0/16.0);
      
      vec4 tmp = dip_filter(_smooth_fil, texture, intXY, vecSize);
      gl_FragColor = tmp;
      }*/
     
     /*
      {// 描边
      vec2 intXY = vec2(TexCoord.x * vecSize.x, TexCoord.y * vecSize.y);
      //box 模糊
      mat3 _smooth_fil = mat3(-0.5,-1.0,0.0,
      -1.0,0.0,1.0,
      0.0,1.0,0.5);
      vec4 delColor = dip_filter(_smooth_fil, texture, intXY, vecSize);
      float deltaGray = 0.3*delColor.x + 0.59*delColor.y + 0.11*delColor.z;
      if(deltaGray < 0.0) deltaGray = -1.0 * deltaGray;
      deltaGray = 1.0 - deltaGray;
      gl_FragColor = vec4(deltaGray,deltaGray,deltaGray,1.0);
      }*/
     
      {// HDR + Blow
      float k = 1.6;
      vec4 _dsColor = texture2D(texture, TexCoord);
      float _lum = 0.3*_dsColor.x + 0.59*_dsColor.y;
      vec4 _fColor = texture2D(texture, TexCoord);
      gl_FragColor = xposure(_fColor, _lum, k);
      }
 }
 );

#endif


#if BeautyEffect
// vertex shader
static NSString *const TextureRGBVS = SHADER_STRING
(
 attribute vec3 aPos;
 attribute vec2 aTextCoord;
 attribute vec3 acolor;
 
 //纹理坐标，传给片段着色器的
 varying vec2 textureCoordinate;
 varying vec3 outColor;
 
 void main() {
     gl_Position = vec4(aPos,1.0);
     textureCoordinate = aTextCoord.xy;
     outColor = acolor.rgb;
 }
 );

// fragment shader
static NSString *const TextureRGBFS = SHADER_STRING
(
 
// //指明精度
// precision mediump float;
//
// //纹理坐标，从顶点着色器那里传过来
// varying mediump vec2 TexCoord;
// varying mediump vec3 outColor;
//
// //纹理采样器
// uniform sampler2D texture;
//
// void main() {
//     //跟颜色值混合
//    gl_FragColor = texture2D(texture, TexCoord) * vec4(outColor, 1.0);
 
     precision highp float;
     varying highp vec2 textureCoordinate;

      uniform sampler2D vTexture;

      uniform highp vec2 singleStepOffset;
      uniform highp vec4 params;
      uniform highp float brightness;
      uniform float texelWidthOffset;
      uniform float texelHeightOffset;

      const highp vec3 W = vec3(0.299, 0.587, 0.114);
      const highp mat3 saturateMatrix = mat3(
          1.1102, -0.0598, -0.061,
          -0.0774, 1.0826, -0.1186,
          -0.0228, -0.0228, 1.1772);
      highp vec2 blurCoordinates[24];

highp float hardLight(highp float color) {
      if (color <= 0.5)
          color = color * color * 2.0;
      else
          color = 1.0 - ((1.0 - color)*(1.0 - color) * 2.0);
      return color;
}

void main(){
      highp vec3 centralColor = texture2D(vTexture, textureCoordinate).rgb;
      vec2 singleStepOffset=vec2(texelWidthOffset,texelHeightOffset);
      blurCoordinates[0] = textureCoordinate.xy + singleStepOffset * vec2(0.0, -10.0);
      blurCoordinates[1] = textureCoordinate.xy + singleStepOffset * vec2(0.0, 10.0);
      blurCoordinates[2] = textureCoordinate.xy + singleStepOffset * vec2(-10.0, 0.0);
      blurCoordinates[3] = textureCoordinate.xy + singleStepOffset * vec2(10.0, 0.0);
      blurCoordinates[4] = textureCoordinate.xy + singleStepOffset * vec2(5.0, -8.0);
      blurCoordinates[5] = textureCoordinate.xy + singleStepOffset * vec2(5.0, 8.0);
      blurCoordinates[6] = textureCoordinate.xy + singleStepOffset * vec2(-5.0, 8.0);
      blurCoordinates[7] = textureCoordinate.xy + singleStepOffset * vec2(-5.0, -8.0);
      blurCoordinates[8] = textureCoordinate.xy + singleStepOffset * vec2(8.0, -5.0);
      blurCoordinates[9] = textureCoordinate.xy + singleStepOffset * vec2(8.0, 5.0);
      blurCoordinates[10] = textureCoordinate.xy + singleStepOffset * vec2(-8.0, 5.0);
      blurCoordinates[11] = textureCoordinate.xy + singleStepOffset * vec2(-8.0, -5.0);
      blurCoordinates[12] = textureCoordinate.xy + singleStepOffset * vec2(0.0, -6.0);
      blurCoordinates[13] = textureCoordinate.xy + singleStepOffset * vec2(0.0, 6.0);
      blurCoordinates[14] = textureCoordinate.xy + singleStepOffset * vec2(6.0, 0.0);
      blurCoordinates[15] = textureCoordinate.xy + singleStepOffset * vec2(-6.0, 0.0);
      blurCoordinates[16] = textureCoordinate.xy + singleStepOffset * vec2(-4.0, -4.0);
      blurCoordinates[17] = textureCoordinate.xy + singleStepOffset * vec2(-4.0, 4.0);
      blurCoordinates[18] = textureCoordinate.xy + singleStepOffset * vec2(4.0, -4.0);
      blurCoordinates[19] = textureCoordinate.xy + singleStepOffset * vec2(4.0, 4.0);
      blurCoordinates[20] = textureCoordinate.xy + singleStepOffset * vec2(-2.0, -2.0);
      blurCoordinates[21] = textureCoordinate.xy + singleStepOffset * vec2(-2.0, 2.0);
      blurCoordinates[22] = textureCoordinate.xy + singleStepOffset * vec2(2.0, -2.0);
      blurCoordinates[23] = textureCoordinate.xy + singleStepOffset * vec2(2.0, 2.0);

      highp float sampleColor = centralColor.g * 22.0;
      sampleColor += texture2D(vTexture, blurCoordinates[0]).g;
      sampleColor += texture2D(vTexture, blurCoordinates[1]).g;
      sampleColor += texture2D(vTexture, blurCoordinates[2]).g;
      sampleColor += texture2D(vTexture, blurCoordinates[3]).g;
      sampleColor += texture2D(vTexture, blurCoordinates[4]).g;
      sampleColor += texture2D(vTexture, blurCoordinates[5]).g;
      sampleColor += texture2D(vTexture, blurCoordinates[6]).g;
      sampleColor += texture2D(vTexture, blurCoordinates[7]).g;
      sampleColor += texture2D(vTexture, blurCoordinates[8]).g;
      sampleColor += texture2D(vTexture, blurCoordinates[9]).g;
      sampleColor += texture2D(vTexture, blurCoordinates[10]).g;
      sampleColor += texture2D(vTexture, blurCoordinates[11]).g;
      sampleColor += texture2D(vTexture, blurCoordinates[12]).g * 2.0;
      sampleColor += texture2D(vTexture, blurCoordinates[13]).g * 2.0;
      sampleColor += texture2D(vTexture, blurCoordinates[14]).g * 2.0;
      sampleColor += texture2D(vTexture, blurCoordinates[15]).g * 2.0;
      sampleColor += texture2D(vTexture, blurCoordinates[16]).g * 2.0;
      sampleColor += texture2D(vTexture, blurCoordinates[17]).g * 2.0;
      sampleColor += texture2D(vTexture, blurCoordinates[18]).g * 2.0;
      sampleColor += texture2D(vTexture, blurCoordinates[19]).g * 2.0;
      sampleColor += texture2D(vTexture, blurCoordinates[20]).g * 3.0;
      sampleColor += texture2D(vTexture, blurCoordinates[21]).g * 3.0;
      sampleColor += texture2D(vTexture, blurCoordinates[22]).g * 3.0;
      sampleColor += texture2D(vTexture, blurCoordinates[23]).g * 3.0;

      sampleColor = sampleColor / 62.0;

      highp float highPass = centralColor.g - sampleColor + 0.5;

      for (int i = 0; i < 5; i++) {
          highPass = hardLight(highPass);
      }
      highp float lumance = dot(centralColor, W);

      highp float alpha = pow(lumance, params.r);

      highp vec3 smoothColor = centralColor + (centralColor-vec3(highPass))*alpha*0.1;

      smoothColor.r = clamp(pow(smoothColor.r, params.g), 0.0, 1.0);
      smoothColor.g = clamp(pow(smoothColor.g, params.g), 0.0, 1.0);
      smoothColor.b = clamp(pow(smoothColor.b, params.g), 0.0, 1.0);

      highp vec3 lvse = vec3(1.0)-(vec3(1.0)-smoothColor)*(vec3(1.0)-centralColor);
      highp vec3 bianliang = max(smoothColor, centralColor);
      highp vec3 rouguang = 2.0*centralColor*smoothColor + centralColor*centralColor - 2.0*centralColor*centralColor*smoothColor;

      gl_FragColor = vec4(mix(centralColor, lvse, alpha), 1.0);
      gl_FragColor.rgb = mix(gl_FragColor.rgb, bianliang, alpha);
      gl_FragColor.rgb = mix(gl_FragColor.rgb, rouguang, params.b);

      highp vec3 satcolor = gl_FragColor.rgb * saturateMatrix;
      gl_FragColor.rgb = mix(gl_FragColor.rgb, satcolor, params.a);
      gl_FragColor.rgb = vec3(gl_FragColor.rgb + vec3(brightness));
    }
 );

#endif
