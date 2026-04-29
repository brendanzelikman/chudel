@import "utils.ck"

public class OscPlayer {
    ADSR env;
    env.set(10::ms, 0::ms, 1.0, 10::ms);
    60 => int baseNote;

    fun void setFreq(float f) { /* override in pitched subclasses */ }
    fun void play(int note) { setFreq(Std.mtof(note)); }
    fun void noteOff() { /* override */ }
    fun void envelope(dur duration) {
        env.keyOn();
        Utils.cleanDur(duration - env.releaseTime()) => now;
        env.keyOff();
        noteOff();
        env.releaseTime() => now;
    }
    fun void playOnce(int note, dur duration) { play(note); envelope(duration); }
}

public class StkPlayer extends OscPlayer {
    fun void play(int note) { super.play(note); noteOn(1.0); }
    fun void noteOn(float v) { /* override */ }
    fun void noteOff(float v) { /* override */ }
    fun void noteOff() { noteOff(1.0); }
}

public class SinOscPlayer extends OscPlayer {
    SinOsc osc => env;
    fun void setFreq(float f) { f => osc.freq; }
}

public class TriOscPlayer extends OscPlayer {
    TriOsc osc => env;
    fun void setFreq(float f) { f => osc.freq; }
}

public class SawOscPlayer extends OscPlayer {
    SawOsc osc => env;
    fun void setFreq(float f) { f => osc.freq; }
}

public class SqrOscPlayer extends OscPlayer {
    SqrOsc osc => env;
    fun void setFreq(float f) { f => osc.freq; }
}

public class PulseOscPlayer extends OscPlayer {
    PulseOsc osc => env;
    fun void setFreq(float f) { f => osc.freq; }
}

public class PhasorPlayer extends OscPlayer {
    Phasor osc => env;
    fun void setFreq(float f) { f => osc.freq; }
}

public class NoisePlayer extends OscPlayer {
    Noise osc => env;
    // No pitch - setFreq is no-op from base
}

public class CNoisePlayer extends OscPlayer {
    CNoise osc => env;
    // No pitch - setFreq is no-op from base
}

// Blit Oscillators
public class BLTPlayer extends OscPlayer { BLT osc => env; fun void setFreq(float f) { f => osc.freq; } }
public class BlitPlayer extends OscPlayer { Blit osc => env; fun void setFreq(float f) { f => osc.freq; } }
public class BlitSawPlayer extends OscPlayer { BlitSaw osc => env; fun void setFreq(float f) { f => osc.freq; } }
public class BlitSquarePlayer extends OscPlayer { BlitSquare osc => env; fun void setFreq(float f) { f => osc.freq; } }

// STK Physical Models
public class BandedWGPlayer extends StkPlayer { BandedWG osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class BlowBotlPlayer extends StkPlayer { BlowBotl osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class BlowHolePlayer extends StkPlayer { BlowHole osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class BowedPlayer extends StkPlayer { Bowed osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class BrassPlayer extends StkPlayer { Brass osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class ClarinetPlayer extends StkPlayer { Clarinet osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class FlutePlayer extends StkPlayer { Flute osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class MandolinPlayer extends StkPlayer { Mandolin osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class ModalBarPlayer extends StkPlayer { ModalBar osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class MoogPlayer extends StkPlayer { Moog osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class SaxofonyPlayer extends StkPlayer { Saxofony osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class ShakersPlayer extends StkPlayer { Shakers osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class SitarPlayer extends StkPlayer { Sitar osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class StifKarpPlayer extends StkPlayer { StifKarp osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class VoicFormPlayer extends StkPlayer { VoicForm osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }

// STK FM Instruments
public class KrstlChrPlayer extends StkPlayer { KrstlChr osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class BeeThreePlayer extends StkPlayer { BeeThree osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class FMVoicesPlayer extends StkPlayer { FMVoices osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class HevyMetlPlayer extends StkPlayer { HevyMetl osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class HnkyTonkPlayer extends StkPlayer { HnkyTonk osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class FrencHrnPlayer extends StkPlayer { FrencHrn osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class PercFlutPlayer extends StkPlayer { PercFlut osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class RhodeyPlayer extends StkPlayer { Rhodey osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class TubeBellPlayer extends StkPlayer { TubeBell osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
public class WurleyPlayer extends StkPlayer { Wurley osc => env; fun void setFreq(float f) { f => osc.freq; } fun void noteOn(float v) { v => osc.noteOn; } fun void noteOff(float v) { v => osc.noteOff; } }
