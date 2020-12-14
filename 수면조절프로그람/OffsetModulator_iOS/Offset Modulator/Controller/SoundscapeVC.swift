//
//  SoundscapeVC.swift
//  Offset Modulator
//
//  Created by Ming Xing Liang on 2020/6/9.
//  Copyright © 2020 Myong Song Ryang. All rights reserved.
//

import UIKit


protocol BackgroundVolumeDelegate {
    func backgroundVolumeChanged(volume: Float)
    func changeBackgroundMusic()
}

class SoundscapeVC: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var modeSelector: UISegmentedControl!
    @IBOutlet weak var typeSelector: UISegmentedControl!
    
    var mainVC: MainVC?
    var delegate: BackgroundVolumeDelegate?
    
    var modeLocker = false
    var typeLocker = false
    var volumeLocker = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.delegate = self
        tableView.dataSource = self
        
        updateUI()
    }
    
    func updateUI() {
        
        if isPad {
            modeSelector.setTitleTextAttributes(segmentControlFont as? [NSAttributedString.Key : Any], for: .normal)
            typeSelector.setTitleTextAttributes(segmentControlFont as? [NSAttributedString.Key : Any], for: .normal)
        }
        
        modeLocker = true
        if soundscapePlayMode == .Off {
            modeSelector.selectedSegmentIndex = 0
            tableView.isUserInteractionEnabled = false
            volumeSlider.isUserInteractionEnabled = false
        } else if soundscapePlayMode == .Play {
            modeSelector.selectedSegmentIndex = 1
            tableView.isUserInteractionEnabled = true
            volumeSlider.isUserInteractionEnabled = false
        } else if soundscapePlayMode == .Background {
            modeSelector.selectedSegmentIndex = 2
            tableView.isUserInteractionEnabled = true
            volumeSlider.isUserInteractionEnabled = true
        }
        modeLocker = false
        
        typeLocker = true
        if soundscapeType == .Ambient {
            typeSelector.selectedSegmentIndex = 0
            soundscapeList = ambientList
        } else if soundscapeType == .Binaural {
            typeSelector.selectedSegmentIndex = 1
            soundscapeList = binauralList
        } else if soundscapeType == .Biomusical {
            typeSelector.selectedSegmentIndex = 2
            soundscapeList = biomusicalList
        } else if soundscapeType == .Elemental {
            typeSelector.selectedSegmentIndex = 3
            soundscapeList = elementalList
        }
        typeLocker = false
        tableView.reloadData()
        
        volumeLocker = true
        volumeSlider.value = backgroundVolume
        volumeLocker = false
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    @IBAction func modeChanged(_ sender: UISegmentedControl) {
        if modeLocker {return}
        if sender.selectedSegmentIndex == 0 {
            if soundscapePlayMode == .Play {
                mainVC?.stopMainMusic()
            } else if soundscapePlayMode == .Background {
                mainVC?.stopBackgroundMusic()
            }
            soundscapePlayMode = .Off
            tableView.isUserInteractionEnabled = false
            volumeSlider.isUserInteractionEnabled = false
        } else if sender.selectedSegmentIndex == 1 {
            mainVC?.stopMusic()
            soundscapePlayMode = .Play
            tableView.isUserInteractionEnabled = true
            volumeSlider.isUserInteractionEnabled = false
        } else {
            if soundscapePlayMode == .Play {
                mainVC?.stopMainMusic()
            } else if soundscapePlayMode == .Off {
                mainVC?.stopBackgroundMusic()
            }
            soundscapePlayMode = .Background
            tableView.isUserInteractionEnabled = true
            volumeSlider.isUserInteractionEnabled = true
        }
    }
    
    @IBAction func typeChanged(_ sender: UISegmentedControl) {
        if typeLocker {return}
        currentSoundscapeIndex = 0
        if sender.selectedSegmentIndex == 0 {
            soundscapeList = ambientList
            soundscapeType = .Ambient
        } else if sender.selectedSegmentIndex == 1 {
            soundscapeList = binauralList
            soundscapeType = .Binaural
        } else if sender.selectedSegmentIndex == 2 {
            soundscapeList = biomusicalList
            soundscapeType = .Biomusical
        } else if sender.selectedSegmentIndex == 3 {
            soundscapeList = elementalList
            soundscapeType = .Elemental
        }
        
        if soundscapePlayMode == .Play {
            mainVC?.stopMainMusic()
        } else if soundscapePlayMode == .Background {
            mainVC?.stopBackgroundMusic()
        }
        
        tableView.reloadData()
    }
    
    
    @IBAction func backgroundVolumnChanged(_ sender: Any) {
        if volumeLocker {return}
        backgroundVolume = volumeSlider.value
        delegate?.backgroundVolumeChanged(volume: backgroundVolume)
    }
    
    @IBAction func soundModeHelp(_ sender: Any) {
        showAlert(for: self, title: "Sound Mode", message: soundModeHelpMessage)
    }
    
}

extension SoundscapeVC: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return soundscapeList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if soundscapeList.count == 0 {
            return UITableViewCell()
        }
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "soundscapeCell", for: indexPath) as? MusicTableViewCell else {
            return UITableViewCell()
        }
        guard let soundscapeItem = getMediaItem(SongUrl: soundscapeList[indexPath.row]) else {
            return UITableViewCell()
        }
        if let artwork = soundscapeItem.artworkImage {
            cell.albumArtwork.image = artwork
        } else {
            cell.albumArtwork.image = UIImage(named: "playlist_noalbumart")
        }
        
        cell.artistLabel.text = soundscapeItem.artist ?? "Unknown Artist"
        cell.titleLabel.text = soundscapeItem.title ?? "Unknown Title"
        cell.artistLabel.leadingBuffer = 20
        cell.artistLabel.trailingBuffer = 20
        cell.titleLabel.leadingBuffer = 20
        cell.titleLabel.trailingBuffer = 20
        cell.titleLabel.speed = .rate(30)
        cell.artistLabel.speed = .rate(20)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        currentSoundscapeIndex = indexPath.row
        if soundscapePlayMode == .Background {
            delegate?.changeBackgroundMusic()
        } else if soundscapePlayMode == .Play {
            DispatchQueue.main.async {
                if self.mainVC!.isPlaying && !self.mainVC!.delayedPlayingStarted {return}
                self.mainVC!.delayedPlayingStarted = false
                UIView.animate(withDuration: 0.5) {
                    self.mainVC?.albumArtImageView.transform = CGAffineTransform.init(scaleX: 1.0, y: 1.0)
                }
                self.mainVC?.playFile()
            }
        }
    }
}
