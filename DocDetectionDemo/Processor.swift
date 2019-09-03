//
//  Processor.swift
//  DocDetectionDemo
//
//  Created by Ruben Nine on 02/09/2019.
//  Copyright © 2019 Filestack. All rights reserved.
//

import FilestackSDK
import Photos.PHAsset

final class Processor {
    private let fsClient: FilestackSDK.Client
    private let storageOptions = StorageOptions(location: .s3, access: .private)
    private let serialQueue = DispatchQueue(label: "com.filestack.DocDetectionDemo.serial-queue")
    private let dispatchGroup = DispatchGroup()
    private let temporaryDirectoryURL = FileManager.default.temporaryDirectory

    // MARK: - Lifecycle

    init(fsClient: FilestackSDK.Client) {
        self.fsClient = fsClient
    }

    // MARK: - Public Functions

    func process(image: UIImage, maxSize: CGSize, completion: @escaping (_ outputURL: URL?) -> Void) {
        serialQueue.async {
            // Save image into temporary URL location.
            guard let url = self.saveImageInCachesDirectory(image: image) else {
                completion(nil)
                return
            }

            // Upload file and obtain Filestack handle.
            guard let fileLink = self.upload(url: url) else {
                completion(nil)
                return
            }

            // Remove temporary URLs.
            self.deleteURLs(urls: [url])

            // Setup transform with array of Filestack handles.
            let transformable = self.fsClient.transformable(handle: fileLink.handle)

            // Add resize transformation.
            transformable.add(transform: ResizeTransform().width(Int(maxSize.width)).height(Int(maxSize.height)))

            // Add document detection transformation.
            transformable.add(transform: DocumentDetectionTransform().coords(false).preprocess(false))

            // Download transformed document and call completion block.
            let task = URLSession.shared.downloadTask(with: transformable.url) { (url, response, error) in
                fileLink.delete(completionHandler: { _ in })

                let outputURL: URL = self.temporaryDirectoryURL
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("jpg")

                if let url = url, (try? FileManager.default.copyItem(at: url, to: outputURL)) != nil {
                    DispatchQueue.main.async {
                        completion(outputURL)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }

            task.resume()
        }
    }

    // MARK: - Private Functions

    // Upload URLs to Filestack and return file links.
    private func upload(url: URL) -> FileLink? {
        var fileLink: FileLink? = nil

        dispatchGroup.enter()

        fsClient.multiPartUpload(from: url, storeOptions: storageOptions) { (response) in
            defer { self.dispatchGroup.leave() }

            if let handle = response.json?["handle"] as? String {
                fileLink = self.fsClient.fileLink(for: handle)
            }
        }

        dispatchGroup.wait()

        return fileLink
    }

    private func saveImageInCachesDirectory(image: UIImage) -> URL? {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else { return nil }

        let imageURL = temporaryDirectoryURL
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")

        if (try? imageData.write(to: imageURL)) != nil {
            return imageURL
        } else {
            return nil
        }
    }

    // Delete temporary URLs.
    private func deleteURLs(urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
