import AppKit
import SwiftUI

/// App delegate that manages the menu bar icon, global event listeners,
/// and coordinates the background system-level features.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Menu Bar
    
    private var statusItem: NSStatusItem!
    
    // MARK: - Managers
    
    let personaManager = PersonaManager()
    let historyManager = HistoryManager()
    let speechRecognizer = SpeechRecognizer()
    
    // MARK: - System-Level Components
    
    private var globalKeyListener: GlobalKeyListener!
    private var textSelectionObserver: TextSelectionObserver!
    private var dictationCoordinator: DictationCoordinator!
    private var rewriteCoordinator: RewriteCoordinator!
    
    // MARK: - Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupCoordinators()
        setupGlobalKeyListener()
        setupTextSelectionObserver()
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Local Whisper")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Local Whisper", action: #selector(openMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let fnItem = NSMenuItem(title: "FN Dictation", action: nil, keyEquivalent: "")
        let fnEnabled = UserDefaults.standard.object(forKey: "fnDictationEnabled") as? Bool ?? true
        fnItem.state = fnEnabled ? .on : .off
        menu.addItem(fnItem)
        
        let toolbarItem = NSMenuItem(title: "Floating Toolbar", action: nil, keyEquivalent: "")
        let toolbarEnabled = UserDefaults.standard.object(forKey: "floatingToolbarEnabled") as? Bool ?? true
        toolbarItem.state = toolbarEnabled ? .on : .off
        menu.addItem(toolbarItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Local Whisper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "Local Whisper" || $0.contentView is NSHostingView<MainAppView> }) {
            configureWindow(window)
            window.makeKeyAndOrderFront(nil)
        } else {
            for window in NSApp.windows {
                if !(window is NSPanel) {
                    configureWindow(window)
                    window.makeKeyAndOrderFront(nil)
                    break
                }
            }
        }
    }
    
    private func configureWindow(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(red: 242/255, green: 242/255, blue: 247/255, alpha: 1.0) // #F2F2F7
    }
    
    // MARK: - Coordinators
    
    private func setupCoordinators() {
        dictationCoordinator = DictationCoordinator(
            speechRecognizer: speechRecognizer,
            historyManager: historyManager
        )
        
        rewriteCoordinator = RewriteCoordinator(
            historyManager: historyManager,
            personaManager: personaManager
        )
    }
    
    // MARK: - Global Key Listener
    
    private func setupGlobalKeyListener() {
        globalKeyListener = GlobalKeyListener()
        
        let fnEnabled = UserDefaults.standard.object(forKey: "fnDictationEnabled") as? Bool ?? true
        globalKeyListener.isEnabled = fnEnabled
        
        globalKeyListener.onFNDown = { [weak self] in
            self?.dictationCoordinator.beginDictation()
        }
        
        globalKeyListener.onFNUp = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.dictationCoordinator.endDictation()
            }
        }
        
        globalKeyListener.start()
    }
    
    // MARK: - Text Selection Observer
    
    private func setupTextSelectionObserver() {
        textSelectionObserver = TextSelectionObserver()
        
        let toolbarEnabled = UserDefaults.standard.object(forKey: "floatingToolbarEnabled") as? Bool ?? true
        textSelectionObserver.isEnabled = toolbarEnabled
        
        textSelectionObserver.onSelectionChanged = { [weak self] text, bounds in
            self?.rewriteCoordinator.showToolbar(selectedText: text, bounds: bounds)
        }
        
        textSelectionObserver.onSelectionCleared = { [weak self] in
            self?.rewriteCoordinator.hideToolbar()
        }
        
        textSelectionObserver.start()
    }
    
    // MARK: - Settings Callbacks
    
    func setFNDictationEnabled(_ enabled: Bool) {
        globalKeyListener.isEnabled = enabled
    }
    
    func setFloatingToolbarEnabled(_ enabled: Bool) {
        textSelectionObserver.isEnabled = enabled
        if !enabled {
            rewriteCoordinator.hideToolbar()
        }
    }
}
