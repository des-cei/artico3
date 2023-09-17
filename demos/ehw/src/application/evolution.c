/** Evolution-related functions.
 *
 * This defines all the functions needed to implement a parallelized (1+1)-ES.
 * Other evolutionary algorithms can be implemented using this file
 * as template, only modifying the body of the functions and maybe
 * adding/removing auxiliary functions.
 *
 * This file includes the definition of the functions used for the PEs
 * (partial bitstreams to be written on the LUTs).
 **/

#include "evolution.h"
#include "sysarr.h" // struct Chromosome, sysarr_cfg(), sysarr_go(), SA_*
#include <stdint.h> // uint32_t

#ifndef __linux__

    #include <xparameters.h> // XPAR_FAST_ICAP_0_MEM0_BASEADDR

    #define ICAP_MEM_BASEADDR  XPAR_FAST_ICAP_SYSARR_0_S_AXI_MEM_BASEADDR
    #define ICAP_MEM_HIGHADDR  XPAR_FAST_ICAP_SYSARR_0_S_AXI_MEM_HIGHADDR
    #if ICAP_MEM_BASEADDR==0xFFFFFFFF || ICAP_MEM_BASEADDR==0xFFFFFFFFFFFFFFFF
        #error XPAR_FAST_ICAP_SYSARR_0_S_AXI_MEM_BASEADDR not set; \
                please set ICAP_MEM_BASEADDR manually
    #endif
    #if ICAP_MEM_HIGHADDR==0
        #error XPAR_FAST_ICAP_SYSARR_0_S_AXI_MEM_HIGHADDR not set; \
                please set ICAP_MEM_HIGHADDR manually
    #endif

#else

    #include <stdio.h>
    #include <stdlib.h>
    #include <unistd.h>
    #include <sys/mman.h>
    #include <fcntl.h>

    #include "artico3.h"

    extern unsigned int naccs;

#endif /* __linux__ */

#define SA_H_MAX  8  // actual dimensions of systolic array
#define SA_W_MAX  8
#define SYSARR_H  SA_H_MAX  // dimensions of systolic array used in evolution
#define SYSARR_W  SA_W_MAX

#define WINDOW_MAX 5 // actual dimensions of input window
#define WINDOW     3 // dimensions of input window used in evolution



/*** PBS generation (LUT functions) (formerly on sysarr.c) ***/

/* LUT content distribution (for A4 fixed to 0):
 * MSb                 LSb     MSb                 LSb           L(M)    L
 *  0  2  4  6 16 18 20 22     32 34 36 38 48 50 52 54    frame 32(34) \ 26
 *  1  3  5  7 17 19 21 23     33 35 37 39 49 51 53 55    frame 33(35) \ 27
 *
 * bit 5 (A6):
 *  0  0  0  0  0  0  0  0      1  1  1  1  1  1  1  1
 *  0  0  0  0  0  0  0  0      1  1  1  1  1  1  1  1
 *
 * bit 4 (A5):
 *  0  0  0  0  1  1  1  1      0  0  0  0  1  1  1  1
 *  0  0  0  0  1  1  1  1      0  0  0  0  1  1  1  1
 *
 * bit 3 (A4): always 0
 *
 * bit 2 (A3):
 *  0  0  1  1  0  0  1  1      0  0  1  1  0  0  1  1
 *  0  0  1  1  0  0  1  1      0  0  1  1  0  0  1  1
 *
 * bit 1 (A2):
 *  0  1  0  1  0  1  0  1      0  1  0  1  0  1  0  1
 *  0  1  0  1  0  1  0  1      0  1  0  1  0  1  0  1
 *
 * bit 0 (A1):
 *  0  0  0  0  0  0  0  0      0  0  0  0  0  0  0  0
 *  1  1  1  1  1  1  1  1      1  1  1  1  1  1  1  1
 */

// Frame:    1st  2nd
//           <--><-->
#define A6 0x00FF00FF
#define A5 0x0F0F0F0F
//      A4 (unused)
#define A3 0x33333333
#define A2 0x55555555
#define A1 0x0000FFFF

