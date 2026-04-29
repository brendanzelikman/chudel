@import "pattern.ck"
@import "parser.ck"
@import "examples.ck"
@import "audiograph.ck"

// Strudel in ChucK! (...and more?!)
public class Chudel {

    // ------------------------------------------
    // Timing
    // ------------------------------------------

    0.1 => static float interval; // query time
    0.1 => static float latency; // start offset
    0.5 => static float cps; // cycles per second
    0 => static float _currentCycle;
    now/1::second => static float _lastTime;
    0 => int intervals;
    
    
    fun static void update(){ interval::second => now; }
    fun int getIntervals(){ return intervals; }
    fun float getCycles(){ return _currentCycle + (now/1::second - _lastTime) * cps; }
    fun float getSeconds(){ return now/1::second; }
    fun float ctos(float c){ return _lastTime + (c - _currentCycle) / cps; }
    fun float stoc(float s){ return _currentCycle + (s - _lastTime) * cps; }
    fun float itos(float i){ return i / interval; }
    fun static void setCps(float newCps) {
        now/1::second => float currentTime;
        (currentTime - _lastTime) * cps +=> _currentCycle;
        currentTime => _lastTime;
        newCps => cps;
    }
    // cycles per minute  → cps = cpm / 60
    fun static void setCpm(float cpm) { setCps(cpm / 60.0); }
    // beats per minute   → cps = bpm / 240  (4 beats per cycle in 4/4)
    fun static void setBpm(float bpm) { setCps(bpm / 240.0); }

    // ------------------------------------------
    // Lazy Loader Shred
    // ------------------------------------------
    
    Event loaderEvent;
    string loadQueue[0];

    // Load samplers on demand
    fun void loaderShred() {
        while (true) {
            loaderEvent => now;
            while (loadQueue.size() > 0) {
                loadQueue[0] => string key;
                loadQueue.erase(0);
                
                // Only load if not already in progress or completed
                if (parser.samplers[key] == null) {
                    parser.sounds.get(key) => string path;
                    Utils.getSubstring(key, ":") => string name;
                    parser.parseNote(name) => int note;
                    new Sampler(path, note) @=> parser.samplers[key];
                }
            }
        }
    }
    // ------------------------------------------
    // Scheduler
    // ------------------------------------------

    Pattern pattern;
    Pattern @ tracks[0];   // one entry per $: orbit
    Parser @ parser;

    -1.0 => float lastEndC;

    fun @construct() { new Parser() @=> parser; }
    fun @construct(string folderName) { new Parser(folderName) @=> parser; }
    
    true => static int print;
    fun void debug(){ true => print; }
    
    // Spawn loader after dependencies are initialized
    spork ~ loaderShred();

    // MIDI support
    MidiOut mout;
    0 => int midiReady;

    // Main Chudel loop!
    fun void loop(){
        getIntervals() => int intervals;
        getCycles() => float cycles;
        getSeconds() => float seconds;

        // Get the current time window
        if (lastEndC < 0) stoc(seconds) => lastEndC;
        lastEndC => float startC;
        stoc(seconds + interval) => float endC;
        endC => lastEndC;

        Math.floor(startC) $ int => int startCycleInt;
        Math.floor(endC) $ int => int endCycleInt;

        // Query and collect overlapping haps
        Hap haps[0];
        for (startCycleInt => int c; c <= endCycleInt; c++) {
            new Arc(c, 1) @=> Arc arc;
            for (0 => int t; t < tracks.size(); t++) {
                tracks[t].query(arc, cycles) @=> Hap trackHaps[];
                for (0 => int j; j < trackHaps.size(); j++) {
                    if (trackHaps[j].start() >= startC && trackHaps[j].start() < endC) {
                        haps << trackHaps[j];
                    }
                }
            }
        }

        // Schedule haps for playback
        for (0 => int i; i < haps.size(); i++){
            ctos(haps[i].start()) => float startTime;
            haps[i].duration() / cps => float durTime;
            Utils.cleanDur(durTime::second - 1::samp) / 1::second => durTime;

            spork ~ play(haps[i], startTime + latency, startTime + durTime);
        }
        intervals++;
        interval::second => now;
    }
    fun void run(){while (true){ loop(); } }

    // ------------------------------------------
    // Audio Playback
    // ------------------------------------------

    16 => int MAX_POLYPHONY;
    0 => int activeVoices;

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
        
