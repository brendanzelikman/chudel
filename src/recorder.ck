// Utility file to record audio output
// e.g. `chuck livecode.ck src/recorder.ck`
"output.wav" => string filename;
dac => WvOut w => blackhole;
filename => w.wavFilename;
while (true) 1::second => now;