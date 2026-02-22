/*


algorithm:

start with ea and eb (exponents of a and b)

let larger exponent number = Large
let smaller exponent = Small

Find:
    1. for the large :
    n = number of times can (mantissa X 10)&(exp--) before it overflows

    2. for both:
    find difference = between ea and eb
        d = |ea - eb|;


if (n >= d){
    do (mantissa X 10)&(exp--) on large:  (d times)
}

else{
    do (mantissa X 10)&(exp--) on large:  (n times)
    do (mantissa / 10)&(exp++) on small:  (d-n times)

}

if(exp of large == exp of small){   //of course it will be, just a sanity check
    add mantissas of both // can overflow 34 bits, so you still need: while mantRes > M_MAX, do mantRes /= 10 and expRes++
    return the sum mantissa, and either exponent of larrge or small
}


1. "evaluates using the old values, so you will typically need one extra cycle after the counters hit 0 (not a big deal), 
but more importantly: on entry to S_CASE_B, nTemp and dnTemp are being assigned in S_CASE (NBAs), 
so in the first cycle of S_CASE_B they may still be old/unknown unless you ensure a clean handoff.
Easiest fix: add a “load” state (or do the loads in S_FIND_ND) so that when you enter S_CASE_B, nTemp/dnTemp are already valid registered values"

wtf are you talkign about? the nums are beig assigned in case, and caseB wont start for another clock cycle, enough time for the register to be assigned, right?

2. "But 17179869183 needs 35 bits;"

wrong, it requires 34 bits. 2^34 -1 = 17179869183, learn to do math.


3. "ou only reset state right now. It’s better to reset mantSum/signSum/expSum, temps, and outputs too, to avoid X-propagation in sim and random state after reset releas"

yes, i need your help finding all registers and resetting them to 0.

4. 






















*/









