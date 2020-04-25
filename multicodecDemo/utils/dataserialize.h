//
//  dataserialize.h
//  g729codec
//
//  Created by JFChen on 2019/2/14.
//  Copyright © 2019 JFChen. All rights reserved.
//

#ifndef dataserialize_h
#define dataserialize_h

#include <stdio.h>

typedef enum FILEWRITETYPE {
    FILEWRITETYPEPCM = 0,
    FILEWRITETYPELSPL1,
    FILEWRITETYPELSPL2,
    FILEWRITETYPELSPL3,
} FILEWRITETYPE;

int openFileWithTag(FILEWRITETYPE tag);
void closeAllFileHandle(void);
int writeDataToFile(int16_t *data, uint32_t length,FILEWRITETYPE tag);
int writeCharDataToFile(char *data, uint32_t length,FILEWRITETYPE tag);
int writeIntValueToFile(int value,FILEWRITETYPE tag);

#endif /* dataserialize_h */
