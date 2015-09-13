package org.apache.lucene.analysis.tr;

/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import java.io.IOException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.net.SocketException;
import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.List;
import java.util.TreeSet;
import java.util.logging.Level;
import org.apache.lucene.analysis.TokenFilter;
import org.apache.lucene.analysis.TokenStream;
import org.apache.lucene.analysis.miscellaneous.StemmerOverrideFilter;
import org.apache.lucene.analysis.tokenattributes.CharTermAttribute;
import org.apache.lucene.analysis.tokenattributes.KeywordAttribute;
import org.apache.lucene.util.BytesRef;
import org.apache.lucene.util.CharsRef;
import org.apache.lucene.util.UnicodeUtil;
import org.apache.lucene.util.fst.FST;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Stemmer based on <a href="https://github.com/coltekin/TRmorph">TRmorph</a>
 */
public final class TRMorphStemFilter extends TokenFilter {

	static {
	    System.loadLibrary("fomahelpers");
	}
	
	public static final Logger log = LoggerFactory.getLogger(TRMorphStemFilter.class);

	public static final SWIGTYPE_p_fsm fsm = FomaWrapper.openFomaFile("/usr/local/lib/trmorph.fst");

	private final CharTermAttribute termAttribute = addAttribute(CharTermAttribute.class);
	private final KeywordAttribute keywordAttribute = addAttribute(KeywordAttribute.class);

	private StemmerOverrideFilter.StemmerOverrideMap cache;
	private FST.BytesReader fstReader;

	private final FST.Arc<BytesRef> scratchArc = new FST.Arc<>();
	private final CharsRef spare = new CharsRef();

	private final String aggregation;

	public static int MAXLEN = 64096;
	public static InetAddress IPAddress;
	public static int portNumber = 6062;

	public void setCache(StemmerOverrideFilter.StemmerOverrideMap cache) {
		this.cache = cache;
		fstReader = cache.getBytesReader();
	}

	public TRMorphStemFilter(TokenStream input, String aggregation) {
		super(input);
		this.aggregation = aggregation;
	}

	@Override
	public boolean incrementToken() throws IOException {

		if (!input.incrementToken()) {
			return false;
		}
		if (keywordAttribute.isKeyword()) {
			return true;
		}

		/**
		 * copied from {@link StemmerOverrideFilter#incrementToken}
		 */
		if (cache != null) {
			final BytesRef stem = cache.get(termAttribute.buffer(), termAttribute.length(), scratchArc, fstReader);
			if (stem != null) {
				final char[] buffer = spare.chars = termAttribute.buffer();
				UnicodeUtil.UTF8toUTF16(stem.bytes, stem.offset, stem.length, spare);
				if (spare.chars != buffer) {
					termAttribute.copyBuffer(spare.chars, spare.offset, spare.length);
				}
				termAttribute.setLength(spare.length);
				return true;
			}
		}

		/**
		 * copied from
		 * {@link org.apache.lucene.analysis.br.BrazilianStemFilter#incrementToken}
		 */
		final String term = termAttribute.toString();
		final String s = stem(term, aggregation);
		// If not stemmed, don't waste the time adjusting the token.
		if ((s != null) && !s.equals(term)) {
			termAttribute.setEmpty().append(s);
		}

		return true;
	}

	static String stem(String word, String aggregation) throws IOException {

		List<String> parses = parseLocal(word);

		TreeSet<String> set = new TreeSet<>();

		for (String parse : parses) {
			String[] parts = parse.split("\\s+");
			if (parts.length < 2) {
				// log.warn("unexpected line " + parse);
				continue;
			}

			String stem = parts[1].trim();

			int i = stem.indexOf("<");

			if (i == -1) {
				if (stem.contains("+?")) {
					return word;
				} else {
					// log.warn("unexpected stem " + stem);
					continue;
				}
			}

			set.add(stem.substring(0, i));

		}

		if (set.size() == 1) {
			return set.first();
		}

		switch (aggregation) {
		case "maxLength":
			return set.pollLast();
		case "minLength":
			return set.pollFirst();
		default:
			throw new RuntimeException("unknown strategy " + aggregation);
		}
	}

	private static List<String> parse(String word) throws SocketException, UnknownHostException, IOException {
		long b = System.currentTimeMillis();

		byte[] sendData = new byte[MAXLEN];
		byte[] receiveData = new byte[MAXLEN];

		InetAddress IPAddress = null;
		try {
			IPAddress = InetAddress.getByName("localhost");
		} catch (UnknownHostException ex) {
			java.util.logging.Logger.getLogger(TRMorphStemFilter.class.getName()).log(Level.SEVERE, null, ex);
		}

		DatagramSocket clientSocket = new DatagramSocket();
		sendData = word.getBytes("UTF-8");
		DatagramPacket sendPacket = new DatagramPacket(sendData, sendData.length, IPAddress, portNumber);
		clientSocket.send(sendPacket);
		DatagramPacket receivePacket = new DatagramPacket(receiveData, receiveData.length);
		clientSocket.receive(receivePacket);
		int recvLen = receivePacket.getLength();
		byte[] bytesBuf = receivePacket.getData();
		String modifiedSentence = new String(bytesBuf, 0, recvLen, "UTF-8");

		clientSocket.close();
		List<String> list = new ArrayList<>();

		String w;
		String[] lines = modifiedSentence.split("\n");
		for (String line : lines) {
			w = line.trim();
			if (w.length() > 0) {
				list.add(w);
			}
		}
		long e = System.currentTimeMillis();
		System.out.println("FROM SERVER: for " + word + ":" + modifiedSentence + " took " + (e - b) + " ms ");
		return list;
	}

	private static List<String> parseLocal(String word)  {
		long b = System.currentTimeMillis();

		String stemWord = FomaWrapper.findStemWord(word,fsm);
		List<String> list = new ArrayList<>();

		String w;
		String[] lines = stemWord.split("\n");
		for (String line : lines) {
			w = line.trim();
			if (w.length() > 0) {
				list.add(w);
			}
		}
		long e = System.currentTimeMillis();
		System.out.println("Stem Obtained " + word + ":" + stemWord + " took " + (e - b) + " ms ");
		return list;
	}

	public static void main(String[] args) throws IOException {

		String a = "kuş asisi ortaklar çekişme masalı TİCARETİN ARTMASI BEKLENİYOR"
				+ "Savinykh Ege Bölgesi Sanayi Odası'nda  düzenlenen Belarus Türkiye Yatırım ve İşbirliği Olanakları "
				+ "Seminerinde yaptığı konuşmada Haziran'dan itibaren Türk halkı vizesiz olarak Belarus'a gidip gelebilecek "
				+ "İki ülke arasındaki ticaret bu anlaşma ile daha da artacak dedi Türkiye ile Belarus arasında ticari "
				+ "kültürel ve sosyal ilişkilerin gelişmesini arzu ettiklerini kaydeden Andrei Savinykh ülkesinin Kırgızistan"
				+ "ve Kazakistan ile Gümrük Birliği anlaşması bulunduğunu önümüzdeki sütlü fındıklı";

		parseLocal("yaptığı");
		parseLocal("konuşmada");
		parseLocal("gelişmesini");
		
		/*
		 * for (String s : a.split("\\s+")) { //parse(s); String root =
		 * stem(s,"min"); System.out.println ("Root of "+s+" = "+root); }
		 */
	}
}
