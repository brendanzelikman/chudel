// -----------------------------------------------------------------------------
// efx.ck
// Custom audio effects (Chugens) for Chudel.
// This file will house new effects that are not natively built into ChucK,
// allowing them to be imported and used within the Chudel signal chain.
// -----------------------------------------------------------------------------

// Wavefolder effect
// limit: defines the threshold at which the audio signal reflects back
public class Wavefolder extends Chugen {
    1.0 => float limit;
    
    fun void setLimit(float l) { l => limit; }
    
    // The tick function processes audio sample-by-sample
    fun float tick(float in) {
        // Basic reflection algorithm
        if (in > limit) return limit - (in - limit);
        if (in < -limit) return -limit - (in + limit);
        return in;
    }
}

// Bitcrusher effect
// bits: defines the number of bits for quantization (e.g. 4 for 4-bit)
public class Bitcrusher extends Chugen {
    8.0 => float bits;
    
    fun void setBits(float b) { b => bits; }
    
    fun float tick(float in) {
        if (bits <= 0) return in;
        Math.pow(2.0, bits - 1.0) => float steps;
        return Math.floor(in * steps + 0.5) / steps;
    }
}

// Add more custom effects below!
