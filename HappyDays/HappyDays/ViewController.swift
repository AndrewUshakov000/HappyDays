//
//  ViewController.swift
//  HappyDays
//
//  Created by Andrew Ushakov on 7/9/22.
//

// swiftlint:disable line_length
import AVFoundation
import Photos
import Speech
import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var helpLabel: UILabel!

    @IBAction func requestPermissions(_ sender: Any) {
        requestPhotosPermission()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

    }

    func requestPhotosPermission() {
        PHPhotoLibrary.requestAuthorization { [unowned self] authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.requestRecordPermissions()
                } else {
                    self.helpLabel.text = "Photos permission was declined; please enable it in settings then tap Continue again."
                }
            }
        }
    }

    func requestRecordPermissions() {
        AVAudioSession.sharedInstance().requestRecordPermission { [unowned self] allowed in
            DispatchQueue.main.async {
                if allowed {
                    self.requestTranscribePermissions()
                } else {
                    self.helpLabel.text = "Recording permission was declined; please enable it in settings then tap Continue again."
                }
            }
        }
    }

    func requestTranscribePermissions() {
        SFSpeechRecognizer.requestAuthorization { [unowned self] authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.authorizationComplete()
                } else {
                    self.helpLabel.text = "Transcription permission was declined; please enable it in settings then tap Continue again."
                }
            }
        }
    }

    func authorizationComplete() {
        dismiss(animated: true)
    }
}
