@import "pattern.ck"
@import "parser.ck"
@import "examples.ck"

// Strudel in ChucK!
public class Chudel {

    0.1 => static float interval; // query time
    0.1 => static float latency; // start offset
    0.5 => static float cps; // cycles per second
    0 => static float _currentCycle;
    now/1::second => static float _lastTime;
    0 => int intervals;
    
    fun static void setCps(float newCps) {
        now/1::second => float currentTime;
        (currentTime - _lastTime) * cps +=> _currentCycle;
        currentTime => _lastTime;
        newCps => cps;
    }
    
    fun static void update(){ interval::second => now; }
    fun int getIntervals(){ return intervals; }
    fun float getCycles(){ return _currentCycle + (now/1::second - _lastTime) * cps; }
    fun float getSeconds(){ return now/1::second; }
    fun float ctos(float c){ return _lastTime + (c - _currentCycle) / cps; }
    fun float stoc(float s){ return _currentCycle + (s - _lastTime) * cps; }
    fun float itos(float i){ return i / interval; }

    // ------------------------------------------
    // Lazy Loader Shred
    // ------------------------------------------
    
    Event loaderEvent;
    string loadQueue[0];

    fun void loaderShred() {
        while (true) {
            loaderEvent => now;
            while (loadQueue.size() > 0) {
                loadQueue[0] => string key;
                loadQueue.erase(0);
                if (parser.samplers[key] == null) {
                    parser.sounds.get(key) => string path;
                    
                    key => string baseName;
                    key.find(":") => int colon;
                    if (colon >= 0) key.substring(0, colon) => baseName;
                    
                    parser.bases.has(baseName) ? Std.atoi(parser.bases.get(baseName)) : 60 => int baseNote;
                    new Sampler(path, baseNote) @=> parser.samplers[key];
                }
            }
        }
    }
    // ------------------------------------------
    // Scheduler
    // ------------------------------------------

    Pattern pattern;
    Pattern @ tracks[0];   // one entry per $: orbit
    Parser parser;
    true => static int print;
    fun void debug(){ true => print; }
    
    // Spawn loader after dependencies are initialized
    spork ~ loaderShred();

    // MIDI support
    MidiOut mout;
    mout.open(0) => int midiReady;

    // Main Chudel loop!
    fun void loop(){
        getIntervals() => int intervals;
        getCycles() => float cycles;
        getSeconds() => float seconds;
        // Collect haps from all active tracks overlapping the current time window
        stoc(seconds - interval/2) => float startC;
        stoc(seconds + interval/2) => float endC;
        Math.floor(startC) $ int => int startCycleInt;
        Math.floor(endC) $ int => int endCycleInt;

        Hap haps[0];
        for (startCycleInt => int c; c <= endCycleInt; c++) {
            new Arc(c, 1) @=> Arc arc;
            for (0 => int t; t < tracks.size(); t++) {
                tracks[t].query(arc, cycles) @=> Hap trackHaps[];
                for (0 => int j; j < trackHaps.size(); j++) haps << trackHaps[j];
            }
        }

        for (0 => int i; i < haps.size(); i++){
            ctos(haps[i].start()) => float startTime;
            haps[i].duration() / cps => float durTime;
            Utils.cleanDur(durTime::second - 1::samp) / 1::second => durTime;

            // Play the hap if it falls within the current window
            if (seconds >= (startTime - interval/2) && seconds < (startTime + interval/2)){
                spork ~ play(haps[i], startTime + latency, startTime + durTime);
            }
        }
        intervals++;
        interval::second => now;
    }
    fun void run(){while (true){ loop(); } }

    // ------------------------------------------
    // Audio Playback
    // ------------------------------------------

    // Wait until the start time and then dispatch isolated audio and midi
    fun void play(Hap hap, float startTime, float endTime){
        now/second => float currentTime;
        Utils.cleanDur((startTime - currentTime)::second) => now;

        // Skip rests
        if (print) hap.print();
        if (hap.isRest()) return;

        Utils.cleanDur((endTime - startTime + latency)::second) => dur duration;
        // Output audio and MIDI concurrently
        spork ~ playAudio(hap, duration);
        spork ~ playMidi(hap, duration);
        
        (duration - 1::samp) => now;
    }