#define N  A5  // north (1st stage)
#define W  A3  // west  (1st stage)
#define N2 A2  // north (2nd stage)
#define W2 A1  // west  (2nd stage)
#define S  A3  // sum   (mod 256)
#define S2 A5  // sum/2 (rounded down)
#define C  A6  // carry (overflow)
#define FF 0xFFFFFFFF // all ones

#define ADD(a,b) (( /* O5: */ ((a)&(b)) & ~A6 ) | ( /* O6: */ ((a)^(b)) & A6 ))
#define SAT(noovf, ovf)  (( (noovf) & ~C ) | ( (ovf) & C ))
#define FUNC(a,b, noovf,ovf)  { ADD((a), (b)),  SAT((noovf), (ovf)) }

//~ #define USE_IMPROVED_LIB // uncomment for new 19-function PE library

#ifndef USE_IMPROVED_LIB
    #define SA_FUNCTIONS  16
#else
    #define SA_FUNCTIONS  19
#endif
#if WINDOW == 3
    #define SA_IN_MUX  9
#else // WINDOW == 5
    #define SA_IN_MUX 25
#endif
#define SA_OUT_MUX     2
#define SA_ALL_LUTS (SA_FUNCTIONS + SA_IN_MUX + SA_OUT_MUX)

#ifndef USE_IMPROVED_LIB
    #define INIT_PE       11 // W
#else
    #define INIT_PE        1 // W
#endif
#if WINDOW == 3
    #define INIT_IN    4 // C
#else // WINDOW == 5
    #define INIT_IN   12 // C
#endif
#define INIT_OUT (SYSARR_H-1) // bottom right

static const uint32_t lut_functions[SA_ALL_LUTS][2] = {
    /** PE functions **/
   #ifndef USE_IMPROVED_LIB
    /* Original (NB: set INIT_PE to 11!) */
    // Stage1  Stage2
    FUNC(N,W,   S,S),   // N+W mod
    FUNC(N,N,   S,S),   // 2N  mod
    FUNC(W,W,   S,S),   // 2W  mod
    FUNC(N,W,   S,FF),  // N+W sat
    FUNC(N,N,   S,FF),  // 2N  sat
    FUNC(W,W,   S,FF),  // 2W  sat
    FUNC(N,W,   S2,S2), // (N+W)/2
    FUNC(0,0,   FF,FF), // 255

    FUNC(N,0,   S2,S2), // N/2
    FUNC(W,0,   S2,S2), // W/2
    FUNC(0,0,   N2,N2), // N
    FUNC(0,0,   W2,W2), // W
    FUNC(N,~W,  W2,N2), // max
    FUNC(N,~W,  N2,W2), // min
    FUNC(~N,W,  ~S,0),  // N-W
    FUNC(~W,N,  ~S,0),  // W-N
   #else
    /* Improved */
    //  Stage1  Stage2
    FUNC(0,0,   N2,N2),   // N
    FUNC(0,0,   W2,W2),   // W
    FUNC(N,~W,  W2,N2),   // max
    FUNC(N,~W,  N2,W2),   // min
    FUNC(N,W,   0,S),     // N+W-256 (sat<0)
    FUNC(~N,W,  ~S,0),    // N-W     (sat<0)
    FUNC(~W,N,  ~S,0),    // W-N     (sat<0)
    FUNC(N,W,   S,FF),    // N+W     (sat>255)
    FUNC(~N,W,  FF,~S),   // N-W+256 (sat>255)
    FUNC(~W,N,  FF,~S),   // W-N+256 (sat>255)
    FUNC(N,W,   S,S),     // N+W (mod)
    FUNC(~N,W,  ~S,~S),   // N-W (mod)
    FUNC(~W,N,  ~S,~S),   // W-N (mod)
    FUNC(N,W,   S2,S2),   // (N+W)/2
    FUNC(~N,W,  ~S2,~S2), // (N-W)/2+128
    FUNC(~W,N,  ~S2,~S2), // (W-N)/2+128
    FUNC(~N,W,  ~S,S),    // abs(N-W+0.5)
    FUNC(~N,W,  FF,0),    // N>=W ? 255 : 0
    FUNC(~W,N,  FF,0),    // W>=N ? 255 : 0
   #endif // USE_IMPROVED_LIB

    /** Input muxes **/
  #if WINDOW_MAX == 3 // && WINDOW == 3 (can't be 5)

    {A6, A6}, {A5, A6}, {A3, A6},  // SE, E, NE    (CH0+0, CH1+0, CH2+0)
    {A6, A5}, {A5, A5}, {A3, A5},  // S,  C,  N    (CH0+1, CH1+1, CH2+1)
    {A6, A3}, {A5, A3}, {A3, A3},  // SW, W, NW    (CH0+2, CH1+2, CH2+2)

  #else // WINDOW_MAX == 5

   #if WINDOW == 3
    {A5, A5}, {A3, A5}, {A2, A5},  // SE, E, NE    (CH1+1, CH2+1, CH3+1)
    {A5, A3}, {A3, A3}, {A2, A3},  // S,  C,  N    (CH1+2, CH2+2, CH3+2)
    {A5, A2}, {A3, A2}, {A2, A2},  // SW, W, NW    (CH1+3, CH2+3, CH3+3)
   #else // WINDOW == 5
    {A6, A6}, {A5, A6}, {A3, A6}, {A2, A6}, {A1, A6}, //CH0..4+0  SE- E -NE
    {A6, A5}, {A5, A5}, {A3, A5}, {A2, A5}, {A1, A5}, //CH0..4+1  - - - - -
    {A6, A3}, {A5, A3}, {A3, A3}, {A2, A3}, {A1, A3}, //CH0..4+2  S - C - N
    {A6, A2}, {A5, A2}, {A3, A2}, {A2, A2}, {A1, A2}, //CH0..4+3  - - - - -
    {A6, A1}, {A5, A1}, {A3, A1}, {A2, A1}, {A1, A1}, //CH0..4+4  SW- W -NW
   #endif // WINDOW

  #endif // WINDOW_MAX

    /** Output muxes **/
    {A6, 0},  // pass
    {A5, 0},  // get
};

