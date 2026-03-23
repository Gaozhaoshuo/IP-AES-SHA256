#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

/* Enable modes in tiny-AES-c (must be defined before including aes.h) */
#define CBC 1
#define ECB 1
#define CTR 1

#include "aes.h"

/* -------------------- helpers -------------------- */
static const char* mode_name_lc(uint8_t blk_mode) { return (blk_mode == 0) ? "ecb" : "cbc"; }
static const char* mode_name_uc(uint8_t blk_mode) { return (blk_mode == 0) ? "ECB" : "CBC"; }

static void dump_hex_line(FILE *fp, const uint8_t *buf, uint32_t len)
{
    for (uint32_t i = 0; i < len; i++) fprintf(fp, "%02x", buf[i]);
    fprintf(fp, "\n");
}

static void dump_hex_pretty(FILE *fp, const char *title, const uint8_t *buf, uint32_t len)
{
    fprintf(fp, "%s (len=%u):\n", title, len);
    for (uint32_t off = 0; off < len; off += 16) {
        fprintf(fp, "  %04x: ", off);
        uint32_t n = (len - off >= 16) ? 16 : (len - off);
        for (uint32_t i = 0; i < n; i++) {
            fprintf(fp, "%02x", buf[off + i]);
            if (i != n - 1) fprintf(fp, " ");
        }
        fprintf(fp, "\n");
    }
}

/* -------------------- trace decrypt (self-check) -------------------- */
/* This reads an "enc trace" bin:
 * header: enc_dec(1B), blk_mode(1B), key_len(1B), test_bulk(4B), key(16/32), [iv(16 if CBC)]
 * each bulk: blk_byte(4B), plaintext(blk_byte), ciphertext(blk_byte)
 * Then decrypt ciphertext and compare with plaintext.
 */
static void hw_trace_decrypt(const char *fname)
{
    FILE *fp = fopen(fname, "rb");
    if (!fp) {
        printf("Open file %s for read failed.\n", fname);
        return;
    }

    uint8_t  enc_dec = (uint8_t)fgetc(fp);
    uint8_t  blk_mode = (uint8_t)fgetc(fp);
    uint8_t  key_len  = (uint8_t)fgetc(fp);
    uint32_t test_bulk = 0;

    fread(&test_bulk, sizeof(uint32_t), 1, fp);

    uint32_t key_bytes = (key_len == 0) ? 16u : 32u;
    uint8_t *key = (uint8_t*)malloc(key_bytes);
    if (!key) { fclose(fp); return; }
    fread(key, 1, key_bytes, fp);

    uint8_t *iv = NULL;
    if (blk_mode != 0) {
        iv = (uint8_t*)malloc(16);
        if (!iv) { free(key); fclose(fp); return; }
        fread(iv, 1, 16, fp);
    }

    printf("Verify by decrypting: %s\n", fname);
    printf("  enc_dec=%u, mode=%s, key_len=%s, bulk=%u\n",
           enc_dec, mode_name_uc(blk_mode), (key_len==0)?"128":"256", test_bulk);

    for (uint32_t bulk = 0; bulk < test_bulk; bulk++) {

        uint32_t blk_byte = 0;
        fread(&blk_byte, sizeof(uint32_t), 1, fp);
        if (blk_byte == 0 || (blk_byte % 16) != 0) {
            printf("  [BULK %u] invalid blk_len=%u\n", bulk, blk_byte);
            break;
        }

        uint8_t *plain_ref = (uint8_t*)malloc(blk_byte);
        uint8_t *cipher_in = (uint8_t*)malloc(blk_byte);
        if (!plain_ref || !cipher_in) {
            free(plain_ref);
            free(cipher_in);
            break;
        }

        fread(plain_ref, 1, blk_byte, fp);
        fread(cipher_in, 1, blk_byte, fp);

        /* decrypt in-place */
        struct AES_ctx ctx;
        uint32_t test_blk = blk_byte / 16;

        if (blk_mode == 0) {
            AES_init_ctx(&ctx, key);
            for (uint32_t i = 0; i < test_blk; i++) {
                AES_ECB_decrypt(&ctx, cipher_in + (i * 16));
            }
        } else {
            AES_init_ctx_iv(&ctx, key, iv);
            AES_CBC_decrypt_buffer(&ctx, cipher_in, blk_byte);
        }

        if (memcmp(cipher_in, plain_ref, blk_byte) == 0) {
            printf("  [BULK %u] success\n", bulk);
        } else {
            printf("  [BULK %u] FAIL\n", bulk);
        }

        free(plain_ref);
        free(cipher_in);
    }

    free(key);
    if (iv) free(iv);
    fclose(fp);
    printf("\n");
}