    fun void playAudio(Hap hap, dur duration){
        // Only default to piano if MIDI isn't exclusively handling this hap
        if (hap.has("midi") && !hap.has("sound")) return;

        hap.getSound() => string sound;
        sound.find(":") => int colon;
        (colon >= 0 ? sound.substring(0, colon) : sound) => string baseName;

        if (hap.hasNote() && parser.sounds.has(baseName)) {
            Std.itoa(Std.atof(hap.getString("note")) $ int) => string noteIdx;
            baseName + ":" + noteIdx => sound;
        }

        (parser.sounds.has(sound) ? sound : "piano") => string lookupKey;
        if (!parser.sounds.has(lookupKey)) return;  // unregistered sound — skip silently
        
        if (parser.samplers[lookupKey] == null) {
            loadQueue << lookupKey;
            loaderEvent.signal();
        }
        
        parser.samplers[lookupKey] @=> Sampler sampler;
        if (sampler == null) return;

        sampler.gain(hap.getGain());
        sampler.pan(hap.getPan());
        sampler.echo(hap.getEcho());

        parser.bases.has(baseName) ? Std.atoi(parser.bases.get(baseName)) : 60 => int baseNote;
        hap.hasNote() && parser.sounds.has(baseName) ? baseNote : hap.getNote() => int note;
        sampler.playOnce(note, duration);
    }

    fun void playMidi(Hap hap, dur duration){
        if (!hap.has("midi") || !midiReady) return;

        Std.atoi(hap.getString("midi")) - 1 => int channel;
        if (channel < 0) 0 => channel;
        if (channel > 15) 15 => channel;
        
        hap.getNote() => int note;

        MidiMsg msg;
        0x90 + channel => msg.data1;
        note => msg.data2;
        127 => msg.data3;
        mout.send(msg);

        (duration/2.0) => now;

        0x80 + channel => msg.data1;
        note => msg.data2;
        0 => msg.data3;
        mout.send(msg);

        (duration/2.0) => now;
    }

    // ------------------------------------------
    // Pattern Functions
    // ------------------------------------------

    fun PatternFunc parse(string input) { return parser.parse(input).pattern; }
    fun Chudel register(string key, string file){ parser.register(key, file); return this; }
    fun Chudel clear(){ new Pattern() @=> pattern; Pattern @ empty[0]; empty @=> tracks; return this; }
    fun Chudel func(PatternFunc p){ 
        new Pattern(p) @=> pattern; 
        if (tracks.size() == 0) {
            Pattern @ single[1];
            pattern @=> single[0];
            single @=> tracks;
        } else {
            pattern @=> tracks[0];
        }
        return this; 
    }
    fun Chudel note(string input){ return func(new _Note(pattern.pattern, parse(input))); }
    fun Chudel n(string input){ return func(new _Note(pattern.pattern, parse(input))); }
    fun Chudel sound(string input){ return func(new _Sound(pattern.pattern, parse(input))); }
    fun Chudel s(string input){ return func(new _Sound(pattern.pattern, parse(input))); }
    fun Chudel scale(string input){ return func(new _Scale(pattern.pattern, parse(input))); }
    fun Chudel gain(string input){ return func(new _Gain(pattern.pattern, parse(input))); }
    fun Chudel pan(string input){ return func(new _Pan(pattern.pattern, parse(input))); }
    fun Chudel echo(string input){ return func(new _Echo(pattern.pattern, parse(input))); }
    fun Chudel fast(string input){ return func(new Fast(pattern.pattern, parse(input))); }
    fun Chudel slow(string input){ return func(new Fast(pattern.pattern, parse(input), 1)); }
    fun Chudel add(string input){ return func(new Add(pattern.pattern, parse(input))); }
    fun Chudel midi(string input){ return func(new _Midi(pattern.pattern, parse(input))); }
    fun Chudel orbit(string input){ return this; } // no-op: orbit routing not implemented

    // ------------------------------------------
    // Transpiling Input
    // ------------------------------------------

    ["note", "n", "scale", "sound", "s", "gain", "pan", "echo", "fast", "slow", "add", "midi", "orbit"] @=> static string commands[];

    // Parse a JavaScript function chain
    fun Chudel input(string l){
        Utils.trim(l) => string line;
        if (!line.length()) return this;
        Utils.outerSplit(line, ".") @=> string parts[];
        for (string p : parts){
            Utils.trim(p) => string part;
            part.length() => int length;
            int hasQuotes;
            int closure;
            if (length >= 4 && p.substring(length - 2, 2) == "\")") {
                1 => hasQuotes;
                length - 2 => closure;
            } else if (length >= 3 && p.substring(length - 2, 2) == "()") {
                0 => hasQuotes;
                length - 2 => closure;
            } else continue;

            // Process each command
            for (string cmd : commands){
                cmd.length() => int len;
                string arg;
                
                if (hasQuotes) {
                    if (length < len + 4) continue;
                    if (part.substring(0, len + 2) != cmd + "(\"") continue;
                    part.substring(len + 2, closure - (len + 2)) => arg;
                } else {
                    if (length != len + 2) continue;
                    if (part.substring(0, len + 2) != cmd + "()") continue;
                    if (cmd == "midi") "1" => arg;
                    else "0" => arg;
                }

                // Parse the command
                if (cmd == "note") { this.note(arg); }
                else if (cmd == "n") { this.note(arg); }
                else if (cmd == "scale") { this.scale(arg); }
                else if (cmd == "sound") { this.sound(arg); }
                else if (cmd == "s") { this.sound(arg); }
                else if (cmd == "gain") { this.gain(arg); }
                else if (cmd == "pan") { this.pan(arg); }
                else if (cmd == "echo") { this.echo(arg); }
                else if (cmd == "fast") { this.fast(arg); }
                else if (cmd == "slow") { this.slow(arg); }
                else if (cmd == "add") { this.add(arg); }
                else if (cmd == "midi") { this.midi(arg); }
                else if (cmd == "orbit") { /* no-op */ }
            }
        }
        return this;
    }

