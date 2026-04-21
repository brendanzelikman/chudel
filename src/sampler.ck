@import "utils.ck"

public class Sampler {

    // Main audio chain
    SndBuf buf => ADSR env => Echo ec => Gain g => Pan2 p => dac;
    buf.gain(0.3);
    env.set(10::ms, 0::ms, 1.0, 10::ms);
    ec.mix(0);

    // Samplers are loaded in by file
    fun @construct(string path){ buf.read(me.dir() + path); }
    fun @construct(string path, int base){ buf.read(me.dir() + path); base => baseNote; }
    fun void discard(){ p =< dac; }

    // A base note is stored for relative pitch
    60 => int baseNote;
    fun void setBase(int base){ base => baseNote; }
    fun float getRate(int note){ return Math.pow(2.0, (note - baseNote) / 12.0); }

    // Parameters can be adjusted
    fun float gain(float g){ g => buf.gain; return g; }
    fun float pan(float pan){ pan => p.pan; return pan; }
    fun float echo(float echo){ echo => ec.mix; return echo; }

    // Play a note for a given duration and then discard
    fun void play(int note){ getRate(note) => buf.rate; 0 => buf.pos; }
    fun void envelope(dur duration){ env.keyOn(); Utils.cleanDur(duration - env.releaseTime()) => now; env.keyOff(); env.releaseTime() => now; }
    fun void playOnce(int note, dur duration){ play(note); envelope(duration); discard(); }
}