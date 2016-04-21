//
//  DetailController.swift
//  SwiftyGif
//
//  Created by Alexis Creuzot on 04/04/16.
//  Copyright © 2016 alexiscreuzot. All rights reserved.
//

import UIKit

class DetailController: UIViewController {

    @IBOutlet private weak var imageView: UIImageView!

    var gifName: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        if let imgName = self.gifName {
            let gifImage = UIImage(gifName: imgName)
            self.imageView.setGifImage(gifImage, manager: SwiftyGifManager.defaultManager, loopCount: -1)
        }

        let panGesture = UIPanGestureRecognizer.init(target: self, action: #selector(self.panGesture))
        self.imageView.addGestureRecognizer(panGesture)
        self.imageView.userInteractionEnabled = true

        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(self.tapGesture))
        self.imageView.addGestureRecognizer(tapGesture)
    }

    var lastX: CGFloat = 0

    func panGesture(sender:UIPanGestureRecognizer){

        let x = sender.translationInView(sender.view).x

        let time = CACurrentMediaTime()
        switch sender.state {
        case .Began:
            self.imageView.startAnimatingGif()
            break

        case .Changed:
            if lastX - x < 0 {
                self.imageView.showFrameForIndexDelta(1)
            } else{
                self.imageView.showFrameForIndexDelta(-1)
            }
            break

        default :
            self.imageView.startAnimatingGif()
        }
        print(CACurrentMediaTime() - time)
        lastX = x
    }

    func tapGesture(sender:UIPanGestureRecognizer){
        if self.imageView.isAnimatingGif {
            self.imageView.stopAnimatingGif()
        }else {
            self.imageView.startAnimatingGif()
        }
    }
}
