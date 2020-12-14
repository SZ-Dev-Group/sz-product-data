package org.med.darknetandroid;

import android.content.Context;
import android.content.Intent;
import android.content.res.AssetManager;
import android.graphics.Bitmap;
import android.os.Bundle;
import android.util.Log;
import android.widget.CompoundButton;
import android.widget.SeekBar;
import android.widget.Switch;
import androidx.appcompat.app.AppCompatActivity;
import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;
import java.util.Scanner;

import org.opencv.android.BaseLoaderCallback;
import org.opencv.android.CameraBridgeViewBase;
import org.opencv.android.LoaderCallbackInterface;
import org.opencv.android.OpenCVLoader;
import org.opencv.android.Utils;
import org.opencv.core.Core;
import org.opencv.core.CvException;
import org.opencv.core.CvType;
import org.opencv.core.Mat;
import org.opencv.core.MatOfPoint;
import org.opencv.core.Point;
import org.opencv.core.Rect;
import org.opencv.core.Scalar;
import org.opencv.core.Size;
import org.opencv.dnn.Dnn;
import org.opencv.dnn.Net;
import org.opencv.android.CameraBridgeViewBase.CvCameraViewListener2;
import org.opencv.android.CameraBridgeViewBase.CvCameraViewFrame;
import org.opencv.imgproc.Imgproc;

public class CameraActivity extends AppCompatActivity implements CvCameraViewListener2 {
    private static final String TAG = "CameraActivity";
    private static List<String> classNames;
    private static List<Scalar> colors = new ArrayList<>();
    private Net net;
    private CameraBridgeViewBase mOpenCvCameraView;

    float zoom_ratio = 1;
    private Mat mat_source, mat_result;
    private Mat dst;
    ArrayList<Point> aligned_outermost = new ArrayList<>();
    ArrayList<Point> corners = new ArrayList<>();
    ArrayList<Integer> corner_x = new ArrayList<>();
    ArrayList<Integer> corner_y = new ArrayList<>();
    ArrayList<Integer> pos_circle_x = new ArrayList<>();
    ArrayList<Integer> pos_circle_y = new ArrayList<>();
    Detect_Background p = new Detect_Background();
    float separate = 0;
    int hexatype = 3;
    int target_count = 0;
    private Switch switchhexagon;
    int cx0 = 0;
    int cy0 = 0;
    int startGC = 10;
    private Rect crop_rect;
    private boolean detection=false;
    class Detect_Background extends Thread {
        public void run() {
            Start_Detect();
        }
    }

