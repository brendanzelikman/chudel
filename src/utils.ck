public class Utils {

    // ------------------------------------------
    // File Utilities
    // ------------------------------------------
    
    static FileIO fio;
    "chudel.txt" => static string defaultFile;
    fun static string readFile(){ return readFile(defaultFile); }
    fun static string readFile(string filePath){
        
        fio.open(me.dir() + filePath, FileIO.READ);
        fio.good() => int fileOk;
        if (!fileOk) return "";
        string content;
        while (fio.more()){ 
            fio.readLine() => string line;
            line + "\n" +=> content; 
        }
        return content;
    }

    // ------------------------------------------
    // Math Utilities
    // ------------------------------------------
    
    ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"] @=> string digits[];
    fun int mod(int a, int b){ return ((a % b) + b) % b; }
    fun int isDigit(string char){ for (string d : digits){ if (char == d) return 1; } return 0; }
    fun static dur cleanDur(dur x){ return x < 0::ms ? 0::ms : x; }

    // ------------------------------------------
    // String Properties
    // ------------------------------------------

    fun static int isLeftBracket(int s){ return s == '['; }
    fun static int isLeftBracket(string s){ return s == "["; }
    fun static int isRightBracket(int s){ return s == ']'; }
    fun static int isRightBracket(string s){ return s == "]"; }
    fun static int isLeftContainer(int s){ return s == '[' || s == '<' || s == '('; }
    fun static int isLeftContainer(string s){ return s == "[" || s == "<" || s == "("; }
    fun static int isRightContainer(int s){ return s == ']' || s == '>' || s == ')'; }
    fun static int isRightContainer(string s){ return s == "]" || s == ">" || s == ")"; }
    fun static int isSeparator(int s){ return s == ',' || s == ' '; }

    fun int isMultiplied(string s){ return findOuterChar(s, "*", [" ", ","]); }
    fun int isDivided(string s){ return findOuterChar(s, "/", [" ", ","]); }
    fun int isElongated(string s){ return findOuterChar(s, "@", [" ", ","]); }
    fun int isReplicated(string s){ return findOuterChar(s, "!", [" ", ","]); }
    fun int isSpaced(string s){ return findOuterChar(s, " ", [","]) > -1; }
    fun int isCommaSeparated(string s){ return findOuterChar(s, ",") > -1; }
    fun int isAlternated(string s){ return s.length() > 2 && s.charAt2(0) == "<" && findOuterChar(s, ">") == s.length() - 1; }
    fun int isGrouped(string s){ return s.length() > 2 && s.charAt2(0) == "[" && findOuterChar(s, "]") == s.length() - 1; }

    // ------------------------------------------
    // String Parsing
    // ------------------------------------------

    ["\n", "\t"] @=> static string trimChars[];
    fun static string trim(string x){ x => string r; for (string c : trimChars){ r.replace(c, ""); } return r; }
    fun string[] unspace(string s){ return outerSplit(s, " "); }
    fun string[] uncomma(string s){ return outerSplit(s, ","); }
    fun string unbracket(string s){ return s.length() < 2 ? s : s.substring(1, s.length() - 2); }

    fun static int find(string arr[], string target){ for (0 => int i; i < arr.size(); i++){ if (arr[i] == target) return i; } return -1; }
    fun static void flush(string arr[], string target){ if (!target.length()) return; target => string s; arr << s; "" => target; }

    // Split a string by a delimiter
    fun static string[] split(string x){ return split(x, " "); }
    fun static string[] split(string x, string delim){
        StringTokenizer strtok;
        strtok.set(x);
        strtok.delims(delim);
        string out[0];
        for (0 => int i; i < strtok.size(); i++){ out << strtok.get(i); }
        return out;
    }
    
    // Search for a one-char string at the outermost level (avoid specific chars)
    fun int findOuterChar(string s, string f){ return findOuterChar(s, f, string none[0]); }
    fun int findOuterChar(string s, string f, string avoid[]){
        0 => int depth;
        s.length() => int length;
        -1 => int found;
        for (0 => int i; i < length; i++){
            s.charAt2(i) => string c;
            if (isLeftContainer(c)){ depth++; } 
            else if (isRightContainer(c)){ depth--; }
            if (depth != 0) continue;
            if (c == f) i => found; continue;
            if (found < 0) continue;
            if (find(avoid, c) > -1) return -1;
        }
        return depth == 0 ? found : -1;
    }

    // Separate a string by char at the outermost level
    fun static string[] outerSplit(string s, string f){
        string out[0];
        0 => int depth;
        "" => string current;
        for (0 => int i; i < s.length(); i++){
            s.charAt2(i) => string c;
            if (isLeftContainer(c)) depth++;
            else if (isRightContainer(c)) depth--;
            if (depth == 0 && c == f) flush(out, current);
            else c +=> current;
        }
        flush(out, current);
        return out;
    }

    // Get the string up until the given char
    fun static string getSubstring(string text, string char){ 
        text.find(char) => int spot;
        return (spot >= 0) ? text.substring(0, spot) : text; 
    }
}

public class Map {
    string map[0];
    fun @construct(){}
    fun @construct(string k, string v){ set(k, v); }
    fun string[] keys(){ map.getKeys(string keys[0]); return keys; }
    fun string get(string key){ return has(key) ? map[key] : ""; }
    fun void set(string key, string value){ value => map[key]; }
    fun int has(string key){ return map.isInMap(key); }
    fun Map copy(){ Map m; keys() @=> string keys[]; for (string k : keys){ m.set(k, map[k]); } return m; }
    fun void clear(){ map.clear(); }
}

public class Arc {
    float start;
    float duration;
    float end;
    fun void set(float s, float d){ s => start; d => duration; s+d => end;}
    fun string toString(){ return "[" + start + "->" + start + duration + "]"; }
    fun @construct(float s, float d){ set(s, d); }
    fun Arc copy() { return new Arc(start, duration);}
}
