//
//  LaunchScreenManager.swift
//  Offset Modulator
//
//  Created by Ming Xing Liang on 2020/5/14.
//  Copyright © 2020 Myong Song Ryang. All rights reserved.
//
import UIKit

class LaunchScreenManager {

    // MARK: - Properties

    // Using a singleton instance and setting animationDurationBase on init makes this class easier to test
    static let instance = LaunchScreenManager(animationDurationBase: 2.0)

    var parentView: UIView?
    var view: UIView?
    var logoView: UIImageView?
    var titleView: UIImageView?
    var bgImageView: UIImageView?
    
    let animationDurationBase: Double


    // MARK: - Lifecycle

    init(animationDurationBase: Double) {
        self.animationDurationBase = animationDurationBase
    }


    // MARK: - Animation

    func animateAfterLaunch(_ parentViewPassedIn: UIView) {
        parentView = parentViewPassedIn
        view = loadView()

        fillParentViewWithView()
        animateView()
    }

    func loadView() -> UIView {
        return UINib(nibName: "LaunchScreen", bundle: nil).instantiate(withOwner: nil, options: nil)[0] as! UIView
    }

    func fillParentViewWithView() {
        parentView!.addSubview(view!)
        view!.frame = parentView!.bounds
        view!.center = parentView!.center
        logoView = view!.viewWithTag(1) as? UIImageView
        titleView = view!.viewWithTag(2) as? UIImageView
        bgImageView = view!.viewWithTag(3) as? UIImageView
        
        bgImageView!.frame = view!.bounds
        logoView!.alpha = CGFloat(0)
        titleView!.alpha = CGFloat(0)
        if !isPad {
            logoView!.frame = CGRect(x: view!.bounds.width / 4, y: view!.bounds
            .height * 0.75 - view!.bounds.width / 4, width: view!.bounds.width / 2, height: view!.bounds.width / 2)
            titleView!.frame = CGRect(x: view!.bounds.width / 3, y: view!.bounds.height * 0.25 + view!.bounds.width / 4, width: view!.bounds.width / 3, height: view!.bounds.width / 9 * 2)
        } else {
            logoView!.frame = CGRect(x: view!.bounds.width * 1 / 3, y: view!.bounds
            .height * 0.75 - view!.bounds.width / 4, width: view!.bounds.width / 3, height: view!.bounds.width / 3)
            titleView!.frame = CGRect(x: view!.bounds.width * 5 / 12, y: view!.bounds.height * 0.25 + logoView!.bounds.height / 2 + 20, width: view!.bounds.width / 6, height: view!.bounds.width / 9)
        }
        
    }
    
    func animateView() {
        UIView.animateKeyframes(withDuration: 3, delay: 0, options: [], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.3) {
                self.logoView!.alpha = CGFloat(1)
                self.logoView!.center.y = 0.25 * self.view!.bounds.height
            }
            UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.7) {
                self.titleView!.alpha = CGFloat(1)
            }
        }) { _ in
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.5, animations: {
                    self.view!.alpha = CGFloat(0)
                }) { _ in
                    self.view!.removeFromSuperview()
                }
            }
            
        }
    }
}
