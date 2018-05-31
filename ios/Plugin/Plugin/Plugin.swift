import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitor.ionicframework.com/docs/plugins/ios
 */
@objc(ZeroConfPlugin)
public class ZeroConfPlugin: CAPPlugin {
    
    //Collection of our watchers
    var browsers: [String: Browser]!
    
    @objc func watch(_ call: CAPPluginCall) {
        
        let type = call.getString("type") ?? "";
        
        let domain = call.getString("domain") ?? "";
        
        guard type != "" else{
            call.reject("Error: type is empty");
            return;
        };
        
        guard domain != "" else{
            call.reject("Error: domain is empty");
            return;
        };
        
        #if DEBUG
        print("Looking for \(type + domain)");
        #endif
        
        let browser = Browser(withDomain: domain, withType: type)
        
        browser.commandDelegate = call;
        
        browser.watch();
        
        //Keep track of this watcher
        browsers[type + domain] = browser;
        
        
    }
    
    @objc func unwatch(_ call:CAPPluginCall) {
        
        let type = call.getString("type") ?? "";
        
        let domain = call.getString("domain") ?? "";
        
        guard type != "" else{
            call.reject("Error: type is empty");
            return;
        };
        
        guard domain != "" else{
            call.reject("Error: domain is empty");
            return;
        };
        
        #if DEBUG
        print("ZeroConf: unwatch \(type + domain)")
        #endif
        
        if let browser = browsers[type + domain] {
            browser.unwatch();
            browsers.removeValue(forKey: type + domain)
        }
        
    }
    
    
    class Browser: NSObject, NetServiceDelegate, NetServiceBrowserDelegate {
        
        var nsb: NetServiceBrowser?
        var domain: String
        var type: String
        var services: [String: NetService] = [:]
        var commandDelegate: CAPPluginCall?
        
        init (withDomain domain: String, withType type: String) {
            self.domain = domain;
            self.type = type;
        }
        
        func watch() {
            
            // Net service browser
            let browser = NetServiceBrowser();
            
            nsb = browser;
            
            browser.delegate = self;
            
            browser.searchForServices(ofType: self.type, inDomain: self.domain);
            
            browser.schedule(in: RunLoop.current, forMode: .commonModes)
            
            RunLoop.current.run(until: Date.init(timeIntervalSinceNow: 300))
        }
        
        func unwatch() {
            
            if let service = nsb {
                service.stop();
            }
            
        }
        
        func destroy() {
            
            if let service = nsb {
                service.stop();
            }
            
        }
        
        @objc func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
            #if DEBUG
            print("ZeroConf: netServiceBrowser:didNotSearch:\(netService) \(errorDict)");
            #endif
            
            commandDelegate?.reject("Error when starting browser");
        }
        
        @objc func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser,
                                     didFind netService: NetService,
                                     moreComing moreServicesComing: Bool) {
            #if DEBUG
            print("ZeroConf: netServiceBrowser:didFindService:\(netService)");
            #endif
            
            netService.delegate = self;
            
            netService.resolve(withTimeout: 5000);
            
            services[netService.name] = netService; // keep strong reference to catch didResolveAddress
        }
        
        @objc func netServiceDidResolveAddress(_ netService: NetService) {
            #if DEBUG
            print("ZeroConf: netService:didResolveAddress:\(netService)");
            #endif
            
            var service = jsonifyService(netService);
            
            service["action"] = "ADD";
            
            commandDelegate?.resolve(service);
        }
        
        @objc func netService(_ netService: NetService, didNotResolve errorDict: [String : NSNumber]) {
            #if DEBUG
            print("ZeroConf: netService:didNotResolve:\(netService) \(errorDict)")
            #endif
            
        }
        
        @objc func netServiceBrowser(_ netServiceBrowser: NetServiceBrowser,
                                     didRemove netService: NetService,
                                     moreComing moreServicesComing: Bool) {
            
            #if DEBUG
            print("ZeroConf: netServiceBrowser:didRemoveService:\(netService)");
            #endif
            services.removeValue(forKey: netService.name);
            
            var service = jsonifyService(netService);
            
            service["action"] = "RMV";
            
            commandDelegate?.resolve(service);
        }
        
        @objc func netServiceDidStop(_ netService: NetService) {
            
            nsb = nil;
            
            services.removeAll();
            
            commandDelegate = nil;
            
            commandDelegate?.reject("Error: stopped browsing");
        }
        
    }
    
    fileprivate static func jsonifyService(_ netService: NetService) -> Dictionary<String, Any> {
        
        var ipv4Addresses: [String] = []
        var ipv6Addresses: [String] = []
        for address in netService.addresses! {
            if let family = extractFamily(address) {
                if  family == 4 {
                    if let addr = extractAddress(address) {
                        ipv4Addresses.append(addr)
                    }
                } else if family == 6 {
                    if let addr = extractAddress(address) {
                        ipv6Addresses.append(addr)
                    }
                }
            }
        }
        
        if ipv6Addresses.count > 1 {
            ipv6Addresses = Array(Set(ipv6Addresses))
        }
        
        var txtRecord: [String: String] = [:]
        if let txtRecordData = netService.txtRecordData() {
            let dict = NetService.dictionary(fromTXTRecord: txtRecordData)
            for (key, data) in dict {
                txtRecord[key] = String(data: data, encoding:String.Encoding.utf8)
            }
        }
        
        var hostName:String = ""
        if netService.hostName != nil {
            hostName = netService.hostName!
        }
        
        var service: Dictionary<String, Any> = [:];
        
        service["type"] = netService.type;
        service["domain"] = netService.domain;
        service["name"] = netService.name;
        service["port"] = netService.port;
        service["ipv4Addresses"] = ipv4Addresses;
        service["ipv6Addresses"] = ipv6Addresses;
        service["txtRecord"] = txtRecord;
        service["hostname"] = hostName;
        
        return service
    }
    
    fileprivate static func extractFamily(_ addressBytes:Data) -> Int? {
        let addr = (addressBytes as NSData).bytes.load(as: sockaddr.self)
        if (addr.sa_family == sa_family_t(AF_INET)) {
            return 4
        }
        else if (addr.sa_family == sa_family_t(AF_INET6)) {
            return 6
        }
        else {
            return nil
        }
    }
    
    fileprivate static func extractAddress(_ addressBytes:Data) -> String? {
        var addr = (addressBytes as NSData).bytes.load(as: sockaddr.self)
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if (getnameinfo(&addr, socklen_t(addr.sa_len), &hostname,
                        socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0) {
            return String(cString: hostname)
        }
        return nil
    }
    
}
