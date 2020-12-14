package org.med.darknetandroid;

import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.Bundle;
import android.util.Log;
import android.widget.ImageView;

import androidx.appcompat.app.AppCompatActivity;

public class ShowValue extends AppCompatActivity {
    private ImageView imageView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_show_value);

        imageView = findViewById(R.id.show_result);

        Intent intent = getIntent();
        byte[] extra = intent.getByteArrayExtra("result");
        String bitstream = intent.getStringExtra("bitstream");

        String[] bitstreams = bitstream.split("  ");
        int index = 0;
        int bit_count = 0;
        for (int i = 0; i < 6; i++) {
            int temp_bits = countChar(bitstreams[i], '1');
            if ((temp_bits > bit_count) && (bitstreams[i].charAt(0) == '1')) {
                index = i;
                bit_count = temp_bits;
            }
        }
        String[][] bits = new String[bitstreams.length][6];
        int count=0;
        for (int i = 0; i < bitstreams.length / 6; i++) {
            for (int j = 0; j < 6; j++) {
                bits[i][j]=bitstreams[count];
                count++;
            }
        }
        String[][] new_bits = new String[bitstreams.length][6];
        String new_bitstream="";
        for (int i = 0; i < bitstreams.length / 6; i++) {
            for (int j = 0; j < 6; j++) {
                new_bits[i][j] = bits[i][(j+index)%6];
                new_bitstream+=new_bits[i][j]+" ";
            }
        }
        Bitmap bitmap = BitmapFactory.decodeByteArray(extra, 0, extra.length);
        imageView.setImageBitmap(bitmap);
        HexagonView hexagonView = findViewById(R.id.hexaview);
        hexagonView.setValues(new_bitstream);
        hexagonView.setRender(true);
        hexagonView.invalidate();
    }

    public int countChar(String str, char c) {
        int count = 0;
        for (int i = 0; i < str.length(); i++) {
            if (str.charAt(i) == c)
                count++;
        }
        return count;
    }
}
