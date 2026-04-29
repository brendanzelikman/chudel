@import "utils.ck"

public class Scale {

    // Convert a pitch class to a number ("C" => 0, "C#" => 1, etc.)
    fun static int getPitchClassNumber(string pc){
        string pitchClassMap[12][0];
        ["B#", "C", "Dbb"] @=> pitchClassMap[0];
        ["B##", "C#", "Db"] @=> pitchClassMap[1];
        ["C##", "D", "Ebb"] @=> pitchClassMap[2];
        ["D#", "Eb", "Fbb"] @=> pitchClassMap[3];
        ["D##", "E", "Fb"] @=> pitchClassMap[4];
        ["E#", "F", "Gbb"] @=> pitchClassMap[5];
        ["E##", "F#", "Gb"] @=> pitchClassMap[6];
        ["F##", "G", "Abb"] @=> pitchClassMap[7];
        ["G#", "Ab"] @=> pitchClassMap[8];
        ["G##", "A", "Bbb"] @=> pitchClassMap[9];
        ["A#", "Bb", "Cbb"] @=> pitchClassMap[10];
        ["A##", "B", "Cb"] @=> pitchClassMap[11];
        for (0 => int i; i < 12; i++){
            pitchClassMap[i] @=> string pcs[];
            for (0 => int j; j < pcs.size(); j++){
                if (pcs[j].lower() == pc.lower()) return i;
            }
        }
        return -1;
    }

    // Convert a pitch class and octave to a MIDI pitch number
    fun static int getPitch(string pc, int octave){
        getPitchClassNumber(pc) => int pcNum;
        if (pcNum == -1) return 60;
        return pcNum + (octave + 1) * 12;
    }

    // Get a note from a scale given a degree
    fun static int indexScale(int scale[], int degree){
        scale.size() => int modulus;
        if (modulus == 0) return 60; // guard: scale lookup failed, return middle C
        Utils.mod(degree, modulus) => int index;
        Math.floor((degree $ float / modulus)) $ int => int octaves;
        return scale[index] + octaves * 12;
    }
    
    // Get the scale notes from a scale string
    fun static int[] getScale(string input){

        // Map of scale names to intervals
        int scaleMap[0][0];
        [0, 2, 4, 5, 7, 9, 11] @=> scaleMap["major"];
        [0, 2, 3, 5, 7, 8, 10] @=> scaleMap["minor"];
        [0, 2, 3, 5, 7, 9, 11] @=> scaleMap["dorian"];
        [0, 1, 3, 5, 7, 8, 10] @=> scaleMap["phrygian"];
        [0, 2, 4, 6, 7, 9, 11] @=> scaleMap["lydian"];
        [0, 2, 4, 5, 7, 9, 10] @=> scaleMap["mixolydian"];
        [0, 1, 3, 5, 6, 8, 10] @=> scaleMap["locrian"];
        string scaleKeys[0];
        scaleMap.getKeys(scaleKeys);

        60 => int baseNote;

        // Check for exact matches
        for (string key : scaleKeys){
            if (key == input){
                scaleMap[key] @=> int intervals[];
                int notes[0];
                for (int interval : intervals){
                    baseNote + interval => int note;
                    notes << note;  
                }
                return notes;
            }
        }

        // Check for roots
        Utils.split(input, ":") @=> string parts[];
        parts.size() => int partCount;
        "c" => string root;
        parts[0] => string scaleType;
        if (partCount == 2){
            parts[0] => root;
            parts[1] => scaleType;
        }

        // Parse the root note
        if (Utils.isDigit(root.charAt2(root.length() - 1))){
            Std.atoi(root.substring(root.length() - 1, 1)) => int octave;
            root.substring(0, root.length() - 1) => string pc;
            getPitch(pc, octave) => baseNote;
        } else {
            getPitch(root, 4) => baseNote;
        }

        // Build the scale from intervals
        scaleMap[scaleType] @=> int intervals[];
        int notes[0];
        for (int interval : intervals){
            baseNote + interval => int note;
            notes << note;
        }
        return notes;
    }

    // Convert a note string to a MIDI note number
    fun static int getNote(string note){
        note.length() => int length;
        if (length == 0) return -1;
        if (note == "-" || note == "~") return -1;

        // If the first digit is a number, parse as an offset from middle C (0 = 60)
        // Check for optional negative sign as well
        if (length < 1 || Utils.isDigit(note.charAt2(0)) || (note.charAt2(0) == "-" && length > 1)) return 60 + Std.atoi(note);

        // Otherwise, parse as a pitch class with potential octave
        4 => int octave;
        getOctaveIndex(note) => int octaveIndex;
        if (octaveIndex == -1) length => octaveIndex;
        else Std.atoi(note.charAt2(octaveIndex)) => octave;
        return Scale.getPitch(note.substring(0, octaveIndex), octave);
    }

    // Get the index of the octave of a pitch class
    fun static int getOctaveIndex(string note){
        note.length() => int length;
        for (1 => int i; i < note.length(); i++){
            note.charAt2(i) => string char;
            Utils.isDigit(char) => int isDigit;
            if (isDigit) return i;
        }
        return -1;
    }
}