/* -------------------- trace encrypt case (bin + log) -------------------- */
static int hw_trace_encrypt_case(uint8_t blk_mode, const char *out_bin, const char *out_log)
{
    FILE *trc_bin = fopen(out_bin, "wb");
    FILE *trc_log = fopen(out_log, "w");
    if (!trc_bin || !trc_log) {
        printf("Open output failed: %s / %s\n", out_bin, out_log);
        if (trc_bin) fclose(trc_bin);
        if (trc_log) fclose(trc_log);
        return 1;
    }

    /* deterministic random for reproducible debug */
    srand(1);

    /* Example keys */
    uint8_t key16[16] = {
        0x2b,0x7e,0x15,0x16,0x28,0xae,0xd2,0xa6,0xab,0xf7,0x15,0x88,0x09,0xcf,0x4f,0x3c
    };
    uint8_t key32[32] = {
        0x60,0x3d,0xeb,0x10,0x15,0xca,0x71,0xbe,0x2b,0x73,0xae,0xf0,0x85,0x7d,0x77,0x81,
        0x1f,0x35,0x2c,0x07,0x3b,0x61,0x08,0xd7,0x2d,0x98,0x10,0xa3,0x09,0x14,0xdf,0xf4
    };

    /* Fixed plaintext prefix (64 bytes), extend with rand if bulk is larger */
    uint8_t plain_prefix[64] = {
        0x32,0x43,0xf6,0xa8,0x88,0x5a,0x30,0x8d,0x31,0x31,0x98,0xa2,0xe0,0x37,0x07,0x34,
        0xae,0x2d,0x8a,0x57,0x1e,0x03,0xac,0x9c,0x9e,0xb7,0x6f,0xac,0x45,0xaf,0x8e,0x51,
        0x30,0xc8,0x1c,0x46,0xa3,0x5c,0xe4,0x11,0xe5,0xfb,0xc1,0x19,0x1a,0x0a,0x52,0xef,
        0xf6,0x9f,0x24,0x45,0xdf,0x4f,0x9b,0x17,0xad,0x2b,0x41,0x7b,0xe6,0x6c,0x37,0x10
    };

    uint8_t iv[16] = {0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f};

    /* key_len in your trace format: 0=128, 2=256 */
#if defined(AES256) && (AES256 == 1)
    uint8_t  key_len = 2;
    uint8_t *key = key32;
    uint32_t key_bytes = 32;
    const char *ks = "256";
#else
    uint8_t  key_len = 0;
    uint8_t *key = key16;
    uint32_t key_bytes = 16;
    const char *ks = "128";
#endif

    uint32_t test_bulk = 10;

    /* -------- header: write bin -------- */
    fputc(0x01, trc_bin);                  /* enc_dec=1 (ENC) */
    fputc(blk_mode, trc_bin);
    fputc(key_len, trc_bin);
    fwrite(&test_bulk, sizeof(uint32_t), 1, trc_bin);
    fwrite(key, 1, key_bytes, trc_bin);
    if (blk_mode != 0) fwrite(iv, 1, 16, trc_bin);

    /* -------- header: write log -------- */
    fprintf(trc_log, "# AES TRACE DUMP (same content as bin)\n");
    fprintf(trc_log, "enc_dec=1 (ENC)\n");
    fprintf(trc_log, "blk_mode=%u (%s)\n", blk_mode, mode_name_uc(blk_mode));
    fprintf(trc_log, "key_len=%u (%s-bit)\n", key_len, ks);
    fprintf(trc_log, "test_bulk_num=%u\n", test_bulk);
    fprintf(trc_log, "KEY=");
    dump_hex_line(trc_log, key, key_bytes);
    if (blk_mode != 0) {
        fprintf(trc_log, "IV =");
        dump_hex_line(trc_log, iv, 16);
    }
    fprintf(trc_log, "\n");

    /* -------- bulks -------- */
    for (uint32_t bulk = 0; bulk < test_bulk; bulk++) {

        uint32_t test_blk = (bulk <= 4) ? (bulk + 1) : (3 * (bulk + 1));
        uint32_t blk_byte = test_blk * 16;

        /* allocate and fill plaintext */
        uint8_t *plain = (uint8_t*)malloc(blk_byte);
        uint8_t *cipher = (uint8_t*)malloc(blk_byte);
        if (!plain || !cipher) {
            free(plain); free(cipher);
            fclose(trc_bin); fclose(trc_log);
            return 1;
        }

        if (blk_byte <= 64) {
            memcpy(plain, plain_prefix, blk_byte);
        } else {
            memcpy(plain, plain_prefix, 64);
            for (uint32_t i = 64; i < blk_byte; i++) plain[i] = rand() % 256;
        }

        memcpy(cipher, plain, blk_byte);

        /* encrypt in-place into cipher */
        struct AES_ctx ctx;
        if (blk_mode == 0) {
            AES_init_ctx(&ctx, key);
            for (uint32_t i = 0; i < test_blk; i++) {
                AES_ECB_encrypt(&ctx, cipher + (i * 16));
            }
        } else {
            AES_init_ctx_iv(&ctx, key, iv);
            AES_CBC_encrypt_buffer(&ctx, cipher, blk_byte);
        }

        /* write bulk to bin: blk_len + plaintext + ciphertext */
        fwrite(&blk_byte, sizeof(uint32_t), 1, trc_bin);
        fwrite(plain, 1, blk_byte, trc_bin);
        fwrite(cipher, 1, blk_byte, trc_bin);

        /* write bulk to log */
        fprintf(trc_log, "[BULK %u]\n", bulk);
        fprintf(trc_log, "blk_len=%u\n", blk_byte);
        dump_hex_pretty(trc_log, "IN  (plaintext)", plain, blk_byte);
        dump_hex_pretty(trc_log, "OUT (ciphertext)", cipher, blk_byte);
        fprintf(trc_log, "\n");

        free(plain);
        free(cipher);
    }

    fclose(trc_bin);
    fclose(trc_log);
    printf("Generated: %s and %s\n", out_bin, out_log);
    return 0;
}

