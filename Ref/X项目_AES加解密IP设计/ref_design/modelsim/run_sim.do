##--- dump waveform and debug mode ---##
vlog -O0 -vlog01compat -f flist.f
vsim -c +nowarnTSCALE -voptargs=+acc -L ./work -l load.log tb_aes
radix hex
add log -r /tb_aes/*
do ./wave.do
run -all
