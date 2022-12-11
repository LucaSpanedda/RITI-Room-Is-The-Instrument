// Faust standard libraries
import("stdfaust.lib");

// Spectral Modeling Synthesis
// https://en.wikipedia.org/wiki/Spectral_modeling_synthesis

//  BP FILTER ----------------------------------------------
// optimized BP from the TPT version of the SVF Filter by Vadim Zavalishin
// reference : (by Will Pirkle)
// http://www.willpirkle.com/Downloads/AN-4VirtualAnalogFilters.2.0.pdf
BPSVF(glin, bw, cf, x) = loop ~ si.bus(2) : (! , ! , _)
    with {
        g = tan(cf * ma.PI * ma.T);
        Q = cf / max(1.0, bw);
        R = 1.0 / (Q + Q);
        G = 1.0 / (1.0 + 2.0 * R * g + g * g);
        loop(s1, s2) = u1 , u2 , bp * glin
            with {
                bp = (g * (x - s2) + s1) * G;
                bp2 = bp + bp;
                v2 = bp2 * g;
                u1 = bp2 - s1;
                u2 = v2 + s2;
            };
    };

// INSTRUMENT SPECTRE --------------------------------------
// list: Frequencies, Amps, Bandwidth
spectrefreq = ( 129.55994499312413, 261.8764845605701, 259.11988998624827, 325.27815976997124, 132.31653956744594, 195.7182147768471, 135.07313414176772, 256.3632954119265, 264.6330791348919, 328.03475434429305, 846.2745343167896, 520.9963745468184, 1108.1510188773598, 330.79134891861486, 137.8297287160895, 391.4364295536942, 198.47480935116891, 716.7145893236655, 1105.394424303038, 780.1162645330667, 121.29016127015878, 118.53356669583698, 192.96162020252532, 782.8728591073884, 2409.263657957245, 319.7649706213277, 317.00837604700587, 333.5479434929366, 1041.9927490936368, 275.659457432179, 454.83810476309543, 650.5563195399425, 115.7769721215152, 314.2517814726841, 1171.552694086761, 201.2314039254907, 203.98799849981248, 124.04675584448057, 190.20502562820354, 245.33691711463933, 975.8344793099138, 278.4160520065008, 267.38967370921364, 66.15826978372297, 242.58032254031755, 849.0311288911114, 272.90286285785726, 388.67983497937246, 148.8561070133767, 311.4951868983623, 978.5910738842356, 2412.0202525315667, 281.17264658082263, 206.7445930741343, 253.6067008376047, 151.61270158769847, 126.80335041880235, 912.4328041005126, 294.95561945243156, 239.82372796599577, 336.3045380672584, 457.5946993374172, 322.5215651956495, 2083.9854981872736 );
spectreamps = ( 0.10296897, 0.08541786, 0.08251663, 0.06961161, 0.05287735, 0.045743566, 0.023809433, 0.0222178, 0.021449901, 0.020397715, 0.018738171, 0.016159637, 0.014195229, 0.012720414, 0.0122202635, 0.011309004, 0.01096574, 0.010652141, 0.010569801, 0.01052872, 0.010389255, 0.009786074, 0.009583302, 0.0088912705, 0.008741568, 0.00872121, 0.008528015, 0.008511754, 0.008424098, 0.008201121, 0.008183193, 0.008126589, 0.007836982, 0.0077589434, 0.0076152403, 0.007559998, 0.0075054276, 0.0073422813, 0.007247762, 0.007225244, 0.0070567015, 0.006937664, 0.0067791366, 0.0067622834, 0.006728307, 0.0064722965, 0.0061831484, 0.005800677, 0.0057434384, 0.0057088095, 0.005630103, 0.0055296235, 0.0054903137, 0.00545266, 0.0054097753, 0.0054018316, 0.005351535, 0.0052661845, 0.0051531605, 0.0051409504, 0.005139122, 0.0051108524, 0.004931564, 0.0048702704 );
spectreband = ( 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 );
// index of the lists
Flist(index) = ba.take(index + 1, spectrefreq);
Alist(index) = ba.take(index + 1, spectreamps);
BWlist(index) = ba.take(index + 1, spectreband);

// Spectre BP Filter Bank
filterbanks(cascade, parallel, gglob, bwglob, fsglob, x) = 
    x <: par(i, parallel,
                            seq(r, cascade, BPSVF(
                                            Alist(i) * gglob, 
                                            BWlist(i) * bwglob, 
                                            Flist(i) * fsglob
                                            ) 
                                )
            ):> (+/parallel);
//process = (no.noise : filterbanks(2, 64, 2, 1, 1)),_;

// Spectre Sinusoidal Oscillators Bank
oscillatorbanks(parallel, gglob, fsglob) = 
         par(i, parallel,   ( 
                                os.osc( Flist(i) * fsglob) * 
                                        Alist(i) ) * gglob
            ):> (+/parallel);
//process = oscillatorbanks(32, 40, 1) <: _,_;     


// SMS OUT
smspan = hslider("sms",.8,0,1,.001) : si.smoo;    
bwpan = hslider("bwpan",5,1,100,.001) : si.smoo;  
outgain = hslider("outgain",1,1,100,.001) : si.smoo;  
process =   ((oscillatorbanks(32, 40, 1) * (1-smspan)) +
            (no.noise : filterbanks(2, 64, 2, bwpan, 1)) * smspan) * 
                outgain <: _,_;
