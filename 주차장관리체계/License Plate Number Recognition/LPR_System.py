from PyQt5.QtWidgets import QWidget, QLabel, QGroupBox, QDesktopWidget, QApplication, \
    QHBoxLayout, QVBoxLayout, QPushButton, QMessageBox
from PyQt5 import QtGui
from PyQt5.Qt import QPixmap
from PyQt5 import QtCore
import sys
from PyQt5.Qt import QFont
from PyQt5.QtCore import Qt
import cv2
from src.utils import im2single
from src.keras_utils import load_model, detect_lp
import darknet.python.darknet as dn
from darknet.python.darknet import detect
from src.label import dknet_label_conversion
from src.utils import nms
from keras.models import model_from_json
from PIL import Image
import scipy.spatial.distance as dist
import os
import numpy as np
import _sqlite3
from datetime import datetime


def adjust_pts(pts, lroi):
    return pts * lroi.wh().reshape((2, 1)) + lroi.tl().reshape((2, 1))


class Recognition(QWidget):
    def __init__(self):
        super().__init__()
        self.title = "Car Recognition System"
        app = QDesktopWidget()
        screen = app.screenGeometry()
        screen_w, screen_h = screen.width(), screen.height()
        self.addtask = None
        self.width = screen_w * 0.75
        self.height = screen_h * 0.75
        self.left = (screen_w - self.width) / 2
        self.top = (screen_h - self.height) / 2
        self.lpr_result = ""
        self.Init_UI()
        self.register_status = False
        self.car_index = 0
        self.mode = True
        self.prepare_status = False

        self.cars = ['Alfa Romeo', 'Audi', 'BMW', 'Chevrolet', 'Citroen', 'Dacia', 'Daewoo', 'Dodge',
                     'Ferrari', 'Fiat', 'Ford', 'Honda', 'Hyundai', 'Jaguar', 'Jeep', 'Kia', 'Lada',
                     'Lancia', 'Land Rover', 'Lexus', 'Maserati', 'Mazda', 'Mercedes', 'Mitsubishi',
                     'Nissan', 'Opel', 'Peugeot', 'Porsche', 'Renault', 'Rover', 'Saab', 'Seat',
                     'Skoda', 'Subaru', 'Suzuki', 'Tata', 'Tesla', 'Toyota', 'Volkswagen', 'Volvo']

    def Init_UI(self):
        self.setWindowTitle(self.title)
        self.setGeometry(self.left, self.top, self.width, self.height)
        self.setStyleSheet("background-color:rgb(12,12,23); border-style:solid; border-color:rgb(0,0,11)")
        self.ui_layout = QVBoxLayout()
        self.hbox = QHBoxLayout()

        groupstyle = "QGroupBox {margin:10px;border: 1px solid rgb(255, 255, 255); color:white; padding:20px}"
        groupfont = QFont()
        groupfont.setPointSize(15)
        label_style = "border: 1px solid rgb(255, 255, 255)"
        label_width = self.width / 2 - 80
        label_height = label_width * 0.6
        enter_groupbox = QGroupBox("Enter")
        enter_groupbox.setFont(groupfont)
        enter_groupbox.setStyleSheet(groupstyle)

        self.enter_car_video = QLabel("car1")
        self.enter_car_video.setFixedWidth(label_width)
        self.enter_car_video.setFixedHeight(label_height)
        self.enter_car_video.setStyleSheet(label_style)

        enter_group_layout = QVBoxLayout()
        enter_group_layout.addWidget(self.enter_car_video)
        self.register_btn = PositiveSmallButton()
        self.register_btn.setText("Register Car")
        self.register_btn.setStyleSheet(
            "border-style:solid; border-color:rgb(0,255,0);border-width:1; color:rgb(255,255,255);border-radius:4px")
        self.register_btn.clicked.connect(self.register_car)

        enter_group_layout.addWidget(self.register_btn)
        enter_groupbox.setLayout(enter_group_layout)

        exit_groupbox = QGroupBox("Exit")
        exit_groupbox.setFont(groupfont)
        exit_groupbox.setStyleSheet(groupstyle)
        self.exit_car_video = QLabel("car1")
        self.exit_car_video.setStyleSheet(label_style)
        self.exit_car_video.setFixedHeight(label_height)
        self.exit_car_video.setFixedWidth(label_width)

        exit_group_layout = QVBoxLayout()
        self.check_btn = PositiveSmallButton()
        self.check_btn.setText("Check car")
        self.check_btn.clicked.connect(self.check_car)

        exit_group_layout.addWidget(self.exit_car_video)
        exit_group_layout.addWidget(self.check_btn)
        exit_groupbox.setLayout(exit_group_layout)
        self.hbox.addWidget(enter_groupbox)
        self.hbox.addWidget(exit_groupbox)

        detail_info = QGroupBox("car Details")
        detail_info.setFont(groupfont)
        detail_info.setStyleSheet(groupstyle)
        detail_info.setFixedHeight(self.height / 4)
        detail_label_style = "color:yellow;"
        self.lpr_label = QLabel("License Plate Number:")
        self.lpr_label.setFixedWidth(200)
        self.lpr_show = QLabel("No Value")
        self.lpr_show.setStyleSheet(detail_label_style)
        self.lpr_label.setStyleSheet(detail_label_style)

        self.logo_label = QLabel("Car Type:")
        self.logo_label.setFixedWidth(200)
        self.logo_show = QLabel("No Value")
        self.logo_show.setStyleSheet(detail_label_style)
        self.logo_label.setStyleSheet(detail_label_style)

        detail_layout = QVBoxLayout()

        lpr_layout = QHBoxLayout()
        lpr_layout.addWidget(self.lpr_label)
        lpr_layout.addWidget(self.lpr_show)

        logo_layout = QHBoxLayout()
        logo_layout.addWidget(self.logo_label)
        logo_layout.addWidget(self.logo_show)

        detail_layout.addItem(lpr_layout)
        detail_layout.addItem(logo_layout)
        detail_info.setLayout(detail_layout)

        button_hox = QHBoxLayout()
        prepare_button = PositiveButton()
        prepare_button.setText("Prepare")
        prepare_button.setStyleSheet(
            "border-style:solid; border-color:rgb(0,255,0);border-width:1; color:rgb(255,255,255);border-radius:10px;margin:10px")
        prepare_button.setFont(groupfont)
        prepare_button.clicked.connect(self.prepare)

        start_button = PositiveButton()
        start_button.setText("Start")
        start_button.setStyleSheet(
            "border-style:solid; border-color:rgb(0,255,0);border-width:1; color:rgb(255,255,255);border-radius:10px;margin:10px")
        start_button.setFont(groupfont)
        start_button.clicked.connect(self.start_connect)

        mode_button = PositiveButton()
        mode_button.setText("Select Mode")
        mode_button.setStyleSheet(
            "border-style:solid; border-color:rgb(0,255,0);border-width:1; color:rgb(255,255,255);border-radius:10px;margin:10px")
        mode_button.setFont(groupfont)
        mode_button.clicked.connect(self.select_mode)

        exit_button = NegtiveButton()
        exit_button.setText("Exit")
        exit_button.setStyleSheet(
            "border-style:solid; border-color:rgb(255,0,0);border-width:1; color:rgb(255,255,255);border-radius:10px;margin:10px")
        exit_button.setFont(groupfont)
        exit_button.clicked.connect(self.exit_system)

        button_hox.addWidget(prepare_button)
        button_hox.addWidget(start_button)
        button_hox.addWidget(mode_button)
        button_hox.addWidget(exit_button)
        detail_hbox = QHBoxLayout()
        detail_info.setLayout(detail_hbox)
        self.ui_layout.addItem(self.hbox)
        self.ui_layout.addItem(button_hox)
        self.ui_layout.addWidget(detail_info)
        self.setLayout(self.ui_layout)
        self.show()

    def select_mode(self):
        self.mode = not self.mode
        self.lpr_result = ""
        self.lpr_show = ""

    def start_connect(self):
        if (self.prepare_status == True):

                cap1 = cv2.VideoCapture(2)
                while (True):
                    ret1, frame1 = cap1.read()
                    rgbImage = cv2.cvtColor(frame1, cv2.COLOR_BGR2RGB)
                    self.lpr(rgbImage)
                    convertToQtFormat = QtGui.QImage(rgbImage.data, rgbImage.shape[1], rgbImage.shape[0],
                                                     QtGui.QImage.Format_RGB888)
                    convertToQtFormat = QtGui.QPixmap.fromImage(convertToQtFormat)

                    pixmap = QPixmap(convertToQtFormat)

                    resizeImage = pixmap.scaled(self.enter_car_video.width(), self.enter_car_video.height(),
                                                QtCore.Qt.KeepAspectRatioByExpanding)

                    QApplication.processEvents()
                    if self.mode == True:
                        self.enter_car_video.setPixmap(resizeImage)
                    else:
                        self.exit_car_video.setPixmap(resizeImage)
            # except:
            #     msg = QMessageBox()
            #     msg.setText("Device connect failed")
            #     msg.setWindowTitle("Warning")
            #     msg.setStyleSheet("background-color:rgb(12,12,23);color: rgb(0, 255, 0);")
            #     msg.exec_()
        else:
            msg = QMessageBox()
            msg.setText("System don't prepare for datasets. Please Click Prepare button")
            msg.setWindowTitle("Warning")
            msg.setStyleSheet("background-color:rgb(12,12,23);color: rgb(0, 255, 0);")
            msg.exec_()

    def prepare(self):
        self.lp_threshold = .5
        self.ocr_threshold = .4
        self.ocr_weights = 'data/ocr/ocr-net.weights'
        self.ocr_netcfg = 'data/ocr/ocr-net.cfg'
        self.ocr_dataset = 'data/ocr/ocr-net.data'
        self.ocr_net = dn.load_net(self.ocr_netcfg.encode('utf-8'), self.ocr_weights.encode('utf-8'), 0)
        self.ocr_meta = dn.load_meta(self.ocr_dataset.encode('utf-8'))
        self.wpod_net_path = "data/lp-detector/wpod-net_update1.h5"
        self.wpod_net = load_model(self.wpod_net_path)
        json_file = open('logo_model/model.json', 'r')
        loaded_model_json = json_file.read()
        json_file.close()
        self.logo_model = model_from_json(loaded_model_json)
        self.logo_model.load_weights("logo_model/logo_detect.h5")
        self.prepare_status = True
        msg = QMessageBox()
        msg.setText("Prepare Complete")
        msg.setWindowTitle("Success")
        msg.setStyleSheet("background-color:rgb(12,12,23);color: rgb(0, 255, 0);")
        msg.exec_()

    def ImageConvert(self,n, i):
        im_ex = i.reshape(n, 50, 50, 3)
        im_ex = im_ex.astype('float32') / 255
        # zero center data
        im_ex = np.subtract(im_ex, 0.5)
        # ...and to scale it to (-1, 1)
        im_ex = np.multiply(im_ex, 2.0)
        return im_ex

    def lpr(self, image):
        Ivehicle = image
        h, w, c = Ivehicle.shape
        logo = Ivehicle[int(h / 2):int(h / 2) + 100, int(w / 2) - 50:int(w / 2) + 50]
        cv2.imwrite("temp/logo.png", logo)
        im = Image.open("temp/logo.png").convert("RGB")
        new_im = np.array(im.resize((50, 50))).flatten()
        m = int(np.argmax(self.logo_model.predict(self.ImageConvert(1, new_im), verbose=0), axis=1))
        self.logo_show.setText(self.cars[m])

        ratio = float(max(Ivehicle.shape[:2])) / min(Ivehicle.shape[:2])
        side = int(ratio * 288.)
        bound_dim = min(side + (side % (2 ** 4)), 608)

        Llp, LlpImgs, _ = detect_lp(self.wpod_net, im2single(Ivehicle), bound_dim, 2 ** 4, (240, 80), self.lp_threshold)
        if len(LlpImgs):
            Ilp = LlpImgs[0]
            Ilp = cv2.cvtColor(Ilp, cv2.COLOR_BGR2GRAY)
            Ilp = cv2.cvtColor(Ilp, cv2.COLOR_GRAY2BGR)
            cv2.imwrite('temp/lpr.png', Ilp * 255.)
            img_path = 'temp/lpr.png'
            # number plate ocr
            R, (width, height) = detect(self.ocr_net, self.ocr_meta, img_path.encode('utf-8'),
                                        thresh=self.ocr_threshold, nms=None)
            if len(R):
                L = dknet_label_conversion(R, width, height)
                L = nms(L, .45)

                L.sort(key=lambda x: x.tl()[0])
                lp_str = ''.join([chr(l.cl()) for l in L])
                print(lp_str)

                if (len(self.lpr_result) <= len(lp_str)):
                    self.lpr_result = lp_str
                    self.lpr_show.setText(self.lpr_result)
                elif (len(self.lpr_result) > 5):
                    self.register_status = True
            else:
                print('No characters found')

    def register_car(self):
        if (self.register_status == True & self.mode == True):
            msg = QMessageBox()
            msg.setText("Register succefully")
            msg.setWindowTitle("Success")
            msg.setStyleSheet("background-color:rgb(12,12,23);color: rgb(0, 255, 0);")
            msg.exec_()
            self.register_status = False
            self.lpr_show.setText("")
            self.mode = False

            # Insert data to database
            conn = _sqlite3.connect("car_record")
            now = datetime.now()
            dt_string = now.strftime("%d/%m/%Y %H:%M:%S")
            val = conn.execute("SELECT COUNT(*) FROM car_info")
            (number_of_rows,) = val.fetchone()
            conn.execute("INSERT INTO car_info VALUES (" + str(number_of_rows + 1) + ",'" + str(
                self.lpr_result) + "','" + dt_string + "','')")
            conn.commit()
            conn.close()

        else:
            msg = QMessageBox()
            msg.setText("Register status bad")
            msg.setWindowTitle("Warning")
            msg.setStyleSheet("background-color:rgb(12,12,23);color: rgb(0, 255, 0);")
            msg.exec_()

    def check_car(self):
        print("Checking start")
        conn = _sqlite3.connect("car_record")
        cursorObj1 = conn.cursor()
        cursorObj1.execute("SELECT * FROM car_info WHERE enter_lpr=?", (self.lpr_result,))
        result = cursorObj1.fetchall()
        if len(result) > 0:
            msg = QMessageBox()
            msg.setText("Registred car! Pass!")
            msg.setWindowTitle("Warning")
            msg.setStyleSheet("background-color:rgb(12,12,23);color: rgb(0, 255, 0);")
            msg.exec_()
            # Update data to database
            now = datetime.now()
            dt_string = now.strftime("%d/%m/%Y %H:%M:%S")

            def sql_update(con):
                cursorObj2 = con.cursor()
                cursorObj2.execute("UPDATE car_info SET exit_time ='" + dt_string + "' where LP='" + result + "'")
                con.commit()

            sql_update(conn)
            conn.close()

        else:
            msg = QMessageBox()
            msg.setText("Unknown car! No Pass!")
            msg.setWindowTitle("Warning")
            msg.setStyleSheet("background-color:rgb(12,12,23);color: rgb(0, 255, 0);")
            msg.exec_()
        self.mode = True
        self.lpr_result = ""
        self.lpr_show.setText("")

    def exit_system(self):
        exit(0)


