//
//  Common.swift
//  Offset Modulator
//
//  Created by Ming Xing Liang on 2020/5/15.
//  Copyright © 2020 Myong Song Ryang. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer

enum Affinity {
    case Random
    case Left
    case Right
}

enum Optimization {
    case Complete
    case Relaxation
    case Focus
}

enum SoundscapePlayMode {
    case Off
    case Play
    case Background
}

enum SoundscapeType {
    case Ambient
    case Binaural
    case Biomusical
    case Elemental
}

var currentIndex = 0
var currentSoundscapeIndex = 0
var soundscapePlayMode: SoundscapePlayMode = .Off
var soundscapeType: SoundscapeType = .Ambient
var backgroundVolume: Float = 0.5
var playList: [String] = [String]()
var affinity = Affinity.Random
var wakeUpTime = 0 //0 -> 5 am, 1 -> 5.30 am, 2 -> 6 am etc
var optimization = Optimization.Complete
var offsetActive: Bool = false
var circadianActive: Bool = false

let wakeTimeArray = ["05:00", "05:30", "06:00", "06:30", "07:00", "07:30", "08:00", "08:30", "09:00"]
let sleepTimeArray = ["20:00", "20:30", "21:00", "21:30", "22:00", "22:30", "23:00", "23:30", "24:00"]

let smallFont: [AnyHashable : Any] = [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 17)]
let bigFont: [AnyHashable : Any] = [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 25)]
var isHQ = false

var segmentControlFont: [AnyHashable: Any] {
    if UIDevice.current.userInterfaceIdiom == .pad {
        return bigFont
    } else {
        return smallFont
    }
}

var isPad : Bool {
    if UIDevice.current.userInterfaceIdiom == .pad {
        return true
    } else {
        return false
    }
}

func saveSettings() {
    print("Saving settings ...")
    var affinityIndex = 0
    if affinity == .Random {
        affinityIndex = 0
    } else if affinity == .Left {
        affinityIndex = 1
    } else {
        affinityIndex = 2
    }
    var optIndex = 0
    if optimization == .Complete {
        optIndex = 0
    } else if optimization == .Relaxation {
        optIndex = 1
    } else {
        optIndex = 2
    }
    
    var soundscapePlayModeIndex = 0
    if soundscapePlayMode == .Off {
        soundscapePlayModeIndex = 0
    } else if soundscapePlayMode == .Play {
        soundscapePlayModeIndex = 1
    } else if soundscapePlayMode == .Background {
        soundscapePlayModeIndex = 2
    }
    
    var soundscapeTypeIndex = 0
    if soundscapeType == .Ambient {
        soundscapeTypeIndex = 0
    } else if soundscapeType == .Binaural {
        soundscapeTypeIndex = 1
    } else if soundscapeType == .Biomusical {
        soundscapeTypeIndex = 2
    } else if soundscapeType == .Elemental {
        soundscapeTypeIndex = 3
    }
    
    Prefs.value(forKey: "affinity", value: affinityIndex)
    Prefs.value(forKey: "wakeUpTime", value: wakeUpTime)
    Prefs.value(forKey: "optimization", value: optIndex)
    Prefs.value(forKey: "playlist", value: playList)
    Prefs.value(forKey: "currentIndex", value: currentIndex)
    Prefs.value(forKey: "offsetActive", value: offsetActive)
    Prefs.value(forKey: "circadianActive", value: circadianActive)
    
    Prefs.value(forKey: "soundscapePlayMode", value: soundscapePlayModeIndex)
    Prefs.value(forKey: "soundscapeType", value: soundscapeTypeIndex)
    Prefs.value(forKey: "currentSoundscapeIndex", value: currentSoundscapeIndex)
    Prefs.value(forKey: "backgroundVolume", value: backgroundVolume)
}

