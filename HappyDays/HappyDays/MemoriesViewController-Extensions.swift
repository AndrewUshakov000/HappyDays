//
//  MemoriesViewController-Extension.swift
//  HappyDays
//
//  Created by Andrew Ushakov on 10/13/22.
//

import Photos
import Speech
import CoreSpotlight
import MobileCoreServices
import UIKit

extension MemoriesViewController: UIImagePickerControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        dismiss(animated: true)

        if let possibleImage = info[.originalImage] as? UIImage {
            saveNewMemory(image: possibleImage)
            loadMemories()
        }
    }
}

extension MemoriesViewController: AVAudioRecorderDelegate {
    func recordMemory() {
        audioPlayer?.stop()

        collectionView.backgroundColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)

        let recodingSession = AVAudioSession.sharedInstance()

        do {
            // configure the session for recording and playback through the speaker
            try recodingSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try recodingSession.setActive(true)

            // set up a high-quality recording session
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            // create the audio recording, and assign ourselves as the delegate
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
        } catch {
            print("Failed to record: \(error)")
            finishRecording(success: false)
        }
    }

    func finishRecording(success: Bool) {
        collectionView.backgroundColor = UIColor.gray

        audioRecorder?.stop()

        if success {
            do {
                let memoryAudioURL = activeMemory.appendingPathExtension("m4a")
                let fileManager = FileManager.default

                if fileManager.fileExists(atPath: memoryAudioURL.path()) {
                    try fileManager.removeItem(at: memoryAudioURL)
                }

                try fileManager.moveItem(at: recordingURL, to: memoryAudioURL)
                transcribeAudio(memory: activeMemory)
            } catch {
                print("Failure finish recording: \(error)")
            }
        }
    }

    func transcribeAudio(memory: URL) {
        // get paths to where the audio is, and where the transcription should be”
        let audio = audioURL(for: memory)
        let transcription = transcriptionURL(for: memory)

        // create a new recognizer and point it at our audio
        let recognizer = SFSpeechRecognizer()
        let request = SFSpeechURLRecognitionRequest(url: audio)

        // start recognition
        recognizer?.recognitionTask(with: request) { [unowned self] (result, error) in
            // abort if we didn't get any transcription back
            guard let result = result else {
                print("There was an error: \(error!)")
                return
            }

            // if we got the final transcription back, we need to write it to disk
            if result.isFinal {
                // pull out the best transcription...
                let text = result.bestTranscription.formattedString
                self.indexMemory(memory: memory, text: text)
                // ...and write it to disk at the correct filename for this memory.
                do {
                    try text.write(to: transcription, atomically: true, encoding: String.Encoding.utf8)
                } catch {
                    print("Failed to save transcription.")
                }
            }
        }
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishRecording(success: false)
        }
    }
}

extension MemoriesViewController: UISearchResultsUpdating, UISearchBarDelegate {
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text else { return }

        filterMemories(text: text)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterMemories(text: searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func activateFilter(matches: [CSSearchableItem]) {
        filteredMemories = matches.map { item in
            return URL(fileURLWithPath: item.uniqueIdentifier)
        }

        UIView.performWithoutAnimation {
            collectionView.reloadSections(IndexSet(integer: 1))
        }
    }

    func filterMemories(text: String) {
        guard text.count > 0 else {
            filteredMemories = memories
            UIView.performWithoutAnimation { collectionView?.reloadSections(IndexSet(integer: 1)) }

            return
        }

        var allItems = [CSSearchableItem]()

        searchQuery?.cancel()

        let queryString = "contentDescription == \"*\(text)*\"c"
        searchQuery = CSSearchQuery(queryString: queryString, attributes: nil)

        searchQuery?.foundItemsHandler = { items in allItems.append(contentsOf: items) }
        searchQuery?.completionHandler = { _ in
            DispatchQueue.main.async { [unowned self] in
                self.activateFilter(matches: allItems)
            }
        }
        searchQuery?.start()
    }
}

extension MemoriesViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        if section == 0 {
            return CGSize.zero
        } else {
            return CGSize(width: 0, height: 50)
        }
    }
}
