//
//  ContentView.swift
//  wos-0923
//
//  Created by Juan Aboites on 9/15/23.
//


//Content view
//  Blank
//  App Error
//  Camera
//  State
//    detected class
//    confidence
//    etc

import SwiftUI

struct ContentView: View {
    
    @ObservedObject var core = Core()
        
    var body: some View {
        Text(core.errorState)
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