#undef FUNC
#undef ADD
#undef SAT

#undef N
#undef W
#undef N2
#undef W2
#undef S
#undef S2
#undef C
#undef FF

#undef A6
#undef A5
//     A4
#undef A3
#undef A2
#undef A1

#ifndef __linux__

    #define PE_SIZE  ((ICAP_MEM_HIGHADDR - ICAP_MEM_BASEADDR + 1) \
            / sizeof (uint32_t) / 64)
    #define PE_ADDR  ((volatile uint32_t (*)[PE_SIZE]) ICAP_MEM_BASEADDR)
    void sysarr_load_pbs(void) {
        int i;
        for (i=0; i<SA_ALL_LUTS; i++) {
            uint32_t f1, f2;

            // Stage 1 (2 frames; ABOVE stage 2)
            f1 = f2 = lut_functions[i][0];
            f1 = f1 >> 16;    // frame 1
            f2 = f2 & 0xFFFF; // frame 2

            //   2 CLBs * 2 words/frame/CLB * 2 frames = 8 words
            PE_ADDR[i][4] = PE_ADDR[i][5] = PE_ADDR[i][6] = PE_ADDR[i][7]
                    = f1<<16 | f1;
            PE_ADDR[i][12] = PE_ADDR[i][13] = PE_ADDR[i][14] = PE_ADDR[i][15]
                    = f2<<16 | f2;

            // Stage 2 (2 frames; BELOW stage 1)
            f1 = f2 = lut_functions[i][1];
            f1 = f1 >> 16;    // frame 1
            f2 = f2 & 0xFFFF; // frame 2

            //   2 CLBs * 2 words/frame/CLB * 2 frames = 8 words
            PE_ADDR[i][0] = PE_ADDR[i][1] = PE_ADDR[i][2] = PE_ADDR[i][3]
                    = f1<<16 | f1;
            PE_ADDR[i][8] = PE_ADDR[i][9] = PE_ADDR[i][10] = PE_ADDR[i][11]
                    = f2<<16 | f2;
        }
    }

