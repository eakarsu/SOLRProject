package org.apache.lucene.analysis.tr;
// runme.java

public class test {
  static {
    System.loadLibrary("fomahelpers");
  }

  public static void main(String argv[]) {
    String result = null;
    SWIGTYPE_p_fsm fsm = FomaWrapper.openFomaFile("/home/eakarsu/TRmorph/trmorph.fst");
    
    long s = System.currentTimeMillis();
    
    String w = FomaWrapper.findStemWord("sular",fsm);
    
    long e = System.currentTimeMillis();
    System.out.println (" In java got stem:"+w+"   in "+(e-s)+" ms");
    FomaWrapper.destroyFomaFile(fsm);
  }
}
