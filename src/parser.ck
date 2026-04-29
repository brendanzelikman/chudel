@import "pattern.ck"
@import "utils.ck"

// -------------------------------------------------------
// CachedEvent - a decoded event from one parse call
// Times are normalized to 0->1 (one cycle)
// -------------------------------------------------------
public class CachedEvent {
    "0" => string number;
    string value;
    float start;
    float end;
}

// -------------------------------------------------------
// MiniPatternFunc
//   - Parses the input string ONCE via mini.chug on first query
//   - Caches the decoded event list; all subsequent queries are fast O(n)
//   - Arc mapping is pure ChucK arithmetic - no C++ calls per cycle
// -------------------------------------------------------
public class MiniPatternFunc extends PatternFunc {
    mini m;
    string rawInput;
    Map @ sounds;          // shared sound registry for token classification

    CachedEvent @ cache[0]; // decoded events (lazily populated)
    int parsed;             // 0 = not yet parsed
    int parsedCycle;        // last parsed cycle

    fun Hap[] query(Arc arc, float cycles) {
        rawInput.find("?") >= 0 => int hasDeg;
        rawInput.find("<") >= 0 => int hasSeq;
        rawInput.find("{") >= 0 => int hasPoly;
        rawInput.find("%") >= 0 => int hasFeet;
        rawInput.find("rand") >= 0 => int hasRand;
        rawInput.find("/") >= 0 => int hasDiv;
        rawInput.find("*") >= 0 => int hasMul;
        rawInput.find("|") >= 0 => int hasChoice;
        rawInput.find("!") >= 0 => int hasRep;
        rawInput.find("..") >= 0 => int hasRange;
        
        (hasDeg || hasSeq || hasPoly || hasFeet || hasRand || hasDiv || hasMul || hasChoice || hasRep || hasRange) => int isDynamic;
        
        if (!parsed || (isDynamic && (arc.start < parsedStart || arc.end > parsedEnd))) {
            new CachedEvent[0] @=> cache;
            if (isDynamic) {
                buildCache(arc.start, arc.end);
                arc.start => parsedStart;
                arc.end => parsedEnd;
            } else {
                buildCache(0, 1);
            }
            1 => parsed;
        }

        Hap out[0];
        if (isDynamic) {
            for (0 => int i; i < cache.size(); i++) {
                cache[i] @=> CachedEvent ev;
                Arc a(ev.start, ev.end - ev.start);
                out << new Hap(classify(ev.value, ev.number), a);
            }
        } else {
            Math.floor(arc.start) $ int => int s_cycle;
            Math.ceil(arc.end) $ int => int e_cycle;
            for (s_cycle => int c; c < e_cycle; c++) {
                for (0 => int i; i < cache.size(); i++) {
                    cache[i] @=> CachedEvent ev;
                    c + ev.start => float s;
                    c + ev.end => float e;
                    if (e > arc.start && s < arc.end) {
                        Arc a(s, e - s);
                        out << new Hap(classify(ev.value, ev.number), a);
                    }
                }
            }
        }
        return out;
    }

    float parsedStart, parsedEnd;

    // ------- Parse & decode -------

    fun void buildCache(float start, float end) {
        m.parse(rawInput, start, end) => string result;
    

        if (!result.length()) {
            // Fallback: single atom over the whole cycle
            CachedEvent ev;
            rawInput => ev.value;
            0.0 => ev.start;
            1.0 => ev.end;
            cache << ev;
            return;
        }

        // Format: "value:sn/sd->en/ed|..."
        Utils.split(result, "|") @=> string entries[];
        for (string entry : entries) {
            decodeEntry(entry) @=> CachedEvent ev;
            if (ev != null) cache << ev;
        }
    }