#else

    #define PE_SIZE (0x10000 / sizeof (uint32_t) / 64)
    volatile uint32_t (*PE_ADDR)[PE_SIZE];

    void sysarr_load_pbs(void) {

        // Managed through /dev/mem
        int fd;
        fd = open("/dev/mem", O_RDWR);

        // Map ICAP_MEM to userspace
        PE_ADDR = mmap(NULL, 0x10000, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0x41000000);
        //~ printf("ICAP_MEM  : %p\n", PE_ADDR);

        int i;
        for (i=0; i<SA_ALL_LUTS; i++) {
            uint32_t f1, f2;

            // Stage 1 (2 frames; ABOVE stage 2)
            f1 = f2 = lut_functions[i][0];
            f1 = f1 >> 16;    // frame 1
            f2 = f2 & 0xFFFF; // frame 2

            //   2 CLBs * 2 words/frame/CLB * 2 frames = 8 words
            PE_ADDR[i][4] = PE_ADDR[i][5] = PE_ADDR[i][6] = PE_ADDR[i][7]
                    = f1<<16 | f1;
            PE_ADDR[i][12] = PE_ADDR[i][13] = PE_ADDR[i][14] = PE_ADDR[i][15]
                    = f2<<16 | f2;

            // Stage 2 (2 frames; BELOW stage 1)
            f1 = f2 = lut_functions[i][1];
            f1 = f1 >> 16;    // frame 1
            f2 = f2 & 0xFFFF; // frame 2

            //   2 CLBs * 2 words/frame/CLB * 2 frames = 8 words
            PE_ADDR[i][0] = PE_ADDR[i][1] = PE_ADDR[i][2] = PE_ADDR[i][3]
                    = f1<<16 | f1;
            PE_ADDR[i][8] = PE_ADDR[i][9] = PE_ADDR[i][10] = PE_ADDR[i][11]
                    = f2<<16 | f2;
        }

        // Unmap ICAP_MEM
        munmap(PE_ADDR, 0x10000);

        close(fd);
    }

#endif /* __linux__ */


/*** Gene handling functions ***/

/** Generate a uniformly distributed pseudo-random number between 0 and n-1,
 * where n MUST NOT be larger than 256 (but can be up to 256). **/
unsigned int rand_n_seed = 1;
unsigned int rand_n(unsigned int n) {
    rand_n_seed = rand_n_seed * 1103515245 + 12345; // example LCG in the C std
    return ((rand_n_seed>>8) * n) >> 24; //efficiently restrict range to 0..n-1
}


/** Offsets and shifts of each PE in a column **/
#define SA_WPC 3  /* chromosome words per sysarr column */
static const unsigned woffs[SA_H_MAX+1] = { 0, 0, 0, 0, 1, 1, 1, 1, 2};
static const unsigned shift[SA_H_MAX+1] = { 0, 8,16,24, 0, 8,16,24, 0};
#define GENE_MASK 63u

/** Set a specific gene in a chromosome **/
static inline void set_gene(struct Chromosome *ch, int i, int j, unsigned v) {
    if (i==0 && j==0) {
        unsigned ii;
        for (ii=0; ii<SA_H_MAX; ii++) {
            unsigned v2 = SA_FUNCTIONS + SA_IN_MUX + ((ii==v) ? 1 : 0);
            int w = woffs[ii+1] + SA_WPC*(1+SA_W_MAX);
            int s = shift[ii+1];
            ch->cfg[w] &= ~(GENE_MASK<<s);
            ch->cfg[w] |= v2<<s;
        }
    } else {
        if (i==0 || j==0)  v += SA_FUNCTIONS;
        int w = woffs[i] + SA_WPC*j;
        int s = shift[i];
        ch->cfg[w] &= ~(GENE_MASK<<s);
        ch->cfg[w] |= v<<s;
    }
}

/** Get the gene i,j from a chromosome.
 * If i=0 and j=0, get the output multiplexer (0 to height-1).
 * If i=0 or j=0, get an input multiplexer  (0 to 8).
 * Otherwise, get the function from PE (i-1, j-1)  (0 to 15).
 **/
int get_gene(struct Chromosome *ch, int i, int j) {
    if (i==0 && j==0) {
        unsigned ii;
        for (ii=0; ii<SA_H_MAX; ii++) {
            int w = woffs[ii+1] + SA_WPC*(1+SA_W_MAX);
            int s = shift[ii+1];
            int v = (ch->cfg[w] >> s) & GENE_MASK;
            if (v == SA_FUNCTIONS + SA_IN_MUX + 1) return ii;
        }
        return -1;  // should never happen
    } else {
        int w = woffs[i] + SA_WPC*j;
        int s = shift[i];
        int v = (ch->cfg[w] >> s) & GENE_MASK;
        if (i==0 || j==0)  v -= SA_FUNCTIONS;
        return v;
    }
}

