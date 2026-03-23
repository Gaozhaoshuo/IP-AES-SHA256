#include "../include/SHA256.h"
#include <cstring>
#include <sstream>
#include <iomanip>
#include <stdio.h>
#include <string.h>
#include <stdint.h>


extern FILE *fp_sta;
extern FILE *fp_res;
extern int	blk_num;

uint32_t K[64] = {
		0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,
		0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
		0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,
		0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
		0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,
		0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
		0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,
		0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
		0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,
		0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
		0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,
		0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
		0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,
		0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
		0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,
		0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
};

// m_blocklen(0), m_bitlen(0) 是构造函数初始化列表，先把两成员设为 0。
SHA256::SHA256(): m_blocklen(0), m_bitlen(0) {
	m_state[0] = 0x6a09e667;
	m_state[1] = 0xbb67ae85;
	m_state[2] = 0x3c6ef372;
	m_state[3] = 0xa54ff53a;
	m_state[4] = 0x510e527f;
	m_state[5] = 0x9b05688c;
	m_state[6] = 0x1f83d9ab;
	m_state[7] = 0x5be0cd19;
}


// 流式输入接口，可以多次调用，分块喂数据进来。
// m_data[64]：内部 512bit 缓存。
// 逻辑：
// 每读入 1 字节，存到 m_data[m_blocklen]，然后 m_blocklen++。
// 当 m_blocklen == 64：
// 说明凑满了一个 512bit block → 调用 transform() 对这一块执行压缩函数。
// m_bitlen += 512：累计已处理的 bit 数。
// m_blocklen = 0：重新从下一个块的第 0 字节开始。
void SHA256::update(const uint8_t * data, size_t length) {
	for (size_t i = 0 ; i < length ; i++) {
		m_data[m_blocklen++] = data[i];
		if (m_blocklen == 64) {
			transform();

			// End of the block
			m_bitlen += 512;
			m_blocklen = 0;
		}
	}
}


void SHA256::update(const std::string &data) {
	update(reinterpret_cast<const uint8_t*> (data.c_str()), data.size());
}


// hash = new uint8_t[32];：在堆上分配 32 字节存结果。
// pad();：完成 padding + 最后一个/两个 block 的 transform。
// revert(hash);：把内部状态 m_state[0..7] 转成 32 字节 big-endian 格式写到 hash。
// 返回指针，让调用者拿到结果。
uint8_t * SHA256::digest() {
	uint8_t * hash = new uint8_t[32];
	pad();
	revert(hash);
	return hash;
}


uint32_t SHA256::rotr(uint32_t x, uint32_t n) {
	return (x >> n) | (x << (32 - n));
}

uint32_t SHA256::choose(uint32_t e, uint32_t f, uint32_t g) {
	return (e & f) ^ (~e & g);
}

uint32_t SHA256::majority(uint32_t a, uint32_t b, uint32_t c) {
	return (a & (b | c)) | (b & c);
}

uint32_t SHA256::sig0(uint32_t x) {
	return SHA256::rotr(x, 7) ^ SHA256::rotr(x, 18) ^ (x >> 3);
}

uint32_t SHA256::sig1(uint32_t x) {
	return SHA256::rotr(x, 17) ^ SHA256::rotr(x, 19) ^ (x >> 10);
}


