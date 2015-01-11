package migrosdbread;

import java.io.BufferedInputStream;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.UnsupportedEncodingException;
import java.sql.*;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import au.com.bytecode.opencsv.CSVReader;
import au.com.bytecode.opencsv.CSVWriter;
import oracle.jdbc.OracleResultSet;

public class readBlob {
 
	public final static String [][]TURKISH_CHARS = {
	{"&frac12;","&#189;","½"},
	{"&frac14;","&#188;","¼"},
	{"&frac34;","&#190;","¾"},
	{"&sup2;","&#178;","²"},
	{"&Acirc;","&#194;","Â"},
	{"&Atilde;","&#195;","Ã"},
	{"&Ccedil;","&#199;","Ç"},
	{"&Oacute;","&#211;","Ó"},
	{"&Ouml;","&#214;","Ö"},
	{"&Uuml;","&#220;","Ü"},
	{"&aacute;","&#225;","á"},
	{"&acirc;","&#226;","â"},
	{"&acute;","&#180;","´"},
	{"&auml;","&#228;","ä"},
	{"&ccedil;","&#231;","ç"},
	{"&curren;","&#164;","¤"},
	{"&deg;","&#176;","°"},
	{"&eacute;","&#233;","é"},
	{"&ecirc;","&#234;","ê"},
	{"&egrave;","&#232;","à"},
	{"&euml;","&#235;","ë"},
	{"&iacute;","&#237;","í"},
	{"&icirc;","&#238;","î"},
	{"&micro;","&#181;","µ"},
	{"&middot;","&#183;","·"},
	{"&nbsp;","&#160;"," "},
	{"&oacute;","&#243;","ó"},
	{"&ordm;","&#186;","º"},
	{"&ouml;","&#246;","ö"},
	{"&plusmn;","&#177;","±"},
	{"&reg;","&#174;","®"},
	{"&shy;","&#173;"," "},
	{"&szlig;","&#223;","ß"},
	{"&times;","&#215;","×"},
	{"&uacute;","&#250;","ú"},
	{"&ucirc;","&#251;","û"},
	{"&uuml;","&#252;","ü"},
	{"&yacute;","&#253;","ý"},
	{"\"","&#34;","'"}
};
	public final static String [][]TURKISH_CHARS2 = {
		{"&nbsp;","&#160;"},
		{"&iexcl;","&#161;"},
		{"&cent;","&#162;"},
		{"&pound;","&#163;"},
		{"&curren;","&#164;"},
		{"&yen;","&#165;"},
		{"&brvbar;","&#166;"},
		{"&sect;","&#167;"},
		{"&uml;","&#168;"},
		{"&copy;","&#169;"},
		{"&ordf;","&#170;"},
		{"&laquo;","&#171;"},
		{"&not;","&#172;"},
		{"&shy;","&#173;"},
		{"&reg;","&#174;"},
		{"&macr;","&#175;"},
		{"&deg;","&#176;"},
		{"&plusmn;","&#177;"},
		{"&sup2;","&#178;"},
		{"&sup3;","&#179;"},
		{"&acute;","&#180;"},
		{"&micro;","&#181;"},
		{"&para;","&#182;"},
		{"&middot;","&#183;"},
		{"&cedil;","&#184;"},
		{"&sup1;","&#185;"},
		{"&ordm;","&#186;"},
		{"&raquo;","&#187;"},
		{"&frac14;","&#188;"},
		{"&frac12;","&#189;"},
		{"&frac34;","&#190;"},
		{"&iquest;","&#191;"},
		{"&Agrave;","&#192;"},
		{"&Aacute;","&#193;"},
		{"&Acirc;","&#194;"},
		{"&Atilde;","&#195;"},
		{"&Auml;","&#196;"},
		{"&Aring;","&#197;"},
		{"&AElig;","&#198;"},
		{"&Ccedil;","&#199;"},
		{"&Egrave;","&#200;"},
		{"&Eacute;","&#201;"},
		{"&Ecirc;","&#202;"},
		{"&Euml;","&#203;"},
		{"&Igrave;","&#204;"},
		{"&Iacute;","&#205;"},
		{"&Icirc;","&#206;"},
		{"&Iuml;","&#207;"},
		{"&ETH;","&#208;"},
		{"&Ntilde;","&#209;"},
		{"&Ograve;","&#210;"},
		{"&Oacute;","&#211;"},
		{"&Ocirc;","&#212;"},
		{"&Otilde;","&#213;"},
		{"&Ouml;","&#214;"},
		{"&times;","&#215;"},
		{"&Oslash;","&#216;"},
		{"&Ugrave;","&#217;"},
		{"&Uacute;","&#218;"},
		{"&Ucirc;","&#219;"},
		{"&Uuml;","&#220;"},
		{"&Yacute;","&#221;"},
		{"&THORN;","&#222;"},
		{"&szlig;","&#223;"},
		{"&agrave;","&#224;"},
		{"&aacute;","&#225;"},
		{"&acirc;","&#226;"},
		{"&atilde;","&#227;"},
		{"&auml;","&#228;"},
		{"&aring;","&#229;"},
		{"&aelig;","&#230;"},
		{"&ccedil;","&#231;"},
		{"&egrave;","&#232;"},
		{"&eacute;","&#233;"},
		{"&ecirc;","&#234;"},
		{"&euml;","&#235;"},
		{"&igrave;","&#236;"},
		{"&iacute;","&#237;"},
		{"&icirc;","&#238;"},
		{"&iuml;","&#239;"},
		{"&eth;","&#240;"},
		{"&ntilde;","&#241;"},
		{"&ograve;","&#242;"},
		{"&oacute;","&#243;"},
		{"&ocirc;","&#244;"},
		{"&otilde;","&#245;"},
		{"&ouml;","&#246;"},
		{"&divide;","&#247;"},
		{"&oslash;","&#248;"},
		{"&ugrave;","&#249;"},
		{"&uacute;","&#250;"},
		{"&ucirc;","&#251;"},
		{"&uuml;","&#252;"},
		{"&yacute;","&#253;"},
		{"&thorn;","&#254;"},
		{"&yuml;","&#255;"},
		{"\"","'"}
};
 	
