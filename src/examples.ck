public class Examples {

    fun static string Beat(){
       return "
        [bd bd] <[bd bd] [bd - - bd - - bd <- bd>]>,
        [- hh] [- hh] [- hh] [- hh*2],
        [oh - <- oh - oh*2> oh - - oh -]*2,
        [- sd]*4
        ";
    }

    fun static string Sweden(){
        return "<
        [e2 f#2]
        [g2 b2]
        [a2 g2]
        [d2]
        ,
        [e3,g3]
        [a3,d4]
        [f#3,a3]
        [c#4,e4]
        [e3,g3,b3]
        [a3,d4,f#4]
        [f#3,a3,c#4]
        [a3,c#4,e4]
        ,
        -!8
        [- [a4 b4]]
        [- [- [- [d4 e4]]]]
        [- [- [- [f#4 a4]]]]
        -
        [- d5 b4 a4]
        [- [- [- [d4 e4]]]]
        [- [- [- [a4 f#4]]]]
        -
        [- [a4 b4]]
        [d5 [- [- [f#5 e5]]]]
        [c#5 [- [- [d5 c#5]]]]
        a4
        [- [b4 a4]]
        [- [- [- [d4 e4]]]]
        [- [- [- [f#4 a4]]]]
        -
        >";
    }

    fun static string Tetris(){
        return "
        <
        [e5 [b4 c5] d5 [c5 b4]]
        [a4 [a4 c5] e5 [d5 c5]]
        [b4 [~ c5] d5 e5]
        [c5 a4 a4 ~]
        [[~ d5] [~ f5] a5 [g5 f5]]
        [e5 [~ c5] e5 [d5 c5]]
        [b4 [b4 c5] d5 e5]
        [c5 a4 a4 ~]
        ,
        [[e2 e3]*4]
        [[a2 a3]*4]
        [[g#2 g#3]*2 [e2 e3]*2]
        [a2 a3 a2 a3 a2 a3 b1 c2]
        [[d2 d3]*4]
        [[c2 c3]*4]
        [[b1 b2]*2 [e2 e3]*2]
        [[a1 a2]*4]
        >
        ";
    }
}