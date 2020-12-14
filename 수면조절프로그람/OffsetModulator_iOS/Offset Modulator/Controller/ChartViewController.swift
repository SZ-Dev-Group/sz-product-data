//
//  ChartViewController.swift
//  Offset Modulator
//
//  Created by Ming Xing Liang on 2020/6/25.
//  Copyright © 2020 Myong Song Ryang. All rights reserved.
//

import UIKit
import Charts

class ChartViewController: UIViewController {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    @IBOutlet weak var chartViewPhone: LineChartView!
    @IBOutlet weak var chartViewPad: LineChartView!
    @IBOutlet weak var systemTimeText: UITextField!
    @IBOutlet weak var deviationText: UITextField!
    @IBOutlet weak var offsetText: UITextField!
    
    
    var chartView: LineChartView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        chartView = chartViewPad
        if !isPad {
            appDelegate.deviceOrientation = .landscape
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            chartView = chartViewPhone
        }
        // Do any additional setup after loading the view.
        generateChart()
    }
    
    @IBAction func goBack(_ sender: Any) {
        appDelegate.deviceOrientation = .portrait
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        dismiss(animated: true, completion: nil)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard UIApplication.shared.applicationState == .inactive else {
            return
        }
        generateChart()
    }
    
    func generateChart() {
        // Adding data
        //1. Create Entry objects
        let refPoints = getShiftedSinConst(wakeupTime: wakeUpTime)
        var entries: [ChartDataEntry] = []
        var delta: Double = 0
        if wakeUpTime % 2 == 0 {
            delta = 0
        } else {
            delta = 0.5
        }
        for i in 0 ..< 25 {
            entries.append(ChartDataEntry(x: Double(i) + delta, y: refPoints[i]))
        }
        //2. Add Entries to DataSet with style options
        let set1 = LineChartDataSet(entries: entries)
        
        set1.drawIconsEnabled = false
        
//        set1.lineDashLengths = [5, 2.5]
        set1.highlightLineDashLengths = [5, 2.5]
        
        set1.lineWidth = 1
        set1.circleRadius = 3
        set1.drawCircleHoleEnabled = false
        set1.valueFont = .systemFont(ofSize: 9)
        set1.formLineDashLengths = [5, 2.5]
        set1.formLineWidth = 1
        set1.formSize = 15
        set1.valueTextColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        
        
        
        // chart color
        if traitCollection.userInterfaceStyle == .dark {
            set1.setColor(.init(red: 253.0/255, green: 217.0/255, blue: 152.0/255, alpha: 1.0))
            set1.setCircleColor(.init(red: 253.0/255, green: 217.0/255, blue: 152.0/255, alpha: 1.0))
            set1.highlightColor = .init(red: 253.0/255, green: 217.0/255, blue: 152.0/255, alpha: 1.0)
        } else {
            set1.setColor(.init(red: 52.0/255, green: 104.0/255, blue: 35.0/255, alpha: 1.0))
            set1.setCircleColor(.init(red: 52.0/255, green: 104.0/255, blue: 35.0/255, alpha: 1.0))
            set1.highlightColor = .init(red: 52.0/255, green: 104.0/255, blue: 35.0/255, alpha: 1.0)
        }
        
        //3. Add DataSet to Data
        let data = LineChartData(dataSet: set1)
        //4. Refresh ChartView
        chartView.data = data
        chartView.drawBordersEnabled = true
        chartView.setVisibleYRange(minYRange: 0, maxYRange: 1.1, axis: .left)
        chartView.legend.enabled = false
        
        
        // chart axis label color
        if traitCollection.userInterfaceStyle == .dark {
            chartView.xAxis.labelTextColor = .init(red: 253.0/255, green: 217.0/255, blue: 152.0/255, alpha: 1.0)
            chartView.leftAxis.labelTextColor = .init(red: 253.0/255, green: 217.0/255, blue: 152.0/255, alpha: 1.0)
            chartView.rightAxis.labelTextColor = .init(red: 253.0/255, green: 217.0/255, blue: 152.0/255, alpha: 1.0)
        } else {
            chartView.xAxis.labelTextColor = .init(red: 0, green: 0, blue: 0, alpha: 1.0)
            chartView.leftAxis.labelTextColor = .init(red: 0, green: 0, blue: 0, alpha: 1.0)
            chartView.rightAxis.labelTextColor = .init(red: 0, green: 0, blue: 0, alpha: 1.0)
        }
        
        
        // update chart info
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        systemTimeText.text = formatter.string(from: Date())
    
        deviationText.text = String.init(format: "%.6f", getSinValue(refValue: getShiftedSinConst(wakeupTime: wakeUpTime), date: Date()))
        
        offsetText.text = "\(getDeviation(wakeupTime: wakeUpTime, hq: isHQ))"
    }
}
