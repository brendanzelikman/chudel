@import "pattern.ck"
@import "utils.ck"

public class Parser {
    Map sounds;
    Map bases;
    Utils utils;

    // Initialize registry of sounds
    ["bd", "sd", "hh", "oh", "cp", "ah", "do", "piano", "bass"] @=> string defaultSounds[];
    fun @construct(){ for (string s : defaultSounds){ 
        // "samples/" + s + ".wav" => string path;
        s + ".wav" => string path;

        // Handle special files
        if (s == "do") "special:dope" => path;
        else if (s == "ah") "special:ahh" => path;

        // Handle base notes
        60 => int base;
        if (s == "piano") 61 => base;
        else if (s == "bass") 48 => base;

        // Register the sound
        register(s, path, Std.itoa(base));
    } }
    fun void register(string k, string v){ sounds.set(k, v); }
    fun void register(string k, string v, string b){ sounds.set(k, v); bases.set(k, b); }

    // Parse a mini notation string into a Pattern
    fun Pattern parse(string t){
        Utils.trim(t) => string token;

        // Handle commas
        utils.isCommaSeparated(token) => int comma;
        if (comma){
            utils.uncomma(token) @=> string itemsStr[];
            PatternFunc itemsPatterns[0];
            for (string item : itemsStr){
                itemsPatterns << parse(item).pattern;
            }
            return new Pattern(new Parallel(itemsPatterns));
        }

        // Handle spaces
        utils.isSpaced(token) => int isSpaced;
        if (isSpaced){
            return new Pattern(new Sequence(unspace(token)));
        }

        // Handle groups
        utils.isGrouped(token) => int isGrouped;
        if (isGrouped){
            utils.unbracket(token) @=> string inner;
            parse(inner) @=> Pattern group;
            return new Pattern(new Sequence([group.pattern]));
        }

        // Handle alternation
        utils.isAlternated(token) => int isAlternated;
        if (isAlternated){
            utils.unbracket(token) => string content;
            utils.uncomma(content) @=> string options[];
            PatternFunc patterns[0];
            for (string option : options){
                unspace(option) @=> PatternFunc funcs[];
                patterns << (new Pattern(new Alternate(funcs))).pattern;
            }
            return new Pattern(new Parallel(patterns));
        }

        // Handle multiplication
        utils.isMultiplied(token) => int asterisk;
        if (asterisk > -1){
            parse(token.substring(0, asterisk)) @=> Pattern left;
            parse(token.substring(asterisk+1)) @=> Pattern right;
            return new Pattern(new Fast(left.pattern, right.pattern));
        }

        // Handle division
        utils.isDivided(token) => int slash;
        if (slash > -1){
            parse(token.substring(0, slash)) @=> Pattern left;
            parse(token.substring(slash+1)) @=> Pattern right;
            return new Pattern(new Fast(left.pattern, right.pattern, 1));
        }

        // Compute the speed (density)
        utils.isReplicated(token) => int rep;
        if (rep > -1) {
            token.substring(0, rep) => string item;
            Std.atof(token.substring(rep+1)) => float speed;
            parse(item) @=> Pattern p;
            speed => p.pattern.density;
            return new Pattern(new Replicate(p.pattern));
        }

        // Elongation
        utils.isElongated(token) => int elongate;
        if (elongate > -1) {
            token.substring(0, elongate) => string item;
            return parse(item);
        }

        // Return as a sound if possible
        if (sounds.has(token)){
            return new Pattern(new Atom(new Map("sound", token)));
        }

        // Return as a note if possible
        Scale.getNote(token) => int note;
        if (note != -1){
            return new Pattern(new Atom(new Map("note", token)));
        } 

        // Otherwise, return as a generic value
        return new Pattern(new Atom(new Map("value", token)));
    }

    // Deal with a sequence of space-separated tokens
    fun PatternFunc[] unspace(string token){
        utils.unspace(token) @=> string itemsStr[];
        PatternFunc itemsPatterns[0];

        for (0 => int i; i < itemsStr.size(); i++){
            itemsStr[i] => string token;
            token => string item;

            // Compute the weight
            utils.isElongated(token) => int elongate;
            1.0 => float weight;
            if (elongate > -1) {
                Std.atof(item.substring(elongate+1)) => weight;
                item.substring(0, elongate) => item;
            }

            // Compute the density
            utils.isReplicated(item) => int rep;
            1.0 => float density;
            if (rep > -1) {
                Std.atof(item.substring(rep+1)) => weight;
                item.substring(0, rep) => item;
                1 / weight => density;
            }

            parse(item) @=> Pattern p;
            weight => p.pattern.weight;
            density => p.pattern.density;
            // if (rep > -1) itemsPatterns << new Replicate(p.pattern); else
            itemsPatterns << p.pattern;
        }
        return itemsPatterns;
    }

}