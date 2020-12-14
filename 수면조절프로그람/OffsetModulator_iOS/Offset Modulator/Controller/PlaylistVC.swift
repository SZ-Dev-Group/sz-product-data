//
//  PlaylistVC.swift
//  Offset Modulator
//
//  Created by Ming Xing Liang on 2020/5/16.
//  Copyright © 2020 Myong Song Ryang. All rights reserved.
//

import UIKit
import MediaPlayer

class PlaylistVC: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    var mainVC: MainVC?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    @IBAction func addMusic(_ sender: Any) {
        let mediaPicker = MPMediaPickerController(mediaTypes: .anyAudio)
        mediaPicker.allowsPickingMultipleItems = true
        mediaPicker.delegate = self
        present(mediaPicker, animated: true, completion: nil)
    }
    
    @IBAction func editPlaylist(_ sender: Any) {
        tableView.isEditing = !tableView.isEditing
    }
    
    @IBAction func clearPlayList(_ sender: Any) {
        let deleteAlert = UIAlertController(title: "Clear Playlist", message: "Do you want to clear playlist?", preferredStyle: UIAlertController.Style.actionSheet)

        let deleteAction = UIAlertAction(title: "Clear", style: .destructive) { (action: UIAlertAction) in
            // Code to delete
            playList = []
            self.tableView.reloadData()
            currentIndex = -1
            self.mainVC?.stopMusic()
            self.mainVC?.clearColorBorderFromArtwork()
            self.mainVC?.albumArtImageView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            self.mainVC?.albumArtImageView.image = UIImage(named: "main_noalbumart")
            self.mainVC?.titleLabel.text = "Unknown Title"
            self.mainVC?.artistLabel.text = "Unknown Artist"
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        deleteAlert.addAction(deleteAction)
        deleteAlert.addAction(cancelAction)
        self.present(deleteAlert, animated: true, completion: nil)
        
    }
    
}

extension PlaylistVC: UITableViewDataSource, UITableViewDelegate, MPMediaPickerControllerDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return playList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if playList.count == 0 {
            return UITableViewCell()
        }
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "musicCell", for: indexPath) as? MusicTableViewCell else {
            return UITableViewCell()
        }
        guard let musicItem = getMediaItem(SongUrl: playList[indexPath.row]) else {return UITableViewCell()}
        if let artwork = musicItem.artwork {
            cell.albumArtwork.image = artwork.image(at: cell.albumArtwork.bounds.size)
        } else {
            cell.albumArtwork.image = UIImage(named: "playlist_noalbumart")
        }
        
        cell.artistLabel.text = musicItem.artist ?? "Unknown Artist"
        cell.titleLabel.text = musicItem.title ?? "Unknown Title"
        cell.artistLabel.leadingBuffer = 20
        cell.artistLabel.trailingBuffer = 20
        cell.titleLabel.leadingBuffer = 20
        cell.titleLabel.trailingBuffer = 20
        cell.titleLabel.speed = .rate(30)
        cell.artistLabel.speed = .rate(20)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if tableView.isEditing {
            return .none
        } else {
            return .delete
        }
    }
    
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    // reorder the list
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let itemToMove = playList[sourceIndexPath.row]
        playList.remove(at: sourceIndexPath.row)
        playList.insert(itemToMove, at: destinationIndexPath.row)
        if currentIndex == sourceIndexPath.row {
            currentIndex = destinationIndexPath.row
        } else if sourceIndexPath.row < currentIndex && destinationIndexPath.row >= currentIndex {
            currentIndex -= 1
        } else if sourceIndexPath.row > currentIndex && destinationIndexPath.row <= currentIndex {
            currentIndex += 1
        }
    }
    
    // delete item
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            
            DispatchQueue.main.async {
                playList.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
                
                // if current playing music is deleted, skip to the next music
                if currentIndex == indexPath.row {
                    currentIndex = indexPath.row - 1
                    if playList.count == 0 {
                        self.mainVC?.stopMusic()
                    } else {
                        self.mainVC?.titleLabel.restartLabel()
                        self.mainVC?.artistLabel.restartLabel()
                        self.mainVC?.setNextMusicIndex()
                        self.mainVC?.playFile()
                    }
                } else if currentIndex > indexPath.row {
                    currentIndex -= 1
                }
            }
            
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        currentIndex = indexPath.row
        if soundscapePlayMode == .Play {
            soundscapePlayMode = .Off
        }
        DispatchQueue.main.async {
            if self.mainVC!.isPlaying && !self.mainVC!.delayedPlayingStarted {return}
            self.mainVC!.delayedPlayingStarted = false
            UIView.animate(withDuration: 0.5) {
                self.mainVC?.albumArtImageView.transform = CGAffineTransform.init(scaleX: 1.0, y: 1.0)
            }
            self.mainVC?.playFile()
        }
    }
    
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        for item in mediaItemCollection.items {
            if let urlString = item.assetURL?.absoluteString, let ext = item.assetURL?.absoluteURL.pathExtension.lowercased() {
                if playList.contains(urlString) || ext == "m4p" {continue}
                playList.append(urlString)
            }
        }
        
        dismiss(animated: true, completion: nil)
        tableView.isEditing = false
        tableView.reloadData()
        
        // Update current play item as the first item on the playlist
        if currentIndex == -1 {
            currentIndex = 0
            guard let currentItem = getMediaItem(SongUrl: playList[0]) else {
                return
            }
            if let artwork = currentItem.artwork {
                self.mainVC?.albumArtImageView.image = artwork.image(at: (self.mainVC?.albumArtImageView.bounds.size)!)
                self.mainVC?.addColorBorderToArtwork()
            } else {
                self.mainVC?.albumArtImageView.image = UIImage(named: "main_noalbumart")
                self.mainVC?.clearColorBorderFromArtwork()
            }
            self.mainVC?.titleLabel.text = currentItem.title ?? "Unknown Title"
            self.mainVC?.artistLabel.text = currentItem.artist ?? "Unknown Artist"
        }
        
    }
    
}
