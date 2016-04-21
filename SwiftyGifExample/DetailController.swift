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
    let gifManager = SwiftyGifManager(memoryLimit:100)

    override func viewDidLoad() {
        super.viewDidLoad()

        if let imgName = self.gifName {
            let gifImage = UIImage(gifName: imgName)
            self.imageView.setGifImage(gifImage, manager: gifManager, loopCount: -1)
        }

        let panGesture = UIPanGestureRecognizer.init(target: self, action: #selector(self.panGesture))
        self.imageView.addGestureRecognizer(panGesture)
        self.imageView.userInteractionEnabled = true

        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(self.tapGesture))
        self.imageView.addGestureRecognizer(tapGesture)
    }


    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
    }

    func panGesture(sender:UIPanGestureRecognizer){

        switch sender.state {
        case .Began:
            self.imageView.stopAnimatingGif()
            break

        case .Changed:
            if sender.velocityInView(sender.view).x > 0 {
                self.imageView.showFrameForIndexDelta(1)
            } else{
                self.imageView.showFrameForIndexDelta(-1)
            }
            break

        default:
            break
        }

    }

    func tapGesture(sender:UIPanGestureRecognizer){
        if self.imageView.isAnimatingGif {
            self.imageView.stopAnimatingGif()
        }else {
            self.imageView.startAnimatingGif()
        }
    }
}
