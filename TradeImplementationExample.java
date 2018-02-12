package tapi.utils;

import org.web3j.crypto.ECKeyPair;
import org.web3j.crypto.Sign;
import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.nio.ShortBuffer;
import java.util.ArrayList;
import java.util.List;

/**
 * Created by sangalli on 12/2/18.
 */

class TransactionDetails
{
    BigInteger value;
    List<BigInteger> ticketIndices;
    Sign.SignatureData signatureData;
}

public class TradeImplementationExample 
{

    private static final String contractAddress = "fFAB5Ce7C012bc942F5CA0cd42c3C2e1AE5F0005";

    public static void main(String[] args)
    {
        short[] ticketPlaces = new short[]{3, 4};
        //zero timestamp means unlimited
        byte[] msg = encodeMessageForTrade(BigInteger.ONE, BigInteger.ZERO, ticketPlaces);
        List<BigInteger> indices = new ArrayList<>();
        for(int i = 0; i < ticketPlaces.length; i++)
        {
            indices.add(BigInteger.valueOf(ticketPlaces[i]));
        }
        TransactionDetails td = createTrade(msg, indices, BigInteger.ONE);

        System.out.println("Price: 1 ");
        System.out.println("expiry: 0 (does not expiry)");
        System.out.println("Signature v value: " + td.signatureData.getV());
        System.out.println("Signature r value: 0x" + bytesToHex(td.signatureData.getR()));
        System.out.println("Signature s value: 0x" + bytesToHex(td.signatureData.getS()));
        System.out.println("Ticket indices: 3, 4");
    }

    public static byte[] encodeMessageForTrade(BigInteger price, BigInteger expiryTimestamp, short[] tickets)
    {
        byte[] priceInWei = price.toByteArray();
        byte[] expiry = expiryTimestamp.toByteArray();
        ByteBuffer message = ByteBuffer.allocate(96 + tickets.length * 2);
        byte[] leadingZeros = new byte[32 - priceInWei.length];
        message.put(leadingZeros);
        message.put(priceInWei);
        byte[] leadingZerosExpiry = new byte[32 - expiry.length];
        message.put(leadingZerosExpiry);
        message.put(expiry);
        byte[] prefix = "ERC800-CNID1".getBytes();
        byte[] contract = hexStringToBytes(contractAddress);
        message.put(prefix);
        message.put(contract);
        ShortBuffer shortBuffer = message.slice().asShortBuffer();
        shortBuffer.put(tickets);

        return message.array();
    }

    private static String bytesToHex(byte[] bytes)
    {
        final char[] hexArray = "0123456789ABCDEF".toCharArray();
        char[] hexChars = new char[bytes.length * 2];
        for ( int j = 0; j < bytes.length; j++ )
        {
            int v = bytes[j] & 0xFF;
            hexChars[j * 2] = hexArray[v >>> 4];
            hexChars[j * 2 + 1] = hexArray[v & 0x0F];
        }
        String finalHex = new String(hexChars);
        return finalHex;
    }

    private static byte[] hexStringToBytes(String s)
    {
        int len = s.length();
        byte[] data = new byte[len / 2];
        for (int i = 0; i < len; i += 2)
        {
            data[i / 2] = (byte) ((Character.digit(s.charAt(i), 16) << 4)
                    + Character.digit(s.charAt(i + 1), 16));
        }
        return data;
    }

    public static TransactionDetails createTrade(byte[] message, List<BigInteger> indices, BigInteger price)
    {
        try
        {
            //Note: you can replace with your own key instead of using same key generated from BigInteger.ONE
            Sign.SignatureData sigData = Sign.signMessage(message,
                    ECKeyPair.create(BigInteger.ONE));
            TransactionDetails TransactionDetails = new TransactionDetails();
            TransactionDetails.ticketIndices = indices;
            TransactionDetails.value = price;

            byte v = sigData.getV();

            String hexR = bytesToHex(sigData.getR());
            String hexS = bytesToHex(sigData.getS());

            byte[] rBytes = hexStringToBytes(hexR);
            byte[] sBytes = hexStringToBytes(hexS);

            BigInteger r = new BigInteger(rBytes);
            BigInteger s = new BigInteger(sBytes);

            TransactionDetails.signatureData = new Sign.SignatureData(v, r.toByteArray(), s.toByteArray());

            return TransactionDetails;
        }
        catch(Exception e)
        {
            e.printStackTrace();
            return null;
        }
    }

}
