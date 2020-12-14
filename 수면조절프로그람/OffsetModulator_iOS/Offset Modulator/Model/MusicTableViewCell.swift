//
//  MusicTableViewCell.swift
//  Offset Modulator
//
//  Created by Ming Xing Liang on 2020/5/16.
//  Copyright © 2020 Myong Song Ryang. All rights reserved.
//

import UIKit
import MarqueeLabel


class MusicTableViewCell: UITableViewCell {
        
    @IBOutlet weak var albumArtwork: UIImageView!
    @IBOutlet weak var artistLabel: MarqueeLabel!
    @IBOutlet weak var titleLabel: MarqueeLabel!
        
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        albumArtwork.layer.cornerRadius = 5
    }
    
}