    // Cache file content to avoid redundant parsing
    string file;
    fun void inputFile(string content){
        if (content == file) return;
        content => file;

        if (content.find("hush") >= 0) {
            clear();
            return;
        }

        // Split into lines and look for $: orbit markers
        Utils.split(content, "\n") @=> string lines[];
        Pattern @ newTracks[0];
        
        for (string line : lines) {
            // Handle setcps and setcpm globals
            line.find("setcps(") => int cpsPos;
            if (cpsPos >= 0) {
                line.find(")", cpsPos) => int endPos;
                if (endPos > cpsPos) {
                    line.substring(cpsPos + 7, endPos - (cpsPos + 7)) => string arg;
                    arg.replace("\"", ""); arg.replace("'", "");
                    setCps(Std.atof(arg));
                    <<< "[Chudel] Tempo updated to", cps, "CPS" >>>;
                }
            }
            line.find("setcpm(") => int cpmPos;
            if (cpmPos >= 0) {
                line.find(")", cpmPos) => int endPos;
                if (endPos > cpmPos) {
                    line.substring(cpmPos + 7, endPos - (cpmPos + 7)) => string arg;
                    arg.replace("\"", ""); arg.replace("'", "");
                    setCps(Std.atof(arg) / 60.0);
                    <<< "[Chudel] Tempo updated to", cps, "CPS (from CPM)" >>>;
                }
            }
            line.find("setmidi(") => int midiPos;
            if (midiPos >= 0) {
                line.find(")", midiPos) => int endPos;
                if (endPos > midiPos) {
                    line.substring(midiPos + 8, endPos - (midiPos + 8)) => string arg;
                    arg.replace("\"", ""); arg.replace("'", "");
                    Std.atoi(arg) => int port;
                    mout.open(port) => midiReady;
                    <<< "[Chudel] MIDI Output mapped to port:", port, "- Ready:", midiReady >>>;
                }
            }

            line.find("//") => int commentPos;
            line.find("$:") => int pos;
            if (pos < 0) continue;              // not an orbit line
            if (commentPos >= 0 && commentPos < pos) continue; // commented out
            
            line.substring(pos + 2) => string chain;
            // Utils.trim only strips \n/\t; strip leading spaces too so commands match
            while (chain.length() > 0 && chain.charAt2(0) == " ") chain.substring(1) => chain;
            
            clear();
            input(chain);
            
            new Pattern(pattern.pattern) @=> Pattern p;
            newTracks << p;
        }

        if (newTracks.size() > 0) {
            newTracks @=> tracks;
            newTracks[0] @=> pattern;
        } else {
            // No $: found — treat whole content as one pattern
            clear();
            input(content);
            Pattern @ single[1];
            pattern @=> single[0];
            single @=> tracks;
        }
    }

    // Read changes from a file live
    50::ms => dur poll;
    fun void syncFile(string path){ while (true){ inputFile(Utils.readFile(path)); poll => now; } }
    fun void syncFile(){ syncFile(Utils.defaultFile); }

    // Live code from default file or specified path
    fun void livecode(string path){ inputFile(Utils.readFile(path)); spork ~ syncFile(path); }
    fun void livecode(){ inputFile(Utils.readFile()); spork ~ syncFile(); }

    // ------------------------------------------
    // Demos
    // ------------------------------------------

    fun Chudel kit(){ return sound("bd*4, [~ <sd cp>]*2, [~ hh]*4");}
    fun Chudel beat(){ return sound(Examples.Beat()); }
    fun Chudel tetris(){ return note(Examples.Tetris()).sound("bass"); }
    fun Chudel sweden(){ return note(Examples.Sweden()); }
    fun Chudel hats(){ return sound("hh*16").gain("[.25 1]*4").pan("-1 1"); }
    fun Chudel shuffle(){ return note("<[4@2 4] [5@2 5] [6@2 6] [5@2 5]>*2").scale("<C2:mixolydian F2:mixolydian>/4").sound("piano"); }
    fun Chudel pretty(){ return note("<0 -3>, 2 4 <[6,8] [7,9]>").scale("<C:major D:mixolydian>/4").sound("piano").fast("2"); }
}
