srcSourceCodeView
debImport "-f" "flist.f" "-2001" "-top" "tb_aes"
srcResizeWindow 107 48 1778 987
srcHBSelect "tb_aes.dut" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb_aes.dut" -delim "."
srcHBSelect "tb_aes.dut.core" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb_aes.dut.core" -delim "."
srcDeselectAll -win $_nTrace1
srcSelect -signal "next" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "keylen" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "block" -win $_nTrace1
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {97 97 12 13 9 1}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {103 103 12 13 9 1}
srcSearchString "block" -win $_nTrace1 -prev -case
srcSelect -win $_nTrace1 -range {97 97 12 13 9 1}
srcSearchString "block" -win $_nTrace1 -prev -case
srcSelect -win $_nTrace1 -range {55 55 14 15 1 1}
srcTraceLoad "tb_aes.dut.core.block\[127:0\]" -win $_nTrace1
srcHBSelect "tb_aes.dut.core.dec_block" -win $_nTrace1
srcHBSelect "tb_aes.dut.core.enc_block" -win $_nTrace1
srcHBSelect "tb_aes.dut.core.enc_block" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb_aes.dut.core.enc_block" -delim "."
srcDeselectAll -win $_nTrace1
srcSelect -signal "block" -win $_nTrace1
srcTraceLoad "tb_aes.dut.core.enc_block.block\[127:0\]" -win $_nTrace1
srcSelect -win $_nTrace1 -range {158 158 12 13 1 1}
srcNextTraced -scope
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {181 181 12 12 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {182 182 12 12 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {183 183 12 12 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {184 184 12 12 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {185 185 12 12 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {186 186 4 4 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {187 187 4 4 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {188 188 4 4 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {189 189 4 4 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {212 212 4 5 5 1}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {212 212 9 9 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {212 212 12 12 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {212 212 15 15 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {212 212 18 18 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {227 227 2 2 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {228 228 2 2 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {229 229 2 2 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {230 230 2 2 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {238 238 5 5 1 6}
srcSearchString "block" -win $_nTrace1 -next -case
srcSelect -win $_nTrace1 -range {239 239 2 2 1 6}
srcDeselectAll -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "new_sboxw" -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcSelect -signal "new_sboxw" -win $_nTrace1
srcAction -pos 282 5 4 -win $_nTrace1 -name "new_sboxw" -ctrlKey off
srcBackwardHistory -win $_nTrace1
srcDeselectAll -win $_nTrace1
srcAction -pos 292 5 8 -win $_nTrace1 -name "addkey_init_block" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "block" -win $_nTrace1
srcHBSelect "tb_aes.dut.core.enc_block" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb_aes.dut.core.enc_block" -delim "."
srcDeselectAll -win $_nTrace1
srcSelect -signal "new_block" -win $_nTrace1
srcAction -pos 62 13 2 -win $_nTrace1 -name "new_block" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcSelect -signal "block_w0_reg" -win $_nTrace1
srcAction -pos 211 8 7 -win $_nTrace1 -name "block_w0_reg" -ctrlKey off
srcDeselectAll -win $_nTrace1
srcHBSelect "tb_aes.dut.core.enc_block" -win $_nTrace1
srcSetScope -win $_nTrace1 "tb_aes.dut.core.enc_block" -delim "."
srcDeselectAll -win $_nTrace1
srcSelect -signal "new_block" -win $_nTrace1
debExit
