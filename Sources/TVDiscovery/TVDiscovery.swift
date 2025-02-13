import Foundation

open class TVDiscoveryService: NSObject, @unchecked Sendable {
    
    public var onDeviceDiscovered: ((String, String) -> Void)?
    public var onScanFinished: (() -> Void)?
    
    private let browser = NetServiceBrowser()
    private var discoveredServices = Set<NetService>()
    private var searchTimeout: DispatchWorkItem?
    private var retryTimer: Timer?
    private var isSearching = false
    private var initialSearchTime: Date?
    
    private let serviceType: String
    
    public init(serviceType: String) {
        self.serviceType = serviceType
    }
    
    public func start() {
        stop()
        isSearching = true
        discoveredServices.removeAll()
        browser.delegate = self
        browser.stop()
        initialSearchTime = Date()
        performSearch()
    }
    
    private func performSearch() {
        guard isSearching else { return }
        
        browser.searchForServices(ofType: serviceType, inDomain: "local.")
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.isSearching else { return }
                self.browser.stop()
                self.browser.searchForServices(ofType: self.serviceType, inDomain: "local.")
                
                if let startTime = self.initialSearchTime, Date().timeIntervalSince(startTime) >= 10.0 {
                    self.stop()
                    self.onScanFinished?()
                }
            }
        }
    }
    
    func stop() {
        isSearching = false
        retryTimer?.invalidate()
        browser.stop()
    }
}

extension TVDiscoveryService: NetServiceBrowserDelegate {
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        guard discoveredServices.insert(service).inserted else { return }
        service.delegate = self
        service.resolve(withTimeout: 5)
    }
}

extension TVDiscoveryService: NetServiceDelegate {
    public func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addressData = sender.addresses?.first, let ip = extractIP(from: addressData) else {
            return
        }
        let deviceName = sender.name
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.onDeviceDiscovered?(deviceName, ip)
        }
    }
    
    private func extractIP(from addressData: Data) -> String? {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        addressData.withUnsafeBytes { ptr in
            let sockaddr = ptr.baseAddress!.assumingMemoryBound(to: sockaddr.self)
            getnameinfo(sockaddr, socklen_t(addressData.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
        }
        return String(cString: hostname)
    }
}
