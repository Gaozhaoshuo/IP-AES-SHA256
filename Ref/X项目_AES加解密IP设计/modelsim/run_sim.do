##--- dump waveform and debug mode ---##
vlog -O0 -vlog01compat -f flist.f
vsim -c +nowarnTSCALE -voptargs=+acc -noglitch -L ./work -l load.log tb
radix hex
add log -r /tb/*
do ./wave.do
run -all
