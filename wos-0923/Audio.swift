//
//  Audio.swift
//  wos-0923
//
//  Created by Juan Aboites on 10/20/23.
//
//

import Foundation
import Vision
import AVFAudio
import AudioKit


class Audio: ObservableObject {
    
    let engine = AudioEngine()
    let cueMixer = Mixer()
    var cues: [Cue] = []
    
    init(){
        
        createCues()
        connectCues()
        guard (try? AVAudioSession.sharedInstance().setCategory(
            .playAndRecord, options:
            [.defaultToSpeaker, .mixWithOthers, .allowBluetoothA2DP]
        )) != nil
        else {
            print("Audio Session Init Failed")
            return
        }
        
        guard (try? engine.start()) != nil
        else {
            //consider throwing here instead
            print("Audio Engine Failed To Start")
            return
        }
        
    }
    
    private func createTestCue() -> Cue {
        
        //PlayerConfig is meta data related to each audioPlayer which plays one file
        var pc = PlayerConfig()
        pc.bufferd = true
        pc.loops = true
        pc.startTime = 0
        pc.path = "CantinaBand60.wav"
        
        let cue = Cue(odClass: "person", playerConfigs: [pc])
        return cue
    }
    
    private func createCues(){
        cues.append(createTestCue())
        
    }
    
    private func connectCues(){
        for cue in cues{
            cueMixer.addInput(cue.output)
        }
        
        engine.output = cueMixer
    }
    
    
    func update(preds: Array<VNClassificationObservation>, box: CGRect){
        for pred in preds {
            for cue in cues {
                if pred.identifier == cue.odClass{
                    cue.play()
                }
                else {
                    print("--- Pausing Cue", pred.identifier)
                    cue.pause()
                }
            }
        }
    }
    
}