#ifdef INIT_RANDOM
/** Generate a random chromosome (in place). **/
static void initialize_chrom(struct Chromosome *ch) {
    int i, j;
    // Initialize all elements to 63 (unconfigured).
    //   0xFFFFFFFF = 11_111111__11_111111__11_111111__11_111111
    //   MSbit(x2) (ignored by FastICAP) used to tell uninit'd and 0 apart.
    for (i=0; i<SA_WORDS; i++)  ch->cfg[i] = 0xFFFFFFFF;
    // Randomize each element.  Fill rest with copy-west.
    for (i=0; i<SYSARR_H+1; i++) {
        for (j=0; j<SYSARR_W+1; j++) {  // Randomize element
           #ifndef MUTATE_OUTPUT
            if (i==0&&j==0)  continue; // fixed output mux -- will be set later
           #endif
            unsigned v = rand_n( (i==0&&j==0) ? SYSARR_H :
                                 (i==0||j==0) ? SA_IN_MUX : SA_FUNCTIONS);
            set_gene(ch, i, j, v);
        };
        for ( ; j<SA_W_MAX+1; j++) {  // Fill rest with copy-west
            set_gene(ch, i, j, 11);  // 11 = copy west
        };
       #ifndef MUTATE_OUTPUT
        set_gene(ch, 0, 0, SYSARR_H-1); // fixed output mux
       #endif
    }
}
#else // INIT_RANDOM
/** Generate a chromosome for a copy filter (in place). **/
static void initialize_chrom(struct Chromosome *ch) {
    int i, j;
    // Initialize all elements to 63 (unconfigured).
    //   0xFFFFFFFF = 11_111111__11_111111__11_111111__11_111111
    //   MSbit(x2) (ignored by FastICAP) used to tell uninit'd and 0 apart.
    for (i=0; i<SA_WORDS; i++)  ch->cfg[i] = 0xFFFFFFFF;
    // Config each element as a copy filter.
    for (i=0; i<SYSARR_H+1; i++)  for (j=0; j<SA_W_MAX+1; j++) {
        set_gene(ch, i, j,
                (i==0&&j==0) ? INIT_OUT : (i==0||j==0) ? INIT_IN : INIT_PE);
    }
}
#endif // INIT_RANDOM

/** Generate a random chromosome (in place). **/
static void random_chrom(struct Chromosome *ch) {
    int i, j;
    // Initialize all elements to 63 (unconfigured).
    //   0xFFFFFFFF = 11_111111__11_111111__11_111111__11_111111
    //   MSbit(x2) (ignored by FastICAP) used to tell uninit'd and 0 apart.
    for (i=0; i<SA_WORDS; i++)  ch->cfg[i] = 0xFFFFFFFF;
    // Randomize each element.  Fill rest with copy-west.
    for (i=0; i<SYSARR_H+1; i++) {
        for (j=0; j<SYSARR_W+1; j++) {  // Randomize element
           #ifndef MUTATE_OUTPUT
            if (i==0&&j==0)  continue; // fixed output mux -- will be set later
           #endif
            unsigned v = rand_n( (i==0&&j==0) ? SYSARR_H :
                                 (i==0||j==0) ? SA_IN_MUX : SA_FUNCTIONS);
            set_gene(ch, i, j, v);
        };
        for ( ; j<SA_W_MAX+1; j++) {  // Fill rest with copy-west
            set_gene(ch, i, j, 11);  // 11 = copy west
        };
       #ifndef MUTATE_OUTPUT
        set_gene(ch, 0, 0, SYSARR_H-1); // fixed output mux
       #endif
    }
}

