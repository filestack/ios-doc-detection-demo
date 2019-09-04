//
//  ViewController.swift
//  DocDetectionDemo
//
//  Created by Ruben Nine on 28/08/2019.
//  Copyright © 2019 Filestack. All rights reserved.
//

import FilestackSDK
import Photos
import SVProgressHUD
import UIKit

private struct Images {
    // Placeholder image URL
    static let placeholderImageURL = Bundle.main.url(forResource: "placeholder", withExtension: "png")!
}

private let processSize = CGSize(width: 2000, height: 2000)

class ViewController: UIViewController {
    private let imageView: UIImageView = {
        // Setup transformed image view
        let imageView = UIImageView(image: UIImage(contentsOfFile: Images.placeholderImageURL.path))

        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        return imageView
    }()

    // MARK: - View Overrides

    override func viewDidLoad() {
        // Add stack view to view hierarchy
        view.addSubview(imageView)
        updateNavBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        // Setup stack view constraints
        let views = ["imageView" : imageView]
        let margin: CGFloat = 22

        let h = NSLayoutConstraint.constraints(withVisualFormat: "H:|-left-[imageView]-right-|",
                                               metrics: ["left": view.safeAreaInsets.left + margin,
                                                         "right": view.safeAreaInsets.right + margin],
                                               views: views)

        let w = NSLayoutConstraint.constraints(withVisualFormat: "V:|-top-[imageView]-bottom-|",
                                               metrics: ["top": view.safeAreaInsets.top + margin,
                                                         "bottom": view.safeAreaInsets.bottom + margin],
                                               views: views)

        // Remove existing view constraints
        view.removeConstraints(view.constraints)
        // Add new view constraints
        view.addConstraints(h)
        view.addConstraints(w)

        super.viewDidAppear(animated)
    }

    // MARK: - Actions

    @IBAction func pickAndTransformImage(_ sender: AnyObject) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary

        present(picker, animated: true, completion: nil)
    }

    // MARK: - Private Functions

    private func updateNavBar() {
        let button = UIBarButtonItem(title: "Select image", style: .done, target: self, action: #selector(pickAndTransformImage))
        navigationItem.leftBarButtonItem = button
    }
}

extension ViewController: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: false)

        guard let fsClient = fsClient, let originalImage = info[.originalImage] as? UIImage else {
            SVProgressHUD.showError(withStatus: "Unable to pick image.")
            return
        }

        SVProgressHUD.show(withStatus: "Processing")
        let processor = Processor(fsClient: fsClient)

        processor.process(image: originalImage, maxSize: processSize) { (outputURL) in
            SVProgressHUD.dismiss()

            guard let outputURL = outputURL else {
                SVProgressHUD.showError(withStatus: "Unable to complete process.")
                return
            }

            // Update image view's image with our processed document image.
            if let imageData = try? Data(contentsOf: outputURL), let image = UIImage(data: imageData) {
                self.imageView.image = image
            }

            // Try to save transformed document in photos library, and upon completion, delete temporary file at `outputURL`.
            PHPhotoLibrary.requestAuthorization { (status) in
                switch status {
                case .authorized:
                    PHPhotoLibrary.shared().performChanges({
                        let request = PHAssetCreationRequest.forAsset()
                        request.addResource(with: .photo, fileURL: outputURL, options: nil)
                    }) { (success, error) in
                        // Delete file at temporary location.
                        try? FileManager.default.removeItem(at: outputURL)

                        DispatchQueue.main.async {
                            if let error = error {
                                SVProgressHUD.showError(withStatus: error.localizedDescription)
                            } else {
                                SVProgressHUD.showSuccess(withStatus: "Document added to photos album.")
                            }
                        }
                    }
                default:
                    break
                }
            }
        }
    }
}
