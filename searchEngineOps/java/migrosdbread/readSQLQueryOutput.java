package migrosdbread;

import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileReader;
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

public class readSQLQueryOutput {
 


	public static String transTurkishChars(String s)
	{
		for (String[] pair:readBlob.TURKISH_CHARS){
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
				int pos = readBlob.ESCAPE_CHARS.indexOf(character);
				if (pos > -1) {
					stringBuilder.append(readBlob.ESCAPE_STRINGS.get(pos));
					modified = true;
				} else {
					if ((character.compareTo(readBlob.UNICODE_LOW) > -1)
							&& (character.compareTo(readBlob.UNICODE_HIGH) < 1)) {
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
	public static String readSQLFile(String fname) {

		String sqlStmt= "";
		try {
			BufferedReader reader = new BufferedReader(new FileReader(fname));
			String line = null;
			while ((line = reader.readLine()) != null){
				sqlStmt += " "+line;
			}			
			reader.close();
		} catch (UnsupportedEncodingException e) {
			e.printStackTrace();
		} catch (FileNotFoundException e) {
			e.printStackTrace();
		} catch (IOException e) {
			e.printStackTrace();
		}
		return sqlStmt;

	}
	

	public static void main(String args[]) {

		ResultSet rst = null;
		CSVWriter writer = null;

		if (args.length < 3 ){
			System.out.println("Usage: csvFileame sqlFileName Test|Prod -rows numberOfRows -sdate Aug -edate Dec");
			System.exit(0);
		}
		String csvFileName = args[0]; 
		String sqlFileName = args[1];
		boolean isTest = args[2].equalsIgnoreCase("test")?true:false;
		int count = 0;
		String sdate="",edate="";
		String srown="",erown="";
		for (int j=3;j<args.length;j+=2){
			String opt = args[j];
			if (opt.equals("-rows")){
				count = Integer.parseInt(args[j+1]);
			}
			else if (opt.equals("-sdate")){
				sdate = args[j+1];
			}
			else if (opt.equals("-edate")){
				edate = args[j+1];
			}
			else if (opt.equals("-srown")){
				srown = args[j+1];
			}
			else if (opt.equals("-erown")){
				erown = args[j+1];
			}
		}
		String sqlStmt = readSQLFile(sqlFileName);
		if (count > 0){
			sqlStmt += " AND rownum <  "+count;
		}
		if (edate.length() > 0){
			sqlStmt = sqlStmt.replace("EDATE", edate);
		}
		if (sdate.length() > 0){
			sqlStmt = sqlStmt.replace("SDATE", sdate);
		}
		if (srown.length() > 0){
			sqlStmt = sqlStmt.replace("SROWN", srown);
		}
		if (erown.length() > 0){
			sqlStmt = sqlStmt.replace("EROWN", erown);
		}
		 
		System.out.println ("Running SQL statement :"+sqlStmt);
		
		
		try { 

			writer = new CSVWriter(new OutputStreamWriter(new FileOutputStream(
					csvFileName,true), "UTF-8"));
		} catch (IOException e2) {
			e2.printStackTrace();
		}

		try {
			Class.forName("oracle.jdbc.driver.OracleDriver");
			Connection conn = null;
			if (isTest)
				conn = DriverManager
				.getConnection("jdbc:oracle:thin:kangurum/planetuc9@195.87.90.150:1522/KANGTEST");
			else
			 conn = DriverManager
					.getConnection("jdbc:oracle:thin:kangurum/planetuc9@212.12.132.196:1521/kngdb");
			
			PreparedStatement psGetBlob = conn.prepareStatement(sqlStmt);
			rst = psGetBlob.executeQuery(); 
			ResultSetMetaData metadata = rst.getMetaData();
			final int cc = metadata.getColumnCount();
			
			List<String[]> rows = new ArrayList<String[]>();
			List<String> nextRow = new ArrayList<String>();
			
			for(int k = 1; k <= cc; k++) {
		          final Object value = metadata.getColumnName(k);
		          // null values are ignored
		          if(value == null){
		        	  nextRow.add("");
		        	  continue;
		          }
		          nextRow.add(value.toString());
	        }
			writer.writeNext(nextRow.toArray(new String[]{}));
			nextRow.clear();
			
			int counter = 0;
			while (rst.next()) {
				counter++;
				for(int k = 1; k <= cc; k++) {
			          final Object value = rst.getObject(k);
			          // null values are ignored
			          if(value == null){
			        	  nextRow.add("");
			        	  continue;
			          }
			          nextRow.add(value.toString());
 		        }
				rows.add(nextRow.toArray(new String[]{}));
				nextRow.clear();
				if (counter % 1000 == 0){
					writer.writeAll(rows);
					rows.clear();
					counter = 0;
				}
			} 
			if (rows.size() == 0){
				writer.writeAll(rows);
			}
			
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
