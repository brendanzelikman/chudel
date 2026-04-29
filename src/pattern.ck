@import "hap.ck"

// Base pattern class
public class PatternFunc {
    float cycles;
    1.0 => float weight;
    1.0 => float density;
    fun Hap[] query(Arc arc, float cycles){ Hap haps[0]; return haps; }
    fun Hap[] query(Arc arc){ Hap haps[0]; return haps; }
}

// Returns a single hap spanning the queried arc with the raw string stored verbatim.
// Used for parameters (e.g. scale names) that must not be processed by mini.chug.
public class LiteralPatternFunc extends PatternFunc {
    string rawValue;
    fun Hap[] query(Arc arc, float cycles){
        Hap out[0];
        out << new Hap(new Map("note", rawValue), new Arc(arc.start, arc.duration));
        return out;
    }
}

// Scheduled pattern that can be queried for haps
public class Pattern {
    PatternFunc pattern;
    public @construct(PatternFunc p){ p @=> pattern; }

    fun Hap[] query(Arc arc, float cycles){ 
        pattern.query(arc, cycles) @=> Hap haps[];
        Hap out[0];
        for (0 => int i; i < haps.size(); i++){
            if (haps[i].within(arc)) out << haps[i];
        }
        return out; 
    }
    fun Pattern add(Pattern other){ return new Pattern(new _Combine(this.pattern, other.pattern)); }
}

// Time Stretch (Multiplication + Division)
public class Fast extends PatternFunc {
    PatternFunc left; // multiplicand
    PatternFunc right; // multiplier
    int divide;
    fun @construct(PatternFunc left, PatternFunc right, int divide){
        left @=> this.left;
        right @=> this.right;
        divide => this.divide;
    }
    fun @construct(PatternFunc left, PatternFunc right){
        left @=> this.left;
        right @=> this.right;
        0 => this.divide;
    }
    
    // Query the right pattern for its factors,
    // then apply them to the left pattern
    fun Hap[] query(Arc arc, float cycles){
        right.query(arc, cycles) @=> Hap rightHaps[];
        Hap out[0];

        if (rightHaps.size() == 0) return out;

        for (0 => int i; i < rightHaps.size(); i++){
            rightHaps[i] @=> Hap rightHap;
            rightHap.getValue() => string note;
            Std.atof(note) => float factor;
            if (divide) 1.0 / factor => factor;
            if (factor <= 0) continue;

            // Find the intersection of the current arc and the factor's arc
            arc.start => float s;
            arc.end => float e;
            if (rightHap.arc.start > s) rightHap.arc.start => s;
            if (rightHap.arc.end < e) rightHap.arc.end => e;
            if (s >= e) continue;

            // Scale the arc to the "fast" time
            new Arc(s * factor, (e - s) * factor) @=> Arc fastArc;
            
            // Query the base pattern
            left.query(fastArc, cycles * factor) @=> Hap subHaps[];
            
            // Scale the results back
            for (0 => int j; j < subHaps.size(); j++){
                subHaps[j] @=> Hap h;
                out << new Hap(h.value, new Arc(h.arc.start / factor, h.arc.duration / factor));
            }
        }
        return out;
    }
} 

// --------------------------------------------------
// Pattern Effects
// --------------------------------------------------

// Template for combinable pattern
public class PatternEffect extends PatternFunc {
    PatternFunc base;
    PatternFunc effect;
    
    fun @construct(PatternFunc base, PatternFunc effect){ construct(base, effect); }
    fun construct(PatternFunc base, PatternFunc effect){ base @=> this.base; effect @=> this.effect; }
    fun Hap[] query(Arc arc, float cycles){ return base.query(arc, cycles); }

    // Named method (not an overload) so subclasses can call it unambiguously via ChucK's super
    fun Hap[] applyKey(Arc arc, float cycles, string key){
        base.query(arc, cycles) @=> Hap baseHaps[];
        effect.query(arc, cycles) @=> Hap effectHaps[];
        baseHaps.size() => int baseSize;
        effectHaps.size() => int effectSize;
        Hap haps[0];

        // If there is no base or effect, return appropriately
        if (!baseSize && !effectSize) return haps;
        if (!baseSize) {
            for (0 => int i; i < effectSize; i++) {
                haps << effectHaps[i].copyWithNewValue(key, effectHaps[i].getValue());
            }
            return haps;
        }
        if (!effectSize) return baseHaps;

        // Otherwise, apply the effect to each relevant base
        for (0 => int i; i < baseHaps.size(); i++){
            for (0 => int j; j < effectHaps.size(); j++){
                if (!baseHaps[i].within(effectHaps[j].arc)) continue;
                haps << baseHaps[i].copyWithNewValue(key, effectHaps[j].getValue());
            }
        }
        return haps;
    }
}

// --------------------------------------------------
// Core Pattern Composition
// --------------------------------------------------

// Layers (comma operator)
public class _Combine extends PatternFunc {
    PatternFunc left;
    PatternFunc right;
    fun @construct(PatternFunc l, PatternFunc r){ l @=> left; r @=> right; }
    fun Hap[] query(Arc arc, float cycles){
        left.query(arc, cycles) @=> Hap leftHaps[];
        right.query(arc, cycles) @=> Hap rightHaps[];
        Hap out[0];
        for (0 => int i; i < leftHaps.size(); i++) out << leftHaps[i];
        for (0 => int i; i < rightHaps.size(); i++) out << rightHaps[i];
        return out;
    }
}


public class _Note extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "note"); }
}

// _N: selects sample index from folder (e.g. n("3") => hh:3)
// Distinct from _Note which sets playback pitch/rate
public class _N extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "n"); }
}

public class _Sound extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "sound"); }
}

public class _Scale extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "scale"); }
}

public class _Gain extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "gain"); }
}

public class _Pan extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "pan"); }
}

public class _Echo extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "echo"); }
}

public class _Midi extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "midi"); }
}

public class Add extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "offset"); }
}

public class _Jcrev extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "jcrev"); }
}

public class _Nrev extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "nrev"); }
}

public class _Prcrev extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "prcrev"); }
}

public class _Lpf extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "lpf"); }
}

public class _Hpf extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "hpf"); }
}

public class _Chorus extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "chorus"); }
}

public class _Shifter extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "shifter"); }
}

public class _Delay extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "delay"); }
}

public class _DelayL extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "delayl"); }
}

public class _DelayA extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "delaya"); }
}

public class _HalfRect extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "halfrect"); }
}

public class _FullRect extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "fullrect"); }
}

public class _BPF extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "bpf"); }
}

public class _BRF extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "brf"); }
}

public class _BiQuad extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "biquad"); }
}

public class _ResonZ extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "resonz"); }
}

public class _OnePole extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "onepole"); }
}

public class _OneZero extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "onezero"); }
}

public class _TwoPole extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "twopole"); }
}

public class _TwoZero extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "twozero"); }
}

public class _PoleZero extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "polezero"); }
}

public class _Modulate extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "modulate"); }
}