        // Wait for child shreds to finish (Sampler release time is 10ms)
        Math.max(duration / 1::samp, 10::ms / 1::samp)::samp + 1::samp => now;
    }

    // Play a hap's audio for the given duration
    fun void playAudio(Hap hap, dur duration){
        if (hap.has("midi") && !hap.has("sound")) return;
        hap.getSound() => string sound;
        Utils.getSubstring(sound, ":") => string baseName;

        // n() for samples: remap sample index (e.g. n("3").sound("hh") => hh:3)
        // We skip this if a scale is present, as n() then represents a degree for pitch shifting.
        0 => int remapped;
        if (hap.has("n") && parser.sounds.has(baseName) && !hap.has("scale")) {
            Std.itoa(Std.atof(hap.getString("n")) $ int) => string nIdx;
            baseName + ":" + nIdx => sound;
            1 => remapped;
        }

        (parser.sounds.has(sound) ? sound : "piano") => string lookupKey;

        // Ensure sample is loaded BEFORE checking polyphony
        if (!parser.ugens.has(baseName) && parser.sounds.has(lookupKey)) {
            if (parser.samplers[lookupKey] == null) {
                // Check if already in queue to avoid duplicates
                0 => int inQueue;
                for (0 => int j; j < loadQueue.size(); j++) if (loadQueue[j] == lookupKey) 1 => inQueue;
                if (!inQueue) {
                    loadQueue << lookupKey;
                    loaderEvent.signal();
                }
                
                // Wait for the asynchronous loader to finish (with safety timeout)
                now => time startWait;
                while (parser.samplers[lookupKey] == null && now < startWait + 1::second) 5::ms => now;
                
                // If it still failed to load, don't block polyphony, just return
                if (parser.samplers[lookupKey] == null) return;
            }
        }

        // Now check polyphony
        if (activeVoices >= MAX_POLYPHONY) {
            return;
        }
        activeVoices++;

        hap.getNote() => int playNote;
        
        // If we remapped to a sample index, we usually want rate 1.0 (baseNote)
        if (remapped) {
            parser.parseNote(baseName) => playNote;
        }

        // Build LOCAL effect chain — all UGens live as long as this shred runs.
        UGen chain[0];
        int hasTail;

        if (hap.has("lpf") && hap.getFloat("lpf") > 0)           chain << AudioGraph.lpf(hap.getFloat("lpf"));
        if (hap.has("hpf") && hap.getFloat("hpf") > 0)           chain << AudioGraph.hpf(hap.getFloat("hpf"));
        if (hap.has("bpf") && hap.getFloat("bpf") > 0)           chain << AudioGraph.bpf(hap.getFloat("bpf"));
        if (hap.has("brf") && hap.getFloat("brf") > 0)           chain << AudioGraph.brf(hap.getFloat("brf"));
        if (hap.has("biquad") && hap.getFloat("biquad") > 0)     chain << AudioGraph.biquad(hap.getFloat("biquad"));
        if (hap.has("resonz") && hap.getFloat("resonz") > 0)     chain << AudioGraph.resonz(hap.getFloat("resonz"));
        if (hap.has("onepole") && hap.getFloat("onepole") > 0)   chain << AudioGraph.onepole(hap.getFloat("onepole"));
        if (hap.has("onezero") && hap.getFloat("onezero") > 0)   chain << AudioGraph.onezero(hap.getFloat("onezero"));
        if (hap.has("twopole") && hap.getFloat("twopole") > 0)   chain << AudioGraph.twopole(hap.getFloat("twopole"));
        if (hap.has("twozero") && hap.getFloat("twozero") > 0)   chain << AudioGraph.twozero(hap.getFloat("twozero"));
        if (hap.has("polezero") && hap.getFloat("polezero") > 0) chain << AudioGraph.polezero(hap.getFloat("polezero"));
        if (hap.has("halfrect"))                                  chain << AudioGraph.halfrect();
        if (hap.has("fullrect"))                                  chain << AudioGraph.fullrect();
        if (hap.has("shifter") && hap.getFloat("shifter") != 1.0) chain << AudioGraph.shifter(hap.getFloat("shifter"), 1.0);
        if (hap.has("modulate") && hap.getFloat("modulate") > 0)  chain << AudioGraph.modulate(hap.getFloat("modulate"));
        if (hap.has("chorus") && hap.getFloat("chorus") > 0) {
            AudioGraph.chorus() @=> Chorus c; hap.getFloat("chorus") => c.mix; chain << c;
        }
        if (hap.has("echo") && hap.getFloat("echo") > 0) {
            AudioGraph.delay(0.25) @=> Echo e; hap.getFloat("echo") => e.mix; chain << e;
            1 => hasTail;
        }
        if (hap.has("delay") && hap.getFloat("delay") > 0)       { chain << AudioGraph.delay(hap.getFloat("delay")); 1 => hasTail; }
        if (hap.has("delayl") && hap.getFloat("delayl") > 0)     { chain << AudioGraph.delayl(hap.getFloat("delayl")); 1 => hasTail; }
        if (hap.has("delaya") && hap.getFloat("delaya") > 0)     { chain << AudioGraph.delaya(hap.getFloat("delaya")); 1 => hasTail; }
        if (hap.has("jcrev") && hap.getFloat("jcrev") > 0)       { chain << AudioGraph.jcrev(hap.getFloat("jcrev"));   1 => hasTail; }
        if (hap.has("nrev") && hap.getFloat("nrev") > 0)         { chain << AudioGraph.nrev(hap.getFloat("nrev"));     1 => hasTail; }
        if (hap.has("prcrev") && hap.getFloat("prcrev") > 0)     { chain << AudioGraph.prcrev(hap.getFloat("prcrev")); 1 => hasTail; }
        
        chain << AudioGraph.gain(hap.getGain());
        chain << AudioGraph.pan(hap.getPan());

        // Connect chain: chain[0] → chain[1] → … → chain[last] → DAC
        for (0 => int i; i < chain.size() - 1; i++) chain[i] => chain[i+1];
        chain[chain.size()-1] => dac;

        UGen source;

        // ------ OscPlayer path (SinOsc, SawOsc, Noise, etc.) ------
        if (parser.ugens.has(baseName)) {
            parser.getOscPlayer(baseName) @=> OscPlayer osc;
            if (osc != null) {
                osc.env @=> source;
                source => chain[0];
                osc.playOnce(playNote, duration);
            }
        } 
        // ------ Sampler path (file-based samples) ------
        else {
            (parser.sounds.has(sound) ? sound : "piano") => string lookupKey;
            if (parser.sounds.has(lookupKey)) {
                parser.samplers[lookupKey] @=> Sampler sampler;
                if (sampler != null) {
                    sampler.env @=> source;
                    source => chain[0];
                    sampler.playOnce(playNote, duration);
                }
            }
        }

        if (source != null) source =< chain[0];
        
        activeVoices--; 

        if (hasTail) {
            1.0::second => now;   // shred sleeps; reverb/delay rings naturally
        }
        
        chain[chain.size()-1] =< dac;
    }

    fun void playMidi(Hap hap, dur duration){
        if (!hap.has("midi") || !midiReady) return;

        // Extract the midi channel and note
        Std.atoi(hap.getString("midi")) => int midi;
        Math.clampi(midi - 1, 0, 15) => int channel;        
        hap.getNote() => int note;

        // Send the note on message
        MidiMsg msg;
        0x90 + channel => msg.data1;
        note => msg.data2;
        127 => msg.data3;
        mout.send(msg);
        (duration/2.0) => now;

        // Send the note off message
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
    fun Chudel hush(){ 
        new Pattern() @=> pattern; 
        Pattern @ empty[0]; empty @=> tracks; 
        0 => activeVoices; 
        -1.0 => lastEndC; 
        return this; 
    }
    fun Chudel clearState(){ 
        new Pattern() @=> pattern; 
        0 => activeVoices; 
        return this; 
    }
    fun Chudel clear(){ return hush(); }

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
    fun Chudel n(string input){ return func(new _N(pattern.pattern, parse(input))); }
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
    fun Chudel jcrev(string input){ return func(new _Jcrev(pattern.pattern, parse(input))); }
    fun Chudel nrev(string input){ return func(new _Nrev(pattern.pattern, parse(input))); }
    fun Chudel prcrev(string input){ return func(new _Prcrev(pattern.pattern, parse(input))); }
    fun Chudel lpf(string input){ return func(new _Lpf(pattern.pattern, parse(input))); }
    fun Chudel hpf(string input){ return func(new _Hpf(pattern.pattern, parse(input))); }
    fun Chudel chorus(string input){ return func(new _Chorus(pattern.pattern, parse(input))); }
    fun Chudel shifter(string input){ return func(new _Shifter(pattern.pattern, parse(input))); }
    fun Chudel delay(string input){ return func(new _Delay(pattern.pattern, parse(input))); }
    fun Chudel delayl(string input){ return func(new _DelayL(pattern.pattern, parse(input))); }
    fun Chudel delaya(string input){ return func(new _DelayA(pattern.pattern, parse(input))); }
    fun Chudel halfrect(string input){ return func(new _HalfRect(pattern.pattern, parse(input))); }
    fun Chudel fullrect(string input){ return func(new _FullRect(pattern.pattern, parse(input))); }
    fun Chudel bpf(string input){ return func(new _BPF(pattern.pattern, parse(input))); }
    fun Chudel brf(string input){ return func(new _BRF(pattern.pattern, parse(input))); }
    fun Chudel biquad(string input){ return func(new _BiQuad(pattern.pattern, parse(input))); }
    fun Chudel resonz(string input){ return func(new _ResonZ(pattern.pattern, parse(input))); }
    fun Chudel onepole(string input){ return func(new _OnePole(pattern.pattern, parse(input))); }
    fun Chudel onezero(string input){ return func(new _OneZero(pattern.pattern, parse(input))); }
    fun Chudel twopole(string input){ return func(new _TwoPole(pattern.pattern, parse(input))); }
    fun Chudel twozero(string input){ return func(new _TwoZero(pattern.pattern, parse(input))); }
    fun Chudel polezero(string input){ return func(new _PoleZero(pattern.pattern, parse(input))); }
    fun Chudel modulate(string input){ return func(new _Modulate(pattern.pattern, parse(input))); }

    // ------------------------------------------
    // Transpiling Input
    // ------------------------------------------

    ["note", "n", "scale", "sound", "s", "gain", "pan", "echo", "fast", "slow", "add", "midi", "orbit",
     "jcrev", "nrev", "prcrev", "lpf", "hpf", "chorus", "shifter",
     "delay", "delayl", "delaya", "halfrect", "fullrect",
     "bpf", "brf", "biquad", "resonz", "onepole", "onezero",
     "twopole", "twozero", "polezero", "modulate"] @=> static string commands[];

    fun Chudel input(string l){
        Utils.trim(l) => string line;
        if (!line.length()) return this;
        Utils.outerSplit(line, ".") @=> string parts[];
        for (0 => int i; i < parts.size(); i++){
            parts[i] => string p;
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
            for (0 => int j; j < commands.size(); j++){
                commands[j] => string cmd;
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
                if (cmd == "note" || cmd == "not") { this.note(arg); }
                else if (cmd == "n") { this.n(arg); }
                else if (cmd == "scale") { this.scale(arg); }
                else if (cmd == "sound") { this.sound(arg); }
                else if (cmd == "s") { this.sound(arg); }
                else if (cmd == "gain") { this.gain(arg); }
                else if (cmd == "pan") { this.pan(arg); }
                else if (cmd == "echo") { this.echo(arg); }
                else if (cmd == "fast") { this.fast(arg); }
                else if (cmd == "slow") { this.slow(arg); }
                else if (cmd == "add") { this.add(arg); }
                else if (cmd == "midi") { 
                    if (!midiReady) {
                        mout.open(0) => midiReady;
                        if (midiReady) <<< "[Chudel] MIDI auto-initialized on port 0" >>>;
                    }
                    this.midi(arg); 
                }
                else if (cmd == "orbit") { /* no-op */ }
                else if (cmd == "jcrev") { this.jcrev(arg); }
                else if (cmd == "nrev") { this.nrev(arg); }
                else if (cmd == "prcrev") { this.prcrev(arg); }
                else if (cmd == "lpf") { this.lpf(arg); }
                else if (cmd == "hpf") { this.hpf(arg); }
                else if (cmd == "chorus") { this.chorus(arg); }
                else if (cmd == "shifter") { this.shifter(arg); }
                else if (cmd == "delay") { this.delay(arg); }
                else if (cmd == "delayl") { this.delayl(arg); }
                else if (cmd == "delaya") { this.delaya(arg); }
                else if (cmd == "halfrect") { this.halfrect(arg); }
                else if (cmd == "fullrect") { this.fullrect(arg); }
                else if (cmd == "bpf") { this.bpf(arg); }
                else if (cmd == "brf") { this.brf(arg); }
                else if (cmd == "biquad") { this.biquad(arg); }
                else if (cmd == "resonz") { this.resonz(arg); }
                else if (cmd == "onepole") { this.onepole(arg); }
                else if (cmd == "onezero") { this.onezero(arg); }
                else if (cmd == "twopole") { this.twopole(arg); }
                else if (cmd == "twozero") { this.twozero(arg); }
                else if (cmd == "polezero") { this.polezero(arg); }
                else if (cmd == "modulate") { this.modulate(arg); }
            }
        }
        return this;
    }

    // Cache file content to avoid redundant parsing
    string file;
    fun void inputFile(string content){
        if (content == file) return;
        content => file;
        <<< "[Chudel] Loading new pattern..." >>>;

        // Split into lines and look for globals and orbits
        Utils.split(content, "\n") @=> string lines[];
        Pattern @ newTracks[0];
        
        cps => float targetCps;
        0 => int cpsFound;
        
        for (0 => int l; l < lines.size(); l++) {
            lines[l] => string line;
            line.find("//") => int commentPos;
            commentPos < 0 => int noComment;
            line.find("hush") => int hushPos;
            if (hushPos >= 0 && (noComment || hushPos < commentPos)) {
                hush();
                return;
            }

            // Handle setcps, setcpm, setbpm, setmidi globals
            ["setcps", "setcpm", "setbpm", "setmidi"] @=> string globals[];
            for (0 => int k; k < globals.size(); k++) {
                globals[k] => string g;
                line.find(g) => int gPos;
                if (gPos >= 0 && (noComment || gPos < commentPos)) {
                    // Check if it's at the start of the line (only whitespace before)
                    1 => int isStart;
                    for (0 => int j; j < gPos; j++) {
                        line.charAt2(j) => string c;
                        if (c != " " && c != "\t") 0 => isStart;
                    }
                    if (!isStart) continue;

                    gPos + g.length() => int i;
                    // Skip '(', ' ', '"', ''', or other noise before the number
                    while (i < line.length() && (line.charAt2(i) == "(" || line.charAt2(i) == " " || line.charAt2(i) == "\"" || line.charAt2(i) == "'")) i++;
                    i => int start;
                    // Read digits, dots, and signs
                    while (i < line.length() && (Utils.isDigit(line.charAt2(i)) || line.charAt2(i) == "." || line.charAt2(i) == "-")) i++;
                    if (i > start) {
                        line.substring(start, i - start) => string arg;
                        Std.atof(arg) => float val;
                        if (g == "setcps") { val => targetCps; 1 => cpsFound; }
                        else if (g == "setcpm") { val / 60.0 => targetCps; 1 => cpsFound; }
                        else if (g == "setbpm") { val / 240.0 => targetCps; 1 => cpsFound; }
                        else if (g == "setmidi") {
                            Std.atoi(arg) => int port;
                            if (mout.open(port)) {
                                1 => midiReady;
                                <<< "[Chudel] MIDI Output mapped to port:", port >>>;
                            }
                        }
                    }
                }
            }

            // Skip lines without orbits
            line.find("$:") => int pos;
            if (pos < 0) continue;
            // Skip lines with _$: (custom comment style)
            if (pos > 0 && line.charAt2(pos - 1) == "_") continue;
            // Skip comments
            if (commentPos >= 0 && commentPos < pos) continue; // commented out
            
            line.substring(pos + 2) => string chain;
            while (chain.length() > 0 && chain.charAt2(0) == " ") chain.substring(1) => chain;
            
            clearState();
            input(chain);
            new Pattern(pattern.pattern) @=> Pattern p;
            newTracks << p;
        }

        // Apply tempo if a new one was found and it differs from current
        if (cpsFound && Math.fabs(targetCps - cps) > 0.0001) {
            setCps(targetCps);
            <<< "[Chudel] Tempo:", cps, "CPS |", cps*60.0, "CPM |", cps*240.0, "BPM" >>>;
        }

        // Decide between orbit mode ($: syntax) and single-pattern inline mode.
        // If any $: was found in the file (active or commented), use orbit mode
        // so that commenting all orbits results in silence rather than fallback.
        int hasOrbitMarker;
        for (0 => int i; i < lines.size(); i++) {
            if (lines[i].find("$:") >= 0) { 1 => hasOrbitMarker; break; }
        }

        if (hasOrbitMarker) {
            // Orbit mode: always sync tracks (empty newTracks = silence)
            newTracks @=> tracks;
            if (newTracks.size() > 0) newTracks[0] @=> pattern;
        } else {
            // Inline single-pattern mode: parse entire content as one chain
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
    fun Chudel shuffle(){ return note("<[4@2 4] [5@2 5] [6@2 6] [5@2 5]>*2").scale("<C2:mixolydan F2:mixolydian>/4").sound("piano"); }
    fun Chudel pretty(){ return note("<0 -3>, 2 4 <[6,8] [7,9]>").scale("<C:major D:mixolydian>/4").sound("piano").fast("2"); }
}
