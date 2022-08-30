import Foundation
import Darwin
import CoreLocation

class Solar {
    
    // convinience method to return a unit-epoch data from a julian date
    func dateFromJulianDay(_ julianDay: Double) -> Date {
        let unixTime = (julianDay - 2440587) * 86400.0
        return Date(timeIntervalSince1970: unixTime)
    }
    
    func julianDayFromDate(_ date: Date) -> Double {
        //==let JD = Integer(365.25 * (Y + 4716)) + Integer(30.6001 * (M +1)) +
        let ti = date.timeIntervalSince1970
        return ((ti / 86400.0) + 2440587.5)
    }
    
    // calculate the elevation of the sun for a given date and location
    func sun(date: Date, lat: Double, lon: Double) -> Double {
        // these come in handy
        let twopi = Double.pi * 2
        let deg2rad = Double.pi / 180.0
        
        // latitude to radians
        let lat_radians = lat * deg2rad
        
        // the Astronomer's Almanac method used here is based on Epoch 2000, so we need to
        // convert the date into that format. We start by calculating "n", the number of
        // days since 1 January 2000. So if your date format is 1970-based, convert that
        // a pure julian date and pass that in. If your date is 2000-based, then
        // just let n = date
        let n = julianDayFromDate(date) - 2451545.0
        
        // it continues by calculating the position in ecliptic coordinates,
        // starting with the mean longitude of the sun in degrees, corrected for aberation
        var meanlong_degrees = 280.460 + (0.9856474 * n)
        meanlong_degrees = meanlong_degrees.truncatingRemainder(dividingBy: 360.0)
        
        // and the mean anomaly in degrees
        var meananomaly_degrees = 357.528 + (0.9856003 * n)
        meananomaly_degrees = meananomaly_degrees.truncatingRemainder(dividingBy: 360.0)
        let meananomaly_radians = meananomaly_degrees * deg2rad
        
        // and finally, the eliptic longitude in degrees
        var elipticlong_degrees = meanlong_degrees + (1.915 * sin(meananomaly_radians)) + (0.020 * sin(2 * meananomaly_radians))
        elipticlong_degrees = elipticlong_degrees.truncatingRemainder(dividingBy: 360.0)
        let elipticlong_radians = elipticlong_degrees * deg2rad
        
        // now we want to convert that to equatorial coordinates
        let obliquity_degrees = 23.439 - (0.0000004 * n)
        let obliquity_radians = obliquity_degrees * deg2rad
        
        // right ascention in radians
        let num = cos(obliquity_radians) * sin(elipticlong_radians)
        let den = cos(elipticlong_radians)
        var ra_radians = atan(num / den)
        ra_radians = ra_radians.truncatingRemainder(dividingBy: Double.pi)
        if den < 0 {
            ra_radians = ra_radians + Double.pi
        } else if num < 0 {
            ra_radians = ra_radians + twopi
        }
        // declination is simpler...
        let dec_radians = asin(sin(obliquity_radians) * sin(elipticlong_radians))
        
        // and from there, to local coordinates
        // start with the UTZ sidereal time, which is probably a lot easier in non-Swift languages
        var utzCal = Calendar(identifier: .gregorian)
        utzCal.timeZone = TimeZone(secondsFromGMT: 0)!
        let h = Double(utzCal.component(.hour, from: date))
        let m = Double(utzCal.component(.minute, from: date))
        let f: Double // universal time in hours and decimals (not days!)
        if h == 0 && m == 0 {
            f = 0.0
        } else if h == 0 {
            f = m / 60.0
        } else if m == 0 {
            f = h
        } else {
            f = h + (m / 60.0)
        }
        var utz_sidereal_time = 6.697375 + 0.0657098242 * n + f
        utz_sidereal_time = utz_sidereal_time.truncatingRemainder(dividingBy: 24.0)
        
        // then convert that to local sidereal time
        var localtime = utz_sidereal_time + lon / 15.0
        localtime = localtime.truncatingRemainder(dividingBy: 24.0)
        let localtime_radians = localtime * 15.0  * deg2rad
        
        // hour angle in radians
        var hourangle_radians =  localtime_radians - ra_radians
        hourangle_radians = hourangle_radians.truncatingRemainder(dividingBy: twopi)
        
        // get elevation in degrees
        let elevation_radians = (asin(sin(dec_radians) * sin(lat_radians) + cos(dec_radians) * cos(lat_radians) * cos(hourangle_radians)))
        let elevation_degrees = elevation_radians / deg2rad
        
        // all done!
        return elevation_degrees
    }
}




let solar = Solar()
let buildingOppositePosition = () // some lat / long
let sunElevationAngleFromBuilding = solar.sun(date: Date.now, lat: buildingOppositePosition.0, lon: buildingOppositePosition.1)

let buildingHeight = 50.0 // assume building height of 50m
let lengthOfShadow = buildingHeight * tan(sunElevationAngleFromBuilding)

let home = () // some lat long
let sunElevationAngleFromHome = solar.sun(date: Date.now, lat: home.0, lon: home.1)


if(sunElevationAngleFromHome < sunElevationAngleFromBuilding) {
    print("IN THE SUN!!")
} else {
    print("IN THE SHADOW!!")
}
