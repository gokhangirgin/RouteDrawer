//
//  RouteDrawer.swift
//
//  Created by Gökhan Girgin on 29.05.2015.
//  Copyright (c) 2015 GG. All rights reserved.
//

import Foundation
import GoogleMaps
import SwiftyJSON
protocol DirectionDelegate {
    func Response(status : RouteDrawer.STATUS, response : JSON, routeDrawer : RouteDrawer) -> Void
}
protocol AnimationDelegate {
    func start() -> Void
    func finish() -> Void
    func progress(progress : Int, total: Int) -> Void
}

class RouteDrawer {
    
    /*
        Request mode
    */
    enum MODE : String {
        case
        WALKING     = "walking",
        DRIVING     = "driving",
        BICYCLING   = "bicycling"
    }
    /*
        Response Status
    */
    enum STATUS : String {
        case
        OK                      = "OK",
        NOT_FOUND               = "NOT_FOUND",
        ZERO_RESULTS            = "ZERO_RESULTS",
        MAX_WAYPOINTS_EXCEEDED  = "MAX_WAYPOINTS_EXCEEDED",
        INVALID_REQUEST         = "INVALID_REQUEST",
        OVER_QUERY_LIMIT        = "OVER_QUERY_LIMIT",
        REQUEST_DENIED          = "REQUEST_DENIED",
        UNKNOWN_ERROR           = "UNKNOWN_ERROR"
    }
    /*
        Animation speed
    */
    enum SPEED : Double {
        case
        FASTEST = 1,
        FAST    = 2,
        NORMAL  = 3,
        SLOW    = 4,
        SLOWEST = 5
    }
    
    
    private var enableLogging           : Bool                      = false
    private var animateMarkerPosition   : CLLocationCoordinate2D?   = nil
    private var startPosition           : CLLocationCoordinate2D?   = nil
    private var endPosition             : CLLocationCoordinate2D?   = nil
    private var coordinateList          : [CLLocationCoordinate2D]? = nil
    private var animateMarker           : GMSMarker?                = nil
    private var animateLine             : GMSPolyline?              = nil
    private var googleMap               : GMSMapView?               = nil
    private var step                    : Int                       = -1
    private var animationSpeed          : Int                       = -1
    private var mode                    : String                    = STATUS.OK.rawValue
    private var mapZoom                 : Int                       = -1
    private var animateDistance         : Double                    = -1
    private var animateCamera           : Double                    = -1
    private var sumOfAnimateDistance    : Int                       = -1
    private var cameraFlag              : Bool                      = false
    private var drawMaker               : Bool                      = false
    private var drawLine                : Bool                      = false
    private var flatMarker              : Bool                      = false
    private var isCameraTilt            : Bool                      = false
    private var isCameraZoomed          : Bool                      = false
    private var isAnimated              : Bool                      = false
    private var directionDelegate       : DirectionDelegate?        = nil
    private var animationDelegate       : AnimationDelegate?        = nil
    
    init(){
        setCameraUpdateSpeed(SPEED.NORMAL)
    }
    
    func request(beginLocation : CLLocationCoordinate2D, endLocation : CLLocationCoordinate2D, mode : MODE) -> String {
        let urlStr : String = String(format:"http://maps.googleapis.com/maps/api/directions/json?origin=%.6f,%.6f&destination=%.6f,%.6f&sensor=false&units=metric&mode=%@", beginLocation.latitude, beginLocation.longitude, endLocation.latitude, endLocation.longitude, mode.rawValue)
        
        let url : NSURL = NSURL(string: urlStr)!
        
        if self.enableLogging {
            println(urlStr)
        }
        
        let urlSession = NSURLSession.sharedSession()
        
        let directionTask = urlSession.dataTaskWithURL(url) {
            (data, response, error) -> Void in
            if error != nil {
                println(error.localizedDescription)
            }
            else {
                let jsonData : JSON = JSON(data: data)
                println(jsonData.description)
                if self.directionDelegate != nil {
                    let statusOfResponse = jsonData["status"].stringValue
                    self.directionDelegate?.Response(self.getStatus(statusOfResponse), response: jsonData, routeDrawer: self)
                }
            }
        }
        directionTask.resume()
        return urlStr
    }
    
    func setLogging(state : Bool) -> Void {
        self.enableLogging = state
    }
    
    func getStatus(status : String) -> STATUS {
        
        switch status.uppercaseString {
        case "OK" :
            return STATUS.OK
        case "NOT_FOUND" :
            return STATUS.NOT_FOUND
        case "MAX_WAYPOINTS_EXCEEDED" :
            return STATUS.MAX_WAYPOINTS_EXCEEDED
        case "INVALID_REQUEST" :
            return STATUS.INVALID_REQUEST
        case "OVER_QUERY_LIMIT" :
            return STATUS.OVER_QUERY_LIMIT
        case "REQUEST_DENIED" :
            return STATUS.REQUEST_DENIED
        case "UNKNOWN_ERROR" :
            return STATUS.UNKNOWN_ERROR
        default :
            return STATUS.OK
        }
    
    }
    
