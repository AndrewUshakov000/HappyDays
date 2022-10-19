//
//  MemoriesViewController.swift
//  HappyDays
//
//  Created by Andrew Ushakov on 7/12/22.
//

// swiftlint:disable force_cast

import Photos
import Speech
import CoreSpotlight
import MobileCoreServices
import UIKit

class MemoriesViewController: UICollectionViewController, UINavigationControllerDelegate {

    var memories = [URL]()
    var filteredMemories = [URL]()
    var activeMemory: URL!
    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?
    var recordingURL: URL!
    var searchQuery: CSSearchQuery?

    let searchController = UISearchController()

    override func viewDidLoad() {
        super.viewDidLoad()
        loadMemories()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addTapped)
        )

        searchController.searchResultsUpdater = self
        searchController.searchBar.tintColor = .white
        searchController.searchBar.searchBarStyle = .prominent
        navigationItem.searchController = searchController

        recordingURL = getDocumentsDirectory().appendingPathComponent("recording.m4a")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkPermissions()
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredMemories.count
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Memory", for: indexPath) as! MemoryCell

        let memory = filteredMemories[indexPath.row]
        let imageName = thumbnailURL(for: memory).path()
        let image = UIImage(contentsOfFile: imageName)
        cell.imageView.image = image

        if cell.gestureRecognizers == nil {
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(memoryLongPress))
            recognizer.minimumPressDuration = 0.25

            cell.addGestureRecognizer(recognizer)
            cell.layer.borderColor = UIColor.white.cgColor
            cell.layer.borderWidth = 3
            cell.layer.cornerRadius = 10
        }

        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let memory = filteredMemories[indexPath.row]
        let fileManager = FileManager.default

        do {
            let audioName = audioURL(for: memory)
            let transcriptionName = transcriptionURL(for: memory)

            if fileManager.fileExists(atPath: audioName.path()) {
                audioPlayer = try AVAudioPlayer(contentsOf: audioName)
                audioPlayer?.play()
            }

            if fileManager.fileExists(atPath: transcriptionName.path()) {
                let contents = try String(contentsOf: transcriptionName)
                print(contents)
            }
        } catch {
            print("Error loading audio.")
        }
    }

    func checkPermissions() {
        // check status for all three permissions
        let photoAuthorized = PHPhotoLibrary.authorizationStatus() == .authorized
        let recordingAuthorized = AVAudioSession.sharedInstance().recordPermission == .granted
        let transcibeAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized

        // make a single boolean out of all three
        let authorized = photoAuthorized && recordingAuthorized && transcibeAuthorized

        // if we're missing one, show the first run screen

        if authorized == false {
            if let viewController = storyboard?.instantiateViewController(withIdentifier: "FirstRun") {
                navigationController?.present(viewController, animated: true)
            }
        }
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }

    func loadMemories() {
        memories.removeAll()

        // attempt to add all memories in our document directory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: getDocumentsDirectory(),
            includingPropertiesForKeys: nil,
            options: []
        ) else { return }

        for file in files {
            let filename = file.lastPathComponent

            // check it ends with ".thumb" so we don't count each memory more than once
            if filename.hasSuffix(".thumb") {
                let noExtention = filename.replacingOccurrences(of: ".thumb", with: "")

                // create a full path from the memory
                let memoryPath = getDocumentsDirectory().appendingPathComponent(noExtention)

                // add it to our array
                memories.append(memoryPath)
            }
        }
        // reload our list of memories
        collectionView.reloadSections(IndexSet(integer: 1))
        filteredMemories = memories
    }

    @objc func addTapped() {
        let viewController = UIImagePickerController()
        viewController.modalPresentationStyle = .formSheet
        viewController.delegate = self
        navigationController?.present(viewController, animated: true)
    }

    func saveNewMemory(image: UIImage) {
        // create a unique name for this memory
        let memoryName = "memory-\(Date().timeIntervalSince1970)"

        // use the unique name to create filenames for the full-size image and the thumbnail
        let imageName = memoryName + ".jpg"
        let thumbnailName = memoryName + ".thumb"

        do {
            // create a URL where we can write the JPEG to
            let imagePath = getDocumentsDirectory().appendingPathComponent(imageName)

            // convert UIImage to JPEG data object
            if let jpegImage = image.jpegData(compressionQuality: 0.8) {

                // write that data to the URL we created
                try jpegImage.write(to: imagePath, options: [.atomicWrite])
            }

            if let thumbnail = resize(image: image, to: 200) {
                let imagePath = getDocumentsDirectory().appendingPathComponent(thumbnailName)

                if let jpegImage = thumbnail.jpegData(compressionQuality: 0.8) {
                    try jpegImage.write(to: imagePath, options: [.atomic])
                }
            }
        } catch {
            print("Failed to save to disk.")
        }
    }

    func resize(image: UIImage, to width: CGFloat) -> UIImage? {
        // calculate how much we need to bring the width down to match our target size
        let scale = width / image.size.width

        // bring the height down by the same amount so that the aspect ratio is preserved
        let height = image.size.height * scale

        // create a new image context we can draw into
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0)

        // draw the original image into the context
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))

        // pull out the resized version
        let newImage = UIGraphicsGetImageFromCurrentImageContext()

        // end the context so UIKit can clean up
        UIGraphicsEndImageContext()

        // send it back to the caller
        return newImage
    }

    func imageURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("jpg")
    }

    func thumbnailURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("thumb")
    }

    func audioURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("m4a")
    }

    func transcriptionURL(for memory: URL) -> URL {
        return memory.appendingPathExtension("txt")
    }

    @objc func memoryLongPress(sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            let cell = sender.view as! MemoryCell

            if let index = collectionView.indexPath(for: cell) {
                activeMemory = filteredMemories[index.row]
                recordMemory()
            }
        } else if sender.state == .ended {
            finishRecording(success: true)
        }
    }

    func indexMemory(memory: URL, text: String) {
        // create a basic attribute set
        let attributeSet = CSSearchableItemAttributeSet.init(contentType: UTType.text)
        attributeSet.title = "Happy Days Memory"
        attributeSet.contentDescription = text
        attributeSet.thumbnailURL = thumbnailURL(for: memory)

        // wrap it in a searchable item, using the memory's partial path as its unique identifier

        // MARK: Original variant
        // let item = CSSearchableItem(uniqueIdentifier: memory.path, domainIdentifier: "andrewushakov", attributeSet: attributeSet)

        // MARK: Challenge #1
        let memoryParts = memory.path().split(separator: "/").map { return String($0) }
        let partialPath = memoryParts.last

        let item = CSSearchableItem(
            uniqueIdentifier: partialPath,
            domainIdentifier: "andrewushakov",
            attributeSet: attributeSet
        )

        // make it never expire
        item.expirationDate = .distantFuture

        // ask Spotlight to index the item
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("Indexing error: \(error.localizedDescription)")
            } else {
                print("Search item successfully indexed: \(text)")
            }
        }
    }
}
