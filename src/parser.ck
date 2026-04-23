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
//   - Arc mapping is pure ChucK arithmetic — no C++ calls per cycle
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
        
        (hasDeg || hasSeq || hasPoly || hasFeet || hasRand) => int isDynamic;
        Math.floor(arc.start) $ int => int cycleInt;
        
        if (!parsed || (isDynamic && cycleInt != parsedCycle)) {
            new CachedEvent[0] @=> cache;
            buildCache(cycleInt);
            cycleInt => parsedCycle;
            1 => parsed;
        }

        Hap out[0];
        for (0 => int i; i < cache.size(); i++) {
            cache[i] @=> CachedEvent ev;
            // Map 0->1 event times into the queried arc
            arc.start + ev.start * arc.duration => float s;
            arc.start + ev.end   * arc.duration => float e;
            Arc a(s, e - s);
            out << new Hap(classify(ev.value, ev.number), a);
        }
        return out;
    }

    // ------- Parse & decode -------

    fun void buildCache(int cycle) {
        m.parse(rawInput, cycle) => string result;

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
        // Split "name, N" — comma is optional; bare name defaults to sample 0
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

    // Parse "n/d" → float
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
// Parser — wraps mini.chug, provides the same API surface
// as the old ChucK-native parser so chudel.ck is unchanged
// -------------------------------------------------------
public class Parser {
    mini m;
    Map sounds;
    Map bases;

    Sampler @ samplers[0];

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

        string dirtSamples[names.size()][0];

        for(0 => int i; i < names.size(); i++)
        {
            FileIO files;
            if(files.open(folderName + names[i], FileIO.READ )){
                files.dirList() @=> dirtSamples[names[i]];
            }
        } 

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

            // Also register bare name → sample 0 for classify() lookup
            if (dirtSamples[s].size() > 0) {
                folderName + s + "/" + dirtSamples[s][0] => string path0;
                register(s, path0, baseStr);
            }
        }
    }

    fun @construct() {
        init(me.dir(-1) + "Dirt-Samples/");
    }

    fun @construct(string folderName) {
        init(folderName);
    }

    fun void register(string k, string v) { sounds.set(k, v); }
    fun void register(string k, string v, string b) { sounds.set(k, v); bases.set(k, b); }

    // Returns a Pattern backed by MiniPatternFunc.
    // The C++ parse runs once lazily; all queries are fast ChucK arithmetic.
    fun Pattern parse(string input) {
        Utils.trim(input) => string t;
        MiniPatternFunc pf;
        m @=> pf.m;
        sounds @=> pf.sounds;
        t => pf.rawInput;
        return new Pattern(pf);
    }
}