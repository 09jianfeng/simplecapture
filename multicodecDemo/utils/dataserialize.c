//
//  dataserialize.c
//  g729codec
//
//  Created by JFChen on 2019/2/14.
//  Copyright © 2019 JFChen. All rights reserved.
//

#include "dataserialize.h"
#include "time.h"
#include <stdlib.h>

FILE * openFileWithFileName(const char *fileName);
static FILE* fileHandles[10] = {NULL};

void getStringNameWithTag(FILEWRITETYPE tag, char *fileName){
    time_t timep;
    struct tm *p;
    time (&timep);
    p=gmtime(&timep);
    int mon = 1+p->tm_mon;
    int day = p->tm_mday;
    int hour = 8+p->tm_hour;
    int min = p->tm_min;
    int second = p->tm_sec;
    sprintf(fileName, "%d_%d_%d_%d_%d",mon,day,hour,min,second);
    
    switch (tag) {
        case FILEWRITETYPEPCM:
            sprintf(fileName, "%s_source.PCM",fileName);
            return;
        case FILEWRITETYPELSPL1:
            sprintf(fileName, "%s_LSPL1.txt",fileName);
            return;
        case FILEWRITETYPELSPL2:
            sprintf(fileName, "%s_LSPL2.txt",fileName);
            return;
        case FILEWRITETYPELSPL3:
            sprintf(fileName, "%s_LSPL3.txt",fileName);
            return;
            
        default:
            break;
    }
    
    return;
}

char* itoa(int val, int base){
    static char buf[32] = {0};
    int i = 30;
    
    if (val == 0) {
        buf[i--] = '0';
    }
    
    for(; val && i ; --i, val /= base)
        buf[i] = "0123456789abcdef"[val % base];
    return &buf[i+1];
}

int stringLen(char *string){
    int len = 0;
    while (string[len] != '\0') {
        len++;
    }
    
    return len;
}

int openFileWithTag(FILEWRITETYPE tag){
    if (fileHandles[tag] == NULL) {
        char fileName[100];
        getStringNameWithTag(tag,fileName);
        FILE *fileHandle = openFileWithFileName(fileName);
        if (fileHandle == NULL) {
            return -1;
        }
        
        fileHandles[tag] = fileHandle;
    }
    return 0;
}

FILE * openFileWithFileName(const char *fileName){
    FILE *fileHandle;
    if ((fileHandle = fopen(fileName, "wb")) == NULL){
        printf("error openning %s !! \n", fileName);
    }
    return fileHandle;
}

void closeAllFileHandle(void){
    for (int i = 0; i < 10; i++) {
        FILE *fileHandle = fileHandles[i];
        if (fileHandle != NULL) {
            fclose(fileHandles[i]);
        }
    }
}

void closeFileHandleWithTag(FILEWRITETYPE tag){
    FILE *fileHandle = fileHandles[tag];
    if (fileHandle != NULL) {
        fclose(fileHandle);
    }
}

int writeDataToFile(int16_t *data, uint32_t length,FILEWRITETYPE tag){
    FILE *fileHandle = fileHandles[tag];
    if (fileHandle == NULL) {
        return -1;
    }
    
    if(fwrite(data, sizeof(int16_t), length, fileHandle) != length){
        printf("error writting!!");
        return -1;
    }
    
    return 0;
}

int writeCharDataToFile(char *data, uint32_t length,FILEWRITETYPE tag){
    FILE *fileHandle = fileHandles[tag];
    if (fileHandle == NULL) {
        return -1;
    }
    
    if(fwrite(data, sizeof(char), length, fileHandle) != length){
        printf("error writting!!");
        return -1;
    }
    
    return 0;
}

int writeIntValueToFile(int value,FILEWRITETYPE tag){
    
    char *valueStr = itoa(value, 10);
    writeCharDataToFile(valueStr, stringLen(valueStr), tag);
    return 0;
}