    fun CachedEvent decodeEntry(string entry) {
        entry.length() => int len;

        // Find last ':' followed by a digit or '-' (splits value from timing)
        -1 => int col;
        for (len - 1 => int i; i >= 0; i--) {
            if (entry.charAt2(i) == ":" && i + 1 < len && digitOrMinus(entry.charAt2(i + 1))) {
                i => col; break;
            }
        }
        if (col < 0) return null;

        entry.substring(0, col) => string value;
        entry.substring(col + 1) => string timing;

        // Find "->" in timing
        -1 => int arrow;
        for (0 => int i; i < timing.length() - 1; i++) {
            if (timing.charAt2(i) == "-" && timing.charAt2(i + 1) == ">") {
                i => arrow; break;
            }
        }
        if (arrow < 0) return null;

        CachedEvent ev;
        // Split "name, N" - comma is optional; bare name defaults to sample 0
        value.find(",") => int comma;
        if (comma >= 0) {
            value.substring(0, comma) => ev.value;
            // C++ mini emits the index as a float ("1.000000"); normalise to int string
            Std.itoa(Std.atof(value.substring(comma + 2)) $ int) => ev.number;
        } else {
            value => ev.value;
            "0" => ev.number;
        }
        frac(timing.substring(0, arrow)) => ev.start;
        frac(timing.substring(arrow + 2)) => ev.end;
        return ev;
    }

    // Parse "n/d" -> float
    fun float frac(string s) {
        -1 => int sl;
        for (0 => int i; i < s.length(); i++) {
            if (s.charAt2(i) == "/") { i => sl; break; }
        }
        if (sl < 0) return Std.atof(s);
        Std.atof(s.substring(sl + 1)) => float den;
        return den == 0.0 ? 0.0 : Std.atof(s.substring(0, sl)) / den;
    }

    // Classify a token into the right Map key for Hap
    // 'v' is the bare name ("arpy"), 'n' is the sample index ("4")
    // The Hap stores "arpy:4" so chudel.ck looks up the right path.
    fun Map classify(string v, string n) {
        if (v == "-" || v == "~") return new Map("note", v);
        if (sounds != null && sounds.has(v)) return new Map("sound", v + ":" + n);
        if (v.length() > 0 && (digit(v.charAt2(0)) || (v.charAt2(0) == "-" && v.length() > 1)))
            return new Map("value", v);
        return new Map("note", v);
    }

    fun int digit(string c) {
        return c == "0" || c == "1" || c == "2" || c == "3" || c == "4" ||
               c == "5" || c == "6" || c == "7" || c == "8" || c == "9";
    }
    fun int digitOrMinus(string c) {
        return c == "-" || digit(c);
    }
}

// -------------------------------------------------------
// Parser - wraps mini.chug, provides the same API surface
// as the old ChucK-native parser so chudel.ck is unchanged
// -------------------------------------------------------
public class Parser {
    mini m;
    Map sounds;
    Map bases;
    Map ugens;               // oscillator type registry: name -> name

    Sampler @ samplers[0];

    fun @construct() { init(me.dir(-1) + "Dirt-Samples/"); }
    fun @construct(string folderName) { init(folderName); }

    // Initialize the sound bank by scanning the folder for samples
    fun void init(string folderName) {
        if (folderName.charAt2(folderName.length()-1) != "/") {
            folderName + "/" => folderName;
        }

        FileIO fio;
        if (!fio.open( folderName, FileIO.READ )) {
            <<< "[Parser] Could not open sample directory:", folderName >>>;
            return;
        }
        fio.dirList() @=> string names[];

        // Import each subfolder
        string dirtSamples[names.size()][0];
        for(0 => int i; i < names.size(); i++){
            FileIO files;
            if(files.open(folderName + names[i], FileIO.READ )){
                files.dirList() @=> dirtSamples[names[i]];
            }
        } 

        // Iterate over each name
        for (string s : names) {
            if (dirtSamples[s].size() == 0) continue;
            60 => int base;
            if (s == "piano") 61 => base;
            else if (s == "bass") 48 => base;
            string baseStr;
            Std.itoa(base) => baseStr;

            // Register every sample in the folder as "name:N"
            for (0 => int n; n < dirtSamples[s].size(); n++) {
                folderName + s + "/" + dirtSamples[s][n] => string path;
                register(s + ":" + Std.itoa(n), path, baseStr);
            }

            // Also register bare name -> sample 0 for classify() lookup
            if (dirtSamples[s].size() > 0) {
                folderName + s + "/" + dirtSamples[s][0] => string path0;
                register(s, path0, baseStr);
            }
        }

        // Register built-in oscillator sources
        for (string osc : ["SinOsc", "TriOsc", "SawOsc", "SqrOsc", "PulseOsc", "Phasor", "Noise", "CNoise",
                           "BLT", "Blit", "BlitSaw", "BlitSquare", "BandedWG", "BlowBotl", "BlowHole",
                           "Bowed", "Brass", "Clarinet", "Flute", "Mandolin", "ModalBar", "Moog", "Saxofony", 
                           "Shakers", "Sitar", "StifKarp", "VoicForm", "KrstlChr", "BeeThree",
                           "FMVoices", "HevyMetl", "HnkyTonk", "FrencHrn", "PercFlut", "Rhodey", "TubeBell", "Wurley"]) {
            ugens.set(osc, osc);
        }
    }


