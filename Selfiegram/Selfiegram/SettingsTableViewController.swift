//
//  SettingsTableViewController.swift
//  Selfiegram
//
//  Created by Pham Hoang Minh on 19/5/26.
//

import UIKit
import UserNotifications

enum SettingsKey: String {
    case saveLocation
}

class SettingsTableViewController: UITableViewController {

    @IBOutlet weak var locationSwitch: UISwitch!
    
    @IBOutlet weak var reminderSwitch: UISwitch!
    
    @IBAction func locationSwitchToggled(_ sender: Any) {
        // {saveLocation: true/false}
        UserDefaults.standard.set(locationSwitch.isOn, forKey: SettingsKey.saveLocation.rawValue)
    }
    
    @IBAction func reminderSwitchToggled(_ sender: Any) {
        // get the current Notification Center
        let current = UNUserNotificationCenter.current()
        switch reminderSwitch.isOn {
        case true:
            // type of notifications. "alert" in our case
            let notificationsOptions: UNAuthorizationOptions = [.alert]
            // Ask permission to send notifications
            current.requestAuthorization(
                options: notificationsOptions,
                completionHandler: { (granted, error) in
                    if granted {
                        // queue the notification
                        self.addNotificationRequest()
                    }
                    // if User doesn't granted notification permission => turn switch back OFF
                    self.updateReminderSwitch()
                }
            )
        case false:
            current.removeAllPendingNotificationRequests()
        }
    }
    
    // type of notification
    private let notificationId = "SelfiegramReminder"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // change appearance of switch accordingly
        locationSwitch.isOn = UserDefaults.standard.bool(forKey: SettingsKey.saveLocation.rawValue)
        updateReminderSwitch()
    }
    
    func addNotificationRequest() {
        // get Notification Center
        let current = UNUserNotificationCenter.current()
        // remove pending notifications
        current.removeAllPendingNotificationRequests()
        // prepare content
        let content = UNMutableNotificationContent()
        content.title = "Take a selfie!"
        // create Date component at "10AM"
        var components = DateComponents()
        components.setValue(13, for: Calendar.Component.hour)
        // batch job
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        // create request
        let request = UNNotificationRequest(identifier: self.notificationId, content: content, trigger: trigger)
        // add to Notification Center
        // handler will execute when we finish adding "request" to "Notification Center"
        current.add(request, withCompletionHandler: { (error) in
            self.updateReminderSwitch() // update UISwitch on front-end
        })
    }
    
    // update UISwitch appearance based
    // user approves or not => "enabled" or "disabled"
    // there is a scheduled to notify => "active" or "non-active"
    func updateReminderSwitch() {
        UNUserNotificationCenter.current().getNotificationSettings {
            (settings) in
            switch settings.authorizationStatus {
            case .authorized:
                // get current noti requests in NC and check their IDs
                UNUserNotificationCenter.current().getPendingNotificationRequests(
                    completionHandler: {
                        (requests) in
                        // we "enable" AND "activate" if list of requests has at least 1 with our wanted ID
                        let active = requests.filter({ $0.identifier == self.notificationId }).count > 0
                        self.updateReminderUI(enabled: true, active: active)
                    }
                )
            case .denied:
                // we "disable" AND "non-activate" that button when User clicks "Denied"
                self.updateReminderUI(enabled: false, active: false)
            case .notDetermined:
                // switch is "enable" BUT "non-activate" when User hasn't been asked yet
                self.updateReminderUI(enabled: true, active: false)
            @unknown default:
                self.updateReminderUI(enabled: false, active: false)
            }
        }
    }
    
    func updateReminderUI(enabled: Bool, active: Bool) {
        // to make this closure run in Main-thread because Notification Center runs on the background (async)
        OperationQueue.main.addOperation {
            self.reminderSwitch.isEnabled = enabled
            self.reminderSwitch.isOn = active
        }
    }
}
