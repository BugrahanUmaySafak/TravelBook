import UIKit
import MapKit
import CoreLocation
import CoreData

final class ViewController: UIViewController {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var nameText: UITextField!
    @IBOutlet private weak var commentText: UITextField!
    @IBOutlet private weak var mapView: MKMapView!
    @IBOutlet private weak var saveButton: UIButton!

    var selectedTitle = ""
    var selectedTitleID: UUID?

    private let locationManager = CLLocationManager()
    private var selectedCoordinate: CLLocationCoordinate2D?
    private var hasCenteredOnUserLocation = false

    private enum Constants {
        static let entityName = "Places"
        static let annotationReuseIdentifier = "PlaceAnnotation"
        static let latitudeDelta = 0.05
        static let longitudeDelta = 0.05
        static let longPressDuration: TimeInterval = 1.0
    }

    private enum ScreenMode {
        case create
        case edit(UUID)
    }

    private enum PlacePersistenceError: Error {
        case placeNotFound
    }

    private struct PlaceDetails {
        let id: UUID
        let title: String
        let subtitle: String
        let coordinate: CLLocationCoordinate2D
    }

    private var screenMode: ScreenMode {
        if let id = selectedTitleID {
            return .edit(id)
        }
        return .create
    }

    private var context: NSManagedObjectContext? {
        (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureScreen()
        configureMapView()
        configureLocationServices()
        configureGestureRecognizer()
        loadPlaceIfNeeded()
    }

    @IBAction private func saveButtonClicked(_ sender: Any) {
        guard let context else {
            showAlert(title: "Error", message: "Database context could not be created.")
            return
        }

        guard let selectedCoordinate else {
            showAlert(title: "Location Missing", message: "Press and hold on the map to choose a place before saving.")
            return
        }

        let placeName = trimmedPlaceName()
        guard placeName.isEmpty == false else {
            showAlert(title: "Name Missing", message: "Enter a place name before saving.")
            return
        }

        let placeComment = trimmedPlaceComment()

        do {
            switch screenMode {
            case .create:
                insertPlace(name: placeName, comment: placeComment, coordinate: selectedCoordinate, into: context)
            case .edit(let placeID):
                try updatePlace(id: placeID, name: placeName, comment: placeComment, coordinate: selectedCoordinate, in: context)
            }

            try context.save()
            navigationController?.popViewController(animated: true)
        } catch PlacePersistenceError.placeNotFound {
            showAlert(title: "Update Failed", message: "The selected place could not be found.")
        } catch {
            showAlert(title: "Save Failed", message: "The place could not be saved. Please try again.")
        }
    }

    private func configureScreen() {
        switch screenMode {
        case .create:
            titleLabel.text = "Add A Place"
            subtitleLabel.text = "Press and hold on the map to choose a place, then save it with a name and note."
            updateSaveButtonTitle("Save Place")
        case .edit:
            titleLabel.text = selectedTitle.isEmpty ? "Place Details" : selectedTitle
            subtitleLabel.text = "Saved place details"
            updateSaveButtonTitle("Save Changes")
        }
    }

    private func updateSaveButtonTitle(_ title: String) {
        saveButton.setTitle(title, for: .normal)
        saveButton.configuration?.title = title
    }

    private func configureMapView() {
        mapView.delegate = self
        mapView.showsUserLocation = true
    }

    private func configureLocationServices() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        startLocationUpdatesIfNeeded()
    }

    private func configureGestureRecognizer() {
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        gestureRecognizer.minimumPressDuration = Constants.longPressDuration
        mapView.addGestureRecognizer(gestureRecognizer)
    }

    private func loadPlaceIfNeeded() {
        guard case .edit(let placeID) = screenMode else {
            return
        }

        guard let context else {
            showAlert(title: "Error", message: "Database context could not be created.")
            return
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: Constants.entityName)
        request.predicate = NSPredicate(format: "id == %@", placeID as CVarArg)
        request.fetchLimit = 1
        request.returnsObjectsAsFaults = false

        do {
            guard let object = try context.fetch(request).first,
                  let place = mapPlaceDetails(from: object) else {
                showAlert(title: "Load Failed", message: "The selected place could not be loaded.")
                return
            }

            applySavedPlace(place)
        } catch {
            showAlert(title: "Load Failed", message: "The selected place could not be loaded.")
        }
    }

    private func mapPlaceDetails(from object: NSManagedObject) -> PlaceDetails? {
        guard let id = object.value(forKey: "id") as? UUID,
              let title = object.value(forKey: "title") as? String,
              let subtitle = object.value(forKey: "subtitle") as? String,
              let latitude = object.value(forKey: "latitude") as? Double,
              let longitude = object.value(forKey: "longitude") as? Double else {
            return nil
        }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return PlaceDetails(id: id, title: title, subtitle: subtitle, coordinate: coordinate)
    }

