//
//  SelfDefineQua.h
//  g729codec
//
//  Created by JFChen on 2019/2/19.
//  Copyright © 2019 JFChen. All rights reserved.
//

#ifndef SelfDefineQua_h
#define SelfDefineQua_h

#include <stdio.h>

void bitsStatisticIn5(void);
void sortGlobalLSPCoefficient(void);

void bitsStatisticIn7(void);

void LSPL2DividedIntoTwo(int value, int *x, int *y);
int LSPL2GetCombineValue(int x, int y);

void LSPL3DividedIntoTwo(int value, int *x, int *y);
int LSPL3GetCombineValue(int x, int y);

void LSPL1DividedIntoTwo(int value, int *x, int *y);
int LSPL1GetCombineValue(int x, int y);

void testPermutation(void);

void getL1Keywords(int L1, short keywordValuesX[], short keywordValuesY[], int *keyLen);
int getL1XKeywordIndex(int keyword);
int getL1YKeywordIndex(int keyword);

#endif /* SelfDefineQua_h */
