//
//  ViewController.swift
//  Offset Modulator
//
//  Created by Ming Xing Liang on 2020/5/14.
//  Copyright © 2020 Myong Song Ryang. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer

enum RepeatMode {
    case Off
    case One
    case All
}

enum ShuffleMode {
    case On
    case Off
}

class MainVC: UIViewController {
    
    // MARK: UI Controls
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var albumArtHolder: UIView!
    @IBOutlet weak var albumArtImageView: UIImageView!
    @IBOutlet weak var titleLabel: ShadowLabel!
    @IBOutlet weak var artistLabel: ShadowLabel!
    
    @IBOutlet weak var prevButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    
    @IBOutlet weak var playlistButton: UIButton!
    @IBOutlet weak var shuffleButton: UIButton!
    @IBOutlet weak var repeatButton: UIButton!
    
    @IBOutlet weak var lowVolumeImageView: UIImageView!
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var highVolumeImageView: UIImageView!
    
    
    @IBOutlet weak var pullDownButton_Top: UIButton!
    @IBOutlet weak var pullUpButton_Top: UIButton!
    @IBOutlet weak var pullDownMenu: UIView!
    @IBOutlet weak var pullDownMenuBottomSpacing: NSLayoutConstraint!
    @IBOutlet weak var pullDownMenuBottomSpacingPad: NSLayoutConstraint!
    
    
    @IBOutlet weak var pullUpButton: UIButton!
    @IBOutlet weak var pullDownButton: UIButton!
    @IBOutlet weak var pullUpMenuView: UIView!
    @IBOutlet weak var pullUpMenuBackgroundImageView: UIImageView!
    @IBOutlet weak var pullUpMenuTopSpacing: NSLayoutConstraint!
    @IBOutlet weak var pullUpMenuTopSpacingPad: NSLayoutConstraint!
    @IBOutlet weak var offsetButton: UIButton!
    @IBOutlet weak var circadianButton: UIButton!
    @IBOutlet weak var label1: UILabel!
    @IBOutlet weak var textField1: UITextField!
    @IBOutlet weak var label2: UILabel!
    @IBOutlet weak var textField2: UITextField!
    
    // for iPad
    @IBOutlet weak var textField1Pad: UITextField!
    @IBOutlet weak var textField2Pad: UITextField!
    
    
    // MARK: Class variables
    var player: AVAudioPlayerNode?
    var backgroundPlayer: AVAudioPlayerNode?
    var audioEngine = AVAudioEngine()
    var audioError: NSError?
    var audioFile: AVAudioFile?
    var backgroundAudioFile: AVAudioFile?
    
    var audioFormat: AVAudioFormat?
    var audioFrameCount: UInt32 = 0
    var channelNo = 0
    var offset = 0
    var offsetTime = 0
    var manualOverride = false
    var isPlaying = false
    var isPaused = false
    var shuffleMode: ShuffleMode = .Off
    var repeatMode: RepeatMode = .Off
    var stopRequested = false
    var offsetBuffer: [Float] = []
    var fileBuffer: AVAudioPCMBuffer?
    var backgroundFileBuffer: AVAudioPCMBuffer?
    var delayedPlayingStarted = true
    let nc = NotificationCenter.default
    
    var mpVolumeView: MPVolumeView = MPVolumeView()
    
