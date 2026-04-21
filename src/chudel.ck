@import "pattern.ck"
@import "parser.ck"
@import "examples.ck"

// Strudel in ChucK!
public class Chudel {

    0.1 => static float interval; // query time
    0.1 => static float latency; // start offset
    0.5 => static float cps; // cycles per second
    0 => int intervals;
    fun static void update(){ interval::second => now; }
    fun int getIntervals(){ return intervals; }
    fun float getCycles(){ return (now/1::second)*cps; }
    fun float getSeconds(){ return now/1::second; }
    fun float ctos(float c){ return c / cps; }
    fun float stoc(float s){ return s * cps; }
    fun float itos(float i){ return i / interval; }

    // ------------------------------------------
    // Scheduler
    // ------------------------------------------

    Pattern pattern;
    Parser parser;
    true => static int print;
    fun void debug(){ true => print; }

    // Main Chudel loop!
    fun void loop(){
        getIntervals() => int intervals;
        getCycles() => float cycles;
        getSeconds() => float seconds;

        // Query all haps in the current window
        pattern.query(new Arc(cycles $ int, 1), cycles) @=> Hap haps[];
        for (0 => int i; i < haps.size(); i++){
            ctos(haps[i].start()) => float startTime;
            ctos(haps[i].duration()) => float durTime;

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

    // Wait until the start time to play a hap until the end time
    fun void play(Hap hap, float startTime, float endTime){
        now/1::second => float currentTime;
        Utils.cleanDur((startTime - currentTime)::second) => now;

        // Skip rests
        if (print) hap.print();
        if (hap.isRest()) return;
        
        // Create sampler
        hap.getSound() => string sound;
        parser.sounds.get(parser.sounds.has(sound) ? sound : "piano") => string path;
        parser.bases.has(sound) ? Std.atoi(parser.bases.get(sound)) : 60 => int baseNote;
        Sampler sampler(path, baseNote);

        // Set parameters
        sampler.gain(hap.getGain());
        sampler.pan(hap.getPan());
        sampler.echo(hap.getEcho());

        // Play and discard
        hap.getNote() => int note;
        Utils.cleanDur((endTime - startTime + latency)::second) => dur duration;
        sampler.playOnce(note, duration);
    }

    // ------------------------------------------
    // Pattern Functions
    // ------------------------------------------

    fun PatternFunc parse(string input) { return parser.parse(input).pattern; }
    fun Chudel register(string key, string file){ parser.register(key, file); return this; }
    fun Chudel clear(){ new Pattern() @=> pattern; return this; }
    fun Chudel func(PatternFunc p){ new Pattern(p) @=> pattern; return this; }
    fun Chudel note(string input){ return func(new _Note(pattern.pattern, parse(input))); }
    fun Chudel sound(string input){ return func(new _Sound(pattern.pattern, parse(input))); }
    fun Chudel scale(string input){ return func(new _Scale(pattern.pattern, parse(input))); }
    fun Chudel gain(string input){ return func(new _Gain(pattern.pattern, parse(input))); }
    fun Chudel pan(string input){ return func(new _Pan(pattern.pattern, parse(input))); }
    fun Chudel echo(string input){ return func(new _Echo(pattern.pattern, parse(input))); }
    fun Chudel fast(string input){ return func(new Fast(pattern.pattern, parse(input))); }
    fun Chudel slow(string input){ return func(new Fast(pattern.pattern, parse(input), 1)); }
    fun Chudel add(string input){ return func(new Add(pattern.pattern, parse(input))); }

    // ------------------------------------------
    // Transpiling Input
    // ------------------------------------------

    ["note", "scale", "sound", "gain", "pan", "echo", "fast", "slow", "add"] @=> static string commands[];

    // Parse a JavaScript function chain
    fun Chudel input(string l){
        Utils.trim(l) => string line;
        if (!line.length()) return this;
        Utils.outerSplit(line, ".") @=> string parts[];
        for (string p : parts){
            Utils.trim(p) => string part;
            part.length() => int length;
            if (length < 4) continue;

            // Make sure the end of the string has a valid closure
            length - 2 => int closure;
            p.substring(closure, 2) => string end;
            if (end != "\")") continue;

            // Process each command
            for (string cmd : commands){
                cmd.length() => int len;
                
                // Make sure the start of the string has a valid opening
                if (length < len + 4) continue;
                if (part.substring(0, len + 2) != cmd + "(\"") continue;
                part.substring(len + 2, closure - (len + 2)) => string arg;

                // Parse the command
                if (cmd == "note") { this.note(arg); }
                else if (cmd == "scale") { this.scale(arg); }
                else if (cmd == "sound") { this.sound(arg); }
                else if (cmd == "gain") { this.gain(arg); }
                else if (cmd == "pan") { this.pan(arg); }
                else if (cmd == "echo") { this.echo(arg); }
                else if (cmd == "fast") { this.fast(arg); }
                else if (cmd == "slow") { this.slow(arg); }
                else if (cmd == "add") { this.add(arg); }
            }
        }
        return this;
    }

    // Cache file content to avoid redundant parsing
    string file;
    fun void inputFile(string content){
        if (content == file) return;
        content => file; 
        clear();
        input(content); 
    }

    // Read changes from a file live
    50::ms => dur poll;
    fun void syncFile(string path){ while (true){ inputFile(Utils.readFile(path)); poll => now; } }
    fun void syncFile(){ syncFile(Utils.defaultFile); }

    // Live code from default file or specified path
    fun void livecode(string path){ input(Utils.readFile(path)); spork ~ syncFile(path); }
    fun void livecode(){ input(Utils.readFile()); spork ~ syncFile(); }

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
