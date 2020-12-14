package org.med.darknetandroid;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Point;
import android.util.AttributeSet;
import android.util.Log;
import android.view.View;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * TODO: document your custom view class.
 */
public class HexagonView extends View {
    private String mExampleString=""; // TODO: use a default from R.string...
    private boolean isRender = false;
    public HexagonView(Context context) {
        super(context);
        init(null, 0);
    }

    public HexagonView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init(attrs, 0);
    }

    public HexagonView(Context context, AttributeSet attrs, int defStyle) {
        super(context, attrs, defStyle);
        init(attrs, defStyle);
    }

    private void init(AttributeSet attrs, int defStyle) {

    }
    public void setValues(String values) {
        this.mExampleString = values;
        invalidate();
    }
    public void setRender(boolean render)
    {
        isRender = render;
        invalidate();
    }
    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        if(isRender ) {
            canvas.drawColor(Color.BLACK);
            int radius = (int)(canvas.getWidth()/10);
            int width = canvas.getWidth()/2;
            String[] bitstreams = mExampleString.split(" ");
            int hexagons = bitstreams.length / 6;
            for (int i = 0; i < hexagons; i++)
            {
                int r = radius * (hexagons - i);
                Path path = new Path();
                path.setFillType(Path.FillType.EVEN_ODD);
                path.moveTo(r + width,width );
                for(int j=1;j<6;j++)
                {
                    path.lineTo((int)(r * Math.cos(j * 60 * Math.PI / 180)) + width,width - (int)(r * Math.sin(j * 60 * Math.PI / 180)));
                }
                path.close();
                Paint paint_polygon = new Paint();
                paint_polygon.setStrokeWidth(3);
                paint_polygon.setColor(Color.rgb(20*(i+1),20*(i+1),20*(i+1)));
                paint_polygon.setStyle(Paint.Style.FILL);
                paint_polygon.setAntiAlias(true);
                canvas.drawPath(path, paint_polygon);
                for (int j = 0; j < 6; j++)
                {
                    String bit = bitstreams[i * 6 + j];
                    int size = bit.length();
                    int x1 = (int)(r * Math.cos(j * 60 * Math.PI / 180)) + width;
                    int y1 = width - (int)(r * Math.sin(j * 60 * Math.PI / 180));
                    int x2 = (int)(r * Math.cos((j + 1) * 60 * Math.PI / 180)) + width;
                    int y2 = width - (int)(r * Math.sin((j + 1) * 60 * Math.PI / 180));
                    for (int k = 0; k < bit.length(); k++)
                    {
                        int m = 2 * size - 1 - 2 * k;
                        int n = 1 + 2 * k;
                        float x0 = (m * x1 + n * x2) / (m + n);
                        float y0 = (m * y1 + n * y2) / (m + n);
                        if (bit.charAt(k) == '1')
                        {
                            Paint paint = new Paint();
                            paint.setAntiAlias(true);
                            paint.setColor(Color.RED);
                            paint.setStyle(Paint.Style.FILL);
                            paint.setStrokeWidth(4.5f);
                            canvas.drawCircle(x0, y0, 20, paint);
                        }
                        else{
                            Paint paint = new Paint();
                            paint.setAntiAlias(true);
                            paint.setColor(Color.BLACK);
                            paint.setStyle(Paint.Style.FILL);
                            paint.setStrokeWidth(4.5f);
                            canvas.drawCircle(x0, y0, 20, paint);
                        }
                    }
                }
            }
        }
    }
}
