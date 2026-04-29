public class AudioGraph {
    fun static JCRev jcrev(float m){ JCRev rev; rev.mix(m); return rev; }
    fun static NRev nrev(float m){ NRev rev; rev.mix(m); return rev; }
    fun static PRCRev prcrev(float m){ PRCRev rev; rev.mix(m); return rev; }
    fun static HPF hpf(float f){ HPF h; h.freq(f); return h; }
    fun static LPF lpf(float f){ LPF l; l.freq(f); return l; }
    fun static BPF bpf(float f){ BPF b; b.freq(f); return b; }
    fun static BRF brf(float f){ BRF b; b.freq(f); return b; }
    fun static BiQuad biquad(float f){ BiQuad b; b.pfreq(f); return b; }
    fun static ResonZ resonz(float f){ ResonZ r; r.freq(f); return r; }
    fun static OnePole onepole(float coeff){ OnePole o; o.pole(coeff); return o; }
    fun static OneZero onezero(float coeff){ OneZero o; o.zero(coeff); return o; }
    fun static TwoPole twopole(float f){ TwoPole t; t.freq(f); return t; }
    fun static TwoZero twozero(float f){ TwoZero t; t.freq(f); return t; }
    fun static PoleZero polezero(float coeff){ PoleZero p; p.allpass(coeff); return p; }
    fun static Chorus chorus(){ Chorus c; return c; }
    fun static PitShift shifter(float shift, float mix){ PitShift p; p.shift(shift); p.mix(mix); return p; }
    fun static Modulate modulate(float vf){ Modulate mod; mod.vibratoRate(vf); return mod; }
    fun static Echo delay(float t){ Echo d(t::second); return d; }
    fun static DelayL delayl(float t){ DelayL d; t::second => d.delay; return d; }
    fun static DelayA delaya(float t){ DelayA d; t::second => d.delay; return d; }
    fun static HalfRect halfrect(){ HalfRect h; return h; }
    fun static FullRect fullrect(){ FullRect f; return f; }
    
    fun static Pan2 pan(float p){ Pan2 pan2; p => pan2.pan; return pan2; }
    fun static Gain gain(float g){ Gain gainNode; g => gainNode.gain; return gainNode; }
}