/** Mutate a chromosome (in place) **/
static inline void mutate_chrom(struct Chromosome *ch) {
    int ii;
   #ifdef SINGLE_COLUMN
    int j = rand_n(SYSARR_W+1);
   #endif
    for (ii=0; ii<MUT_RATE; ii++) {
        int i = rand_n(SYSARR_H+1);
       #ifndef SINGLE_COLUMN
        int j = rand_n(SYSARR_W+1);
       #endif
       #ifndef MUTATE_OUTPUT
        if (i==0&&j==0) { // do not mutate output mux
            ii--; // retry
            continue;
        }
       #endif
        unsigned v = rand_n( (i==0&&j==0) ? SYSARR_H :
                             (i==0||j==0) ? SA_IN_MUX : SA_FUNCTIONS);
        set_gene(ch, i, j, v);
    }
}



/*** Evolutionary algorithm functions ***/

/** Re-calculate the fitnesses of the population.
 *
 * Useful when the population has been modified externally, the sa_cfg
 * function has changed or has been affected (e.g. fault injection),
 * or the training images have changed.
 **/
void evolve_check(const struct Chromosome pop[], unsigned int pop_fit[],
        int (*sa_cfg)(const struct Chromosome *ch, int arr) ) {
    if (!sa_cfg)  sa_cfg = sysarr_cfg; // default
    int i1;
#ifndef __linux__
    for (i1=0; i1<TRIBES; i1+=SA_NUM) {
        int n = (SA_NUM <= TRIBES-i1) ? SA_NUM : TRIBES-i1;
#else
    for (i1=0; i1<TRIBES; i1+=naccs) {
        int n = (naccs <= TRIBES-i1) ? naccs : TRIBES-i1;
#endif /* __linux__ */
        int i2;
        for (i2=0; i2<n; i2++) sa_cfg(&pop[i1+i2], i2);
        sysarr_go((1u<<n) - 1);  // use n arrays
#ifndef __linux__
        for (i2=0; i2<n; i2++) pop_fit[i1+i2] = SA_FITNESS[i2];
#else
        a3data_t rcfg[SA_NUM] = {[0 ... SA_NUM-1] = 0}; // SA fitness
        artico3_kernel_rcfg("sysarr_system", SA_FITNESS(0), rcfg);
        for (i2=0; i2<n; i2++) pop_fit[i1+i2] = rcfg[i2];
#endif /* __linux__ */
    }
}

/** Initialize the population to be used in evolve_gen().
 *
 * pop[] and pop_fit[] are pointers into arrays that will hold the population
 * and its fitnesses, and must be previously allocated.
 * sa_cfg() is a callback function to be used for configuring a chromosome
 * (or NULL for using sysarr_cfg()).
 *
 * 8×(1+λ)-ES, so population size is 8
 **/
void evolve_init(struct Chromosome pop[], unsigned int pop_fit[],
        int (*sa_cfg)(const struct Chromosome *ch, int arr) ) {
    int i;
    for (i=0; i<TRIBES; i++)  initialize_chrom(&pop[i]);
    evolve_check(pop, pop_fit, sa_cfg);
}

/** Perform a war, selecting a new "best".  Used in evolve_gen().
 * If WAR is defined, also duplicate best and kill worst. **/
#ifdef WAR // "bloody" war -- one dies, one invades the resulting hole
static inline void war(struct Chromosome pop[], unsigned int pop_fit[]) {
    int best = 0, worst = 0;
    int i;
    for (i=1; i<TRIBES; i++) {
        if (pop_fit[i] < pop_fit[best])  best  = i;
        if (pop_fit[i] > pop_fit[worst]) worst = i;
    }
    pop[worst] = pop[0]; //remove worst (and move [0] out of the way)
    pop_fit[worst] = pop_fit[0];
    pop[0] = pop[best];  // duplicate best (and put it in [0])
    pop_fit[0] = pop_fit[best];
}
#else // "democracy" -- just elect best
static inline void war(struct Chromosome pop[], unsigned int pop_fit[]) {
    int best = 0;
    int i;
    for (i=1; i<TRIBES; i++) {
        if (pop_fit[i] < pop_fit[best])  best = i;
    }
    if (best == 0) return;
    struct Chromosome best_ch = pop[best];
    unsigned int best_fit = pop_fit[best];
    pop[best] = pop[0];
    pop_fit[best] = pop_fit[0];
    pop[0] = best_ch;
    pop_fit[0] = best_fit;
}
#endif // WAR

static inline void random_select(struct Chromosome pop[], unsigned int pop_fit[]) {
    int best = 0;
    int i;
    for (i=1; i<TRIBES; i++) {
        if (pop_fit[i] < pop_fit[best])  best = i;
    }
    if (best == 0) return;
    struct Chromosome best_ch = pop[best];
    unsigned int best_fit = pop_fit[best];
    pop[best] = pop[0];
    pop_fit[best] = pop_fit[0];
    pop[0] = best_ch;
    pop_fit[0] = best_fit;
}


/** Evolve population for SUBEVO_GENS generation.
 *
 * Arguments are the parent population, the fitnesses of the parent population,
 * and a callback function to be used for configuring the chromosomes
 * (or NULL for using sysarr_cfg()).
 *
 * Returns the number of times a child has replaced a parent.
 * This is useful for monitoring whether the algorithm has stopped evolving
 * (to check for actual improvements, pop_fit[] has to be checked).
 *
 * The algorithm is implemented so that pop[0] is the best individual.
 *
 * This implements a macro-generation of an Nx(1+1) "tribal" algorithm.
 * Each tribe evolves separately using a simple (1+1) mutation algorithm,
 * and at the end a "war" between tribes happens, duplicating the best tribe
 * and killing the weakest.  Additionally, the strongest is moved to [0].
 *
 * However, the parameters in evolution.h can tweak this behavior,
 * making it a (1+N) evolution or an Nx(1+1) with no wars (but with the
 * fittest individual still being moved to position [0]).
 **/

#ifdef ONEPLUSLAMBDA

int evolve_gen(struct Chromosome pop[], unsigned int pop_fit[],
        int (*sa_cfg)(const struct Chromosome *ch, int arr) ) {

    if (!sa_cfg)  sa_cfg = sysarr_cfg; // default (unneeded with evolve_check)

    int changes = 0;
    int i;

    // separate evolutions
    struct Chromosome children[TRIBES];
    unsigned int children_fit[TRIBES];
    unsigned int gen;
    for (gen = 0; gen < SUBEVO_GENS; gen++) {
        // mutate
        for (i=0; i<TRIBES; i++)  children[i] = pop[0];
        for (i=0; i<TRIBES; i++)  mutate_chrom(&children[i]);

        // evaluate
        evolve_check(children, children_fit, sa_cfg);

        // select
        int changed = 0;
        for (i=0; i<TRIBES; i++) {
            if (children_fit[i] <= pop_fit[0]) {  // if child fitter/equal
                pop[0] = children[i];
                pop_fit[0] = children_fit[i];
                changed = 1;
            }
        }
        changes += changed;
    }

    // no wars here

    return changes;
}

#else // not ONEPLUSLAMBDA

//~ #define HALF_AND_HALF  // requires as many systolic arrays as tribes!

#ifdef HALF_AND_HALF

#if SA_NUM < TRIBES
    #error Half-and-half evolution requires as many systolic arrays as tribes
#endif

int evolve_gen(struct Chromosome pop[], unsigned int pop_fit[],
        int (*sa_cfg)(const struct Chromosome *ch, int arr) ) {

    if (!sa_cfg)  sa_cfg = sysarr_cfg; // default

    int changes = 0;
    int i;

    // separate evolutions
    struct Chromosome children[TRIBES];
    unsigned int children_fit[TRIBES];
    unsigned int gen;

    for (gen = 0; gen <= SUBEVO_GENS; gen++) {
        // 1st half - select previous
        if (gen > 0) {
            for (i=0; i<TRIBES/2; i++) {
                if (children_fit[i] <= pop_fit[i]) { // if child fitter/equal
                    changes ++;
                    pop[i] = children[i];
                    pop_fit[i] = children_fit[i];
                }
            }
        }
        // 1st half - mutate
        if (gen < SUBEVO_GENS) {
            for (i=0; i<TRIBES/2; i++)  children[i] = pop[i];
            for (i=0; i<TRIBES/2; i++)  mutate_chrom(&children[i]);
        }
        // 1st half - reconfigure
        if (gen < SUBEVO_GENS) {
            for (i=0; i<TRIBES/2; i++)  sa_cfg(&children[i], i);
        }
        // 2nd half - finish previous launch
        if (gen > 0) {
            sysarr_wait();
            for (i=TRIBES/2; i<TRIBES; i++) children_fit[i] = SA_FITNESS[i];
        }
        // 1st half - launch
        if (gen < SUBEVO_GENS) {
            sysarr_start((1u<<(TRIBES/2))-1);
        }

        // 2nd half - select previous
        if (gen > 0) {
            for (i=TRIBES/2; i<TRIBES; i++) {
                if (children_fit[i] <= pop_fit[i]) { // if child fitter/equal
                    changes ++;
                    pop[i] = children[i];
                    pop_fit[i] = children_fit[i];
                }
            }
        }
        // 2nd half - mutate
        if (gen < SUBEVO_GENS) {
            for (i=TRIBES/2; i<TRIBES; i++)  children[i] = pop[i];
            for (i=TRIBES/2; i<TRIBES; i++)  mutate_chrom(&children[i]);
        }
        // 2nd half - reconfigure
        if (gen < SUBEVO_GENS) {
            for (i=TRIBES/2; i<TRIBES; i++)  sa_cfg(&children[i], i);
        }
        // 1st half - finish launch
        if (gen < SUBEVO_GENS) {
            sysarr_wait();
            for (i=0; i<TRIBES/2; i++) children_fit[i] = SA_FITNESS[i];
        }
        // 2nd half - launch
        if (gen < SUBEVO_GENS) {
            sysarr_start( ((1u<<TRIBES)-1) & ~ ((1u<<(TRIBES/2))-1) );
        }
    }

    // war
    war(pop, pop_fit);

    return changes;
}

#else // not HALF_AND_HALF

int evolve_gen(struct Chromosome pop[], unsigned int pop_fit[],
        int (*sa_cfg)(const struct Chromosome *ch, int arr) ) {

    if (!sa_cfg)  sa_cfg = sysarr_cfg; // default (unneeded with evolve_check)

    int changes = 0;
    int i;

    // separate evolutions
    struct Chromosome children[TRIBES];
    unsigned int children_fit[TRIBES];
    unsigned int gen;
    for (gen = 0; gen < SUBEVO_GENS; gen++) {
        // mutate
        for (i=0; i<TRIBES; i++)  children[i] = pop[i];
        for (i=0; i<TRIBES; i++)  mutate_chrom(&children[i]);

        // evaluate
        evolve_check(children, children_fit, sa_cfg);

        // select
        for (i=0; i<TRIBES; i++) {
            if (children_fit[i] <= pop_fit[i]) {  // if child fitter/equal
                pop[i] = children[i];
                pop_fit[i] = children_fit[i];
                changes ++;
            }
        }
    }

    // war
    war(pop, pop_fit);

    return changes;
}

#endif // HALF_AND_HALF

#endif // ONEPLUSLAMBDA

int random_gen(struct Chromosome pop[], unsigned int pop_fit[],
        int (*sa_cfg)(const struct Chromosome *ch, int arr) ) {

    if (!sa_cfg)  sa_cfg = sysarr_cfg; // default (unneeded with evolve_check)

    int i;

    // separate evolutions
    struct Chromosome children[TRIBES];
    unsigned int children_fit[TRIBES];
    unsigned int gen;
    for (gen = 0; gen < SUBEVO_GENS; gen++) {
        // generate random solution
        for (i=0; i<TRIBES; i++)  random_chrom(&children[i]);

        // evaluate
        evolve_check(children, children_fit, sa_cfg);

        // select
        for (i=0; i<TRIBES; i++) {
            if (children_fit[i] <= pop_fit[i]) {  // if child fitter/equal
                pop[i] = children[i];
                pop_fit[i] = children_fit[i];
            }
        }
    }

    // selection of best individual
    random_select(pop, pop_fit);

    return 0;
}



#if 0    /** Example evolution code **/

static struct Chromosome simple_evolution(void) {
    struct Chromosome pop[TRIBES];
    unsigned int pop_fit[TRIBES];
    unsigned int evals;

    evolve_init(pop, pop_fit, NULL);
    for (evals = 0; evals < EVALS; evals += TRIBES * SUBEVO_GENS) {
        evolve_gen(pop, pop_fit, NULL);
    }
    return pop[0];
}

#endif // 0

