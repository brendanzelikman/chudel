@import "utils.ck"

public class Sampler {

    SndBuf buf => ADSR env;
    buf.gain(1.0);
    env.set(10::ms, 0::ms, 1.0, 10::ms);

    string filePath;
    // Samplers are loaded in by file
    fun @construct(string path){ path => filePath; buf.read(path); }
    fun @construct(string path, int base){ path => filePath; buf.read(path); base => baseNote; }

    // A base note is stored for relative pitch
    60 => int baseNote;
    fun void setBase(int base){ base => baseNote; }
    fun float getRate(int note){ return Math.pow(2.0, (note - baseNote) / 12.0); }

    // Play a note for a given duration
    fun void play(int note){ 
        getRate(note) => buf.rate; 
        0 => buf.pos; 
    }
    fun void envelope(dur duration){ env.keyOn(); Utils.cleanDur(duration - env.releaseTime()) => now; env.keyOff(); env.releaseTime() => now; }
    fun void playOnce(int note, dur duration){ play(note); envelope(duration);}
}