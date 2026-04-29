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
    
    ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"] @=> static string digits[];
    fun static int mod(int a, int b){ return ((a % b) + b) % b; }
    fun static int isDigit(string char){ for (0 => int i; i < digits.size(); i++){ if (char == digits[i]) return 1; } return 0; }
    fun static dur cleanDur(dur x){ return x < 0::ms ? 0::ms : x; }

    // ------------------------------------------
    // String Properties
    // ------------------------------------------

    fun static int isLeftBracket(int s){ return s == '['; }
    fun static int isLeftBracket(string s){ return s == "["; }
    fun static int isRightBracket(int s){ return s == ']'; }
    fun static int isRightBracket(string s){ return s == "]"; }
    "[" => static string LEFT_BRACKET;
    "]" => static string RIGHT_BRACKET;
    "<" => static string LEFT_ANGLE;
    ">" => static string RIGHT_ANGLE;
    "(" => static string LEFT_PAREN;
    ")" => static string RIGHT_PAREN;
    fun static int isLeftContainer(string s){ return s == LEFT_BRACKET || s == LEFT_ANGLE || s == LEFT_PAREN; }
    fun static int isRightContainer(string s){ return s == RIGHT_BRACKET || s == RIGHT_ANGLE || s == RIGHT_PAREN; }
    fun static int isSeparator(int s){ return s == ',' || s == ' '; }

    // ------------------------------------------
    // String Parsing
    // ------------------------------------------

    ["\n", "\t"] @=> static string trimChars[];
    fun static string trim(string x){ x => string r; for (0 => int i; i < trimChars.size(); i++){ r.replace(trimChars[i], ""); } return r; }
    fun static string[] outerSplit(string s, string f){
        string out[0];
        0 => int depth;
        "" => string current;
        for (0 => int i; i < s.length(); i++){
            s.substring(i, 1) => string c;
            if (isLeftContainer(c)) depth++;
            else if (isRightContainer(c)) depth--;
            if (depth == 0 && c == f) {
                if (current.length() > 0) out << current.substring(0);
                "" => current;
            }
            else c +=> current;
        }
        if (current.length() > 0) out << current.substring(0);
        return out;
    }
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
    fun Map copy(){ Map m; keys() @=> string ks[]; for (0 => int i; i < ks.size(); i++){ m.set(ks[i], map[ks[i]]); } return m; }
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