    /*
    "duration" : {
        "text" : "1 dakika",
        "value" : 65
    }
    */
    func getDurations(json : JSON) -> [(String, Int)]?{
        
        var durations : [(String, Int)]? = nil
        if let routes = json["routes"].array {
            durations = [(String, Int)]()
            for route in routes {
                if let legs = route["legs"].array {
                    for leg : JSON in legs {
                        if let steps = leg["steps"].array {
                            for step in steps {
                                let tuple = (step["duration"]["text"].stringValue, step["duration"]["value"].intValue)
                                durations?.append(tuple)
                            }
                        }
                
                    }
                }
            }
        }
        return durations
    }
    /*
    "duration" : {
    "text" : "5 saat 18 dakika",
    "value" : 19087
    }
    */
    func getTotalDurations(json : JSON) -> [(String, Int)]?{
        var durations : [(String, Int)]? = nil
        if let routes = json["routes"].array {
            durations = [(String, Int)]()
            for route in routes {
                if let legs = route["legs"].array {
                    for leg : JSON in legs {
                        let tuple = (leg["duration"]["text"].stringValue, leg["duration"]["value"].intValue)
                        durations?.append(tuple)
                    }
                }
            }
        }
        return durations
    }
    
    func getStartEndAddresses(json : JSON) -> [(String, String)]?{
        var adresses : [(String, String)]? = nil
        if let routes = json["routes"].array {
            adresses = [(String, String)]()
            for route in routes {
                if let legs = route["legs"].array {
                    for leg : JSON in legs {
                        let tuple = (leg["start_address"].stringValue, leg["end_address"].stringValue)
                        adresses?.append(tuple)
                    }
                }
            }
        }
        return adresses
    }
    func getCopyRights(json : JSON) -> [String]? {
        var copyRights : [String]? = nil
        if let routes = json["routes"].array {
            copyRights = [String]()
            for route in routes {
                if let legs = route["legs"].array {
                    for leg : JSON in legs {
                        let tuple = leg["copyrights"].stringValue
                        copyRights?.append(tuple)
                    }
                }
            }
        }
        return copyRights
    }
    func getDirections(json : JSON) -> [CLLocationCoordinate2D] {
        
        return []
    }
    func getSection(json : JSON) -> [CLLocationCoordinate2D] {
        return []
    }
    func getPolyline(json : JSON) -> GMSPolyline? {
        return nil
    }
    private func decodePoly(data : String) -> [CLLocationCoordinate2D] {
        return []
    }
    func setDirectionDelegate(directionDelegate : DirectionDelegate) -> Void {
        self.directionDelegate = directionDelegate
    }
    func setAnimationDelegate(animationDelegate : AnimationDelegate) -> Void {
        self.animationDelegate = animationDelegate
    }
    func animateDirections(
        gm          : GMSMapView,
        directions  : [CLLocationCoordinate2D],
        speed       : SPEED,
        cameraLock  : Bool,
        isCameraTilt: Bool,
        isCameraZoom: Bool,
        drawMarker  : Bool,
        drawLine    : Bool,
        polyOpt     : UIColor) -> Void {}
    func cancelAnimated() -> Void {
        self.isAnimated = false
    }
    func isAnimatedInProgress() -> Bool {
        return self.isAnimated
    }
    func getAnimateMarker() -> GMSMarker? {
        return animateMarker
    }
    func getPolyline() -> GMSPolyline? {
        return animateLine
    }
    func getNewPosition(begin : CLLocationCoordinate2D, end : CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D()
    }
    func getBearing() -> Float {
        return 0
    }
    func setCameraUpdateSpeed(speed : SPEED) -> Void {
    
        switch speed {
        case .SLOWEST :
            self.animateDistance = 0.000005
            self.animationSpeed  = 20
            self.animateCamera   = 0.0004
            self.mapZoom         = 19
        case .SLOW   :
            self.animateDistance = 0.00001
            self.animationSpeed  = 20
            self.animateCamera   = 0.0008
            self.mapZoom         = 18
        case .NORMAL :
            self.animateDistance = 0.00005
            self.animationSpeed  = 20
            self.animateCamera   = 0.002
            self.mapZoom         = 16
        case .FAST   :
            self.animateDistance = 0.0001
            self.animationSpeed  = 20
            self.animateCamera   = 0.004
            self.mapZoom         = 15
        case .FASTEST:
            self.animateDistance = 0.001
            self.animationSpeed  = 20
            self.animateCamera   = 0.004
            self.mapZoom         = 13
            
        }
    }
    
}