// 一个 512bit block 的核心计算
void SHA256::transform() {

	uint32_t maj, xorA, ch, xorE, sum, newA, newE, m[64];
	uint32_t state[8];

	// 写入 m_data 的 64 字节（16 * 4）。
	// 用于生成 inout_sha256.bin，让硬件 testbench 可以对照同样的输入。
	fwrite(m_data, sizeof(uint8_t), 16*4, fp_res);

	//--- log cal status of each round(before cal)
	fprintf(fp_sta, "block number: %08x\n", blk_num);

	// 把 64 字节拆成 16 个 32-bit word（大端）
	for (uint8_t i = 0, j = 0; i < 16; i++, j += 4) { // Split data in 32 bit blocks for the 16 first words
		m[i] = (m_data[j] << 24) | (m_data[j + 1] << 16) | (m_data[j + 2] << 8) | (m_data[j + 3]);
	}

	// 扩展到 m[16..63]
	for (uint8_t k = 16 ; k < 64; k++) { // Remaining 48 blocks
		m[k] = SHA256::sig1(m[k - 2]) + m[k - 7] + SHA256::sig0(m[k - 15]) + m[k - 16];
	}

	// 初始化 state = 当前哈希状态，state[0]..state[7] 对应 a..h。
	for(uint8_t i = 0 ; i < 8 ; i++) {
		state[i] = m_state[i];
	}

	// 64 轮主循环
	for (uint8_t i = 0; i < 64; i++) {
		fprintf(fp_sta, "round: %04x\n", i);
		fprintf(fp_sta, "w: %08x\n", m[i]);
		fprintf(fp_sta, "a: %08x\n", state[0]);
		fprintf(fp_sta, "b: %08x\n", state[1]);
		fprintf(fp_sta, "c: %08x\n", state[2]);
		fprintf(fp_sta, "d: %08x\n", state[3]);
		fprintf(fp_sta, "e: %08x\n", state[4]);
		fprintf(fp_sta, "f: %08x\n", state[5]);
		fprintf(fp_sta, "g: %08x\n", state[6]);
		fprintf(fp_sta, "h: %08x\n", state[7]);

		maj   = SHA256::majority(state[0], state[1], state[2]);
		xorA  = SHA256::rotr(state[0], 2) ^ SHA256::rotr(state[0], 13) ^ SHA256::rotr(state[0], 22);

		ch = choose(state[4], state[5], state[6]);

		xorE  = SHA256::rotr(state[4], 6) ^ SHA256::rotr(state[4], 11) ^ SHA256::rotr(state[4], 25);

	  //T1	 =  Wt  + Kt   +   h    + Ch(e,f,g) + E1(e)  
		sum  = m[i] + K[i] + state[7] + ch + xorE;
      //newa = E0(a)+Maaj(a,b,c) + T1 
		newA = xorA + maj + sum;
		newE = state[3] + sum;

		state[7] = state[6];
		state[6] = state[5];
		state[5] = state[4];
		state[4] = newE;
		state[3] = state[2];
		state[2] = state[1];
		state[1] = state[0];
		state[0] = newA;
	}

	// 把结果加回全局状态
	for(uint8_t i = 0 ; i < 8 ; i++) {
		m_state[i] += state[i];
	}

	blk_num++;
}

void SHA256::pad() {

	uint64_t i = m_blocklen;
	uint8_t end = m_blocklen < 56 ? 56 : 64;

	m_data[i++] = 0x80; // Append a bit 1
	while (i < end) {
		m_data[i++] = 0x00; // Pad with zeros
	}

	if(m_blocklen >= 56) {
		transform();
		memset(m_data, 0, 56);
	}

	// Append to the padding the total message's length in bits and transform.
	m_bitlen += m_blocklen * 8;
	m_data[63] = m_bitlen;
	m_data[62] = m_bitlen >> 8;
	m_data[61] = m_bitlen >> 16;
	m_data[60] = m_bitlen >> 24;
	m_data[59] = m_bitlen >> 32;
	m_data[58] = m_bitlen >> 40;
	m_data[57] = m_bitlen >> 48;
	m_data[56] = m_bitlen >> 56;
	transform();
}

void SHA256::revert(uint8_t * hash) {
	//log hash result
	fwrite(m_state, sizeof(uint32_t), 8, fp_res);	//log alen

	// SHA uses big endian byte ordering
	// Revert all bytes
	for (uint8_t i = 0 ; i < 4 ; i++) {
		for(uint8_t j = 0 ; j < 8 ; j++) {
			hash[i + (j * 4)] = (m_state[j] >> (24 - i * 8)) & 0x000000ff;
		}
	}
}

std::string SHA256::toString(const uint8_t * digest) {
	std::stringstream s;
	s << std::setfill('0') << std::hex;

	for(uint8_t i = 0 ; i < 32 ; i++) {
		s << std::setw(2) << (unsigned int) digest[i];
	}

	return s.str();
}
