// Random.h
#pragma once
#ifndef __RANDOM_H__
#define __RANDOM_H__

extern "C" {
    // Fills dest with 128 bits of random data
    void TVPGetRandomBits128(void *dest);
    
    // Pushes noise into the environment PRNG pool
    void TVPPushEnvironNoise(const void *source, int byte_size);
}

#endif
