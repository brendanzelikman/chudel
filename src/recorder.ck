"output.wav" => string filename;

dac => WvOut w => blackhole;
filename => w.wavFilename;
while (true) 1::second => now;