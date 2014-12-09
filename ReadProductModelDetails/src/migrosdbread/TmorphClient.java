package migrosdbread;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.net.Socket;
import java.net.SocketException;
import java.net.UnknownHostException;

public class TmorphClient {

	public static void main(String[] args) throws UnknownHostException {
		// TODO Auto-generated method stub

		  /*if (args.length != 2) {
	            System.err.println(
	                "Usage: java EchoClient <host name> <port number>");
	            System.exit(1);
	        }
	        String hostName = args[0];
	        int portNumber = Integer.parseInt(args[1]);
	 */
		
	        String hostName = "192.168.1.6";
	        int portNumber = 6062;
	        InetAddress IPAddress = InetAddress.getByName("192.168.142.131");
	        while (true)
	        try {
				    getTRMorphStem(portNumber,IPAddress);
			} catch (SocketException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			} catch (UnknownHostException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			} catch (IOException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
	    }

	private static String getTRMorphStem(int portNumber,InetAddress IPAddress) throws SocketException,
			UnknownHostException, IOException {
		long b = System.currentTimeMillis();
		
		BufferedReader inFromUser =
		    new BufferedReader(new InputStreamReader(System.in));
		 DatagramSocket clientSocket = new DatagramSocket();
		 //InetAddress IPAddress = InetAddress.getByName("192.168.1.6");
		 byte[] sendData = new byte[1024];
		 byte[] receiveData = new byte[1024];
		 String sentence = inFromUser.readLine();
		 sendData = sentence.getBytes();
		 DatagramPacket sendPacket = new DatagramPacket(sendData, sendData.length, IPAddress, portNumber);
		 clientSocket.send(sendPacket);
		 DatagramPacket receivePacket = new DatagramPacket(receiveData, receiveData.length);
		 clientSocket.receive(receivePacket);
		 String modifiedSentence = new String(receivePacket.getData());
		 clientSocket.close();
		 long e = System.currentTimeMillis();
		 System.out.println("FROM SERVER:"+modifiedSentence+" took "+ (e-b)+" ms ");
		 return modifiedSentence;
	}
	}


