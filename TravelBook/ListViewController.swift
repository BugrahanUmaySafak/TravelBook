import UIKit
import CoreData

final class ListViewController: UIViewController {

    @IBOutlet private weak var tableView: UITableView!

    private enum Constants {
        static let entityName = "Places"
        static let segueIdentifier = "toViewController"
        static let cellReuseIdentifier = "PlaceCell"
    }

    private struct PlaceListItem {
        let id: UUID
        let title: String
    }

    private var places: [PlaceListItem] = []
    private var selectedPlace: PlaceListItem?

    private var context: NSManagedObjectContext? {
        (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationBar()
        configureTableView()
        loadPlaces()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadPlaces()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == Constants.segueIdentifier,
              let destinationVC = segue.destination as? ViewController else {
            return
        }

        destinationVC.selectedTitle = selectedPlace?.title ?? ""
        destinationVC.selectedTitleID = selectedPlace?.id
    }

    @objc private func addButtonTapped() {
        selectedPlace = nil
        performSegue(withIdentifier: Constants.segueIdentifier, sender: nil)
    }

    private func configureNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addButtonTapped)
        )
    }

    private func configureTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.cellReuseIdentifier)
        tableView.tableFooterView = UIView()
    }

    private func loadPlaces() {
        guard let context else {
            showAlert(title: "Error", message: "Database context could not be created.")
            return
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: Constants.entityName)
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        request.returnsObjectsAsFaults = false

        do {
            let results = try context.fetch(request)
            places = results.compactMap { mapPlace(from: $0) }
            tableView.reloadData()
        } catch {
            showAlert(title: "Load Failed", message: "Places could not be loaded.")
        }
    }

    private func mapPlace(from object: NSManagedObject) -> PlaceListItem? {
        guard let id = object.value(forKey: "id") as? UUID else {
            return nil
        }

        let rawTitle = (object.value(forKey: "title") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let title = (rawTitle?.isEmpty == false) ? rawTitle! : "Untitled Place"

        return PlaceListItem(id: id, title: title)
    }

    private func deletePlace(_ place: PlaceListItem, completion: @escaping (Bool) -> Void) {
        guard let context else {
            showAlert(title: "Delete Failed", message: "Database context could not be created.")
            completion(false)
            return
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: Constants.entityName)
        request.predicate = NSPredicate(format: "id == %@", place.id as CVarArg)
        request.fetchLimit = 1
        request.returnsObjectsAsFaults = false

        do {
            guard let object = try context.fetch(request).first else {
                showAlert(title: "Delete Failed", message: "The selected place could not be found.")
                completion(false)
                return
            }

            context.delete(object)
            try context.save()

            if let index = places.firstIndex(where: { $0.id == place.id }) {
                places.remove(at: index)
                tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
            } else {
                tableView.reloadData()
            }

            completion(true)
        } catch {
            showAlert(title: "Delete Failed", message: "The selected place could not be deleted.")
            completion(false)
        }
    }

    private func presentDeleteConfirmation(for place: PlaceListItem, completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: "Delete Place",
            message: "\"\(place.title)\" will be permanently removed.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(false)
        })

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deletePlace(place, completion: completion)
        })

        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension ListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        places.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(
            withIdentifier: Constants.cellReuseIdentifier,
            for: indexPath
        )

        let place = places[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = place.title
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator

        return cell
    }
}

extension ListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectedPlace = places[indexPath.row]
        performSegue(withIdentifier: Constants.segueIdentifier, sender: nil)
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let place = places[indexPath.row]

        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.presentDeleteConfirmation(for: place, completion: completion)
        }

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
}
