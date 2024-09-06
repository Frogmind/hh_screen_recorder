import Flutter
import UIKit
import ReplayKit


public class SwiftHhScreenRecorderPlugin: NSObject, FlutterPlugin, RPPreviewViewControllerDelegate {
  
    var flutterRes : FlutterResult?
	static var channel : FlutterMethodChannel?;
	var wasShareFinishSent : bool;
    
  public static func register(with registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(name: "hh_screen_recorder", binaryMessenger: registrar.messenger())
    let instance = SwiftHhScreenRecorderPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel!)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

    flutterRes = result
	wasShareFinishSent = false
      
    if (call.method == "startRecording")
    {
        print("HHRecorder: Start Recording")
       
        RPScreenRecorder.shared().startRecording { err in
          guard err == nil else {
              print("HHRecorder: Error starting recording: \(err.debugDescription)")
              result(false)
              return }
            
            print("HHRecorder: Started recording.")
            result(true)
        }
    }
    else if (call.method == "stopRecording")
    {
        print("HHRecorder: Attempting to stop recording & show preview window")

        RPScreenRecorder.shared().stopRecording { preview, err in
          guard let preview = preview else {
              print("HHRecorder: Error stopping recording: no preview window!");
              result(false)
              return
          }
            
            if let err = err {
                print("HHRecorder: Error stopping recording: \(err.localizedDescription)")
                result(false)
                return
            }

            if UIDevice.current.userInterfaceIdiom == .pad {
            preview.modalPresentationStyle = .popover
            preview.popoverPresentationController?.sourceRect = .zero
            preview.popoverPresentationController?.sourceView =
                UIApplication.shared.delegate?.window??.rootViewController?.view
        }else {
          preview.modalPresentationStyle = .overFullScreen
        }
          preview.previewControllerDelegate = self
            UIApplication.shared.delegate?.window??.rootViewController?.present(preview, animated: true)
        }
        
    }
    else if (call.method == "isRecordingSupported")
    {
        // iOS 9.0+ is always supported on HH
        result(true)
    }
    else
    {
        result(false)
        // result(FlutterMethodNotImplemented)
    }
  }

  public func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
	  
	  if (wasShareFinishSent)
			return;
      
      UIApplication.shared.delegate?.window??.rootViewController?.dismiss(animated: true)
      print("HHRecorder: Stopped recording")
	  SwiftHhScreenRecorderPlugin.channel?.invokeMethod("onRecordingShareFinished", arguments: nil)
    }
	
	public func previewController(_ previewController: RPPreviewViewController, didFinishWithActivityTypes activityTypes: Set<String>) {
		UIApplication.shared.delegate?.window??.rootViewController?.dismiss(animated: true)
		print("HHRecorder: Preview finished activities \(activityTypes)")
		
		/*let myDictionary: [String: String] = activityTypes.enumerated().reduce(into: [String: String]()) { dict, element in
			dict[element.element] = element.element
		}*/
		
		let myDictionary: [String: String] = Dictionary(uniqueKeysWithValues: activityTypes.map { ($0, $0) })
		
		SwiftHhScreenRecorderPlugin.channel?.invokeMethod("onRecordingShareFinished", arguments: myDictionary)
		
		wasShareFinishSent = true
	}
}
