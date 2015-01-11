package migrosdbread;

import java.io.UnsupportedEncodingException;
import java.net.URLDecoder;
import java.net.URLEncoder;

public class test {

	public static void main(String[] args) throws UnsupportedEncodingException {
		// TODO Auto-generated method stub

		String s = "<img src=\"\"http://www.oralb.com.tr/tr-TR/assets/images/goodhousekeeping_logo_blue.jpg\"\" alt=\"\"bottom\"\" /> </span> </span> </span> </span> <span> ";
		String s1 = s.replace("&ccedil;", "ç");
		int b = s.indexOf("&ccedil;");
		s1 = s1.replace("\"\"","ttttt");
		System.out.println (s1+":"+b);
		
		String str ="psi=28833638&amp;name=CAPPY%20%100PORTAKAL%20SUYU250ML%20CAM&amp;shopCode=08055097&amp;shopCategoryId=32056";
		String str1 = "ct%0d%0alabne+peynir%0d%0akarnabahar%0d%0alimon%0d%0aportakal+s%c4%b1kma%0d%0adimes+100+portakal+suyu%0d%0atuvalet+ka%c4%9f%c4%b1d%c4%b1%0d%0akabak%0d%0aarpa+%c5%9fehriye%0d%0ayo%c4%9furt%0d%0anesquik%0d%0akereviz";
		String str2 = "FORG0006 psi=28442438&amp;name=KECHEESE%20%20100%20KE%C3%87%C4%B0%20Y%C3%96R%C3%9CK%20PEYN%C4%B0R%C4%B0%20KG&amp;shopCode=10403315&amp;shopCategoryId";
		s = URLDecoder.decode(str2, "UTF-8");
		String st = URLDecoder.decode("%25100");
		System.out.println ("ttt="+s);
		System.out.println ("tr=\n"+st);
	}

}