    private func applySavedPlace(_ place: PlaceDetails) {
        nameText.text = place.title
        commentText.text = place.subtitle
        selectedCoordinate = place.coordinate

        titleLabel.text = place.title
        subtitleLabel.text = place.subtitle.isEmpty ? "Saved place details" : place.subtitle

        showSelectionAnnotation(
            at: place.coordinate,
            title: place.title,
            subtitle: place.subtitle.isEmpty ? nil : place.subtitle
        )

        centerMap(on: place.coordinate)
        locationManager.stopUpdatingLocation()
    }

    private func insertPlace(name: String, comment: String, coordinate: CLLocationCoordinate2D, into context: NSManagedObjectContext) {
        let newPlace = NSEntityDescription.insertNewObject(forEntityName: Constants.entityName, into: context)
        newPlace.setValue(UUID(), forKey: "id")
        newPlace.setValue(name, forKey: "title")
        newPlace.setValue(comment, forKey: "subtitle")
        newPlace.setValue(coordinate.latitude, forKey: "latitude")
        newPlace.setValue(coordinate.longitude, forKey: "longitude")
    }

    private func updatePlace(id: UUID, name: String, comment: String, coordinate: CLLocationCoordinate2D, in context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: Constants.entityName)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        request.returnsObjectsAsFaults = false

        guard let placeToUpdate = try context.fetch(request).first else {
            throw PlacePersistenceError.placeNotFound
        }

        placeToUpdate.setValue(name, forKey: "title")
        placeToUpdate.setValue(comment, forKey: "subtitle")
        placeToUpdate.setValue(coordinate.latitude, forKey: "latitude")
        placeToUpdate.setValue(coordinate.longitude, forKey: "longitude")
    }

    private func showSelectionAnnotation(at coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = title
        annotation.subtitle = subtitle

        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        mapView.addAnnotation(annotation)
        mapView.selectAnnotation(annotation, animated: true)
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        let span = MKCoordinateSpan(latitudeDelta: Constants.latitudeDelta, longitudeDelta: Constants.longitudeDelta)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        mapView.setRegion(region, animated: true)
    }

    private func openDirections(to coordinate: CLLocationCoordinate2D, name: String) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = name

        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        mapItem.openInMaps(launchOptions: launchOptions)
    }

    private func trimmedPlaceName() -> String {
        nameText.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func trimmedPlaceComment() -> String {
        commentText.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func currentAnnotationTitle() -> String {
        let currentName = trimmedPlaceName()
        if currentName.isEmpty == false {
            return currentName
        }

        switch screenMode {
        case .create:
            return "Selected Place"
        case .edit:
            return selectedTitle.isEmpty ? "Selected Place" : selectedTitle
        }
    }

    private func currentAnnotationSubtitle() -> String? {
        let currentComment = trimmedPlaceComment()
        return currentComment.isEmpty ? nil : currentComment
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard gestureRecognizer.state == .began else {
            return
        }

        let touchedPoint = gestureRecognizer.location(in: mapView)
        let touchedCoordinate = mapView.convert(touchedPoint, toCoordinateFrom: mapView)

        selectedCoordinate = touchedCoordinate

        showSelectionAnnotation(
            at: touchedCoordinate,
            title: currentAnnotationTitle(),
            subtitle: currentAnnotationSubtitle()
        )

        centerMap(on: touchedCoordinate)
        locationManager.stopUpdatingLocation()
    }

    private func startLocationUpdatesIfNeeded() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            guard case .create = screenMode, hasCenteredOnUserLocation == false else {
                return
            }
            locationManager.startUpdatingLocation()
        case .notDetermined:
            if case .create = screenMode {
                locationManager.requestWhenInUseAuthorization()
            }
        case .denied, .restricted:
            if case .create = screenMode {
                subtitleLabel.text = "Location access is off. You can still choose a place manually by pressing and holding on the map."
            }
        @unknown default:
            break
        }
    }
}

extension ViewController: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        startLocationUpdatesIfNeeded()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard case .create = screenMode,
              hasCenteredOnUserLocation == false,
              let coordinate = locations.last?.coordinate else {
            return
        }

        centerMap(on: coordinate)
        hasCenteredOnUserLocation = true
        locationManager.stopUpdatingLocation()
    }
}

extension ViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }

        let markerView: MKMarkerAnnotationView

        if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: Constants.annotationReuseIdentifier) as? MKMarkerAnnotationView {
            markerView = dequeuedView
            markerView.annotation = annotation
        } else {
            markerView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: Constants.annotationReuseIdentifier)
            markerView.canShowCallout = true
            markerView.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        }

        return markerView
    }

    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        guard case .edit = screenMode,
              let coordinate = view.annotation?.coordinate else {
            return
        }

        openDirections(to: coordinate, name: currentAnnotationTitle())
    }
}
