//
//  ContentView.swift
//  Brinks of Audio
//
//  Created by Elouann Domenech on 2025-02-28.
//

import SwiftUI
import UniformTypeIdentifiers

// PluginDataStore remains the same
class PluginDataStore: ObservableObject {
    @Published var scannedPlugins: [PluginInfo] = []
    @Published var scanComplete: Bool = false
}

struct ContentView: View {
    @StateObject private var pluginDataStore = PluginDataStore()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MainView()
                .tabItem {
                    Label("Plugins", systemImage: "waveform")
                }
                .tag(0)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)
        }
        .frame(minWidth: 900, minHeight: 650)
        .overlay(alignment: .bottom) {
            // Copyright footer properly positioned at bottom
            Text("© 2025 Elouann Domenech. All rights reserved.")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.bottom, 4)
        }
        .environmentObject(pluginDataStore)
        .preferredColorScheme(.dark) // For better glass effect
    }
}

struct MainView: View {
    @EnvironmentObject private var pluginDataStore: PluginDataStore
    @State private var isScanning = false
    @State private var showingExportDialog = false
    @State private var selectedPluginType: PluginTypeFilter = .all
    @State private var searchText = ""
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedPluginType) {
                ForEach(PluginTypeFilter.allCases, id: \.self) { type in
                    HStack {
                        Label(
                            title: { Text(type.displayName) },
                            icon: { Image(systemName: type.iconName) }
                        )
                        
                        Spacer()
                        
                        Text("\(filteredPlugins(for: type).count)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .frame(minWidth: 24)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .tag(type)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 220)
            
        } detail: {
            // Main content view with glass effect
            ZStack {
                // Background with thin material
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with actions
                    toolbarView
                        .padding([.horizontal, .top])
                        .padding(.bottom, 8)
                    
                    // Plugin list
                    if pluginDataStore.scanComplete && !filteredPlugins(for: selectedPluginType).isEmpty {
                        pluginListView
                    } else {
                        emptyStateView
                    }
                }
            }
        }
        .navigationTitle(selectedPluginType.displayName)
        .fileExporter(
            isPresented: $showingExportDialog,
            document: CSVDocument(pluginsData: convertToCSV()),
            contentType: .commaSeparatedText,
            defaultFilename: "Audio_Plugins_\(formattedCurrentDate())"
        ) { result in
            switch result {
            case .success(let url):
                print("CSV saved successfully: \(url.path)")
            case .failure(let error):
                print("Error saving CSV: \(error.localizedDescription)")
            }
        }
        .searchable(text: $searchText, prompt: "Search plugins")
    }
    
    // MARK: - Component Views
    
    private var toolbarView: some View {
        HStack {
            Button(action: {
                startScan()
            }) {
                HStack {
                    Image(systemName: isScanning ? "stop.circle.fill" : "play.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.blue)
                    Text(isScanning ? "Scanning..." : "Scan Plugins")
                }
                .frame(minWidth: 120)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isScanning)
            
            Button(action: {
                showingExportDialog = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .symbolRenderingMode(.hierarchical)
                    Text("Export")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isScanning || filteredPlugins(for: selectedPluginType).isEmpty)
            
            Spacer()
            
            if isScanning {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .padding(.trailing)
            } else if pluginDataStore.scanComplete {
                Text("\(pluginDataStore.scannedPlugins.count) plugins found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var pluginListView: some View {
        List {
            ForEach(searchResults, id: \.id) { plugin in
                pluginRow(plugin)
                    .contextMenu {
                        Button {
                            // Copy path
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(plugin.path, forType: .string)
                        } label: {
                            Label("Copy Path", systemImage: "doc.on.doc")
                        }
                        
                        Divider()
                        
                        Button {
                            // Open in Finder
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: plugin.path)])
                        } label: {
                            Label("Show in Finder", systemImage: "folder")
                        }
                    }
            }
        }
        .listStyle(.inset)
        .animation(.easeOut, value: searchResults)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 48))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            
            Text(pluginDataStore.scanComplete ? "No plugins found" : "Scan to discover your plugins")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(pluginDataStore.scanComplete ? "Try selecting a different plugin type" : "Click the Scan button to find audio plugins on your system")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            if !pluginDataStore.scanComplete {
                Button(action: {
                    startScan()
                }) {
                    Text("Start Scanning")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Helper Functions
    
    private func pluginRow(_ plugin: PluginInfo) -> some View {
        HStack(spacing: 16) {
            // Enhanced plugin type icons
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 40, height: 40)
                
                // Plugin type specific icon
                Image(systemName: plugin.type.iconName)
                    .font(.system(size: 16))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(plugin.type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(plugin.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(plugin.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(plugin.manufacturer)
                        .font(.subheadline)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("v\(plugin.version)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(plugin.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var searchResults: [PluginInfo] {
        let filtered = filteredPlugins(for: selectedPluginType)
        
        if searchText.isEmpty {
            return filtered
        } else {
            return filtered.filter { plugin in
                plugin.name.localizedCaseInsensitiveContains(searchText) ||
                plugin.manufacturer.localizedCaseInsensitiveContains(searchText) ||
                plugin.path.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func filteredPlugins(for type: PluginTypeFilter) -> [PluginInfo] {
        switch type {
        case .all:
            return pluginDataStore.scannedPlugins
        case .au:
            return pluginDataStore.scannedPlugins.filter { $0.type == .au }
        case .vst:
            return pluginDataStore.scannedPlugins.filter { $0.type == .vst }
        case .aax:
            return pluginDataStore.scannedPlugins.filter { $0.type == .aax }
        }
    }
    
    // Reuse your existing scan and CSV functions
    private func startScan() {
        isScanning = true
        pluginDataStore.scannedPlugins = []
        
        // Simulate scanning with a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // This is where we would actually scan the file system
            scanForPlugins()
            isScanning = false
            pluginDataStore.scanComplete = true
        }
    }
    
    // Update the scanForPlugins function to include Waves .bundle plugins

    private func scanForPlugins() {
        // Set up file manager
        let fileManager = FileManager.default
        pluginDataStore.scannedPlugins = []
        
        // Define standard plugin directories to scan
        let auDirectories = [
            "/Library/Audio/Plug-Ins/Components",
            NSHomeDirectory() + "/Library/Audio/Plug-Ins/Components"
        ]
        
        let vstDirectories = [
            "/Library/Audio/Plug-Ins/VST",
            "/Library/Audio/Plug-Ins/VST3",
            NSHomeDirectory() + "/Library/Audio/Plug-Ins/VST",
            NSHomeDirectory() + "/Library/Audio/Plug-Ins/VST3"
        ]
        
        let aaxDirectories = [
            "/Library/Application Support/Avid/Audio/Plug-Ins",
            NSHomeDirectory() + "/Library/Application Support/Avid/Audio/Plug-Ins"
        ]
        
        // Specific Waves plugin directories (direct containment of .bundle files)
        let wavesDirectories = [
            "/Applications/Waves/Plug-Ins V9/Waves",
            "/Applications/Waves/Plug-Ins V10/Waves",
            "/Applications/Waves/Plug-Ins V11/Waves",
            "/Applications/Waves/Plug-Ins V12/Waves",
            "/Applications/Waves/Plug-Ins V13/Waves",
            "/Applications/Waves/Plug-Ins V14/Waves",
            "/Applications/Waves/Plug-Ins V15/", // Added V15 support
            "/Applications/Waves/Plug-Ins/Waves",
            "/Library/Application Support/Waves/Plug-Ins",
            NSHomeDirectory() + "/Library/Application Support/Waves/Plug-Ins"
        ]
        
        // Scan standard plugin formats
        var auPlugins: [PluginInfo] = []
        for directory in auDirectories {
            auPlugins.append(contentsOf: scanDirectory(path: directory, type: .au))
        }
        
        var vstPlugins: [PluginInfo] = []
        for directory in vstDirectories {
            vstPlugins.append(contentsOf: scanDirectory(path: directory, type: .vst))
        }
        
        var aaxPlugins: [PluginInfo] = []
        for directory in aaxDirectories {
            aaxPlugins.append(contentsOf: scanDirectory(path: directory, type: .aax))
        }
        
        // Scan Waves .bundle plugins
        var wavesPlugins: [PluginInfo] = []
        for directory in wavesDirectories {
            wavesPlugins.append(contentsOf: scanWavesDirectory(path: directory))
        }
        
        pluginDataStore.scannedPlugins.append(contentsOf: auPlugins)
        pluginDataStore.scannedPlugins.append(contentsOf: vstPlugins)
        pluginDataStore.scannedPlugins.append(contentsOf: aaxPlugins)
        pluginDataStore.scannedPlugins.append(contentsOf: wavesPlugins)
    }
    
    // Add a new function specifically for scanning Waves .bundle plugins
    private func scanWavesDirectory(path: String) -> [PluginInfo] {
        let fileManager = FileManager.default
        var results: [PluginInfo] = []
        
        guard fileManager.fileExists(atPath: path) else { return [] }
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            
            for item in contents {
                // Check for Waves bundle formats
                if item.hasSuffix(".bundle") {
                    let fullPath = path + "/" + item
                    
                    // Get name from file name (without extension)
                    let name = item.components(separatedBy: ".bundle").first ?? item
                    
                    // Clean up name - often Waves plugins have format like "Waves X-Plugin.bundle"
                    var cleanName = name
                    if cleanName.hasPrefix("Waves ") {
                        cleanName = String(cleanName.dropFirst(6)) // Remove "Waves " prefix
                    }
                    
                    // Get file attributes
                    let attributes = try fileManager.attributesOfItem(atPath: fullPath)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    let modDate = attributes[.modificationDate] as? Date ?? Date()
                    
                    // Determine which plugin type based on the directory or contents
                    let type = determineWavesPluginType(path: fullPath)
                    
                    let plugin = PluginInfo(
                        id: UUID(),
                        name: cleanName,
                        type: type,
                        path: fullPath,
                        version: extractWavesVersion(fromPath: fullPath, directoryPath: path) ?? "Unknown",
                        manufacturer: "Waves",
                        fileSize: fileSize,
                        modificationDate: modDate
                    )
                    
                    results.append(plugin)
                }
            }
        } catch {
            print("Error scanning Waves directory \(path): \(error.localizedDescription)")
        }
        
        return results
    }
    
    // Helper function to determine plugin type for Waves bundles
    private func determineWavesPluginType(path: String) -> PluginType {
        let fileManager = FileManager.default
        
        // Check for standard type indicators within the bundle
        if fileManager.fileExists(atPath: path + "/Contents/MacOS/VST") {
            return .vst
        } else if fileManager.fileExists(atPath: path + "/Contents/MacOS/VST3") {
            return .vst
        } else if fileManager.fileExists(atPath: path + "/Contents/MacOS/AU") {
            return .au
        } else if fileManager.fileExists(atPath: path + "/Contents/MacOS/AAX") {
            return .aax
        }
        
        // Try to determine by looking at the info.plist
        let infoPlistPath = path + "/Contents/Info.plist"
        if fileManager.fileExists(atPath: infoPlistPath),
           let plistData = NSDictionary(contentsOfFile: infoPlistPath) {
            if let bundleID = plistData["CFBundleIdentifier"] as? String {
                if bundleID.contains("vst") {
                    return .vst
                } else if bundleID.contains("audiounit") || bundleID.contains("au") {
                    return .au
                } else if bundleID.contains("aax") {
                    return .aax
                }
            }
        }
        
        // If no specific indicators found, guess based on path
        if path.lowercased().contains("vst") {
            return .vst
        } else if path.lowercased().contains("au") || path.lowercased().contains("audiounit") {
            return .au
        } else if path.lowercased().contains("aax") {
            return .aax
        }
        
        // Default to VST as most common for Waves
        return .vst
    }
    
    // Special version extractor for Waves plugins
    private func extractWavesVersion(fromPath path: String, directoryPath: String) -> String? {
        // Try to extract version from the containing directory path
        // Waves often uses directories like "Plug-Ins V14"
        if let versionMatch = directoryPath.range(of: "V[0-9]+", options: .regularExpression) {
            let versionStr = String(directoryPath[versionMatch])
            return String(versionStr.dropFirst()) // Remove the 'V' prefix
        }
        
        // Try to get version from the bundle's info.plist
        let infoPlistPath = path + "/Contents/Info.plist"
        if FileManager.default.fileExists(atPath: infoPlistPath),
           let plistData = NSDictionary(contentsOfFile: infoPlistPath),
           let version = plistData["CFBundleShortVersionString"] as? String {
            return version
        } else if FileManager.default.fileExists(atPath: infoPlistPath),
                  let plistData = NSDictionary(contentsOfFile: infoPlistPath),
                  let version = plistData["CFBundleVersion"] as? String {
            return version
        }
        
        // Fall back to looking for version in the file name
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        if let range = fileName.range(of: "[0-9]+(\\.[0-9]+)+", options: .regularExpression) {
            return String(fileName[range])
        }
        
        return nil
    }
    
    // Helper functions to extract metadata
    private func extractVersion(fromPath path: String) -> String? {
        // Waves-specific version extraction
        if path.contains("/Waves/") || path.contains("Waves ") {
            // Look for Waves version in path (often includes version in directory name)
            if let range = path.range(of: "V[0-9]+", options: .regularExpression) {
                return String(path[range].dropFirst()) // Drop the "V" prefix
            }
            
            // Try to get version from file name for Waves plugins
            let fileName = URL(fileURLWithPath: path).lastPathComponent
            if let range = fileName.range(of: "V[0-9]+(\\.[0-9]+)?", options: .regularExpression) {
                return String(fileName[range].dropFirst())
            }
        }
        
        // Rest of your existing version extraction code
        if path.hasSuffix(".component") {
            // For Audio Unit components, extract version from Info.plist
            let infoPlistPath = path + "/Contents/Info.plist"
            if FileManager.default.fileExists(atPath: infoPlistPath),
               let plistData = NSDictionary(contentsOfFile: infoPlistPath) {
                // Try several common version keys in order of preference
                if let version = plistData["CFBundleShortVersionString"] as? String {
                    return version
                } else if let version = plistData["CFBundleVersion"] as? String {
                    return version
                } else if let version = plistData["AudioUnit Version"] as? String {
                    return version
                }
            }
        } else if path.hasSuffix(".vst") || path.hasSuffix(".vst3") {
            if path.hasSuffix(".vst3") {
                // VST3 plugins may have a moduleinfo.json file
                let moduleInfoPath = path + "/Contents/Resources/moduleinfo.json"
                if FileManager.default.fileExists(atPath: moduleInfoPath) {
                    do {
                        let data = try Data(contentsOf: URL(fileURLWithPath: moduleInfoPath))
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let version = json["version"] as? String {
                            return version
                        }
                    } catch {
                        print("Error reading VST3 moduleinfo: \(error)")
                    }
                }
                
                // Try info.plist for VST3 on Mac
                let infoPlistPath = path + "/Contents/Info.plist"
                if FileManager.default.fileExists(atPath: infoPlistPath),
                   let plistData = NSDictionary(contentsOfFile: infoPlistPath),
                   let version = plistData["CFBundleShortVersionString"] as? String {
                    return version
                }
            } else {
                // VST2 plugins might have version info in resource files
                // This is a simplified approach - would need more complex parsing in real app
                let resourcePath = path + "/Contents/Resources/plugin.info"
                if FileManager.default.fileExists(atPath: resourcePath) {
                    do {
                        let content = try String(contentsOfFile: resourcePath)
                        if let versionRange = content.range(of: "Version:\\s*([0-9.]+)", options: .regularExpression) {
                            let versionMatch = content[versionRange]
                            let components = versionMatch.components(separatedBy: ":")
                            if components.count > 1 {
                                return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                    } catch {
                        print("Error reading VST2 resource file: \(error)")
                    }
                }
            }
        } else if path.hasSuffix(".aaxplugin") {
            // AAX plugins usually have an Info.plist
            let infoPlistPath = path + "/Contents/Info.plist"
            if FileManager.default.fileExists(atPath: infoPlistPath),
               let plistData = NSDictionary(contentsOfFile: infoPlistPath),
               let version = plistData["CFBundleShortVersionString"] as? String {
                return version
            }
        }
        
        // Try to extract version from the directory name if it contains version numbers
        let pathComponents = path.split(separator: "/")
        if let lastComponent = pathComponents.last {
            let fileName = String(lastComponent)
            // Look for common version patterns like "Name 1.2.3" or "Name v1.2.3"
            let versionPattern = "(\\d+[\\.]\\d+([\\.]\\d+)?)"
            if let regex = try? NSRegularExpression(pattern: versionPattern),
               let match = regex.firstMatch(in: fileName, range: NSRange(fileName.startIndex..., in: fileName)) {
                if let range = Range(match.range(at: 1), in: fileName) {
                    return String(fileName[range])
                }
            }
        }
        
        return "Unknown"
    }

    // Update this section in your extractManufacturer function

    private func extractManufacturer(fromPath path: String) -> String? {
        // Waves-specific detection
        if path.contains("/Waves/") || path.contains("Waves ") {
            return "Waves"
        }
        
        // Rest of your existing code for manufacturer extraction...
        if path.hasSuffix(".component") {
            // For Audio Unit components
            let infoPlistPath = path + "/Contents/Info.plist"
            if FileManager.default.fileExists(atPath: infoPlistPath),
               let plistData = NSDictionary(contentsOfFile: infoPlistPath) {
                
                // Try various common manufacturer keys
                if let manufacturer = plistData["AudioUnitVendorName"] as? String {
                    return manufacturer
                } else if let manufacturer = plistData["CFBundleIdentifier"] as? String {
                    // Extract company name from bundle ID (e.g., "com.native-instruments.Kontakt" -> "native-instruments")
                    let components = manufacturer.components(separatedBy: ".")
                    if components.count >= 2 {
                        return formatManufacturerName(components[1])
                    }
                } else if let manufacturer = plistData["NSHumanReadableCopyright"] as? String {
                    // Try to extract company name from copyright string
                    // E.g. "© 2022 Native Instruments GmbH" -> "Native Instruments"
                    let pattern = "©\\s*\\d{4}\\s*([^\\.,]+)"
                    if let regex = try? NSRegularExpression(pattern: pattern),
                       let match = regex.firstMatch(in: manufacturer, range: NSRange(manufacturer.startIndex..., in: manufacturer)) {
                        if let range = Range(match.range(at: 1), in: manufacturer) {
                            return String(manufacturer[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    return manufacturer
                }
            }
        } else if path.hasSuffix(".vst3") {
            // VST3 plugins
            // Check moduleinfo.json first
            let moduleInfoPath = path + "/Contents/Resources/moduleinfo.json"
            if FileManager.default.fileExists(atPath: moduleInfoPath) {
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: moduleInfoPath))
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let vendor = json["vendor"] as? String {
                        return vendor
                    }
                } catch {
                    print("Error reading VST3 moduleinfo: \(error)")
                }
            }
            
            // Fall back to info.plist
            let infoPlistPath = path + "/Contents/Info.plist"
            if FileManager.default.fileExists(atPath: infoPlistPath),
               let plistData = NSDictionary(contentsOfFile: infoPlistPath),
               let bundleID = plistData["CFBundleIdentifier"] as? String {
                let components = bundleID.components(separatedBy: ".")
                if components.count >= 2 {
                    return formatManufacturerName(components[1])
                }
            }
        } else if path.hasSuffix(".vst") {
            // VST2 plugins might have manufacturer info in the file name
            let pathComponents = path.split(separator: "/")
            if let lastComponent = pathComponents.last {
                let fileName = String(lastComponent)
                
                // Many plugins follow naming convention: "Manufacturer PluginName.vst"
                let nameComponents = fileName.components(separatedBy: " ")
                if nameComponents.count >= 2 {
                    return nameComponents[0]
                }
            }
        } else if path.hasSuffix(".aaxplugin") {
            // AAX plugins
            let infoPlistPath = path + "/Contents/Info.plist"
            if FileManager.default.fileExists(atPath: infoPlistPath),
               let plistData = NSDictionary(contentsOfFile: infoPlistPath) {
                if let manufacturer = plistData["AAXManufacturerName"] as? String {
                    return manufacturer
                } else if let bundleID = plistData["CFBundleIdentifier"] as? String {
                    let components = bundleID.components(separatedBy: ".")
                    if components.count >= 2 {
                        return formatManufacturerName(components[1])
                    }
                }
            }
        }
        
        // Try to extract manufacturer from the path as a fallback
        // E.g. "/Library/Audio/Plug-Ins/Components/Waves/WavesPlugin.component" -> "Waves"
        let pathComponents = path.split(separator: "/")
        if pathComponents.count >= 2 {
            let potentialManufacturer = String(pathComponents[pathComponents.count - 2])
            // Only use this if it looks like a company name (not "Components", "VST3", etc.)
            let genericFolders = ["Components", "VST", "VST3", "Plug-Ins", "Audio", "Library", "Plugins"]
            if !genericFolders.contains(potentialManufacturer) {
                return potentialManufacturer
            }
        }
        
        return "Unknown"
    }

    // Helper function to format manufacturer names from bundle IDs
    private func formatManufacturerName(_ rawName: String) -> String {
        var name = rawName.replacingOccurrences(of: "-", with: " ")
        // Capitalize words
        let words = name.components(separatedBy: " ")
        name = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
        return name
    }
    
    private func convertToCSV() -> String {
        // Keep your existing convertToCSV implementation
        // CSV header
        var csvString = "Name,Manufacturer,Version,Format,Path,Size,Last Modified\n"
        
        // Add data rows
        for plugin in pluginDataStore.scannedPlugins {
            // Escape any commas in fields by wrapping in quotes
            let name = "\"\(plugin.name)\""
            let manufacturer = "\"\(plugin.manufacturer)\""
            let version = "\"\(plugin.version)\""
            let format = "\"\(plugin.type.displayName)\""
            let path = "\"\(plugin.path)\""
            
            let row = [
                name,
                manufacturer,
                version,
                format,
                path,
                plugin.formattedSize,
                plugin.formattedDate
            ].joined(separator: ",")
            
            csvString.append(row + "\n")
        }
        
        return csvString
    }
    
    private func formattedCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // Add the scanDirectory function to scan for plugins in a given directory
    private func scanDirectory(path: String, type: PluginType) -> [PluginInfo] {
        let fileManager = FileManager.default
        var results: [PluginInfo] = []
        
        // Check if directory exists
        guard fileManager.fileExists(atPath: path) else { return [] }
        
        do {
            // Get all items in directory
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            
            // Filter for plugin file extensions based on type
            let extensions: [String]
            switch type {
            case .au:
                extensions = [".component"]
            case .vst:
                extensions = [".vst", ".vst3"]
            case .aax:
                extensions = [".aaxplugin"]
            }
            
            // Process each item
            for item in contents {
                let fullPath = path + "/" + item
                var isDir: ObjCBool = false
                
                // Skip if not a directory or doesn't have the right extension
                guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDir),
                      isDir.boolValue,
                      extensions.contains(where: { item.hasSuffix($0) }) else {
                    continue
                }
                
                // Extract plugin name (remove extension)
                var name = item
                for ext in extensions {
                    if name.hasSuffix(ext) {
                        name = String(name.dropLast(ext.count))
                        break
                    }
                }
                
                // Get file attributes
                guard let attributes = try? fileManager.attributesOfItem(atPath: fullPath) else {
                    continue
                }
                
                let fileSize = attributes[.size] as? Int64 ?? 0
                let modDate = attributes[.modificationDate] as? Date ?? Date()
                
                // Extract metadata
                let version = extractVersion(fromPath: fullPath) ?? "Unknown"
                let manufacturer = extractManufacturer(fromPath: fullPath) ?? "Unknown"
                
                // Create plugin info
                let plugin = PluginInfo(
                    id: UUID(),
                    name: name,
                    type: type,
                    path: fullPath,
                    version: version,
                    manufacturer: manufacturer,
                    fileSize: fileSize,
                    modificationDate: modDate
                )
                
                results.append(plugin)
            }
        } catch {
            print("Error scanning directory \(path): \(error.localizedDescription)")
        }
        
        return results
    }
}

// Add this before the PluginTypeFilter enum definition
enum PluginType {
    case au, vst, aax
}

// Enhanced enum with visual properties
enum PluginTypeFilter: String, CaseIterable {
    case all, au, vst, aax
    
    var displayName: String {
        switch self {
        case .all: return "All Plugins"
        case .au: return "Audio Units"
        case .vst: return "VST/VST3"
        case .aax: return "AAX"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "square.stack.3d.up.fill"
        case .au: return "speaker.wave.3.fill"
        case .vst: return "slider.horizontal.3"
        case .aax: return "waveform"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .blue
        case .au: return .orange
        case .vst: return .green
        case .aax: return .purple
        }
    }
}

// Add color property to PluginType
extension PluginType {
    var displayName: String {
        switch self {
        case .au: return "Audio Unit"
        case .vst: return "VST/VST3"
        case .aax: return "AAX"
        }
    }
    
    var iconName: String {
        switch self {
        case .au: return "speaker.wave.3.fill"  // Changed from a.circle
        case .vst: return "slider.horizontal.3"  // Changed from v.circle
        case .aax: return "waveform"            // Changed from x.circle
        }
    }
    
    var color: Color {
        switch self {
        case .au: return .orange
        case .vst: return .green
        case .aax: return .purple
        }
    }
}

// Modernized Settings View
struct SettingsView: View {
    var body: some View {
        ZStack {
            // Background with thin material
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 30) {
                // Main Settings (can expand later)
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scan Locations")
                            .font(.headline)
                        
                        Toggle("System Plugins", isOn: .constant(true))
                        Toggle("User Plugins", isOn: .constant(true))
                        
                        HStack {
                            Toggle("Custom Locations", isOn: .constant(false))
                                .disabled(true)
                            
                            Text("Soon")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                    .padding(8)
                }
                .groupBoxStyle(TransparentGroupBox())
                
                // About section
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("About SoundKeeper", systemImage: "info.circle")
                            .font(.headline)
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        HStack {
                            Image(systemName: "waveform.badge.plus")
                                .font(.system(size: 40))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading) {
                                Text("SoundKeeper")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                
                                Text("Version 0.1 (Beta)")
                                    .foregroundColor(.secondary)
                                
                                Text("© 2025 Elouann Domenech")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                                
                                Text("Code name: Brinks of Audio")
                                    .font(.caption2)
                                    .foregroundColor(.secondary.opacity(0.8))
                            }
                        }
                        
                        Button("Check for Updates") {
                            // Update check logic
                        }
                        .padding(.top, 8)
                    }
                    .padding(8)
                }
                .groupBoxStyle(TransparentGroupBox())
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: 500)
        }
        .navigationTitle("Settings")
    }
}

// Custom GroupBox style for transparent look
struct TransparentGroupBox: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
            configuration.content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// Keep your existing model structs and helper code here
// Define plugin model with enhanced metadata
struct PluginInfo: Identifiable, Equatable {
    let id: UUID
    let name: String
    let type: PluginType
    let path: String
    let version: String
    let manufacturer: String
    let fileSize: Int64
    let modificationDate: Date
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modificationDate)
    }
    
    // Add this static function for Equatable conformance
    static func == (lhs: PluginInfo, rhs: PluginInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

// Document struct for file export
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    
    var text: String
    
    init(pluginsData: String) {
        self.text = pluginsData
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    ContentView()
}
