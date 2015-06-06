//
//  RouteDrawer.swift
//
//  Created by Gökhan Girgin on 29.05.2015.
//  Copyright (c) 2015 GG. All rights reserved.
//

import Foundation
import GoogleMaps
import SwiftyJSON
import GLKit
extension String {
    func charAt (i: Int) -> String {
        return String(self[advance(self.startIndex, i)])
    }
}

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
    enum SPEED : Int {
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
    private var coordinateList          : [CLLocationCoordinate2D]  = [CLLocationCoordinate2D]()
    private var animateMarker           : GMSMarker?                = nil
    private var animateLine             : GMSPolyline?              = nil
    private var googleMap               : GMSMapView?               = nil
    private var step                    : Int                       = -1
    private var animationSpeed          : Int                       = -1
    private var mode                    : String                    = STATUS.OK.rawValue
    private var mapZoom                 : Double                    = -1
    private var animateDistance         : Double                    = -1
    private var animateCamera           : Double                    = -1
    private var sumOfAnimateDistance    : Double                    = 0
    private var cameraFlag              : Bool                      = false
    private var drawMarker              : Bool                      = false
    private var drawLine                : Bool                      = false
    private var flatMarker              : Bool                      = false
    private var isCameraTilt            : Bool                      = false
    private var isCameraZoom            : Bool                      = false
    private var isAnimated              : Bool                      = false
    private var directionDelegate       : DirectionDelegate?        = nil
    private var animationDelegate       : AnimationDelegate?        = nil
    
    init(){
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
                                if self.enableLogging {
                                    println("Duration : " + step["duration"]["text"].stringValue + ", asInt : " + String(step["duration"]["value"].intValue))
                                }

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
                        if self.enableLogging {
                            println("Duration : " + leg["duration"]["text"].stringValue + ", asInt : " + String(leg["duration"]["value"].intValue))
                        }
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
                        if self.enableLogging {
                            println("Start Address : " + leg["start_address"].stringValue + ", End Address : " + leg["end_address"].stringValue)
                        }
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
                        if self.enableLogging {
                            println("Copyrights : " + leg["copyrights"].stringValue)
                        }
                        copyRights?.append(tuple)
                    }
                }
            }
        }
        return copyRights
    }
    func getDirections(json : JSON) -> [CLLocationCoordinate2D]? {
        var points : [CLLocationCoordinate2D]? = nil
        if let routes = json["routes"].array {
            points = [CLLocationCoordinate2D]()
            for route in routes {
                if let legs = route["legs"].array {
                    for leg : JSON in legs {
                        let start_location = CLLocationCoordinate2D(latitude: leg["start_location"]["lat"].double!,
                            longitude: leg["start_location"]["lng"].double!)
                        
                        if self.enableLogging {
                            let str = String(format: "Start Loc  lat: %.6f, lng : %.6f", start_location.latitude, start_location.longitude)
                            println(str)
                            
                        }
                        
                        points?.append(start_location)
                        
                        if let steps = leg["steps"].array {
                            
                            for step : JSON in steps {
                                let step_start_location = CLLocationCoordinate2D(latitude: step["start_location"]["lat"].double!,
                                    longitude: step["start_location"]["lng"].double!)
                                
                                if self.enableLogging {
                                    let str = String(format: "Step Start Loc  lat: %.6f, lng : %.6f", step_start_location.latitude, step_start_location.longitude)
                                    println(str)
                                    
                                }
                                
                                points?.append(step_start_location)
                                
                                points?.extend(self.decodePoly(step["polyline"]["points"].string!))
                                
                                let step_end_location = CLLocationCoordinate2D(latitude: step["end_location"]["lat"].double!,
                                    longitude: step["end_location"]["lng"].double!)
                                if self.enableLogging {
                                    let str = String(format: "Step End Loc  lat: %.6f, lng : %.6f", step_end_location.latitude, step_end_location.longitude)
                                    println(str)
                                    
                                }
                                points?.append(step_end_location)
                            
                            }
                        
                        }
                        
                        let end_location = CLLocationCoordinate2D(latitude: leg["end_location"]["lat"].double!,
                            longitude: leg["end_location"]["lng"].double!)
                        if self.enableLogging {
                            let str = String(format: "End Loc  lat: %.6f, lng : %.6f", end_location.latitude, end_location.longitude)
                            println(str)
                            
                        }
                        points?.append(end_location)
                    }
                }
            }
        }
        return points
    }
    func getSection(json : JSON) -> [CLLocationCoordinate2D] {
        return []
    }
    private func decodePoly(data : String) -> [CLLocationCoordinate2D] {
        var points : [CLLocationCoordinate2D] = [CLLocationCoordinate2D]()
        var index : Int = 0
        var length : Int = count(data)
        var lat = 0, lng = 0
        while index < length {
            var b  = 0
            var shift = 0
            var result = 0
            
            do {
                //unicode value :( refactor
                for char in data.charAt(index++).unicodeScalars {
                    b = Int(char.value)
                }
                b -= 63
                result |= (b & 0x1f) << shift
                shift += 5
                
            }while(b >= 0x20)
            
            var dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lat += dlat;
            shift = 0;
            result = 0;
            do {
                //unicode value :( refactor
                for char in data.charAt(index++).unicodeScalars {
                    b = Int(char.value)
                }
                b -= 63
                result |= (b & 0x1f) << shift
                shift += 5
            } while (b >= 0x20);
            var dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
            lng += dlng
            
            var position : CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: Double(lat) / 1E5, longitude: Double(lng) / 1E5)
            if self.enableLogging {
                let str = String(format: "Decoded Poly lat: %.6f, lng : %.6f", position.latitude, position.longitude)
                println(str)
                
            }
            points.append(position)
            
        }
        return points
    }
    func setDirectionDelegate(directionDelegate : DirectionDelegate) -> Void {
        self.directionDelegate = directionDelegate
    }
    func setAnimationDelegate(animationDelegate : AnimationDelegate) -> Void {
        self.animationDelegate = animationDelegate
    }
    func draw(
        gm              : GMSMapView,
        directions      : [CLLocationCoordinate2D],
        speed           : SPEED,
        cameraLock      : Bool,
        isCameraTilt    : Bool,
        isCameraZoom    : Bool,
        drawMarker      : Bool,
        markerOptions   : GMSMarker?,
        flatMarker      : Bool,
        drawLine        : Bool,
        polyOpt         : UIColor?) -> Void {
    
            if directions.count > 0 {
                self.isAnimated = true
                self.coordinateList = directions
                self.animationSpeed = speed.rawValue
                self.drawMarker = drawMarker
                self.drawLine = drawLine
                self.flatMarker = flatMarker
                self.animateMarker = markerOptions
                self.drawLine = drawLine
                self.step = 0
                self.cameraFlag = true
                self.isCameraZoom = isCameraZoom
                self.isCameraTilt = isCameraTilt
                self.googleMap = gm
                
                self.setCameraUpdateSpeed(speed)
                
                self.startPosition = coordinateList[self.step]
                self.endPosition   = coordinateList[(self.step + 1)]
                
                self.animateMarkerPosition = startPosition
                
                if self.animationDelegate != nil {
                    self.animationDelegate?.progress(step, total: self.coordinateList.count)
                }
                if(cameraFlag){
                    //ameraWithTarget(target: CLLocationCoordinate2D, zoom: Float, bearing: CLLocationDirection, viewingAngle: Double)
                    let bearing : Float = getBearing(startPosition!, end: endPosition!)
                    let cameraPosition : GMSCameraPosition = GMSCameraPosition.cameraWithTarget(self.animateMarkerPosition!,
                        zoom: (isCameraZoom ? Float(self.mapZoom) : self.googleMap?.camera.zoom)!,
                        bearing: CLLocationDirection(bearing), viewingAngle: (isCameraTilt ? 90.0 : self.googleMap?.camera.viewingAngle)!)
                    
                    self.googleMap?.animateToCameraPosition(cameraPosition)
                    
                    if self.drawMarker {
                        if markerOptions != nil {
                            self.animateMarker = markerOptions
                            self.animateMarker?.position = self.startPosition!
                        }
                        else {
                            self.animateMarker = GMSMarker()
                            self.animateMarker?.position = self.startPosition!
                        }
                        self.animateMarker?.map = self.googleMap
                    }
                    
                    if self.drawLine {
                        if polyOpt != nil {
                            self.animateLine = GMSPolyline()
                            var path : GMSMutablePath = GMSMutablePath()
                            path.addCoordinate(startPosition!)
                            path.addCoordinate(endPosition!)
                            self.animateLine?.path = path
                            self.animateLine?.strokeColor = polyOpt!
                            self.animateLine?.strokeWidth = 5
                            
                            
                        }
                        else {
                            self.animateLine = GMSPolyline()
                            var path : GMSMutablePath = GMSMutablePath()
                            path.addCoordinate(startPosition!)
                            path.addCoordinate(endPosition!)
                            self.animateLine?.path = path
                            self.animateLine?.strokeColor = UIColor.blackColor()
                            self.animateLine?.strokeWidth = 5
                        }
                        self.animateLine?.map = self.googleMap
                    }
                    //start with async task from here
                    animateCoordinates()
                    if self.animationDelegate != nil {
                        self.animationDelegate?.start()
                    }
                    
                }
            }
    
    }
    private func animateCoordinates(){
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_MSEC * UInt64(self.animationSpeed)))
        dispatch_after(delayTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0)) { () -> Void in
            self.animateMarkerPosition = self.getNewPosition(self.animateMarkerPosition!, end: self.endPosition!)
            
            if self.drawMarker {
                self.animateMarker?.position = self.animateMarkerPosition!
            }
            
            if self.drawLine {
                var points : GMSMutablePath = self.animateLine?.path as! GMSMutablePath
                points.addCoordinate(self.animateMarkerPosition!)
                self.animateLine?.path = points
            }
            
            if self.animateMarkerPosition?.latitude == self.endPosition?.latitude &&
                self.animateMarkerPosition?.longitude == self.endPosition?.longitude {
                    
                    if self.step == self.coordinateList.count - 2 {
                        //end of animation set free
                        self.isAnimated = false
                        self.sumOfAnimateDistance = 0
                        if self.animationDelegate != nil {
                            self.animationDelegate?.finish()
                        }
                    }else {
                        self.step++
                        self.startPosition = self.coordinateList[self.step]
                        self.endPosition = self.coordinateList[self.step + 1]
                        
                        self.animateMarkerPosition = self.startPosition
                        
                        if self.flatMarker && self.step + 3 < self.coordinateList.count - 1 {
                            let rotation : Float = self.getBearing(self.animateMarkerPosition!, end: self.coordinateList[self.step + 3]) + 180;
                            self.animateMarker?.rotation = CLLocationDegrees(rotation)
                        }
                        
                        if self.animationDelegate != nil {
                            self.animationDelegate?.progress(self.step, total: self.coordinateList.count)
                        }
                    }
            }
            
            if self.cameraFlag && (self.sumOfAnimateDistance > self.animateCamera || !self.isAnimatedInProgress()) {
                self.sumOfAnimateDistance = 0
                
                let bearing : Float = self.getBearing(self.startPosition!, end: self.endPosition!)
                let cameraPosition : GMSCameraPosition = GMSCameraPosition.cameraWithTarget(self.animateMarkerPosition!,
                    zoom: (self.isCameraZoom ? Float(self.mapZoom) : self.googleMap?.camera.zoom)!,
                    bearing: CLLocationDirection(bearing), viewingAngle: (self.isCameraTilt ? 90.0 : self.googleMap?.camera.viewingAngle)!)
                
                self.googleMap?.animateToCameraPosition(cameraPosition)
                
            }
            
            if self.isAnimatedInProgress() {
                self.animateCoordinates()
            }
            
        }
        
    }
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
        let lat : Double = abs(begin.latitude - end.latitude)
        let lng : Double = abs(begin.longitude - end.longitude)
        
        let dist = sqrt(pow(lat, 2) + pow(lng, 2))
        
        if(dist >= animateDistance) {
            var angle : Float = -1
            if(begin.latitude <= end.latitude && begin.longitude <= end.longitude) {
                angle = GLKMathRadiansToDegrees(Float(atan(lng / lat)))
            }
            else if(begin.latitude > end.latitude && begin.longitude <= end.longitude){
                 angle = (90 - GLKMathRadiansToDegrees(Float(atan(lng / lat)))) + 90;
            }
            else if(begin.latitude > end.latitude && begin.longitude > end.longitude){
                angle = GLKMathRadiansToDegrees(Float(atan(lng / lat))) + 180;
            }
            else if(begin.latitude <= end.latitude && begin.longitude > end.longitude)
            {
                angle = (90 - GLKMathRadiansToDegrees(Float(atan(lng / lat)))) + 270;
            }
            let x : Double = Double(cos(GLKMathDegreesToRadians(angle))) * self.animateDistance
            let y : Double = Double(sin(GLKMathDegreesToRadians(angle))) * self.animateDistance
            self.sumOfAnimateDistance += self.animateDistance
            let new_lat : Double = begin.latitude + x
            let new_lng : Double = begin.longitude + y
            return CLLocationCoordinate2D(latitude: new_lat, longitude: new_lng)
        }
        else {
            return end
        }
    }
    func getBearing(begin : CLLocationCoordinate2D, end : CLLocationCoordinate2D) -> Float {
        let lat : Double = abs(begin.latitude - end.latitude)
        let lng : Double = abs(begin.longitude - end.longitude)
        if(begin.latitude < end.latitude && begin.longitude < end.longitude){
            return Float((GLKMathRadiansToDegrees(Float(atan(lng / lat)))))
        }
        else if(begin.latitude >= end.latitude && begin.longitude < end.longitude){
            return Float(((90 - GLKMathRadiansToDegrees(Float(atan(lng / lat)))) + 90))
        }
        else if(begin.latitude >= end.latitude && begin.longitude >= end.longitude){
            return  Float((GLKMathRadiansToDegrees(Float(atan(lng / lat))) + 180))
        }
        else if(begin.latitude < end.latitude && begin.longitude >= end.longitude){
            return Float(((90 - GLKMathRadiansToDegrees(Float(atan(lng / lat)))) + 270))
        }
        return -1;
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