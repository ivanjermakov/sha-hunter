#include <cstdint>
#include <string.h>
#include <stdio.h>

#include <stdlib.h>
#include <memory.h>
#include <curand_kernel.h>

#define SHA256_BLOCK_SIZE 32
#define MESSAGE_SIZE 14
#define RAND_SIZE 5
#define TARGET_NONCE 3
#define BLOCKS 1
#define THREADS 1024
#define HASHES_PER_CHECK 100

typedef struct {
	uint8_t data[64];
	uint32_t datalen;
	unsigned long long bitlen;
	uint32_t state[8];
} CUDA_SHA256_CTX;

#ifndef ROTLEFT
#define ROTLEFT(a,b) (((a) << (b)) | ((a) >> (32-(b))))
#endif

#define ROTRIGHT(a,b) (((a) >> (b)) | ((a) << (32-(b))))

#define CH(x,y,z) (((x) & (y)) ^ (~(x) & (z)))
#define MAJ(x,y,z) (((x) & (y)) ^ ((x) & (z)) ^ ((y) & (z)))
#define EP0(x) (ROTRIGHT(x,2) ^ ROTRIGHT(x,13) ^ ROTRIGHT(x,22))
#define EP1(x) (ROTRIGHT(x,6) ^ ROTRIGHT(x,11) ^ ROTRIGHT(x,25))
#define SIG0(x) (ROTRIGHT(x,7) ^ ROTRIGHT(x,18) ^ ((x) >> 3))
#define SIG1(x) (ROTRIGHT(x,17) ^ ROTRIGHT(x,19) ^ ((x) >> 10))

__constant__ const char charset[] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

__constant__ uint32_t k[64] = {
	0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
	0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
	0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
	0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
	0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
	0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
	0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
	0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
};

__device__  __forceinline__ void cuda_sha256_transform(CUDA_SHA256_CTX *ctx, const uint8_t data[]) {
	uint32_t a, b, c, d, e, f, g, h, i, j, t1, t2, m[64];

	for (i = 0, j = 0; i < 16; ++i, j += 4)
		m[i] = (data[j] << 24) | (data[j + 1] << 16) | (data[j + 2] << 8) | (data[j + 3]);
	for ( ; i < 64; ++i)
		m[i] = SIG1(m[i - 2]) + m[i - 7] + SIG0(m[i - 15]) + m[i - 16];

	a = ctx->state[0];
	b = ctx->state[1];
	c = ctx->state[2];
	d = ctx->state[3];
	e = ctx->state[4];
	f = ctx->state[5];
	g = ctx->state[6];
	h = ctx->state[7];

	for (i = 0; i < 64; ++i) {
		t1 = h + EP1(e) + CH(e,f,g) + k[i] + m[i];
		t2 = EP0(a) + MAJ(a,b,c);
		h = g;
		g = f;
		f = e;
		e = d + t1;
		d = c;
		c = b;
		b = a;
		a = t1 + t2;
	}

	ctx->state[0] += a;
	ctx->state[1] += b;
	ctx->state[2] += c;
	ctx->state[3] += d;
	ctx->state[4] += e;
	ctx->state[5] += f;
	ctx->state[6] += g;
	ctx->state[7] += h;
}

__device__ void cuda_sha256_init(CUDA_SHA256_CTX *ctx) {
	ctx->datalen = 0;
	ctx->bitlen = 0;
	ctx->state[0] = 0x6a09e667;
	ctx->state[1] = 0xbb67ae85;
	ctx->state[2] = 0x3c6ef372;
	ctx->state[3] = 0xa54ff53a;
	ctx->state[4] = 0x510e527f;
	ctx->state[5] = 0x9b05688c;
	ctx->state[6] = 0x1f83d9ab;
	ctx->state[7] = 0x5be0cd19;
}

__device__ void cuda_sha256_update(CUDA_SHA256_CTX *ctx, const uint8_t data[], size_t len) {
	uint32_t i;

	for (i = 0; i < len; ++i) {
		ctx->data[ctx->datalen] = data[i];
		ctx->datalen++;
		if (ctx->datalen == 64) {
			cuda_sha256_transform(ctx, ctx->data);
			ctx->bitlen += 512;
			ctx->datalen = 0;
		}
	}
}