    // MARK: View Controller Init
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupUI()
        prepareAudioSession()
    }
    
    func setupUI() {
        
        hidePullupMenu()
        hidePulldownMenu()
        
        albumArtImageView.transform = CGAffineTransform.init(scaleX: 0.7, y: 0.7)
        titleLabel.activateShadow()
        artistLabel.activateShadow()
        
        titleLabel.speed = .rate(20)
        artistLabel.speed = .rate(15)
        
        
        volumeSlider.value = AVAudioSession.sharedInstance().outputVolume
        (mpVolumeView.subviews.filter{NSStringFromClass($0.classForCoder) == "MPVolumeSlider"}.first as? UISlider)?.setValue(AVAudioSession.sharedInstance().outputVolume, animated: false)
        
        addColorBorderToArtwork()
        clearColorBorderFromArtwork()
        setupAudioNotifications()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard UIApplication.shared.applicationState == .inactive else {
            return
        }
        if soundscapePlayMode == .Play {
            if currentSoundscapeIndex >= 0 && currentSoundscapeIndex < soundscapeList.count {
                guard let currentItem = getMediaItem(SongUrl: soundscapeList[currentSoundscapeIndex]) else {
                    return
                }
                if let artwork = currentItem.artworkImage {
                    albumArtImageView.image = artwork
                    addColorBorderToArtwork()
                } else {
                    albumArtImageView.image = UIImage(named: "main_noalbumart")
                    clearColorBorderFromArtwork()
                }
            }
        } else {
            if currentIndex >= 0 && currentIndex < playList.count {
                guard let currentItem = getMediaItem(SongUrl: playList[currentIndex]) else {
                    return
                }
                if let artwork = currentItem.artwork {
                    albumArtImageView.image = artwork.image(at: albumArtImageView.bounds.size)
                    addColorBorderToArtwork()
                } else {
                    albumArtImageView.image = UIImage(named: "main_noalbumart")
                    clearColorBorderFromArtwork()
                }
            }
        }
    }
    
    func setupAudioNotifications() {
        // Get the default notification center instance.
        
        nc.addObserver(self,
                       selector: #selector(handleInterruption),
                       name: AVAudioSession.interruptionNotification,
                       object: nil)
        
        nc.addObserver(self,
                       selector: #selector(handleRouteChange),
                       name: AVAudioSession.routeChangeNotification,
                       object: nil)
        
        nc.addObserver(self,
                       selector: #selector(handleAudioEngineChange),
                       name: NSNotification.Name.AVAudioEngineConfigurationChange,
                       object: nil)
    }
    
    @objc func handleAudioEngineChange(notification: Notification) {
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
            } catch {
                print(error)
                return
            }
        }
        if player != nil {
            audioEngine.detach(player!)
            audioEngine.attach(player!)
            audioEngine.connect(player!, to: audioEngine.mainMixerNode, format: audioFile?.processingFormat)
        }
        if soundscapePlayMode == .Background && backgroundPlayer != nil {
            audioEngine.connect(backgroundPlayer!, to: audioEngine.mainMixerNode, format: backgroundAudioFile?.processingFormat)
        }
    }
    
    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
        }
        
        // Switch over the interruption type.
        switch type {
            
        case .began:
            // An interruption began. Update the UI as needed.
            self.player?.pause()
            self.backgroundPlayer?.pause()
            playButton.setImage(UIImage(named: "play"), for: .normal)
            isPaused = true
            titleLabel.shutdownLabel()
            artistLabel.shutdownLabel()
            UIView.animate(withDuration: 0.5) {
                self.albumArtImageView.transform = CGAffineTransform.init(scaleX: 0.7, y: 0.7)
            }
        case .ended: ()
            // An interruption ended. Resume playback, if appropriate.
            
            //            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            //            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            //            if options.contains(.shouldResume) {
            //                // Interruption ended. Playback should resume.
            //
            //            } else {
            //                // Interruption ended. Playback should not resume.
            //                playButton.setImage(UIImage(named: "play"), for: .normal)
            //                isPaused = true
            //                titleLabel.shutdownLabel()
            //                artistLabel.shutdownLabel()
            //                UIView.animate(withDuration: 0.5) {
            //                    self.albumArtImageView.transform = CGAffineTransform.init(scaleX: 0.7, y: 0.7)
            //                }
            //            }
            
            
        default: ()
        }
    }
    
    @objc func handleRouteChange(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue:reasonValue) else {
                return
        }
        switch reason {
        case .newDeviceAvailable: ()
        case .oldDeviceUnavailable:
            if let previousRoute =
                userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                for output in previousRoute.outputs {
                    if output.portType == .headphones || output.portType == .bluetoothA2DP {
                        
                        if isPlaying {
                            if output.portType == .headphones {
                                self.player?.pause()
                                self.backgroundPlayer?.pause()
                                self.isPaused = true
                                self.manualOverride = true
                            } else {
                                self.stopMusic()
                            }
                            
                            DispatchQueue.main.async {
                                self.playButton.setImage(UIImage(named: "play"), for: .normal)
                                self.titleLabel.shutdownLabel()
                                self.artistLabel.shutdownLabel()
                                UIView.animate(withDuration: 0.5) {
                                    self.albumArtImageView.transform = CGAffineTransform.init(scaleX: 0.7, y: 0.7)
                                }
                            }
                        }
                        
                        break
                    }
                }
            }
        default: ()
        }
    }
    
    func addColorBorderToArtwork() {
        // adding white border to AlbumArtwork
        
        albumArtHolder.layer.masksToBounds = false
        albumArtImageView.layer.masksToBounds = true
        
        albumArtImageView.layer.borderWidth = 5
        albumArtImageView.layer.borderColor = UIColor(named: "border_color")?.cgColor
        albumArtImageView.layer.cornerRadius = 10
        
        albumArtHolder.layer.rasterizationScale = UIScreen.main.scale
        albumArtHolder.layer.shadowColor = UIColor(named: "border_color")?.cgColor
        albumArtHolder.layer.shadowOpacity = 1.0
        albumArtHolder.layer.shadowRadius = 5.0
        albumArtHolder.clipsToBounds = false
    }
    
    func clearColorBorderFromArtwork() {
        albumArtImageView.layer.borderWidth = 0
        albumArtHolder.layer.shadowOpacity = 0
    }
    
    func updateLastPlayedMusic() {
        if !isPlaying {
            if soundscapePlayMode == .Play {
                if currentSoundscapeIndex >= 0 && currentSoundscapeIndex < soundscapeList.count {
                    guard let currentItem = getMediaItem(SongUrl: soundscapeList[currentSoundscapeIndex]) else {
                        return
                    }
                    if let artwork = currentItem.artworkImage {
                        albumArtImageView.image = artwork
                        addColorBorderToArtwork()
                    } else {
                        albumArtImageView.image = UIImage(named: "main_noalbumart")
                        clearColorBorderFromArtwork()
                    }
                    titleLabel.text = currentItem.title ?? "Unknown Title"
                    artistLabel.text = currentItem.artist ?? "Unknown Artist"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                        self.titleLabel.shutdownLabel()
                        self.artistLabel.shutdownLabel()
                    })
                }
            } else {
                if currentIndex >= 0 && currentIndex < playList.count {
                    guard let currentItem = getMediaItem(SongUrl: playList[currentIndex]) else {
                        return
                    }
                    if let artwork = currentItem.artwork {
                        albumArtImageView.image = artwork.image(at: albumArtImageView.bounds.size)
                        addColorBorderToArtwork()
                    } else {
                        albumArtImageView.image = UIImage(named: "main_noalbumart")
                        clearColorBorderFromArtwork()
                    }
                    titleLabel.text = currentItem.title ?? "Unknown Title"
                    artistLabel.text = currentItem.artist ?? "Unknown Artist"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                        self.titleLabel.shutdownLabel()
                        self.artistLabel.shutdownLabel()
                    })
                }
            }
        }
    }
    
    func prepareAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print(error)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        UIView.animate(withDuration: 0.5, animations: {
            self.view.alpha = CGFloat(1)
        }) { (_) in
            self.updateLastPlayedMusic()
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "sequeToPlaylist" {
            let playListVC = segue.destination as! PlaylistVC
            playListVC.mainVC = self
        } else if segue.identifier == "segueToSettings" {
            hidePullupMenu()
        } else if segue.identifier == "segueToSoundscape" {
            let soundscapeVC = segue.destination as! SoundscapeVC
            soundscapeVC.delegate = self
            soundscapeVC.mainVC = self
        }
    }
    
    // MARK: Pullup bottom menu
    @IBAction func pullUpButtonClicked(_ sender: Any) {
        showPullupMenu()
    }
    
    @IBAction func pullDownButtonClicked(_ sender: Any) {
        hidePullupMenu()
    }
    
    @IBAction func pullDownButtonClick_Top(_ sender: Any) {
        showPulldownMenu()
    }
    
    @IBAction func pullUpButtonClick_Top(_ sender: Any) {
        hidePulldownMenu()
    }
    
    @IBAction func settingsButtonClicked(_ sender: Any) {
        performSegue(withIdentifier: "segueToSettings", sender: self)
    }
    
    @IBAction func soundscapeButtonClicked(_ sender: Any) {
        performSegue(withIdentifier: "segueToSoundscape", sender: self)
    }
    
    func hidePullupMenu() {
        pullUpButton.isHidden = false
        if !isPad {
            pullUpMenuTopSpacing.constant = view.bounds.height
        } else {
            pullUpMenuTopSpacingPad.constant = view.bounds.height
        }
        
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
            self.view.layoutIfNeeded()
        }, completion: {(_) in
            self.pullDownButton.isHidden = true
        })
    }
    
    func showPullupMenu() {
        pullUpButton.isHidden = true
        pullDownButton.isHidden = false
        if !isPad {
            pullUpMenuTopSpacing.constant = view.bounds.height - pullUpMenuView.frame.height
        } else {
            pullUpMenuTopSpacingPad.constant = view.bounds.height - pullUpMenuView.frame.height
        }
        pullUpMenuTopSpacing.constant = view.bounds.height - pullUpMenuView.frame.height
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
            self.view.layoutIfNeeded()
            self.updatePullupMenu()
        }, completion: nil)
    }
    
    func hidePulldownMenu() {
        pullDownButton_Top.isHidden = false
        if !isPad {
            pullDownMenuBottomSpacing.constant = view.bounds.height
        } else {
            pullDownMenuBottomSpacingPad.constant = view.bounds.height
        }
        
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
            self.view.layoutIfNeeded()
        }) { (_) in
            self.pullUpButton_Top.isHidden = true
        }
    }
    
    func showPulldownMenu() {
        pullUpButton_Top.isHidden = false
        if !isPad {
            pullDownMenuBottomSpacing.constant = view.bounds.height - pullDownMenu.frame.height
        } else {
            pullDownMenuBottomSpacingPad.constant = view.bounds.height - pullDownMenu.frame.height
        }
        
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
            self.view.layoutIfNeeded()
        }) { (_) in
            self.pullDownButton_Top.isHidden = true
        }
    }
    
    @IBAction func offsetButtonClicked(_ sender: Any) {
        offsetActive = !offsetActive
        if offsetActive {
            circadianActive = false
        }
        updatePullupMenu()
        // restart the current music to adapt new settings
        if soundscapePlayMode == .Play {
            if soundscapeList.count > 0 && currentSoundscapeIndex >= 0 && currentSoundscapeIndex < soundscapeList.count {
                playFile()
                playButton.setImage(UIImage(named: "pause"), for: .normal)
                isPaused = false
                titleLabel.restartLabel()
                artistLabel.restartLabel()
                UIView.animate(withDuration: 0.5) {
                    self.albumArtImageView.transform = CGAffineTransform.init(scaleX: 1.0, y: 1.0)
                }
            }
        } else {
            if playList.count > 0 && currentIndex >= 0 && currentIndex < playList.count {
                playFile()
                playButton.setImage(UIImage(named: "pause"), for: .normal)
                isPaused = false
                titleLabel.restartLabel()
                artistLabel.restartLabel()
                UIView.animate(withDuration: 0.5) {
                    self.albumArtImageView.transform = CGAffineTransform.init(scaleX: 1.0, y: 1.0)
                }
            }
        }
        
    }
    
    @IBAction func circadianButtonClicked(_ sender: Any) {
        circadianActive = !circadianActive
        if circadianActive {
            offsetActive = false
        }
        updatePullupMenu()
        // restart the current music to adapt new settings
        if soundscapePlayMode == .Play {
            if soundscapeList.count > 0 && currentSoundscapeIndex >= 0 && currentSoundscapeIndex < soundscapeList.count {
                playFile()
                playButton.setImage(UIImage(named: "pause"), for: .normal)
                isPaused = false
                titleLabel.restartLabel()
                artistLabel.restartLabel()
                UIView.animate(withDuration: 0.5) {
                    self.albumArtImageView.transform = CGAffineTransform.init(scaleX: 1.0, y: 1.0)
                }
            }
        } else {
            if playList.count > 0 && currentIndex >= 0 && currentIndex < playList.count {
                playFile()
                playButton.setImage(UIImage(named: "pause"), for: .normal)
                isPaused = false
                titleLabel.restartLabel()
                artistLabel.restartLabel()
                UIView.animate(withDuration: 0.5) {
                    self.albumArtImageView.transform = CGAffineTransform.init(scaleX: 1.0, y: 1.0)
                }
            }
        }
        
    }
    
    func updatePullupMenu() {
        if offsetActive {
            offsetButton.setImage(UIImage(named: "offset_on"), for: .normal)
        } else {
            offsetButton.setImage(UIImage(named: "offset_off"), for: .normal)
        }
        if circadianActive {
            circadianButton.setImage(UIImage(named: "circadian_on"), for: .normal)
        } else {
            circadianButton.setImage(UIImage(named: "circadian_off"), for: .normal)
        }
        
        if circadianActive {
            if isPad {
                self.textField1Pad.text = wakeTimeArray[wakeUpTime]
                self.textField2Pad.text = sleepTimeArray[wakeUpTime]
                self.label1.text = "L-CH"
                self.label2.text = "R-CH"
                
                if self.channelNo == 0 {
                    self.textField1.text = "\(self.offsetTime)".addZeroes()
                    self.textField2.text = "00000"
                } else {
                    self.textField1.text = "00000"
                    self.textField2.text = "\(self.offsetTime)".addZeroes()
                }
            } else {
                self.label1.text = "WAKE"
                self.label2.text = "SLEEP"
                self.textField1.text = wakeTimeArray[wakeUpTime]
                self.textField2.text = sleepTimeArray[wakeUpTime]
            }
        } else {
            self.label1.text = "L-CH"
            self.label2.text = "R-CH"
            if self.channelNo == 0 {
                self.textField1.text = "\(self.offsetTime)".addZeroes()
                self.textField2.text = "00000"
            } else {
                self.textField1.text = "00000"
                self.textField2.text = "\(self.offsetTime)".addZeroes()
            }
        }
        
    }
    
    // MARK: - Play, Pause, Prev, Next
    @IBAction func playResume(_ sender: Any) {
        if soundscapePlayMode == .Play {
            if soundscapeList.count == 0 {return}
            if isPlaying {
                if isPaused {
                    
                    if !audioEngine.isRunning {
                        do {
                            try audioEngine.start()
                        } catch {
                            print(error)
                            return
                        }
                    }
                    
                    player?.play()
                    playButton.setImage(UIImage(named: "pause"), for: .normal)
                    isPaused = false
                    titleLabel.restartLabel()
                    artistLabel.restartLabel()
                    UIView.animate(withDuration: 0.5) {
                        self.albumArtImageView.transform = CGAffineTransform.init(scaleX: 1.0, y: 1.0)
                    }
                } else {
                    player?.pause()
                    playButton.setImage(UIImage(named: "play"), for: .normal)
                    isPaused = true
                    titleLabel.shutdownLabel()
                    artistLabel.shutdownLabel()
                    UIView.animate(withDuration: 0.5) {
                        self.albumArtImageView.transform = CGAffineTransform.init(scaleX: 0.7, y: 0.7)
                    }
                }
            } else {
                titleLabel.restartLabel()
                artistLabel.restartLabel()
                UIView.animate(withDuration: 0.5) {
                    self.albumArtImageView.transform = CGAffineTransform.init(scaleX: 1.0, y: 1.0)
                }
                playFile()
            }
        } else {
            if playList.count == 0 {return}
            if isPlaying {
                if isPaused {
                    
                    if !audioEngine.isRunning {
                        do {
                            try audioEngine.start()
                        } catch {
                            print(error)
                            return
                        }
                    }
                    
                    player?.play()
                    
                    if soundscapePlayMode == .Background {
                        backgroundPlayer?.play()
                    }
                    playButton.setImage(UIImage(named: "pause"), for: .normal)
                    isPaused = false
                    titleLabel.restartLabel()
                    artistLabel.restartLabel()
                    UIView.animate(withDuration: 0.5) {
                        self.albumArtImageView.transform = CGAffineTransform.init(scaleX: 1.0, y: 1.0)
                    }
                } else {
                    player?.pause()
                    backgroundPlayer?.pause()
                    playButton.setImage(UIImage(named: "play"), for: .normal)
                    isPaused = true
                    titleLabel.shutdownLabel()
                    artistLabel.shutdownLabel()
                    UIView.animate(withDuration: 0.5) {
                        self.albumArtImageView.transform = CGAffineTransform.init(scaleX: 0.7, y: 0.7)
                    }
                }
            } else {
                titleLabel.restartLabel()
                artistLabel.restartLabel()
                UIView.animate(withDuration: 0.5) {
                    self.albumArtImageView.transform = CGAffineTransform.init(scaleX: 1.0, y: 1.0)
                }
                playFile()
            }
        }
        
    }
    
    @IBAction func playPrev(_ sender: Any) {
        if soundscapePlayMode == .Play {
            if soundscapeList.count == 0 {
                stopMusic()
                return
            }
        } else {
            if playList.count == 0 {
                stopMusic()
                return
            }
        }
        
        // This is to prevent continuous short-interval click
        if isPlaying && !delayedPlayingStarted {return}
        delayedPlayingStarted = false
        
        titleLabel.restartLabel()
        artistLabel.restartLabel()
        setPrevMusicIndex()
        playFile()
    }
    
    @IBAction func playNext(_ sender: Any) {
        if soundscapePlayMode == .Play {
            if soundscapeList.count == 0 {
                stopMusic()
                return
            }
        } else {
            if playList.count == 0 {
                stopMusic()
                return
            }
        }
        
        // This is to prevent continuous short-interval click
        if isPlaying && !delayedPlayingStarted {return}
        delayedPlayingStarted = false
        
        titleLabel.restartLabel()
        artistLabel.restartLabel()
        setNextMusicIndex()
        playFile()
    }
    
    @IBAction func shuffleButtonClicked(_ sender: Any) {
        if shuffleMode == .On {
            shuffleMode = .Off
            shuffleButton.setImage(UIImage(named: "shuffle_off"), for: .normal)
        } else {
            shuffleMode = .On
            shuffleButton.setImage(UIImage(named: "shuffle_on"), for: .normal)
            // turn off repeat mode because it's meaningless
            repeatMode = .Off
            repeatButton.setImage(UIImage(named: "repeat_off"), for: .normal)
        }
    }
    
    @IBAction func repeatButtonClicked(_ sender: Any) {
        if repeatMode == .Off {
            repeatMode = .One
            repeatButton.setImage(UIImage(named: "repeat_one"), for: .normal)
            // repeating only one means no shuffle
            shuffleMode = .Off
            shuffleButton.setImage(UIImage(named: "shuffle_off"), for: .normal)
        } else if repeatMode == .One {
            repeatMode = .All
            repeatButton.setImage(UIImage(named: "repeat_all"), for: .normal)
            // let's turn off shuffle when repeating all,
            // we can get shuffle for all songs with just shuffle on.
            shuffleMode = .Off
            shuffleButton.setImage(UIImage(named: "shuffle_off"), for: .normal)
        } else {
            repeatMode = .Off
            repeatButton.setImage(UIImage(named: "repeat_off"), for: .normal)
        }
    }
    
    @IBAction func volumnChanged(_ sender: Any) {
        (mpVolumeView.subviews.filter{NSStringFromClass($0.classForCoder) == "MPVolumeSlider"}.first as? UISlider)?.setValue(volumeSlider.value, animated: false)
    }
    
    // get next song index
    func setNextMusicIndex() {
        if soundscapePlayMode == .Play {
            if soundscapeList.count == 0 {
                currentSoundscapeIndex = -1
            }
            if shuffleMode == .On {
                currentSoundscapeIndex = Int.random(in: 0 ... soundscapeList.count - 1)
            } else {
                if repeatMode == .One {
                    
                } else if repeatMode == .All {
                    currentSoundscapeIndex += 1
                    if currentSoundscapeIndex >= soundscapeList.count {
                        currentSoundscapeIndex = 0
                    }
                } else if repeatMode == .Off {
                    currentSoundscapeIndex += 1
                    if currentSoundscapeIndex >= soundscapeList.count {
                        currentSoundscapeIndex = soundscapeList.count
                    }
                }
            }
        } else {
            if playList.count == 0 {
                currentIndex = -1
            }
            if shuffleMode == .On {
                currentIndex = Int.random(in: 0 ... playList.count - 1)
            } else {
                if repeatMode == .One {
                    
                } else if repeatMode == .All {
                    currentIndex += 1
                    if currentIndex >= playList.count {
                        currentIndex = 0
                    }
                } else if repeatMode == .Off {
                    currentIndex += 1
                    if currentIndex >= playList.count {
                        currentIndex = playList.count
                    }
                }
            }
        }
    }
    
    // get next song index
    func setPrevMusicIndex() {
        if soundscapePlayMode == .Play {
            if soundscapeList.count == 0 {
                currentSoundscapeIndex = -1
            }
            
            if shuffleMode == .On {
                currentSoundscapeIndex = Int.random(in: 0 ... soundscapeList.count - 1)
            } else {
                if repeatMode == .One {
                    
                } else if repeatMode == .All {
                    currentSoundscapeIndex -= 1
                    if currentSoundscapeIndex < 0 {
                        currentSoundscapeIndex = soundscapeList.count - 1
                    }
                } else if repeatMode == .Off {
                    currentSoundscapeIndex -= 1
                    if currentSoundscapeIndex < 0 {
                        currentSoundscapeIndex = -1
                    }
                }
            }
        } else {
            if playList.count == 0 {
                currentIndex = -1
            }
            
            if shuffleMode == .On {
                currentIndex = Int.random(in: 0 ... playList.count - 1)
            } else {
                if repeatMode == .One {
                    
                } else if repeatMode == .All {
                    currentIndex -= 1
                    if currentIndex < 0 {
                        currentIndex = playList.count - 1
                    }
                } else if repeatMode == .Off {
                    currentIndex -= 1
                    if currentIndex < 0 {
                        currentIndex = -1
                    }
                }
            }
        }
    }
    
    // Play Selected File
    func playFile() {
        
        manualOverride = true
        
        if soundscapePlayMode == .Play {
            if currentSoundscapeIndex < 0 || currentSoundscapeIndex > soundscapeList.count - 1 {
                stopMusic()
                if currentSoundscapeIndex > soundscapeList.count - 1 {
                    currentSoundscapeIndex = soundscapeList.count - 1
                } else if currentSoundscapeIndex < 0 {
                    currentSoundscapeIndex = 0
                }
                return
            }
        } else {
            if currentIndex < 0 || currentIndex > playList.count - 1 {
                stopMusic()
                if currentIndex > playList.count - 1 {
                    currentIndex = playList.count - 1
                } else if currentIndex < 0 {
                    currentIndex = 0
                }
                return
            }
        }
        
        var currentItem: Any? = nil
        var currentFileUrl: URL? = nil
        
        if soundscapePlayMode == .Play {
            currentItem = getMediaItem(SongUrl: soundscapeList[currentSoundscapeIndex])
            if currentItem != nil {
                let currentSCItem = currentItem as! SoundscapeItem
                currentFileUrl = currentSCItem.assetUrl
                if currentFileUrl == nil {return}
            } else {
                return
            }
        } else {
            currentItem = getMediaItem(SongUrl: playList[currentIndex])! as MPMediaItem
            if currentItem != nil {
                let currentMPItem = currentItem as! MPMediaItem
                currentFileUrl = currentMPItem.assetURL
                if currentFileUrl == nil {return}
            } else {
                return
            }
        }
        
        stopRequested = true
        isPlaying = true
        
        self.player?.stop()
        self.player = AVAudioPlayerNode()
        
        // if ambient mode is active
        self.backgroundPlayer?.stop()
        self.backgroundPlayer = AVAudioPlayerNode()
        if soundscapePlayMode == .Background {
            self.backgroundPlayer?.volume = backgroundVolume
        } else {
            self.backgroundPlayer?.volume = 0
        }
        
        audioEngine = AVAudioEngine()
        do {
            audioFile = try AVAudioFile(forReading: currentFileUrl!)
            audioEngine.attach(player!)
            audioEngine.connect(player!, to: audioEngine.mainMixerNode, format: audioFile?.processingFormat)
            
            if soundscapePlayMode == .Background {
                backgroundAudioFile = try AVAudioFile(forReading: soundscapeList[currentSoundscapeIndex])
                audioEngine.attach(backgroundPlayer!)
                audioEngine.connect(backgroundPlayer!, to: audioEngine.mainMixerNode, format: backgroundAudioFile?.processingFormat)
            } else {
                audioEngine.detach(backgroundPlayer!)
            }
            
        } catch {
            print(error)
            return
        }
        
        do {
            try audioEngine.start()
        } catch {
            print(error)
            return
        }
        
        audioFormat = audioFile!.processingFormat
        audioFrameCount = UInt32(audioFile!.length)
        stopRequested = false
        
        
        //Read file content into fileBuffer
        fileBuffer = AVAudioPCMBuffer(pcmFormat: self.audioFormat!, frameCapacity: audioFrameCount)
        do {
            try self.audioFile!.read(into: fileBuffer!, frameCount: audioFrameCount)
        } catch {
            print(error)
        }
        
        //Read background File content into backgroundFileBuffer
        if soundscapePlayMode == .Background {
            backgroundFileBuffer = AVAudioPCMBuffer(pcmFormat: backgroundAudioFile!.processingFormat, frameCapacity: AVAudioFrameCount(backgroundAudioFile!.length))
            do {
                try self.backgroundAudioFile?.read(into: backgroundFileBuffer!, frameCount: AVAudioFrameCount(backgroundAudioFile!.length))
            } catch {
                print(error)
            }
        } else {
            backgroundFileBuffer = nil
        }
        
        //Process file
        DispatchQueue.global().async{
            //start processing fileBuffer
            let channelNum = Int(self.fileBuffer!.format.channelCount)
            if channelNum <= 1 {
                return
            }
            
            var isFlac = false
            let ext = currentFileUrl!.absoluteURL.pathExtension.lowercased()
            if ext == "flac" || ext == "alac" || ext == "m4a" {
                isFlac = true
            } else {
                isFlac = false
            }
            isHQ = isFlac
            
            self.offsetTime = generateOffset(wakeupTime: wakeUpTime, optimization: optimization, isHQ: isFlac, isOffsetActive: offsetActive, isCircadianActive: circadianActive)
            self.offset = Int(Double(self.offsetTime * Int(self.audioFormat!.sampleRate)) / 1.0e5)
            
            if affinity == .Random {
                self.channelNo = Int.random(in: 0 ... 1)
            } else if affinity == .Left {
                self.channelNo = 1 // giving offset to the right channel
            } else {
                self.channelNo = 0 // giving offset to the left channel
            }
            
            // Update offset bottom control
            DispatchQueue.main.async {
                if circadianActive {
                    if isPad {
                        self.textField1Pad.text = wakeTimeArray[wakeUpTime]
                        self.textField2Pad.text = sleepTimeArray[wakeUpTime]
                        self.label1.text = "L-CH"
                        self.label2.text = "R-CH"
                        
                        if self.channelNo == 0 {
                            self.textField1.text = "\(self.offsetTime)".addZeroes()
                            self.textField2.text = "00000"
                        } else {
                            self.textField1.text = "00000"
                            self.textField2.text = "\(self.offsetTime)".addZeroes()
                        }
                    } else {
                        self.label1.text = "WAKE"
                        self.label2.text = "SLEEP"
                        self.textField1.text = wakeTimeArray[wakeUpTime]
                        self.textField2.text = sleepTimeArray[wakeUpTime]
                    }
                } else {
                    self.label1.text = "L-CH"
                    self.label2.text = "R-CH"
                    if self.channelNo == 0 {
                        self.textField1.text = "\(self.offsetTime)".addZeroes()
                        self.textField2.text = "00000"
                    } else {
                        self.textField1.text = "00000"
                        self.textField2.text = "\(self.offsetTime)".addZeroes()
                    }
                    self.textField1Pad.text = "00:00"
                    self.textField2Pad.text = "00:00"
                }
            }
            
            self.offsetBuffer = []
            self.stopRequested = false
            let frameLength = Int(self.fileBuffer!.frameLength)
            if let data = self.fileBuffer!.floatChannelData?.pointee {
                let offsetChannelData = data.advanced(by: frameLength * self.channelNo)
                for frame in 0 ..< frameLength {
                    if self.stopRequested {return}
                    self.offsetBuffer.append(offsetChannelData[frame])
                    if frame < self.offset {
                        if self.offsetBuffer.count == frame + 1 {
                            offsetChannelData[frame] = 0
                        } else {
                            offsetChannelData[frame] = self.offsetBuffer[frame]
                        }
                    } else {
                        if self.offsetBuffer.count == frame + 1 {
                            offsetChannelData[frame] = self.offsetBuffer[frame - self.offset]
                        } else {
                            offsetChannelData[frame] = self.offsetBuffer[frame]
                        }
                        
                    }
                }
            }
        }
        
        let delayTime = AVAudioSession.sharedInstance().ioBufferDuration * 2
        //Play processed data
        DispatchQueue.main.asyncAfter(deadline: .now() + delayTime, execute: {
            
            self.delayedPlayingStarted = true
            
            self.manualOverride = false
            if soundscapePlayMode == .Background {
                self.backgroundPlayer?.scheduleBuffer(self.backgroundFileBuffer!, at: nil, options: .loops, completionHandler: nil)
            }
            
            self.player?.scheduleBuffer(self.fileBuffer!, at: nil, options: .interrupts, completionHandler: {
                
                if (!self.manualOverride) {
                    self.isPlaying = false
                    DispatchQueue.main.async {
                        self.stopMusic()
                        // playNextSong
                        self.setNextMusicIndex()
                        if soundscapePlayMode == .Play {
                            if currentSoundscapeIndex >= 0 && currentSoundscapeIndex <= soundscapeList.count - 1 {
                                self.playFile()
                            } else {
                                self.albumArtImageView.transform = CGAffineTransform.init(scaleX: 0.7, y: 0.7)
                                if currentSoundscapeIndex > soundscapeList.count - 1 {
                                    currentSoundscapeIndex = soundscapeList.count - 1
                                } else if currentSoundscapeIndex < 0 {
                                    currentSoundscapeIndex = 0
                                }
                            }
                        } else {
                            if currentIndex >= 0 && currentIndex <= playList.count - 1 {
                                self.playFile()
                            } else {
                                self.albumArtImageView.transform = CGAffineTransform.init(scaleX: 0.7, y: 0.7)
                                if currentIndex > playList.count - 1 {
                                    currentIndex = playList.count - 1
                                } else if currentIndex < 0 {
                                    currentIndex = 0
                                }
                            }
                        }
                    }
                }
            })
            self.player?.play()
            if soundscapePlayMode == .Background {self.backgroundPlayer?.play()}
            self.isPlaying = true
            self.isPaused = false
            self.playButton.setImage(UIImage(named: "pause"), for: .normal)
            UIView.animate(withDuration: 0.5) {
                self.albumArtImageView.transform = CGAffineTransform.init(scaleX: 1.0, y: 1.0)
            }
            if soundscapePlayMode == .Play {
                if let artwork = (currentItem as! SoundscapeItem).artworkImage {
                    self.albumArtImageView.image = artwork
                    self.addColorBorderToArtwork()
                } else {
                    self.albumArtImageView.image = UIImage(named: "main_noalbumart")
                    self.clearColorBorderFromArtwork()
                }
                self.titleLabel.text = (currentItem as! SoundscapeItem).title ?? "Unknown Title"
                self.artistLabel.text = (currentItem as! SoundscapeItem).artist ?? "Unknown Artist"
            } else {
                if let artwork = (currentItem as! MPMediaItem).artwork {
                    self.albumArtImageView.image = artwork.image(at: self.albumArtImageView.bounds.size)
                    self.addColorBorderToArtwork()
                } else {
                    self.albumArtImageView.image = UIImage(named: "main_noalbumart")
                    self.clearColorBorderFromArtwork()
                }
                self.titleLabel.text = (currentItem as! MPMediaItem).title ?? "Unknown Title"
                self.artistLabel.text = (currentItem as! MPMediaItem).artist ?? "Unknown Artist"
            }
        })
        
    }
    
    func stopMusic() {
        stopMainMusic()
        stopBackgroundMusic()
    }
    
    func stopMainMusic() {
        stopRequested = true
        isPlaying = false
        self.manualOverride = true
        self.player?.stop()
        DispatchQueue.main.async {
            self.playButton.setImage(UIImage(named: "play"), for: .normal)
        }
    }
    
    func stopBackgroundMusic() {
        self.backgroundPlayer?.stop()
    }
    
}