class PositiveButton(QPushButton):
    def __init__(self, parent=None):
        super(PositiveButton, self).__init__(parent)

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.setStyleSheet("color:rgb(255,255,255);background-color:rgb(22,12,23);border-radius:10px;margin:10px")

    def mouseReleaseEvent(self, event):
        self.setStyleSheet(
            "border-style:solid; border-color:rgb(0,255,0);border-width:1; color:rgb(255,255,255);border-radius:10px;margin:10px")
        if self.rect().contains(event.pos()):
            self.clicked.emit()


class NegtiveButton(QPushButton):
    def __init__(self, parent=None):
        super(NegtiveButton, self).__init__(parent)

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.setStyleSheet("color:rgb(255,0,0);background-color:rgb(22,12,23);border-radius:10px;margin:10px")

    def mouseReleaseEvent(self, event):
        self.setStyleSheet(
            "border-style:solid; border-color:rgb(255,0,0);border-width:1; color:rgb(255,0,0);border-radius:10px;margin:10px")
        if self.rect().contains(event.pos()):
            self.clicked.emit()


class PositiveSmallButton(QPushButton):
    def __init__(self, parent=None):
        super(PositiveSmallButton, self).__init__(parent)
        self.setStyleSheet(
            "border-style:solid; border-color:rgb(0,255,0);border-width:1; color:rgb(255,255,255);border-radius:4px")

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.setStyleSheet("color:rgb(255,255,255);background-color:rgb(22,12,23);border-radius:4px;margin:10px")

    def mouseReleaseEvent(self, event):
        self.setStyleSheet(
            "border-style:solid; border-color:rgb(0,255,0);border-width:1; color:rgb(255,255,255);border-radius:4px")
        if self.rect().contains(event.pos()):
            self.clicked.emit()


class NegitiveSmallButton(QPushButton):
    def __init__(self, parent=None):
        super(NegitiveSmallButton, self).__init__(parent)
        self.setStyleSheet(
            "border-style:solid; border-color:rgb(255,0,0);border-width:1; color:rgb(255,255,255);border-radius:4px;margin:10px")

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.setStyleSheet("color:rgb(255,255,255);background-color:rgb(22,12,23);border-radius:4px;margin:10px")

    def mouseReleaseEvent(self, event):
        self.setStyleSheet(
            "border-style:solid; border-color:rgb(255,0,0);border-width:1; color:rgb(255,255,255);border-radius:4px;margin:10px")
        if self.rect().contains(event.pos()):
            self.clicked.emit()


App = QApplication(sys.argv)
window = Recognition()
sys.exit(App.exec())