/* -------------------- generate + verify ECB/CBC for current key size -------------------- */
static void gen_and_verify_two_modes(void)
{
#if defined(AES256) && (AES256 == 1)
    const char *ks = "256b";
#elif defined(AES128) && (AES128 == 1)
    const char *ks = "128b";
#else
    /* fallback: if aes.h uses different macro style */
    const char *ks = "unknown";
#endif

    for (uint8_t blk_mode = 0; blk_mode <= 1; blk_mode++) {
        char bin_name[128];
        char log_name[128];

        snprintf(bin_name, sizeof(bin_name), "./aes_enc_%s_%s_trc.bin", ks, mode_name_lc(blk_mode));
        snprintf(log_name, sizeof(log_name), "./aes_enc_%s_%s_trc.log", ks, mode_name_lc(blk_mode));

        printf("\n=== CASE: %s %s ===\n", ks, mode_name_uc(blk_mode));
        if (hw_trace_encrypt_case(blk_mode, bin_name, log_name) == 0) {
            hw_trace_decrypt(bin_name);
        }
    }
}

int main(void)
{
#if defined(AES256) && (AES256 == 1)
    printf("Build target: AES256\n");
#elif defined(AES192) && (AES192 == 1)
    printf("Build target: AES192 (not used by generator)\n");
#elif defined(AES128) && (AES128 == 1)
    printf("Build target: AES128\n");
#else
    printf("Build target not specified in aes.h (AES128/AES256). Still trying.\n");
#endif

    gen_and_verify_two_modes();
    return 0;
}
