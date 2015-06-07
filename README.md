# RouteDrawer

## How to use

#### Add Google Maps ios sdk api key to [AppDelegate](https://github.com/gokhangirgin/RouteDrawer/blob/master/RouteDrawer/AppDelegate.swift)

```swift
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        GMSServices.provideAPIKey("")
        // Override point for customization after application launch.
        return true
    }
```

```
$ pod install
```
**Run project**

####Dependendencies
- GoogleMaps ios sdk
- SwiftyJSON

###[RouteDrawer](https://github.com/gokhangirgin/RouteDrawer/blob/master/RouteDrawer/RouteDrawer/RouteDrawer.swift) 
begin & end coordinates can be requested with MODE { DRIVING, BICYCLING, WALKING }

```swift
class ViewController: UIViewController, DirectionDelegate {
override func viewDidLoad() {
   var rd : RouteDrawer = RouteDrawer()
        rd.setDirectionDelegate(self)
        rd.request(CLLocationCoordinate2D(latitude: 38.419223, longitude: 27.128052),
            endLocation: CLLocationCoordinate2D(latitude : 38.470460, longitude : 27.218995), mode: RouteDrawer.MODE.DRIVING)
  }
}
```
Direction delegate has Response callback that you will have after each request **status of response**, response body as json & routeDrawer itself.
```swift
 func Response(status: RouteDrawer.STATUS, response: JSON, routeDrawer: RouteDrawer) {
        
        routeDrawer.draw(self.view as! GMSMapView, directions: routeDrawer.getDirections(response)!, speed: RouteDrawer.SPEED.FASTEST, isCameraTilt: true, isCameraZoom: true, drawMarker: true, markerOptions: nil, flatMarker: false, drawLine: true, polyOpt: polyLine)
    }
```

Animation Delegate has 3 callbacks which are start, progress(step, total), finish can be used to show progress, or removing polyline, marker etc

```swift
protocol AnimationDelegate {
    func start() -> Void
    func finish() -> Void
    func progress(progress : Int, total: Int) -> Void
}
```

After successfull response in Response callback we can get directions & we can draw the route with draw method of routeDrawer which you can also provide custom marker, polyline etc see full list from [RouteDrawer](https://github.com/gokhangirgin/RouteDrawer/blob/master/RouteDrawer/RouteDrawer/RouteDrawer.swift). Unfortunetly google maps ios sdk can't be used except ui thread.

![in action](http://gifyu.com/images/routedrawergif.gif)