func readSettings() {
    print("Reading settings ...")
    let affinityIndex = Prefs.value(forKey: "affinity", defaultValue: 0)
    wakeUpTime = Prefs.value(forKey: "wakeUpTime", defaultValue: 5)
    let optIndex = Prefs.value(forKey: "optimization", defaultValue: 0)
    let tempList: [String] = Prefs.value(forKey: "playlist", defaultValue: [])
    currentIndex = Prefs.value(forKey: "currentIndex", defaultValue: -1)
    offsetActive = Prefs.value(forKey: "offsetActive", defaultValue: false)
    circadianActive = Prefs.value(forKey: "circadianActive", defaultValue: false)
    if affinityIndex == 0 {
        affinity = .Random
    } else if affinityIndex == 1 {
        affinity = .Left
    } else {
        affinity = .Right
    }
    if optIndex == 0{
        optimization = .Complete
    } else if (optIndex == 1) {
        optimization = .Relaxation
    } else {
        optimization = .Focus
    }
    playList = []
    // filter playList
    for item in tempList {
        if getMediaItem(SongUrl: item) != nil {
            playList.append(item)
        }
    }
    let soundscapeModeIndex = Prefs.value(forKey: "soundscapePlayMode", defaultValue: 0)
    if soundscapeModeIndex == 0 {
        soundscapePlayMode = .Off
    } else if soundscapeModeIndex == 1 {
        soundscapePlayMode = .Play
    } else if soundscapeModeIndex == 2 {
        soundscapePlayMode = .Background
    }
    let soundscapeTypeIndex = Prefs.value(forKey: "soundscapeType", defaultValue: 0)
    if soundscapeTypeIndex == 0 {
        soundscapeType = .Ambient
        soundscapeList = ambientList
    } else if soundscapeTypeIndex == 1 {
        soundscapeType = .Binaural
        soundscapeList = binauralList
    } else if soundscapeTypeIndex == 2 {
        soundscapeType = .Biomusical
        soundscapeList = biomusicalList
    } else if soundscapeTypeIndex == 3 {
        soundscapeList = elementalList
        soundscapeType = .Elemental
    }
    currentSoundscapeIndex = Prefs.value(forKey: "currentSoundscapeIndex", defaultValue: 0)
    backgroundVolume = Prefs.value(forKey: "backgroundVolume", defaultValue: 0.5)
}

func getMediaItem(SongUrl: String) -> MPMediaItem? {
    
    var index = 0
    if let range: Range<String.Index> = SongUrl.range(of: "id=") {
        index = SongUrl.distance(from: SongUrl.startIndex, to: range.lowerBound)
    }
    let number = SongUrl.suffix(SongUrl.count - index - 3)
    
    let query = MPMediaQuery.songs();
    let urlQuery = MPMediaPropertyPredicate(value:number,forProperty: MPMediaItemPropertyPersistentID,comparisonType: .contains);
    query.addFilterPredicate(urlQuery);
    let mediaItem = query.items! as [MPMediaItem]
    return mediaItem.first
}

// sin values for circadian algorithm
let sinValues = [
    0.196393398,
    0.290152063, //
    0.383910728,
    0.470292656, //
    0.556674583,
    0.632360165, //
    0.708045747,
    0.770126428, //
    0.832207109,
    0.878297164, //
    0.924387219,
    0.767101152, //
    0.609815084,
    0.685541676, //
    0.761268268,
    0.827798305, //
    0.894328342,
    0.932896186, //
    0.971464030,
    0.939620887, //
    0.907777744,
    0.859015294, //
    0.810252844,
    0.746388772, //
    0.682524699,
    0.605939622, //
    0.529354545,
    0.442903273, //
    0.356452000,
    0.263357119, //
    0.170262237,
    0.085631119, //
    0.001000000,
    0.001000000, //
    0.001000000,
    0.001000000, //
    0.001000000,
    0.001000000, //
    0.001000000,
    0.001000000, //
    0.001000000,
    0.001000000, //
    0.001000000,
    0.001000000, //
    0.001000000,
    0.001000000, //
    0.001000000,
    0.001000000, //
]

func getDeviation(wakeupTime: Int, hq: Bool) -> Int {
    let now = Date()
    //Shifting sinConst so that  the first real element will be for the wakeupTime
    let refValues = getShiftedSinConst(wakeupTime: wakeupTime)
    var deviation = getSinValue(refValue: refValues, date: now)
    if hq {
        deviation = floor(deviation * 120 + 1)
    } else {
        deviation = floor(deviation * 60 + 1)
    }
    return Int(deviation)
}

func getSinValue(refValue: [Double], date: Date) -> Double {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: date)
    let fraction = Double(calendar.component(.minute, from: date)) / 60.0
    let lowerBound = refValue[hour]
    var upperBound = 0.0
    if hour == 23 {
        upperBound = refValue[0]
    } else {
        upperBound = refValue[hour + 1]
    }
    
    return lowerBound + (upperBound - lowerBound) * fraction
}

func getShiftedSinConst(wakeupTime: Int) -> [Double] {
    // wakeupTime = 0 -> 5 am, 1 -> 5.30 am, etc.
    var refValues = [Double]()
    // if wakeUpTime is even number, get even number index values
    // otherwise, get odd number index values
    for i in 0 ..< sinValues.count {
        if wakeupTime % 2 == 0 {// wakeupTime is like 5, 6, 7 am etc.
            if i % 2 == 0 {
                refValues.append(sinValues[i])
            }
        } else { // wakeupTime is like 5.30, 6.30, 7.30 am
            if i % 2 == 1 {
                refValues.append(sinValues[i])
            }
        }
    }
    let wakeupTimeIndex = (wakeupTime + 10) / 2 // 5 am -> index 10, 5.30 am -> index 11
    for _ in 0 ..< wakeupTimeIndex {
        refValues.insert(refValues.last!, at: 0)
        refValues.remove(at: refValues.count - 1)
    }
    if wakeUpTime % 2 == 0 {
        refValues.append(refValues[0])
    } else {
        refValues.append(refValues[1])
    }
    
    return refValues
}

