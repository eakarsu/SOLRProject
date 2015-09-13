#include <stdio.h>
#include <stdlib.h>
#include "fomalib.h"
#include <time.h>

struct fsm *openFomaFile(char *filename);
char *findStemWord(char *word,struct fsm *net);
void destroyFomaFile(struct fsm *net);
 
struct fsm *openFomaFile(char *filename)
{
  struct fsm *net;
  net = fsm_read_binary_file(filename);
  if (net == NULL) {
    perror("Error loading file");
    exit(EXIT_FAILURE);
  }
  return net;
}

float timedifference_msec(struct timeval t0, struct timeval t1)
{
    return (t1.tv_sec - t0.tv_sec) * 1000.0f + (t1.tv_usec - t0.tv_usec) / 1000.0f;
}

char *findStemWord(char *word,struct fsm *net)
{
  struct timeval t0;
  struct timeval t1;
  float elapsed;
  gettimeofday(&t0, 0);
   
  char *stemWord = (char *)malloc(1024);
  struct apply_handle *ah = apply_init(net);
  char *result = apply_up(ah, word);
  while (result != NULL) {
    printf("%s\n", result);
    strcpy(stemWord,result);
    strcat(stemWord,"\n");
    result = apply_down(ah, NULL);
  }
  apply_clear(ah);
  
  gettimeofday(&t1, 0);
  elapsed = timedifference_msec(t0, t1);
  printf("Code executed in %f milliseconds.\n", elapsed);
  
  return stemWord;
}

void destroyFomaFile(struct fsm *net)
{
  fsm_destroy(net);
}

int main(int argc, char *argv[]) {

  struct fsm *net;
  struct apply_handle *ah;
  char *result;
  char stemWord[1024];
  
  net = openFomaFile ("/home/eakarsu/TRmorph/trmorph.fst");
  char *p = findStemWord (argv[1],net);
  printf ("Got stem word = %s\n",p);
  free(p);
  destroyFomaFile(net);
  
  /*
  net = fsm_read_binary_file("/home/eakarsu/TRmorph/trmorph.fst");
  if (net == NULL) {
    perror("Error loading file");
    exit(EXIT_FAILURE);
  }
  clock_t start = clock(), diff;
  
  ah = apply_init(net);
  result = apply_up(ah, argv[1]);
  while (result != NULL) {
    printf ("in loop\n");
    printf("%s\n", result);
    result = apply_down(ah, NULL);
  }
  printf ("done\n");
  apply_clear(ah);
  diff = clock() - start;
  int msec = diff * 1000 / CLOCKS_PER_SEC;
  printf("Time taken %d seconds %d milliseconds", msec/1000, msec%1000);

  fsm_destroy(net);
  */
}
