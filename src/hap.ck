@import "scale.ck"
@import "sampler.ck"
@import "osc_source.ck"

public class Hap {
    Map value;
    Arc arc;
    fun @construct(Map v, Arc a){ v @=> value; a @=> arc; }
    fun Hap copy(){ return new Hap(value.copy(), arc.copy()); }
    fun Hap copyWithNewValue(string k, string v){ value.copy() @=> Map newValue; newValue.set(k, v); return new Hap(newValue, arc.copy()); }
    fun float start(){ return arc.start; }
    fun float duration(){ return arc.duration; }
    fun dur getDuration(){ return arc.duration::second; }
    fun float end(){ return arc.end; }
    fun int within(Arc arc){ return end() > arc.start && start() < arc.end; }
    fun string toString(){ return start() + " -> " + end() + " : " + getValue(); }
    fun void print(){<<<toString()>>>;}

    // --------------------------------------------------
    // Value / Access
    // --------------------------------------------------
    
    fun int has(string key){ return value.has(key); }
    fun string get(string key){ return value.get(key); }
    fun string get(string key, string default){ return value.has(key) ? value.get(key) : default; }
    fun string getString(string key){ return get(key); }
    fun string getString(string key, string default){ return get(key, default); }
    fun float getFloat(string key){ return Std.atof(value.get(key)); }
    fun float getFloat(string key, float default){ return value.has(key) ? Std.atof(value.get(key)) : default; }
    fun string getValue(){ return value.has("note") ? get("note") : value.has("value") ? get("value") : value.has("sound") ? get("sound") : ""; }

    // --------------------------------------------------
    // Properties
    // --------------------------------------------------

    // Notes
    60 => static int defaultNote;
    fun int getNote(){ 
        if (hasNote()) {
            if (has("scale")) return indexScale(); 
            return offsetNote(parseNote()); 
        }
        return defaultNote;
    }
    fun int isRest(){ return getNote() == -1 || getValue() == "-" || getValue() == "~"; }
    fun int hasNote(){ return value.has("note") || value.has("n"); }
    fun int parseNote(){ 
        if (value.has("note")) return Scale.getNote(get("note")); 
        if (value.has("n")) return 60 + (Std.atof(get("n")) $ int);
        return -1;
    }
    fun int offsetNote(int note){ return (note + (getOffset() $ int)); }
    fun int indexScale(){ 
        string key;
        if (value.has("note")) "note" => key; 
        else if (value.has("n")) "n" => key;
        else if (value.has("value")) "value" => key;
        else return defaultNote;

        Scale.indexScale(Scale.getScale(get("scale")), Std.atoi(get(key)) + (getOffset() $ int)) => int note;
    
        return note;
    }

    // I dont know if this is still needed but I'm leaving it for now. 
    // TODO: Could you check?
    // Sound
    "piano" => static string defaultSound;
    fun string getSound(){ return getString("sound", defaultSound); }

    // Offset (semitones)
    0 => static float offset;
    fun float getOffset(){ return getFloat("offset", offset); }

    // Gain
    1.0 => static float defaultGain;
    fun float getGain(){ return getFloat("gain", defaultGain); }

    // Pan
    0.0 => static float defaultPan;
    fun float getPan(){ return getFloat("pan", defaultPan); }

    // Echo
    0.0 => static float defaultEcho;
    fun float getEcho(){ return getFloat("echo", defaultEcho); }

}