func generateOffset(wakeupTime: Int, optimization: Optimization, isHQ: Bool, isOffsetActive: Bool, isCircadianActive: Bool) -> Int {
    var offset = 0
    if !isOffsetActive {
        return offset
    }
    if isCircadianActive {
        offset = getDeviation(wakeupTime: wakeupTime, hq: isHQ)
    } else {
        if optimization == .Complete {
            if isHQ {
                offset = Int.random(in: 1 ... 120)
            } else {
                offset = Int.random(in: 1 ... 60)
            }
        } else if optimization == .Focus {
            if isHQ {
                offset = Int.random(in: 81 ... 120)
            } else {
                offset = Int.random(in: 41 ... 60)
            }
        } else {
            if isHQ {
                offset = Int.random(in: 1 ... 40)
            } else {
                offset = Int.random(in: 1 ... 20)
            }
        }
    }
    return offset
}

var soundscapeList: [URL] = []

var ambientList: [URL] {
    var temp: [URL] = []
    for i in 11 ... 15 {
        if let url = Bundle.main.url(forResource: "soundscape\(i)", withExtension: "mp3") {
            temp.append(url)
        }
    }
    return temp
}

var binauralList: [URL] {
    var temp: [URL] = []
    for i in 16 ... 20 {
        if let url = Bundle.main.url(forResource: "soundscape\(i)", withExtension: "mp3") {
            temp.append(url)
        }
    }
    return temp
}

var biomusicalList: [URL] {
    var temp: [URL] = []
    for i in 1 ... 4 {
        if let url = Bundle.main.url(forResource: "soundscape\(i)", withExtension: "mp3") {
            temp.append(url)
        }
    }
    return temp
}

var elementalList: [URL] {
    var temp: [URL] = []
    for i in 5 ... 10 {
        if let url = Bundle.main.url(forResource: "soundscape\(i)", withExtension: "mp3") {
            temp.append(url)
        }
    }
    return temp
}

func getMediaItem(SongUrl: URL) -> SoundscapeItem? {
    let item = SoundscapeItem()
    item.assetUrl = SongUrl
    item.title = getSounscapeTitle(fileUrl: SongUrl)
    item.artist = getSoundscapeArtist(fileUrl: SongUrl)
    item.artworkImage = getSoundscapeAlbumart(fileUrl: SongUrl)
    return item
}

func getSounscapeTitle(fileUrl: URL) -> String {
    let asset = AVAsset(url: fileUrl) as AVAsset
    //using the asset property to get the metadata of file
    for metaDataItems in asset.commonMetadata {
        //getting the title of the song
        if metaDataItems.commonKey?.rawValue == "title" {
            let titleData = metaDataItems.value as! String
            return titleData
        }
    }
    return "Unknown Title"
}

func getSoundscapeArtist(fileUrl: URL) -> String {
    let asset = AVAsset(url: fileUrl) as AVAsset
    //using the asset property to get the metadata of file
    for metaDataItems in asset.commonMetadata {
        //getting
        if metaDataItems.commonKey?.rawValue == "artist" {
            let artistData = metaDataItems.value as! String
            return artistData
        }
    }
    return "Unknown Artist"
}

func getSoundscapeAlbumart(fileUrl: URL) -> UIImage? {
    let asset = AVAsset(url: fileUrl) as AVAsset
    // using the asset property to get the metadata of file
    for metaDataItems in asset.commonMetadata {
        if metaDataItems.commonKey?.rawValue == "artwork" {
            let imageData = metaDataItems.value as! Data
            return UIImage(data: imageData)
        }
    }
    return nil
}

func showAlert(for parent: UIViewController, title: String, message: String) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
    parent.present(alert, animated: true)
}

extension String {
    func addZeroes(length: Int = 5) -> String {
        let padCount = length - self.count
        var result = self
        for _ in 0 ..< padCount {
            result = "0" + result
        }
        return result
    }
}

let affinityHelpMessage = "A Left or Right preference. Most people find one more comfortable than the other."
let offsetHelpMessage = "A lower, higher, or full offset range to produce more relaxation or more focus."
let circadianHelpMessage = "Reinforce a sleep schedule by synchronizing offset values to a 24-hour circadian (sleep) algorithm."
let soundModeHelpMessage = "Soundscape options to play single or multiple tracks, as well as over other music."
let faqUrl = "https://offsetmodulator.wordpress.com/faq/"
let privacyUrl = "https://offsetmodulator.wordpress.com/privacy-policy/"
