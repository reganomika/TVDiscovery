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
    
    private let serviceTypes: [String]
    private var currentServiceTypeIndex = 0
    
    public init(serviceTypes: [String]) {
        self.serviceTypes = serviceTypes
        super.init()
    }
    
    public convenience init(serviceType: String) {
        self.init(serviceTypes: [serviceType])
    }
    
    public func start() {
        stop()
        isSearching = true
        discoveredServices.removeAll()
        currentServiceTypeIndex = 0
        browser.delegate = self
        browser.stop()
        initialSearchTime = Date()
        performSearch()
    }
    
    private func performSearch() {
        guard isSearching, currentServiceTypeIndex < serviceTypes.count else {
            stop()
            onScanFinished?()
            return
        }
        
        let currentServiceType = serviceTypes[currentServiceTypeIndex]
        browser.searchForServices(ofType: currentServiceType, inDomain: "local.")
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.isSearching else { return }
                
                // Переходим к следующему типу сервиса
                self.currentServiceTypeIndex += 1
                self.browser.stop()
                
                if self.currentServiceTypeIndex < self.serviceTypes.count {
                    let nextServiceType = self.serviceTypes[self.currentServiceTypeIndex]
                    self.browser.searchForServices(ofType: nextServiceType, inDomain: "local.")
                } else {
                    // Если все типы сервисов проверены, начинаем сначала
                    self.currentServiceTypeIndex = 0
                    let firstServiceType = self.serviceTypes[self.currentServiceTypeIndex]
                    self.browser.searchForServices(ofType: firstServiceType, inDomain: "local.")
                }
                
                // Проверяем общее время поиска
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
