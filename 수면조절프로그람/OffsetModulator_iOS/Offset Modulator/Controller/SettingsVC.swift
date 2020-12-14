//
//  SettingsVC.swift
//  Offset Modulator
//
//  Created by Ming Xing Liang on 2020/5/17.
//  Copyright © 2020 Myong Song Ryang. All rights reserved.
//

import UIKit
import iOSDropDown

class SettingsVC: UIViewController {
    
    @IBOutlet weak var faqButton: UIButton!
    @IBOutlet weak var privacyButton: UIButton!
    @IBOutlet weak var wakeTimeDropDown: DropDown!
    @IBOutlet weak var sleepTimeDropDown: DropDown!
    @IBOutlet weak var affinitySelect: UISegmentedControl!
    @IBOutlet weak var optimizationSelect: UISegmentedControl!
    
    var faqButtonLongPressed = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        faqButtonLongPressed = false
        super.viewDidAppear(animated)
    }
    
    func setupUI() {
        if isPad {
            affinitySelect.setTitleTextAttributes(segmentControlFont as? [NSAttributedString.Key : Any], for: .normal)
            optimizationSelect.setTitleTextAttributes(segmentControlFont as? [NSAttributedString.Key : Any], for: .normal)
        }
        
        // Affinity setting
        if affinity == .Random {
            affinitySelect.selectedSegmentIndex = 0
        } else if affinity == .Left {
            affinitySelect.selectedSegmentIndex = 1
        } else {
            affinitySelect.selectedSegmentIndex = 2
        }
        // Optimization setting
        if optimization == .Complete {
            optimizationSelect.selectedSegmentIndex = 0
        } else if optimization == .Relaxation {
            optimizationSelect.selectedSegmentIndex = 1
        } else {
            optimizationSelect.selectedSegmentIndex = 2
        }
        // Giving faq and privacy button rounded borders
        faqButton.layer.borderWidth = 1
        faqButton.layer.borderColor = UIColor.lightGray.cgColor
        faqButton.contentEdgeInsets = UIEdgeInsets.init(top: 5, left: 10, bottom: 5, right: 10)
        faqButton.layer.cornerRadius = faqButton.bounds.height / 3.0
        privacyButton.layer.borderWidth = 1
        privacyButton.layer.borderColor = UIColor.lightGray.cgColor
        privacyButton.contentEdgeInsets = UIEdgeInsets.init(top: 5, left: 10, bottom: 5, right: 10)
        privacyButton.layer.cornerRadius = privacyButton.bounds.height / 3.0
        // Giving border to waketime and sleep time labels
        wakeTimeDropDown.optionArray = wakeTimeArray
        //Its Id Values and its optional
        wakeTimeDropDown.optionIds = [0,1,2,3,4,5,6,7,8,9]
        wakeTimeDropDown.didSelect { (selectedText, index, id) in
            self.sleepTimeDropDown.selectedIndex = index
            self.sleepTimeDropDown.text = sleepTimeArray[index]
            wakeUpTime = index
        }
        sleepTimeDropDown.optionArray = sleepTimeArray
        sleepTimeDropDown.optionIds = [0,1,2,3,4,5,6,7,8,9]
        sleepTimeDropDown.didSelect { (selectedText, index, id) in
            self.wakeTimeDropDown.selectedIndex = index
            self.wakeTimeDropDown.text = wakeTimeArray[index]
            wakeUpTime = index
        }
        wakeTimeDropDown.selectedIndex = wakeUpTime
        sleepTimeDropDown.selectedIndex = wakeUpTime
        wakeTimeDropDown.text = wakeTimeArray[wakeUpTime]
        sleepTimeDropDown.text = sleepTimeArray[wakeUpTime]
        
        faqButton.addGestureRecognizer(UITapGestureRecognizer.init(target: self, action: #selector(faqTapped)))
        faqButton.addGestureRecognizer(UILongPressGestureRecognizer.init(target: self, action: #selector(faqLongPressed)))
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard UIApplication.shared.applicationState == .inactive else {
            return
        }
        dismiss(animated: false, completion: nil)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    @IBAction func affinityChanged(_ sender: Any) {
        if affinitySelect.selectedSegmentIndex == 0 {
            affinity = .Random
        } else if affinitySelect.selectedSegmentIndex == 1 {
            affinity = .Left
        } else {
            affinity = .Right
        }
    }
    
    @IBAction func optimizationChanged(_ sender: Any) {
        if optimizationSelect.selectedSegmentIndex == 0 {
            optimization = .Complete
        } else if optimizationSelect.selectedSegmentIndex == 1 {
            optimization = .Relaxation
        } else {
            optimization = .Focus
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToChart" {
            if let dest = segue.destination as? ChartViewController {
                dest.modalPresentationStyle = .fullScreen
            }
        }
    }
    
    @objc func faqTapped() {
        // show FAQ page
        UIApplication.shared.open(URL.init(string: faqUrl)!)
    }
    
    @objc func faqLongPressed() {
        // show chart
        if !faqButtonLongPressed {
            performSegue(withIdentifier: "segueToChart", sender: self)
            faqButtonLongPressed = true
        }
    }
    
    @IBAction func privacyClicked(_ sender: Any) {
        UIApplication.shared.open(URL.init(string: privacyUrl)!)
    }
    
    @IBAction func affinityHelp(_ sender: Any) {
        showAlert(for: self, title: "Affinity", message: affinityHelpMessage)
    }
    
    @IBAction func offsetHelp(_ sender: Any) {
        showAlert(for: self, title: "Offset Range Optimization", message: offsetHelpMessage)
    }
    
    @IBAction func circadianHelp(_ sender: Any) {
        showAlert(for: self, title: "Circadian Sync", message: circadianHelpMessage)
    }
}
