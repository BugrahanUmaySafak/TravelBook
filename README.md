# TravelBook

An improved travel places app built with Swift, UIKit, Storyboard, MapKit, CoreLocation, and Core Data.

This project started as a course exercise and was later refactored into a cleaner, safer, and more maintainable version. The app allows users to save places with a name, note, and map location, view them in a list, open each item in a detail screen, update existing records, delete records with confirmation, and get directions in Apple Maps.

## About

This project is based on a hands-on app I built while taking a Udemy iOS development course.

The original version focused on learning the basics of:
- UIKit
- Storyboard-based UI development
- Navigation with segues
- `UITableView`
- Core Data
- `MapKit`
- `CoreLocation`
- Local data persistence
- Working with map annotations and directions

After building the original course version, I improved the project to make it cleaner, safer, and closer to a real portfolio project.

## Project Evolution

### Original Version

The first version of the project included:
- Manual list management using separate `titleArray` and `idArray`
- Data refresh flow based on `NotificationCenter`
- Core Data access written directly inside view controllers
- String-based Core Data key access with `value(forKey:)` and `setValue(_:forKey:)`
- Screen mode decisions based on empty string checks
- Saving coordinates through separate latitude and longitude variables
- Limited validation before saving a place
- Basic list and detail screen flow
- More force unwrap and force cast usage

This version was useful for learning the fundamentals, but it had tighter coupling, less safe data handling, and a structure that was harder to maintain.

### Improved Version

The final version includes:
- A cleaner list structure using a single place model instead of parallel arrays
- Reusable table view cells with a more modern UIKit configuration
- Delete support with swipe actions and a confirmation alert
- A simpler refresh flow using `viewWillAppear` instead of `NotificationCenter`
- Safer segue preparation with optional casting instead of force casting
- Better screen mode handling through `selectedTitleID` instead of relying on string checks
- Validation for required place name and selected map coordinate before saving
- Clearer separation of responsibilities inside `ViewController` through helper methods
- Better create and update logic for Core Data records
- Safer fetch requests using UUID predicates and fetch limits
- A cleaner one-selection annotation flow on the map
- Updated Apple Maps direction opening logic with newer `MapKit` usage
- Better access control with `final` classes and `private` helper methods
- Better readability and maintainability while keeping the original UIKit + Storyboard structure intact

## Tech Stack

- Swift
- UIKit
- Storyboard
- Core Data
- `UITableView`
- `MapKit`
- `CoreLocation`
- Apple Maps integration
- Xcode

## Features

- Save a new place with:
  - name
  - note
  - map location
- View saved places in a table view
- Open a detail screen for each saved place
- Update existing places
- Delete places with confirmation
- Persist data locally using Core Data
- Validate user input before saving
- Select a location by pressing and holding on the map
- Open directions in Apple Maps
- Use a cleaner and more maintainable project structure

## What I Practiced

With this project, I practiced:

- Building a multi-screen UIKit application
- Managing navigation with Storyboard segues
- Persisting local data with Core Data
- Working with `MapKit` and `CoreLocation`
- Managing map annotations and selected coordinates
- Opening directions in Apple Maps
- Refactoring beginner-level code into cleaner Swift code
- Improving code organization with helper methods and better access control
- Writing safer and more maintainable UIKit code without changing the original app architecture

## Notes

- This project began as a course practice app and was later improved by me
- The goal was not only to make the app work, but also to rewrite it in a cleaner and more professional way
- I kept the original UIKit + Storyboard structure instead of converting the project to MVVM or SwiftUI
- The improvements mainly focus on code quality, safety, readability, and maintainability
- This project helped me better understand the difference between a course-level implementation and a more polished portfolio version
