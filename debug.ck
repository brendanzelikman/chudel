@import "chudel.ck"

class DebugChudel extends Chudel {
    fun void playAudio(Hap hap, dur duration) {
        <<< "activeVoices before:", activeVoices >>>;
        super.playAudio(hap, duration);
        <<< "activeVoices after:", activeVoices >>>;
    }
}

DebugChudel c;
c.debug();
c.livecode(".strudel");
c.run();