    fun void register(string k, string v) { sounds.set(k, v); }
    fun void register(string k, string v, string b) { sounds.set(k, v); bases.set(k, b); }
    
    fun int parseNote(string name){  return bases.has(name) ? Std.atoi(bases.get(name)) : 60; }

    // Create a fresh OscPlayer for every play event.
    // Never cache: each sporked shred needs its own ADSR so concurrent notes
    // of the same type don't corrupt each other's envelope state.
    fun OscPlayer getOscPlayer(string name) {
        OscPlayer @ p;
        if (name == "SinOsc")        new SinOscPlayer   @=> p;
        else if (name == "TriOsc")   new TriOscPlayer   @=> p;
        else if (name == "SawOsc")   new SawOscPlayer   @=> p;
        else if (name == "SqrOsc")   new SqrOscPlayer   @=> p;
        else if (name == "PulseOsc") new PulseOscPlayer @=> p;
        else if (name == "Phasor")   new PhasorPlayer   @=> p;
        else if (name == "Noise")    new NoisePlayer    @=> p;
        else if (name == "CNoise")   new CNoisePlayer   @=> p;
        else if (name == "BLT")      new BLTPlayer @=> p;
        else if (name == "Blit")     new BlitPlayer @=> p;
        else if (name == "BlitSaw")  new BlitSawPlayer @=> p;
        else if (name == "BlitSquare") new BlitSquarePlayer @=> p;
        else if (name == "BandedWG") new BandedWGPlayer @=> p;
        else if (name == "BlowBotl") new BlowBotlPlayer @=> p;
        else if (name == "BlowHole") new BlowHolePlayer @=> p;
        else if (name == "Bowed")    new BowedPlayer @=> p;
        else if (name == "Brass")    new BrassPlayer @=> p;
        else if (name == "Clarinet") new ClarinetPlayer @=> p;
        else if (name == "Flute")    new FlutePlayer @=> p;
        else if (name == "Mandolin") new MandolinPlayer @=> p;
        else if (name == "ModalBar") new ModalBarPlayer @=> p;
        else if (name == "Moog")     new MoogPlayer @=> p;
        else if (name == "Saxofony") new SaxofonyPlayer @=> p;
        else if (name == "Shakers")  new ShakersPlayer @=> p;
        else if (name == "Sitar")    new SitarPlayer @=> p;
        else if (name == "StifKarp") new StifKarpPlayer @=> p;
        else if (name == "VoicForm") new VoicFormPlayer @=> p;
        else if (name == "KrstlChr") new KrstlChrPlayer @=> p;
        else if (name == "BeeThree") new BeeThreePlayer @=> p;
        else if (name == "FMVoices") new FMVoicesPlayer @=> p;
        else if (name == "HevyMetl") new HevyMetlPlayer @=> p;
        else if (name == "HnkyTonk") new HnkyTonkPlayer @=> p;
        else if (name == "FrencHrn") new FrencHrnPlayer @=> p;
        else if (name == "PercFlut") new PercFlutPlayer @=> p;
        else if (name == "Rhodey")   new RhodeyPlayer @=> p;
        else if (name == "TubeBell") new TubeBellPlayer @=> p;
        else if (name == "Wurley")   new WurleyPlayer @=> p;
        return p;
    }

    // Returns a Pattern that emits the literal string verbatim (no mini.chug parsing).
    // Required for parameters like scale names that contain ':' which mini.chug
    // would otherwise interpret as a sample-index operator.
    fun Pattern parseLiteral(string input) {
        Utils.trim(input) => string t;
        LiteralPatternFunc pf;
        t => pf.rawValue;
        return new Pattern(pf);
    }

    fun Pattern parse(string input) {
        Utils.trim(input) => string t;
        if (!t.length()) return new Pattern(new PatternFunc());

        MiniPatternFunc pf;
        m @=> pf.m;
        sounds @=> pf.sounds;
        t => pf.rawInput;
        return new Pattern(pf);
    }
}