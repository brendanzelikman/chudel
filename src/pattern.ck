@import "hap.ck"

// Base pattern class
public class PatternFunc {
    float cycles;
    1.0 => float weight;
    1.0 => float density;
    fun Hap[] query(Arc arc, float cycles){ Hap haps[0]; return haps; }
    fun Hap[] query(Arc arc){ Hap haps[0]; return haps; }
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

        // Collect all factors
        float factors[0];
        for (0 => int i; i < rightHaps.size(); i++){
            rightHaps[i] @=> Hap rightHap;
            rightHap.getValue() => string note;
            Std.atof(note) => float factor;
            if (divide) 1.0 / factor => factor;
            factors << factor;
        }

        // Apply each factor to the left pattern
        for (0 => int i; i < factors.size(); i++){
            factors[i] => float factor;
            arc.start => float curStart;
            for (0 => int j; j < factor; j++){
                Arc subArc(curStart, arc.duration / factor);
                left.query(subArc, cycles * factor) @=> Hap subHaps[];
                for (0 => int k; k < subHaps.size(); k++){
                    out << subHaps[k];
                }
                (arc.duration / factor) +=> curStart;
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

public class _Note extends PatternEffect {
    fun @construct(PatternFunc base, PatternFunc effect){ return super.construct(base, effect); }
    fun Hap[] query(Arc arc, float cycles){ return applyKey(arc, cycles, "note"); }
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