	public final static String ESCAPE_CHARS = "<>&\"\'";
	public final static List<String> ESCAPE_STRINGS = Collections
			.unmodifiableList(Arrays.asList(new String[] { "&lt;", "&gt;",
					"&amp;", "&quot;", "&apos;", "&Ccedil;", "&ccedil;",
					"&#286;", "&#287;", "&#304;", "&#305;", "&Ouml;", "&ouml;",
					"&#350;", "&#351;", "&Uuml;", "&uuml;"

			}));

	public static String UNICODE_LOW = "" + ((char) 0x20); // space
	public static String UNICODE_HIGH = "" + ((char) 0x7f);

	public static String transTurkishChars(String s)
	{
		for (String[] pair:TURKISH_CHARS){
			s = s.replace(pair[0], pair[2]);
		}
		return s;
	}
	
	// should only use for the content of an attribute or tag
	public static String toEscaped(String content) {
		String result = content;

		if ((content != null) && (content.length() > 0)) {
			boolean modified = false;
			StringBuilder stringBuilder = new StringBuilder(content.length());
			for (int i = 0, count = content.length(); i < count; ++i) {
				String character = content.substring(i, i + 1);
				int pos = ESCAPE_CHARS.indexOf(character);
				if (pos > -1) {
					stringBuilder.append(ESCAPE_STRINGS.get(pos));
					modified = true;
				} else {
					if ((character.compareTo(UNICODE_LOW) > -1)
							&& (character.compareTo(UNICODE_HIGH) < 1)) {
						stringBuilder.append(character);
					} else {
						stringBuilder.append("&#" + ((int) character.charAt(0))
								+ ";");
						modified = true;
					}
				}
			}
			if (modified) {
				result = stringBuilder.toString();
			}
		}

		return result;
	}

	
	public static void readCSVFile(String fname) {

		try {
			CSVReader reader = new CSVReader(new InputStreamReader(
					new FileInputStream(fname), "UTF-8"));
			List<String[]> lines = reader.readAll();
			for (String[] line : lines) {
				System.out.println(line[0] + ":" + line[1]);
			}
			reader.close();
		} catch (UnsupportedEncodingException e) {
			e.printStackTrace();
		} catch (FileNotFoundException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}

	}

	public static void main(String args[]) {

		ResultSet rst = null;
		CSVWriter writer = null;

		if (args.length <3 ){
			System.out.println("Usage: outputFileName numberOfRows Test|Prod");
			System.exit(0);
		}
		String csv = args[0]; //"C:\\tmp\\output2-test.csv";
		int count = Integer.parseInt(args[1]);
		boolean isTest = args[2].equalsIgnoreCase("test")?true:false;
		try { 

			writer = new CSVWriter(new OutputStreamWriter(new FileOutputStream(
					csv), "UTF-8"));
		} catch (IOException e2) {
			e2.printStackTrace();
		}

		//sqlplus64 kangurum/planetuc9@195.87.90.150:1522/KANGTEST
		try {
			Class.forName("oracle.jdbc.driver.OracleDriver");
			Connection conn = null;
			if (isTest)
				conn = DriverManager
				.getConnection("jdbc:oracle:thin:");
			else
			 conn = DriverManager
					.getConnection("jdbc:oracle:thin:");
			 
			String s = "select PRODUCT_MODEL_ID, HTML_CONTENT  from PRODUCT_MODEL_DETAIL where rownum <  "+count;
			//String s = "select PRODUCT_MODEL_ID, HTML_CONTENT  from PRODUCT_MODEL_DETAIL  ";
			PreparedStatement psGetBlob = conn.prepareStatement(s);
			rst = psGetBlob.executeQuery(); 
			byte[] byteData = new byte[1024 * 100];
			List<String[]> data = new ArrayList<String[]>();
			int counter = 0;
			while (rst.next()) {
				String pid = rst.getString(1);
				Blob blob = rst.getBlob(2);
				if (blob == null){
					continue;
				}  
				InputStream in = blob.getBinaryStream();
				BufferedInputStream bis = new BufferedInputStream(in);
				int readLen = bis.read(byteData);
				if (readLen < 0){
					break;
				}
				String blobText = new String(byteData, 0, readLen, "UTF-8");
				
				
				blobText = transTurkishChars(blobText);
				// System.out.println("Product id ="+pid+","+blobText);
				//System.out.println("counter:" + counter++);
				data.add(new String[] { pid, blobText });
			}
			System.out.println(count +" blob for Product modle details pulled form ORacel DB");
			  
			writer.writeAll(data);
			writer.close();
			rst.close();
		} catch (Exception e) {
			e.printStackTrace();
			try {
				rst.close();
			} catch (SQLException e1) {
				e1.printStackTrace();
			}
		}

		// readCSVFile(csv);
	}
}