extension MainVC {
    
    @IBAction func unwindToMainVC(_ unwindSegue: UIStoryboardSegue) {
        //        let sourceViewController = unwindSegue.source
        // Use data from the view controller which initiated the unwind segue
    }
}

extension MainVC: BackgroundVolumeDelegate {
    
    func backgroundVolumeChanged(volume: Float) {
        if soundscapePlayMode == .Background {
            backgroundPlayer?.volume = volume
        } else {
            backgroundPlayer?.volume = 0
        }
    }
    
    func changeBackgroundMusic() {
        if soundscapePlayMode != .Background {return}
        stopBackgroundMusic()
        self.backgroundPlayer = AVAudioPlayerNode()
        self.backgroundPlayer?.volume = backgroundVolume
        
        do {
            backgroundAudioFile = try AVAudioFile(forReading: soundscapeList[currentSoundscapeIndex])
            audioEngine.attach(backgroundPlayer!)
            audioEngine.connect(backgroundPlayer!, to: audioEngine.mainMixerNode, format: backgroundAudioFile?.processingFormat)
        } catch {
            return
        }
        
        backgroundFileBuffer = AVAudioPCMBuffer(pcmFormat: backgroundAudioFile!.processingFormat, frameCapacity: AVAudioFrameCount(backgroundAudioFile!.length))
        do {
            try self.backgroundAudioFile?.read(into: backgroundFileBuffer!, frameCount: AVAudioFrameCount(backgroundAudioFile!.length))
        } catch {
            print(error)
        }
        
        self.backgroundPlayer?.scheduleBuffer(self.backgroundFileBuffer!, at: nil, options: .loops, completionHandler: nil)
        if isPlaying && !isPaused {
            self.backgroundPlayer?.play()
        }
    }
    
}