    private BaseLoaderCallback mLoaderCallback = new BaseLoaderCallback(this) {
        @Override
        public void onManagerConnected(int status) {
            switch (status) {
                case LoaderCallbackInterface.SUCCESS: {
                    mOpenCvCameraView.enableView();
                }
                break;
                default: {
                    super.onManagerConnected(status);
                }
                break;
            }
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        SeekBar zoom_control;
        zoom_control = findViewById(R.id.zoomControl);
        zoom_control.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            float progressValue = 0;

            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                progressValue = progress;
                zoom_ratio = progressValue / 30 + 1;
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {

            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
                zoom_ratio = progressValue / 30 + 1;
            }
        });
        switchhexagon = findViewById(R.id.switch_hexagon);
        switchhexagon.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
                if (isChecked) {
                    hexatype = 4;
                } else {
                    hexatype = 3;
                }
            }
        });
        mOpenCvCameraView = findViewById(R.id.CameraView);
        mOpenCvCameraView.setVisibility(CameraBridgeViewBase.VISIBLE);
        mOpenCvCameraView.setCvCameraViewListener(this);
        mOpenCvCameraView.setMaxFrameSize(1280, 720);
        classNames = readLabels("labels.txt", this);
        for (int i = 0; i < classNames.size(); i++)
            colors.add(randomColor());
    }

    @Override
    public void onResume() {
        super.onResume();
        if (!OpenCVLoader.initDebug()) {
            Log.d(TAG, "Internal OpenCV library not found. Using OpenCV Manager for initialization");
            OpenCVLoader.initAsync(OpenCVLoader.OPENCV_VERSION_3_4_0, this, mLoaderCallback);
        } else {
            Log.d(TAG, "OpenCV library found inside package. Using it!");
            mLoaderCallback.onManagerConnected(LoaderCallbackInterface.SUCCESS);
        }
    }

    @Override
    public void onCameraViewStarted(int width, int height) {
        String modelConfiguration = getAssetsFile("yolov3_tiny.cfg", this);
        String modelWeights = getAssetsFile("yolov3_tiny.weights", this);
        net = Dnn.readNetFromDarknet(modelConfiguration, modelWeights);
    }

    @Override
    public void onCameraViewStopped() {

    }
    @Override
    public Mat onCameraFrame(CvCameraViewFrame inputFrame) {
            startGC--;
            if (startGC == 0) {
                System.gc();
                System.runFinalization();
                startGC = 10;
            }
            try {
                Mat frame = inputFrame.rgba();
                Imgproc.cvtColor(frame, frame, Imgproc.COLOR_RGBA2RGB);
                double h = frame.size().height;
                double w = frame.size().width;
                Rect roi = new Rect((int) (w / 2 - h * h / 2 / w), 0, (int) (h * h / w), (int) h);
                frame = frame.submat(roi);
                Core.flip(frame.t(), frame, 1);
                Imgproc.resize(frame, frame, new Size(w, h), Imgproc.INTER_LINEAR);
                Imgproc.resize(frame, frame, new Size((int) (zoom_ratio * w), (int) (zoom_ratio * h)), Imgproc.INTER_LINEAR);
                Rect roi1 = new Rect((int) (w * (zoom_ratio - 1) / 2), (int) (h * (zoom_ratio - 1) / 2), (int) w, (int) h);
                frame = frame.submat(roi1);
                double h1 = frame.size().height;
                double w1 = frame.size().width;
                int x1 = (int) ((w1 - 320) / 2);
                int y1 = (int) ((h1 - 320) / 2);
                int x2 = (int) (w1 - x1);
                int y2 = (int) (h1 - y1);
                int cx_0 = (int)(w1)/2;
                int cy_0 = (int)(h1)/2;
                int radius = 160;
                crop_rect = new Rect(new Point(x1, y1), new Point(x2, y2));

                Mat mask = new Mat(frame.rows(), frame.cols(), CvType.CV_8U, Scalar.all(0));
                Imgproc.circle(mask, new Point(cx_0, cy_0), radius, new Scalar(255,255,255), -1, 8, 0 );
                dst = new Mat();
                frame.copyTo(dst,mask);
//                mat_source=frame;
                mat_source = dst;
                if(!detection)
                {
                    p.start();
                }
                return dst;
            } catch (Exception ee) {
                p=new Detect_Background();
                return null;
            }
    }
    private void Start_Detect()
    {
        detection=true;
        try {
            mat_result = mat_source.submat(crop_rect);
            Imgproc.resize(mat_result, mat_result, new Size(720, 720));
            mat_result = Detection(mat_result);
            if (corners.size() == 6) {
                int cx = 0;
                int cy = 0;
                for (int i = 0; i < 6; i++) {
                    cx += (int) (corners.get(i).x / 6);
                    cy += (int) (corners.get(i).y / 6);
                }
                cx0 = cx;
                cy0 = cy;
                mat_result = Detection_corner(mat_result, new Point(cx, cy));
                corners.clear();
                Capture(mat_result);
                detection=false;
            } else if (corners.size() == 5) {
                int cx = 0;
                int cy = 0;
                for (int i = 0; i < 3; i++) {
                    Point new_center = find_center(corners.get(i), corners.get(i + 1), corners.get(i + 2));
                    cx += (int) (new_center.x / 3);
                    cy += (int) (new_center.y / 3);
                }
                cx0 = cx;
                cy0 = cy;
                int sum_x = 0;
                int sum_y = 0;
                for (int i = 0; i < 5; i++) {
                    sum_x += corners.get(i).x;
                    sum_y += corners.get(i).y;
                }
                corners.add(new Point((int) (6 * cx - sum_x), (int) (6 * cy - sum_y)));
                mat_result = Detection_corner(mat_result, new Point(cx, cy));
                corners.clear();
                Log.d("aaa", "showvalue started");
                Capture(mat_result);
                detection=false;
            } else {
                pos_circle_x.clear();
                pos_circle_y.clear();
                corners.clear();
                detection=false;
            }
        } catch (Exception ee) {
            Log.d("aaa",ee.getMessage());
            detection=false;
        }
    }
    private Point find_center(Point a, Point b, Point c) {
        float x1 = (float) a.x;
        float y1 = (float) a.y;
        float x2 = (float) b.x;
        float y2 = (float) b.y;
        float x3 = (float) c.x;
        float y3 = (float) c.y;
        float a1 = (x1 - x2) / (y2 - y1);
        float b1 = -a1 * (x1 * x1 + y1 * y1 - x2 * x2 - y2 * y2) / 2 / (x1 - x2);
        float a2 = (x1 - x3) / (y3 - y1);
        float b2 = -a2 * (x1 * x1 + y1 * y1 - x3 * x3 - y3 * y3) / 2 / (x1 - x3);
        int cx = (int) ((b2 - b1) / (a1 - a2));
        int cy = (int) ((a1 * (b2 - b1) / (a1 - a2)) + b1);
        return new Point(cx, cy);
    }

    private Mat Detection_corner(Mat frame, Point center) {
        int cx = (int) center.x;
        int cy = (int) center.y;
        boolean hexacheck = HexaChecker(corners);
        aligned_outermost = Align(corners, center);
        if ((aligned_outermost.size() == 6) && hexacheck) {
            corner_x.clear();
            corner_y.clear();
            target_count = 0;
            if (hexatype == 3) {
                for (int k = 0; k < aligned_outermost.size(); k++) {
                    try {
                        corner_x.add((int) aligned_outermost.get(k).x);
                        corner_y.add((int) aligned_outermost.get(k).y);
                        corner_x.add((int) (aligned_outermost.get(k).x * 2.5 + 1.5 * cx) / 4);
                        corner_y.add((int) (aligned_outermost.get(k).y * 2.5 + 1.5 * cy) / 4);
                        corner_x.add((int) (aligned_outermost.get(k).x + 3 * cx) / 4);
                        corner_y.add((int) (aligned_outermost.get(k).y + 3 * cy) / 4);

                    } catch (Exception e) {
                    }
                }
            } else if (hexatype == 4) {
                for (int k = 0; k < aligned_outermost.size(); k++) {
                    try {
                        corner_x.add((int) aligned_outermost.get(k).x);
                        corner_y.add((int) aligned_outermost.get(k).y);
                        corner_x.add((int) (aligned_outermost.get(k).x + (aligned_outermost.get(k).x + cx) / 2) / 2);
                        corner_y.add((int) (aligned_outermost.get(k).y + (aligned_outermost.get(k).y + cy) / 2) / 2);
                        corner_x.add((int) (aligned_outermost.get(k).x + cx) / 2);
                        corner_y.add((int) (aligned_outermost.get(k).y + cy) / 2);
                        corner_x.add(((int) (aligned_outermost.get(k).x + cx) / 2 + cx) / 2);
                        corner_y.add(((int) (aligned_outermost.get(k).y + cy) / 2 + cy) / 2);

                    } catch (Exception e) {
                        continue;
                    }
                }
            }
        }
        for (int i = 0; i < corner_x.size(); i++) {
            if ((corner_x.get(i) > 0)) {
                Imgproc.circle(frame, new Point(corner_x.get(i), corner_y.get(i)), 6, new Scalar(255, 0, 0), 5);
                Imgproc.putText(frame, "" + i, new Point(corner_x.get(i), corner_y.get(i)), 3, 1, new Scalar(255, 0, 0), 1);
            }
        }
        return frame;
    }

    private Mat Detection(Mat frame) {

        Size frame_size = new Size(416, 416);
        Scalar mean = new Scalar(50);
        Mat blob = Dnn.blobFromImage(frame, 0.00392, frame_size, mean, true, false);

        //save_mat(blob);
        net.setInput(blob);

        List<Mat> result = new ArrayList<>();
        List<String> outBlobNames = net.getUnconnectedOutLayersNames();

        net.forward(result, outBlobNames);
        float confThreshold = 0.2f;
        int index = 0;
        for (int i = 0; i < result.size(); ++i) {
            Mat level = result.get(i);
            for (int j = 0; j < level.rows(); ++j) {
                Mat row = level.row(j);
                Mat scores = row.colRange(5, level.cols());
                Core.MinMaxLocResult mm = Core.minMaxLoc(scores);
                float confidence = (float) mm.maxVal;
                Point classIdPoint = mm.maxLoc;
                if (confidence > confThreshold) {
                    int centerX = (int) (row.get(0, 0)[0] * frame.cols());
                    int centerY = (int) (row.get(0, 1)[0] * frame.rows());
                    int class_id = (int) classIdPoint.x;
                    if (class_id == 0) {
                        pos_circle_x.add(centerX);
                        pos_circle_y.add(centerY);
                        Imgproc.circle(frame, new Point(centerX, centerY), 10, new Scalar(0, 255, 0), 5);
                        Imgproc.putText(frame, "" + index, new Point(centerX, centerY), 3, 2, new Scalar(0, 0, 255), 2);
                        index++;
                    } else if (class_id == 1) {
                        corners.add(new Point(centerX, centerY));
                    }
                }
            }
        }
        return frame;
    }

    private static String getAssetsFile(String file, Context context) {
        AssetManager assetManager = context.getAssets();
        BufferedInputStream inputStream;
        try {
            // Read data from assets.
            inputStream = new BufferedInputStream(assetManager.open(file));
            byte[] data = new byte[inputStream.available()];
            inputStream.read(data);
            inputStream.close();
            // Create copy file in storage.
            File outFile = new File(context.getFilesDir(), file);
            FileOutputStream os = new FileOutputStream(outFile);
            os.write(data);
            os.close();
            return outFile.getAbsolutePath();
        } catch (IOException ex) {
            Log.i(TAG, "Failed to upload a file");
        }
        return "";
    }

    private List<String> readLabels(String file, Context context) {
        AssetManager assetManager = context.getAssets();
        BufferedInputStream inputStream;
        List<String> labelsArray = new ArrayList<>();
        try {
            // Read data from assets.
            inputStream = new BufferedInputStream(assetManager.open(file));
            byte[] data = new byte[inputStream.available()];
            inputStream.read(data);
            inputStream.close();
            // Create copy file in storage.
            File outFile = new File(context.getFilesDir(), file);
            FileOutputStream os = new FileOutputStream(outFile);
            os.write(data);
            os.close();
            Scanner fileScanner = new Scanner(new File(outFile.getAbsolutePath())).useDelimiter("\n");
            String label;
            while (fileScanner.hasNext()) {
                label = fileScanner.next();
                labelsArray.add(label);
            }
            fileScanner.close();
        } catch (IOException ex) {
            Log.i(TAG, "Failed to read labels!");
        }
        return labelsArray;
    }

    private Scalar randomColor() {
        Random random = new Random();
        int r = random.nextInt(255);
        int g = random.nextInt(255);
        int b = random.nextInt(255);
        return new Scalar(r, g, b);
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (mOpenCvCameraView != null)
            mOpenCvCameraView.disableView();
    }

    private static byte[] convertMatToBitMap(Mat input) {
        try {
            Bitmap bmp = null;
            Mat rgb = new Mat();
            Imgproc.cvtColor(input, rgb, Imgproc.COLOR_BGR2RGB);
            try {
                bmp = Bitmap.createBitmap(rgb.cols(), rgb.rows(), Bitmap.Config.ARGB_8888);
                Utils.matToBitmap(rgb, bmp);
            } catch (CvException e) {
                Log.d("Exception", e.getMessage());
            }
            Bitmap resized = Bitmap.createScaledBitmap(bmp, (int) (rgb.cols() / 2), (int) (rgb.rows() / 2), true);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            resized.compress(Bitmap.CompressFormat.PNG, 100, out);
            byte[] byteArray = out.toByteArray();
            return byteArray;
        } catch (Exception ee) {
            Log.d("aaa", "" + ee.getMessage());
            return null;
        }
    }

    public void Capture(Mat frame) {
        ArrayList<Point> circles = new ArrayList<>();
        ArrayList<Integer> hexacorner_x = new ArrayList<>();
        ArrayList<Integer> hexacorner_y = new ArrayList<>();
        String bitstream = "";

        if (hexatype == 3) {
            hexacorner_x.clear();
            hexacorner_y.clear();
            circles.clear();
            for (int i = 0; i < 18; i++) {
                hexacorner_x.add(corner_x.get(i));
                hexacorner_y.add(corner_y.get(i));
            }

            separate = (float) (EuclidDistance(new Point(hexacorner_x.get(0), hexacorner_y.get(0)), new Point(hexacorner_x.get(1), hexacorner_y.get(1))) * Math.sqrt(3) / 2);

            for (int i = 0; i < pos_circle_x.size(); i++) {
                if ((pos_circle_x.get(i) > 0) && (pos_circle_y.get(i) > 0)) {
                    circles.add(new Point(pos_circle_x.get(i), pos_circle_y.get(i)));
                }
            }
            double maxdist = EuclidDistance(new Point(hexacorner_x.get(0), hexacorner_y.get(0)), new Point(cx0, cy0));
            if (circles.size() > 15) {
                for (int k = 0; k < circles.size() - 1; k++) {
                    for (int l = k + 1; l < circles.size(); l++) {
                        double center_dist = EuclidDistance(new Point(cx0, cy0), circles.get(l));
                        if ((EuclidDistance(circles.get(k), circles.get(l)) < 40) | (center_dist > maxdist * 1.1)) {
                            circles.remove(l);
                        }
                    }
                }
            }
            for (int j = 0; j < 3; j++) {
                for (int i = 0; i < 6; i++) {
                    Point p1 = new Point(hexacorner_x.get(i * 3 + j), hexacorner_y.get(i * 3 + j));
                    Point p2 = new Point(hexacorner_x.get(((i + 1) * 3) % 18 + j), hexacorner_y.get(((i + 1) * 3) % 18 + j));
                    int[] result = isbetween3(p1, p2, circles, j);
                    for (int l = 0; l < 3 - j; l++) {
                        bitstream += "" + result[l];
                    }
                    bitstream += "  ";
                }
            }
        } else if (hexatype == 4) {
            hexacorner_x.clear();
            hexacorner_y.clear();
            circles.clear();
            for (int i = 0; i < 24; i++) {
                hexacorner_x.add(corner_x.get(i));
                hexacorner_y.add(corner_y.get(i));
            }
            separate = (float) (EuclidDistance(new Point(hexacorner_x.get(0), hexacorner_y.get(0)), new Point(hexacorner_x.get(1), hexacorner_y.get(1))) * Math.sqrt(3) / 2);
            for (int i = 0; i < pos_circle_x.size(); i++) {
                if ((pos_circle_x.get(i) > 0) && (pos_circle_y.get(i) > 0)) {
                    circles.add(new Point(pos_circle_x.get(i), pos_circle_y.get(i)));
                }
            }

            double maxdist = EuclidDistance(new Point(hexacorner_x.get(0), hexacorner_y.get(0)), new Point(cx0, cy0));
            if (circles.size() > 15) {
                for (int k = 0; k < circles.size() - 1; k++) {
                    for (int l = k + 1; l < circles.size(); l++) {
                        double center_dist = EuclidDistance(new Point(cx0, cy0), circles.get(l));
                        if ((EuclidDistance(circles.get(k), circles.get(l)) < 40) | (center_dist > maxdist * 1.1)) {
                            circles.remove(l);
                        }
                    }
                }
            }
            for (int j = 0; j < 4; j++) {
                for (int i = 0; i < 6; i++) {
                    Point p1 = new Point(hexacorner_x.get(i * 4 + j), hexacorner_y.get(i * 4 + j));
                    Point p2 = new Point(hexacorner_x.get(((i + 1) * 4) % 24 + j), hexacorner_y.get(((i + 1) * 4) % 24 + j));
                    int[] result = isbetween4(p1, p2, circles, j);
                    for (int l = 0; l < 4 - j; l++) {
                        bitstream += "" + result[l];
                    }
                    bitstream += "  ";
                }
            }
        }

        hexacorner_x.clear();
        hexacorner_y.clear();
        circles.clear();
        pos_circle_y.clear();
        pos_circle_x.clear();
        try {
            byte[] result = convertMatToBitMap(frame);
            Intent intent = new Intent(this, ShowValue.class);
            intent.putExtra("result", result);
            intent.putExtra("bitstream", bitstream);
            startActivity(intent);
        } catch (Exception ee) {
            Log.d("bbb", "" + ee.getMessage());
        }
    }

    private boolean HexaChecker(ArrayList<Point> corners_pos) {
        int x1 = (int) corners_pos.get(0).x;
        int y1 = (int) corners_pos.get(0).y;
        int x2 = (int) corners_pos.get(1).x;
        int y2 = (int) corners_pos.get(1).y;
        int x3 = (int) corners_pos.get(2).x;
        int y3 = (int) corners_pos.get(2).y;
        float cosine = Cosine_Angle(x2 - x1, y2 - y1, x3 - x2, y3 - y2);
        if (Math.abs(cosine) > 0.9) {
            return false;
        } else {
            return true;
        }
    }

    private float Cosine_Angle(int vec_x1, int vec_y1, int vec_x2, int vec_y2) {
        return (float) ((vec_x1 * vec_x2 + vec_y1 * vec_y2) / (Math.sqrt(vec_x1 * vec_x1 + vec_y1 * vec_y1) * Math.sqrt(vec_x2 * vec_x2 + vec_y2 * vec_y2)));
    }

    private double EuclidDistance(Point A, Point B) {
        double distance = Math.sqrt(Math.pow((A.x - B.x), 2) + Math.pow((A.y - B.y), 2));
        return distance;
    }

    private ArrayList<Point> Align(ArrayList<Point> points, Point center) {
        try {
            for (int i = 0; i < points.size(); i++) {
                for (int j = i + 1; j < points.size(); j++) {
                    float angle_i = Cosine_Angle((int) (points.get(i).x - center.x), (int) (points.get(i).y - center.y), 1, 0);
                    float angle_j = Cosine_Angle((int) (points.get(j).x - center.x), (int) (points.get(j).y - center.y), 1, 0);
                    if (angle_j > angle_i) {
                        Collections.swap(points, i, j);
                    }
                }
            }
            ArrayList<Point> alignedpoints = new ArrayList<>();
            alignedpoints.add(points.get(0));
            points.remove(0);
            int k = 0;
            while (points.size() > 0) {
                if (points.size() == 1) {
                    alignedpoints.add(points.get(0));
                    points.remove(0);
                } else {
                    for (int i = 0; i < points.size(); i++) {
                        for (int j = i + 1; j < points.size(); j++) {
                            double d_i = EuclidDistance(points.get(i), alignedpoints.get(k));
                            double d_j = EuclidDistance(points.get(j), alignedpoints.get(k));
                            if (d_i > d_j) {
                                Collections.swap(points, i, j);
                            }
                        }
                    }
                    alignedpoints.add(points.get(0));
                    points.remove(0);
                    k++;
                }
            }
            if (alignedpoints.get(1).y > alignedpoints.get(0).y) {
                Collections.swap(alignedpoints, 1, 5);
                Collections.swap(alignedpoints, 2, 4);
            }
            return alignedpoints;
        } catch (Exception ee) {
            return null;
        }
    }

    private int[] isbetween3(Point p1, Point p2, ArrayList<Point> pp, int hexagon) {
        int b1 = 0;
        int b2 = 0;
        int b3 = 0;
        int[] result = new int[3 - hexagon];
        double whole_dist = EuclidDistance(p1, p2);
        for (int i = 0; i < pp.size(); i++) {
            try {
                double dist1 = EuclidDistance(p1, pp.get(i));
                double dist2 = EuclidDistance(p2, pp.get(i));
                float new_dist = Dist_points(p1, p2, pp.get(i));
                if ((new_dist < separate * 0.35) && (dist1 < whole_dist) && (dist2 < whole_dist)) {
                    switch (hexagon) {
                        case 0:
                            if (dist1 <= whole_dist / 3) {
                                b1 = 1;
                            } else if (dist1 >= whole_dist * 2 / 3) {
                                b3 = 1;
                            } else if ((dist1 > whole_dist / 3) && (dist1 < whole_dist * 2 / 3)) {
                                b2 = 1;
                            }
                            result = new int[]{b1, b2, b3};
                            break;
                        case 1:
                            if (dist2 > dist1) {
                                b1 = 1;
                            } else {
                                b2 = 1;
                            }
                            result = new int[]{b1, b2};
                            break;
                        case 2:
                            b1 = 1;
                            result = new int[]{b1};
                            break;
                        default:
                            break;
                    }
                }
            } catch (Exception e) {
            }
        }
        return result;
    }

    private float Dist_points(Point p1, Point p2, Point p0) {
        float a = (float) (p1.y - p2.y);
        float b = (float) (p2.x - p1.x);
        float c = (float) (p1.y * (p1.x - p2.x) - p1.x * (p1.y - p2.y));
        float dist_points = (float) (Math.abs(a * p0.x + b * p0.y + c) / Math.sqrt(a * a + b * b));
        return dist_points;
    }

    private int[] isbetween4(Point p1, Point p2, ArrayList<Point> pp, int hexagon) {
        int b1 = 0;
        int b2 = 0;
        int b3 = 0;
        int b4 = 0;
        int[] result = new int[4 - hexagon];
        double whole_dist = EuclidDistance(p1, p2);
        for (int i = 0; i < pp.size(); i++) {
            try {
                double dist1 = EuclidDistance(p1, pp.get(i));
                double dist2 = EuclidDistance(p2, pp.get(i));
                float new_dist = Dist_points(p1, p2, pp.get(i));
                if ((new_dist < separate * 0.2) && (dist1 < whole_dist) && (dist2 < whole_dist)) {
                    switch (hexagon) {
                        case 0:
                            if (dist1 < whole_dist * 0.25) {
                                b1 = 1;
                            } else if ((dist1 > whole_dist * 0.25) && (dist1 < whole_dist * 0.5)) {
                                b2 = 1;
                            } else if ((dist1 > whole_dist * 0.5) && (dist1 < whole_dist * 0.75)) {
                                b3 = 1;
                            } else if (dist1 > whole_dist * 0.75) {
                                b4 = 1;
                            }
                            result = new int[]{b1, b2, b3, b4};
                            break;
                        case 1:
                            if (dist1 <= whole_dist / 3) {
                                b1 = 1;
                            } else if (dist1 > whole_dist * 2 / 3) {
                                b3 = 1;
                            } else if ((dist1 > whole_dist / 3) && (dist1 < whole_dist * 2 / 3)) {
                                b2 = 1;
                            }
                            result = new int[]{b1, b2, b3};
                            break;
                        case 2:
                            if (dist2 > dist1) {
                                b1 = 1;
                            } else {
                                b2 = 1;
                            }
                            result = new int[]{b1, b2};
                            break;
                        case 3:
                            b1 = 1;
                            result = new int[]{b1};
                            break;
                    }
                }
            } catch (Exception e) {
            }
        }
        return result;
    }
}