__device__ void cuda_sha256_final(CUDA_SHA256_CTX *ctx, uint8_t hash[]) {
	uint32_t i;

	i = ctx->datalen;

	// Pad whatever data is left in the buffer.
	if (ctx->datalen < 56) {
		ctx->data[i++] = 0x80;
		while (i < 56)
			ctx->data[i++] = 0x00;
	}
	else {
		ctx->data[i++] = 0x80;
		while (i < 64)
			ctx->data[i++] = 0x00;
		cuda_sha256_transform(ctx, ctx->data);
		memset(ctx->data, 0, 56);
	}

	ctx->bitlen += ctx->datalen * 8;
	ctx->data[63] = ctx->bitlen;
	ctx->data[62] = ctx->bitlen >> 8;
	ctx->data[61] = ctx->bitlen >> 16;
	ctx->data[60] = ctx->bitlen >> 24;
	ctx->data[59] = ctx->bitlen >> 32;
	ctx->data[58] = ctx->bitlen >> 40;
	ctx->data[57] = ctx->bitlen >> 48;
	ctx->data[56] = ctx->bitlen >> 56;
	cuda_sha256_transform(ctx, ctx->data);

	for (i = 0; i < 4; ++i) {
		hash[i]      = (ctx->state[0] >> (24 - i * 8)) & 0x000000ff;
		hash[i + 4]  = (ctx->state[1] >> (24 - i * 8)) & 0x000000ff;
		hash[i + 8]  = (ctx->state[2] >> (24 - i * 8)) & 0x000000ff;
		hash[i + 12] = (ctx->state[3] >> (24 - i * 8)) & 0x000000ff;
		hash[i + 16] = (ctx->state[4] >> (24 - i * 8)) & 0x000000ff;
		hash[i + 20] = (ctx->state[5] >> (24 - i * 8)) & 0x000000ff;
		hash[i + 24] = (ctx->state[6] >> (24 - i * 8)) & 0x000000ff;
		hash[i + 28] = (ctx->state[7] >> (24 - i * 8)) & 0x000000ff;
	}
}

__global__ void hash_hunt(uint8_t* result, uint8_t* result_hash) {
    curandState state;
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    curand_init(1337, idx, blockIdx.x, &state);

    while (result[0] == 0) {
        for (size_t i = 0; i < HASHES_PER_CHECK; i++) {
            uint8_t in[MESSAGE_SIZE];

            char prefix[] = "ivnj-org/";
            memcpy(in, prefix, 9);

            for (int i = 0; i < RAND_SIZE; i++) {
                int key = curand(&state) % (sizeof(charset) - 1);
                in[MESSAGE_SIZE - RAND_SIZE + i] = charset[key];
            }

            uint8_t out[SHA256_BLOCK_SIZE];
            CUDA_SHA256_CTX ctx;
            cuda_sha256_init(&ctx);
            cuda_sha256_update(&ctx, in, MESSAGE_SIZE);
            cuda_sha256_final(&ctx, out);

            uint8_t nonce = 0;
            while (nonce < SHA256_BLOCK_SIZE) {
                if (out[nonce] != 0) break;
                nonce++;
            }
            if (nonce >= TARGET_NONCE) {
                memcpy(result, in, MESSAGE_SIZE);
                memcpy(result_hash, out, SHA256_BLOCK_SIZE);
            }
        }
    }
}

extern "C" {
    int hunt() {
        uint8_t* h_result = (uint8_t*)malloc(MESSAGE_SIZE);;
        uint8_t* h_result_hash = (uint8_t*)malloc(SHA256_BLOCK_SIZE);;
        cudaError_t error;

        uint8_t* d_result;
        uint8_t* d_result_hash;
        cudaMalloc(&d_result, MESSAGE_SIZE);
        cudaMemset(d_result, 0, MESSAGE_SIZE);
        cudaMalloc(&d_result_hash, SHA256_BLOCK_SIZE);

        hash_hunt<<<BLOCKS, THREADS>>>(d_result, d_result_hash);

        cudaDeviceSynchronize();
        error = cudaGetLastError();
        if (error != cudaSuccess) printf("error %s: %s\n", cudaGetErrorName(error), cudaGetErrorString(error));

        cudaMemcpy(h_result, d_result, MESSAGE_SIZE, cudaMemcpyDeviceToHost);
        cudaMemcpy(h_result_hash, d_result_hash, SHA256_BLOCK_SIZE, cudaMemcpyDeviceToHost);

        if (h_result[0] == 0) {
            printf("not found\n");
        } else {
            printf("%s ", h_result);
            for (size_t i = 0; i < SHA256_BLOCK_SIZE; i++) {
                printf("%02x", h_result_hash[i]);
            }
            printf("\n");
        }

        free(h_result);
        free(h_result_hash);
        cudaFree(d_result);
        cudaFree(d_result_hash);

        return 0;
    }
}
