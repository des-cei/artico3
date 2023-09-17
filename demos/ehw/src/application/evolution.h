#ifndef EVOLUTION_H_
#define EVOLUTION_H_

#include "sysarr.h" /* struct Chromosome */

//~ #define __FULL__

#ifdef __FULL__
#define EVALS  960000  // total number of evaluations in one evolution
#else
#define EVALS  96000  // total number of evaluations in one evolution
#endif /* __FULL__ */

#define TRIBES     12  // population size

#ifdef __FULL__
#define SUBEVO_GENS (12000/TRIBES)  // generations per war
#else
#define SUBEVO_GENS (1200/TRIBES)  // generations per war
#endif /* __FULL__ */

//~ #define ONEPLUSLAMBDA // uncommented = (1+TRIBES); commented = TRIBESx(1+1)
#define WAR  // duplicate best and kill worst

#define MUT_RATE    2  // number of genes that mutate in a mutation
//~ #define MUT_RATE    0  // number of genes that mutate in a mutation
//~ #define INIT_RANDOM  // comment out for starting with copy filter
#define MUTATE_OUTPUT  // comment out for having a fixed output
#define SINGLE_COLUMN  // put all mutations on the same column


void sysarr_load_pbs(void); // formerly on sysarr.h

extern unsigned int rand_n_seed;
//~ unsigned int rand_n(unsigned int n);
int get_gene(struct Chromosome *ch, int i, int j);
void evolve_check(const struct Chromosome pop[], unsigned int pop_fit[],
        int (*sa_cfg)(const struct Chromosome *ch, int arr) );
void evolve_init(struct Chromosome pop[], unsigned int pop_fit[],
        int (*sa_cfg)(const struct Chromosome *ch, int arr) );
int evolve_gen(struct Chromosome pop[], unsigned int pop_fit[],
        int (*sa_cfg)(const struct Chromosome *ch, int arr) );

int random_gen(struct Chromosome pop[], unsigned int pop_fit[],
        int (*sa_cfg)(const struct Chromosome *ch, int arr) );

void resize_chrom(struct Chromosome *ch, int height, int width);

#endif /* EVOLUTION_H_ */

