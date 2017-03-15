//
//  G711.h
//  MCAudioInputQueue
//
//  Created by sks on 2017/2/15.
//  Copyright © 2017年 Chengyin. All rights reserved.
//

#ifndef G711_h
#define G711_h

#include <stdint.h>

enum _e_g711_tp

{
    
    TP_ALAW, //G711A
    
    TP_ULAW //G711U
    
};



unsigned char linear2alaw(int pcm_val); /* 2's complement (16-bit range) */

int alaw2linear(unsigned char a_val);



unsigned char linear2ulaw(int pcm_val); /* 2's complement (16-bit range) */

int ulaw2linear(unsigned char u_val);



unsigned char alaw2ulaw(unsigned char aval);

unsigned char ulaw2alaw(unsigned char uval);

void G711Encoder(short *pcm,unsigned char *code,int size,int lawflag);

int g711_decode(void *pout_buf, int *pout_len, const void *pin_buf, const int in_len , int type);

int g711a_encode(unsigned char g711_data[], const short amp[], int len);

#endif /* G711_h */
