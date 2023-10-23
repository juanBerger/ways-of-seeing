//
//  Cue.swift
//  wos-0923
//
//  Created by Juan Aboites on 10/22/23.
//

import Foundation
import AudioKit
import AVFAudio

class Cue: ObservableObject {
    
    var odClass: String = ""
    var tc: Int32 = 0
    var isPlaying = false
    
    var players: [AudioPlayer] = []
    let output = Mixer()
    
    
    //Each playerConfig creates a new player which loads one sound file
    //All players are connected to the Cue Mixer
    //Each odClass (Object Detector Class) is mapped to a Cue instance
    init(odClass: String, playerConfigs: [PlayerConfig]){
        
        self.odClass = odClass
        
        for pc in playerConfigs {
            
            let ap = AudioPlayer()
            guard let path = Bundle.main.path(forResource: pc.path, ofType: nil) else { continue }
            let url = URL(fileURLWithPath: path)
            guard let file = try? AVAudioFile(forReading: url)
            else {
                print("File Load Error")
                continue
            }
            
            guard (try? ap.load(file: file, buffered: pc.bufferd, preserveEditTime: false)) != nil
            else {
                print("Audio Player Creation Error")
                continue
            }
            
            ap.isLooping = pc.loops
            output.addInput(ap) //connect to the cue level mixer
            
            players.append(ap)
            
        }
    }
    
    func play(){
        
        if (self.isPlaying){
            return
        }
        
        for player in players {
            player.play()
            print("++++ Playing Cue")
        }
        
        self.isPlaying = true
       
    }
    
    func pause(){
        
        if (!self.isPlaying){
            return
        }
        
        for player in players {
            player.pause()
        }
        
        self.isPlaying = false
    }
    
    
    
}
