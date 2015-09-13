/* foma.i */
 %module FomaWrapper
 %{
 /* Put header files here or function declarations like below */
 extern struct fsm *openFomaFile(char *filename);
 extern char *findStemWord(char *word,struct fsm *net);
 extern void destroyFomaFile(struct fsm *net);
 %}
 
 extern struct fsm *openFomaFile(char *filename);
 extern char *findStemWord(char *word,struct fsm *net);
 extern void destroyFomaFile(struct fsm *net);
