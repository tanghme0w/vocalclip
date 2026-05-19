//
//  ContentView.swift
//  vocalclip
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainView()
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsStore())
        .environmentObject(ReadingManager(settingsStore: SettingsStore()))
}
