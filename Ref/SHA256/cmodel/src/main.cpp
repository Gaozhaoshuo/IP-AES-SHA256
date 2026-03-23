#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <iostream>
//#include <chrono>
#include <ctime>
#include "../include/SHA256.h"

FILE	*fp_res;	//bin file
FILE	*fp_sta;	//txt file
int		blk_num;
// FILE *fp_res;：文件指针，用来写二进制文件 inout_sha256.bin。
// FILE *fp_sta;：文件指针，用来写文本日志文件 sta_sha256.log。

// blk_num 用于记录当前消息已经处理到了第几个 block（512bit 块），
// 在 SHA256.cpp::transform() 里用来打印 "block number: xxxx"。

// 把它们定义成全局变量是为了在 SHA256.cpp 那边也能访问这些文件指针和 blk_num


int main(int argc, char ** argv) {

	char	msg[10*1024] = "hello sha256";
	int		msg_len = 12;	
	int		test_num = 40;	
	int		len_pad;
	// 定义一个 10KB 的字符数组 msg，里面先放一行字符串 "hello sha256"。
	// msg_len 指定消息长度 = 12 字节（也就是 "hello sha256" 的长度）。
	// test_num 代表一共要产生 40 组测试数据（40 个“消息”）。
	// len_pad 存放这条消息 padding 之后的总长度（单位：字节），等会算完写进 bin 文件，从1开始计数。

	fp_res = fopen("./inout_sha256.bin", "wb");
	fp_sta = fopen("./sta_sha256.log", "w");
	// 打开两个输出文件

	// fopen("./inout_sha256.bin", "wb");
	// w = 写模式（如果文件已存在会被清空）；b = 二进制模式。
	// fp_res 就是一个指向这个 bin 文件的句柄。

	// fopen("./sta_sha256.log", "w");
	// 文本文件写模式，用于写入一些可读的 log 信息。

	// 之后所有 fwrite / fprintf 都会往这两个文件里写内容。

	fwrite(&test_num, sizeof(int), 1, fp_res);	//log test package number
	// 先把 test_num（40）以 binary 形式写进 inout_sha256.bin 文件的开头。
	// 将来 RTL testbench 读这个文件时，第一步会读出这个整数 → 知道一共有多少组测试。
	// 参数含义：
	// &test_num：要写的数据的地址
	// sizeof(int)：每个元素的大小
	// 1：写几个元素
	// fp_res：写到哪个文件里

	for(int i = 0 ; i < test_num; i++) {
		// i 从 0 到 39，每一轮生成一条消息并计算其 SHA256。
		SHA256 sha;
		// 每次循环创建一个新的 SHA256 对象，相当于“从头开始一条新的消息”。
		blk_num = 0;
		// 每个消息从 block 0 开始计数。
		// 对于第 0 组（i == 0），用的是初始化时的 "hello sha265"，长度 12。
		if(i>0) {
			// 生成不同长度、随机内容的消息
			msg_len = 64*i + rand()%64;
				// 从第 1 组开始（i > 0）：
				// 	msg_len = 64*i + rand()%64;
				// 	例如 i=1 时：msg_len ≈ 64 ~ 127
				// 		i=2 时：msg_len ≈ 128 ~ 191
				// 		消息越来越长。
				// rand()%64 产生 0~63 之间的随机数。

			for(int j=0; j<msg_len; j++) {
				msg[j] = rand()%256;
				// 把 msg[0..msg_len-1] 填成 0~255 的随机字节。
				// 所以每条消息内容都不同，长度也不同，用来测试 SHA256 硬件是否对各种情况都正确。
			}
		}

		if((msg_len%64) <= 55)
			len_pad = ((msg_len >> 6) + 1) << 6;
		else
			len_pad = ((msg_len >> 6) + 2) << 6;
		// 这段是在算：padding 之后，这条消息总共会占多少个字节。

		// msg_len % 64 是当前消息最后一个块已经用了多少字节。
		// msg_len >> 6 等价于 msg_len / 64（右移 6 位就是除以 2⁶ = 64）。

		// 若当前块剩余空间 ≥ 8 字节((msg_len%64) <= 55)（可以容纳：0x80 + 填充0 + 8-byte 长度）
		// len_pad = ((msg_len >> 6) + 1) << 6;
		// +1：只需要再补到“下一个 64 字节整数倍”的总长度。
		// << 6：乘回 64（变回字节长度）。

		// 若当前块剩余空间 < 8 字节((msg_len%64) > 55)，这一块放不下长度字段，需要再多一个块：
		// len_pad = ((msg_len >> 6) + 2) << 6;
		// +2：当前块补满 + 再开一块给长度字段。
		// << 6：乘回 64（变回字节长度）。

		fwrite(&len_pad, sizeof(int), 1, fp_res);
		// 每条消息的最前面，在 bin 文件里先写一个 len_pad（4 字节 int）。
		// 将来 RTL testbench 读 bin 文件时：
		// 先读这个 len_pad → 知道后面有多少个字节是“这条消息 padding 之后的输入数据”。
		// 然后再读 len_pad 个字节的数据并喂给 SHA256 RTL。

		// 开头整体结构大概是这样的：
		// [ test_num (4B) ]
		// [ len_pad_0 (4B) ][ msg0 的原始数据（C模型内部会自己做pad） ]
		// [ len_pad_1 (4B) ][ msg1 的原始数据 ... ]
		// ...
		// len_pad 是为了让 testbench 知道硬件那边应该看到多少个字节的数据。

		fprintf(fp_sta, "Test package number: %04x\n", i);
		// fp_sta 是 txt 日志文件。

		//sha.update(msg);
		sha.update((const uint8_t * )msg, msg_len);
		uint8_t * digest = sha.digest();
		// 调用 SHA256 C 模型进行哈希计算

		// 把当前这条消息的前 msg_len 个字节喂给 SHA256。
		// update 内部会：
		// 累积数据到 64 字节的 m_data 缓冲
		// 每满 64 字节调用一次 transform()
		// 更新 m_bitlen 统计已处理的 bit 数

		// sha.digest()做最后的 padding + 处理最后剩下的块 + 输出 32 字节 hash。
		// 返回一个 uint8_t* 指针，指向 32 字节的堆内存（new[] 出来的）。

		// 此时 digest 指向的内存里就是 32 字节的 SHA256 值（big-endian）。

		std::cout << SHA256::toString(digest) << std::endl;
		// 把 32 字节的 hash 转换成 64 个十六进制字符的字符串，然后用 std::cout 打印到终端。
		delete[] digest;
		// 由于 digest() 内部是用 new uint8_t[32]; 分配的内存。
		// 所以用 delete[] 释放，防止内存泄漏。
	}

	fclose(fp_res);
	fclose(fp_sta);

	return EXIT_SUCCESS;
	// 循环结束后，关闭文件 & 返回
}
