//
//  ViewController.swift
//  RouteDrawer
//
//  Created by Gökhan Girgin on 29.05.2015.
//  Copyright (c) 2015 GG. All rights reserved.
//

import UIKit
import GoogleMaps
import SwiftyJSON
class ViewController: UIViewController, DirectionDelegate {
    var polyLine : GMSPolyline = GMSPolyline()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        var camera = GMSCameraPosition.cameraWithLatitude(38.419223,
            longitude: 27.128052, zoom: 15)
        var mapView = GMSMapView.mapWithFrame(CGRectZero, camera: camera)
        mapView.myLocationEnabled = true
        self.view = mapView
        
        
        var rd : RouteDrawer = RouteDrawer()
        rd.setDirectionDelegate(self)
        rd.request(CLLocationCoordinate2D(latitude: 38.419223, longitude: 27.128052),
            endLocation: CLLocationCoordinate2D(latitude : 38.470460, longitude : 27.218995), mode: RouteDrawer.MODE.DRIVING)
        
        polyLine.strokeColor = UIColor.darkTextColor()
        polyLine.strokeWidth=3

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func Response(status: RouteDrawer.STATUS, response: JSON, routeDrawer: RouteDrawer) {
        
        routeDrawer.draw(self.view as! GMSMapView, directions: routeDrawer.getDirections(response)!, speed: RouteDrawer.SPEED.FASTEST, isCameraTilt: true, isCameraZoom: true, drawMarker: true, markerOptions: nil, flatMarker: false, drawLine: true, polyOpt: polyLine)
    }
}

